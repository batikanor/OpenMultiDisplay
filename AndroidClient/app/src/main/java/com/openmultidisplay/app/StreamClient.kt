package com.openmultidisplay.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Process
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class StreamClient(
    private val host: String,
    private val port: Int,
    private val context: Context? = null,
) {
    private var socket: Socket? = null
    private var inputStream: DataInputStream? = null
    private var outputStream: DataOutputStream? = null
    private var isConnected = false

    // Callback includes actual frame size (may differ from buffer.size due to pooling),
    // receive timestamp, and whether the frame can restart HEVC decoding.
    var onFrameReceived: ((ByteArray, Int, Long, Boolean) -> Unit)? = null
    var onConnectionStatus: ((Boolean) -> Unit)? = null
    var onDisplaySize: ((Int, Int, Int) -> Unit)? = null // width, height, rotation
    var onStats: ((Double, Double) -> Unit)? = null

    private var bytesReceived = 0L
    private var framesReceived = 0L
    private var diagFrameCount = 0L
    private var lastStatsTime = System.currentTimeMillis()
    private val keyframeRequestLock = Any()
    private var lastKeyframeRequestNs = 0L
    private var lastKeyframeReceivedNs = 0L

    // Buffer pooling reduces GC pressure from per-frame allocations.
    private val bufferPool = ArrayDeque<ByteArray>(FRAME_BUFFER_POOL_LIMIT)
    private val poolLock = Any()

    /**
     * Acquire a pooled buffer, or allocate a new one if no reusable buffer is large enough.
     */
    private fun acquireBuffer(minSize: Int): ByteArray {
        synchronized(poolLock) {
            val iterator = bufferPool.iterator()
            while (iterator.hasNext()) {
                val buffer = iterator.next()
                if (buffer.size >= minSize) {
                    iterator.remove()
                    return buffer
                }
            }
        }
        return ByteArray(minSize)
    }

    /**
     * Release a buffer back to the pool after decode completes.
     */
    fun releaseBuffer(buffer: ByteArray) {
        synchronized(poolLock) {
            if (bufferPool.size < FRAME_BUFFER_POOL_LIMIT) {
                bufferPool.addLast(buffer)
            }
        }
    }

    // High-priority thread for touch events to minimize latency
    // Use THREAD_PRIORITY_DISPLAY instead of URGENT_DISPLAY to avoid starving system processes
    private val touchExecutor =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(
                {
                    // Use DISPLAY priority (less aggressive than URGENT_DISPLAY).
                    // ThreadFactory runs on the caller thread, so set Linux priority
                    // from inside the worker thread before processing touch writes.
                    try {
                        Process.setThreadPriority(Process.THREAD_PRIORITY_DISPLAY)
                    } catch (_: Exception) {
                    }
                    runnable.run()
                },
                "TouchThread",
            ).apply {
                priority = Thread.MAX_PRIORITY
            }
        }
    private val touchDispatcher = touchExecutor.asCoroutineDispatcher()
    private val touchScope = CoroutineScope(touchDispatcher)

    suspend fun connect() =
        withContext(Dispatchers.IO) {
            try {
                val connectedSocket =
                    Socket(host, port).apply {
                        tcpNoDelay = true
                    }
                socket = connectedSocket
                inputStream =
                    DataInputStream(
                        BufferedInputStream(connectedSocket.getInputStream(), READ_BUFFER_SIZE_BYTES),
                    )
                outputStream = DataOutputStream(connectedSocket.getOutputStream())
                advertiseFrameMetadataSupport()
                isConnected = true
                lastKeyframeReceivedNs = 0L
                synchronized(keyframeRequestLock) {
                    lastKeyframeRequestNs = 0L
                }

                diagLog("Connected to $host:$port")
                onConnectionStatus?.invoke(true)

                receiveData()
            } catch (e: Exception) {
                Log.e(TAG, "Connection error", e)
                onConnectionStatus?.invoke(false)
                cleanup()
            }
        }

    sealed class WirelessConnectError(msg: String) : Exception(msg) {
        object NetworkUnreachable : WirelessConnectError("Mac unreachable - check both on same WiFi")

        object TokenRejected : WirelessConnectError("Token rejected - re-pair required")

        object ProtocolError : WirelessConnectError("Connection error, please rescan QR")
    }

    /**
     * Wireless connect: opens TCP, performs auth handshake, then resumes the existing receive loop on success.
     * Throws WirelessConnectError on any failure.
     */
    suspend fun connectWireless(
        token: ByteArray,
        deviceName: String,
    ) = withContext(Dispatchers.IO) {
        Log.i(TAG, "connectWireless: trying $host:$port (device=$deviceName, token bytes=${token.size})")

        // Force the socket onto the active WiFi network. On some Android setups
        // (especially LG/Android 12), an app's default outbound socket may take
        // a route that silently drops LAN traffic; binding to the WIFI Network
        // explicitly avoids that.
        val s =
            try {
                val sock = Socket()
                sock.tcpNoDelay = true
                val wifiNetwork =
                    context?.let { ctx ->
                        val cm = ctx.getSystemService(ConnectivityManager::class.java)
                        cm.allNetworks.firstOrNull { net ->
                            val caps = cm.getNetworkCapabilities(net)
                            caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true &&
                                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        }
                    }
                if (wifiNetwork != null) {
                    Log.i(TAG, "connectWireless: binding socket to WiFi network $wifiNetwork")
                    wifiNetwork.bindSocket(sock)
                } else {
                    Log.w(TAG, "connectWireless: no WiFi network found, using default routing")
                }
                sock.connect(java.net.InetSocketAddress(host, port), WIFI_CONNECT_TIMEOUT_MS)
                sock
            } catch (e: java.net.SocketTimeoutException) {
                Log.e(TAG, "connectWireless: TCP connect timeout to $host:$port (${WIFI_CONNECT_TIMEOUT_MS}ms)")
                throw WirelessConnectError.NetworkUnreachable
            } catch (e: IOException) {
                Log.e(
                    TAG,
                    "connectWireless: TCP connect failed to $host:$port: ${e.javaClass.simpleName}: ${e.message}",
                )
                throw WirelessConnectError.NetworkUnreachable
            }
        Log.i(
            TAG,
            "connectWireless: TCP connected, sending handshake " +
                "(${AuthHandshake.REQUEST_FIXED_SIZE_BYTES + deviceName.toByteArray().size} bytes)",
        )

        val request = AuthHandshake.encodeRequest(token, deviceName)
        try {
            s.getOutputStream().write(request)
            s.getOutputStream().flush()
        } catch (e: IOException) {
            s.closeQuietly()
            throw WirelessConnectError.NetworkUnreachable
        }

        val responseBuf = ByteArray(AuthHandshake.RESPONSE_SIZE_BYTES)
        var read = 0
        try {
            while (read < responseBuf.size) {
                val r = s.getInputStream().read(responseBuf, read, responseBuf.size - read)
                if (r <= 0) break
                read += r
            }
        } catch (e: IOException) {
            s.closeQuietly()
            throw WirelessConnectError.NetworkUnreachable
        }
        if (read != responseBuf.size) {
            s.closeQuietly()
            throw WirelessConnectError.ProtocolError
        }

        val status =
            AuthHandshake.parseResponse(responseBuf) ?: run {
                s.closeQuietly()
                throw WirelessConnectError.ProtocolError
            }
        Log.i(TAG, "connectWireless: handshake response status=$status")
        when (status) {
            AuthHandshake.ResponseStatus.OK -> {
                socket = s
                inputStream = DataInputStream(BufferedInputStream(s.getInputStream(), READ_BUFFER_SIZE_BYTES))
                outputStream = DataOutputStream(s.getOutputStream())
                advertiseFrameMetadataSupport()
                isConnected = true
                diagLog("Wireless connected to $host:$port")
                onConnectionStatus?.invoke(true)
                receiveData()
            }
            AuthHandshake.ResponseStatus.INVALID_TOKEN -> {
                s.closeQuietly()
                throw WirelessConnectError.TokenRejected
            }
            else -> {
                s.closeQuietly()
                throw WirelessConnectError.ProtocolError
            }
        }
    }

    private fun advertiseFrameMetadataSupport() {
        outputStream?.let { out ->
            out.write(WireProtocol.encodeClientMetadataSupport())
            out.flush()
            diagLog("Advertised frame metadata support")
        }
    }

    private suspend fun receiveData() =
        withContext(Dispatchers.IO) {
            val input = inputStream ?: return@withContext

            try {
                while (isConnected) {
                    val type = input.readByte()

                    when (type.toInt()) {
                        WireProtocol.MESSAGE_VIDEO_FRAME -> {
                            receiveVideoFrame(input, hasMetadata = false)
                        }

                        WireProtocol.MESSAGE_VIDEO_FRAME_WITH_METADATA -> {
                            receiveVideoFrame(input, hasMetadata = true)
                        }

                        WireProtocol.MESSAGE_DISPLAY_CONFIG -> {
                            val width = input.readInt()
                            val height = input.readInt()
                            val rotation = input.readInt()
                            diagLog("Display config: ${width}x$height @ $rotation°")
                            onDisplaySize?.invoke(width, height, rotation)
                        }

                        WireProtocol.MESSAGE_PONG -> {
                            val buf = ByteArray(WireProtocol.PONG_TIMESTAMP_SIZE_BYTES)
                            input.readFully(buf)
                            val sentTime = ByteBuffer.wrap(buf).order(ByteOrder.LITTLE_ENDIAN).long
                            val rtt = (System.nanoTime() - sentTime) / 1_000_000.0 // ms
                            onLatencyMeasured?.invoke(rtt)
                        }

                        else -> {
                            Log.e(
                                TAG,
                                "Unknown message type: ${type.toInt()}, stream may be misaligned; disconnecting",
                            )
                            break
                        }
                    }
                }
            } catch (e: IOException) {
                if (isConnected) {
                    Log.e(TAG, "Read error", e)
                }
            } finally {
                disconnect()
            }
        }

    fun sendTouch(
        x: Float,
        y: Float,
        action: Int,
        pointerCount: Int = 1,
        x2: Float = 0f,
        y2: Float = 0f,
    ) {
        if (!isConnected) return

        touchScope.launch {
            try {
                socket?.getOutputStream()?.let { out ->
                    out.write(WireProtocol.encodeTouch(x, y, action, pointerCount, x2, y2))
                    out.flush()
                }
            } catch (_: Exception) {
            }
        }
    }

    // Callback for latency measurement (round-trip ping/pong)
    var onLatencyMeasured: ((Double) -> Unit)? = null

    /**
     * Ask the host to send an IDR/sync frame.
     *
     * Non-forced requests are rate-limited here so all callers share the same
     * backpressure guard. Forced requests are reserved for startup and hard
     * decoder recovery paths where waiting for the throttle would leave the
     * client black or unsynchronized.
     */
    fun requestKeyframe(
        force: Boolean = false,
        reason: String = "client request",
    ) {
        if (!isConnected) return
        val now = System.nanoTime()
        val shouldSend =
            synchronized(keyframeRequestLock) {
                if (!force &&
                    lastKeyframeRequestNs > 0L &&
                    now - lastKeyframeRequestNs < KEYFRAME_REQUEST_INTERVAL_NS
                ) {
                    false
                } else {
                    lastKeyframeRequestNs = now
                    true
                }
            }
        if (!shouldSend) return

        diagLog("Requesting keyframe: reason=$reason, force=$force")
        touchScope.launch {
            try {
                outputStream?.let { out ->
                    out.write(WireProtocol.encodeKeyframeRequest(force))
                    out.flush()
                }
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Send a ping to measure round-trip latency through the USB connection
     */
    fun sendPing() {
        if (!isConnected) return
        touchScope.launch {
            try {
                socket?.getOutputStream()?.let { out ->
                    out.write(WireProtocol.encodePing(System.nanoTime()))
                    out.flush()
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun updateStats(bytes: Int) {
        bytesReceived += bytes
        framesReceived++

        val now = System.currentTimeMillis()
        val elapsed = now - lastStatsTime

        if (elapsed >= STATS_WINDOW_MS) {
            val mbps = (bytesReceived * 8.0) / (elapsed / 1000.0) / 1_000_000
            val fps = (framesReceived * 1000.0) / elapsed
            onStats?.invoke(fps, mbps)

            bytesReceived = 0
            framesReceived = 0
            lastStatsTime = now
        }
    }

    private fun receiveVideoFrame(
        input: DataInputStream,
        hasMetadata: Boolean,
    ) {
        val frameSize = input.readInt()

        if (frameSize <= 0 || frameSize > MAX_FRAME_SIZE) {
            throw IOException("Invalid frame size: $frameSize")
        }

        var isKeyframe = false
        if (hasMetadata) {
            val flags = input.readUnsignedByte()
            input.readLong() // Host capture timestamp; clocks are not comparable with Android.
            isKeyframe = (flags and WireProtocol.FRAME_FLAG_KEYFRAME) != 0
        }

        val frameData = acquireBuffer(frameSize)
        input.readFully(frameData, 0, frameSize)

        if (!hasMetadata && !isKeyframe) {
            isKeyframe = isHevcSyncFrame(frameData, frameSize)
        }

        // Capture timestamp after full frame received for accurate age tracking.
        val receiveTimestamp = System.nanoTime()
        checkKeyframeFreshness(receiveTimestamp, isKeyframe)
        diagFrameCount++
        if (diagFrameCount == 1L) {
            diagLog(
                "First video frame: size=$frameSize, keyframe=$isKeyframe, " +
                    "metadata=$hasMetadata, callback=${onFrameReceived != null}",
            )
        }
        if (diagFrameCount % 60L == 0L) {
            diagLog("Frames received: $diagFrameCount")
        }

        val callback = onFrameReceived
        if (callback != null) {
            callback.invoke(frameData, frameSize, receiveTimestamp, isKeyframe)
        } else {
            releaseBuffer(frameData)
        }
        updateStats(frameSize)
    }

    private fun checkKeyframeFreshness(
        receiveTimestamp: Long,
        isKeyframe: Boolean,
    ) {
        if (isKeyframe) {
            lastKeyframeReceivedNs = receiveTimestamp
            return
        }

        val lastKeyframeNs = lastKeyframeReceivedNs
        if (lastKeyframeNs <= 0L) return

        val keyframeAgeNs = receiveTimestamp - lastKeyframeNs
        if (keyframeAgeNs > KEYFRAME_STALE_INTERVAL_NS) {
            requestKeyframe(
                reason = "last keyframe ${keyframeAgeNs / 1_000_000L}ms ago",
            )
        }
    }

    fun disconnect() {
        isConnected = false
        cleanup()
        onConnectionStatus?.invoke(false)
        Log.d(TAG, "Disconnected")
    }

    private fun cleanup() {
        try {
            outputStream?.close()
            inputStream?.close()
            socket?.close()

            touchExecutor.shutdown()
            try {
                if (!touchExecutor.awaitTermination(TOUCH_EXECUTOR_SHUTDOWN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                    touchExecutor.shutdownNow()
                    touchExecutor.awaitTermination(
                        TOUCH_EXECUTOR_FORCED_SHUTDOWN_TIMEOUT_MS,
                        TimeUnit.MILLISECONDS,
                    )
                }
            } catch (e: InterruptedException) {
                touchExecutor.shutdownNow()
                Thread.currentThread().interrupt()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
        outputStream = null
        inputStream = null
        socket = null
    }

    private fun diagLog(msg: String) = DiagLog.log("SC", msg)

    private fun Socket.closeQuietly() {
        try {
            close()
        } catch (_: IOException) {
        }
    }

    companion object {
        private const val TAG = "StreamClient"
        private const val READ_BUFFER_SIZE_BYTES = 64 * 1024
        private const val FRAME_BUFFER_POOL_LIMIT = 8
        private const val MAX_FRAME_SIZE = 5 * 1024 * 1024 // 5MB
        private const val WIFI_CONNECT_TIMEOUT_MS = 5_000
        private const val STATS_WINDOW_MS = 1_000L
        private const val TOUCH_EXECUTOR_SHUTDOWN_TIMEOUT_MS = 500L
        private const val TOUCH_EXECUTOR_FORCED_SHUTDOWN_TIMEOUT_MS = 200L
        private const val KEYFRAME_REQUEST_INTERVAL_NS = 500_000_000L
        private const val KEYFRAME_STALE_INTERVAL_NS = 1_500_000_000L

        private fun isHevcSyncFrame(
            data: ByteArray,
            size: Int,
        ): Boolean {
            var i = 0
            while (i + 5 < size) {
                var start = -1
                var startCodeLength = 0

                while (i + 3 < size) {
                    if (data[i] == 0.toByte() && data[i + 1] == 0.toByte()) {
                        if (data[i + 2] == 1.toByte()) {
                            start = i
                            startCodeLength = 3
                            break
                        }
                        if (i + 3 < size && data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte()) {
                            start = i
                            startCodeLength = 4
                            break
                        }
                    }
                    i++
                }

                if (start < 0) return false

                val nalStart = start + startCodeLength
                if (nalStart + 1 >= size) return false

                val nalType = (data[nalStart].toInt() and 0x7E) shr 1
                if (nalType in 16..21) {
                    return true
                }

                i = nalStart + 2
            }
            return false
        }
    }
}
