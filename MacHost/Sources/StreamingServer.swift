import Foundation
import Network

private enum WireMessage {
    static let legacyVideoFrame: UInt8 = 0
    static let displayConfig: UInt8 = 1
    static let touchEvent: UInt8 = 2
    static let ping: UInt8 = 4
    static let pong: UInt8 = 5
    static let videoFrameWithMetadata: UInt8 = 6
    static let keyframeRequest: UInt8 = 7
    static let clientSupportsFrameMetadata: UInt8 = 8
}

private extension NWEndpoint {
    var isLoopback: Bool {
        switch self {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let v4): return v4.isLoopback
            case .ipv6(let v6): return v6.isLoopback
            case .name(let name, _): return name == "localhost"
            @unknown default: return false
            }
        default:
            return false
        }
    }
}

private final class ClientSession {
    let id = UUID()
    let connection: NWConnection
    var isReceiving = false
    var connectionReady = false
    var waitingForSyncFrame = true
    var clientSupportsFrameMetadata = false
    var inputBuffer = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }
}

class StreamingServer {
    private let port: UInt16
    private var listener: NWListener?
    private var clients: [UUID: ClientSession] = [:]
    private let clientsLock = NSLock()

    var onClientConnected: (() -> Void)?
    var onClientDisconnected: (() -> Void)?
    var onClientCountChanged: ((Int) -> Void)?
    // Touch callback: (x1, y1, action, pointerCount, x2, y2)
    var onTouchEvent: ((Float, Float, Int, Int, Float, Float) -> Void)?
    var onStats: ((Double, Double) -> Void)?
    var onKeyframeRequested: ((Bool) -> Void)?
    // Whether host wants to receive touch events from client. Ping/pong is
    // handled regardless. When false, incoming touch frames are dropped
    // immediately without parsing or dispatching to main queue.
    var touchEnabled: Bool = true

    // Wireless auth: when non-nil, non-loopback connections must present this
    // 32-byte token before being allowed to proceed. nil means wireless mode
    // is inactive, so non-loopback connections are rejected immediately.
    var expectedAuthToken: Data?
    var onWirelessClientPaired: ((String) -> Void)?

    private let frameQueue = DispatchQueue(label: "frameQueue", qos: .userInteractive)
    private let receiveQueue = DispatchQueue(label: "receiveQueue", qos: .userInteractive)
    private let networkQueue = DispatchQueue(label: "networkQueue", qos: .userInteractive)
    private var bytesSent: UInt64 = 0
    private var frameCount: UInt64 = 0
    private var droppedFrames: UInt64 = 0
    private var lastStatsTime = DispatchTime.now()
    private var displayWidth = 1920
    private var displayHeight = 1080
    private var rotation = 0
    private var isStopped = false

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        isStopped = false
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            // Optimize TCP for low-latency streaming.
            if let tcpOptions = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                tcpOptions.noDelay = true
                tcpOptions.enableFastOpen = true
            }

            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))

            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.handleConnection(newConnection)
            }

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    debugLog("TCP Server listening on port \(self.port)")
                case .failed(let error):
                    debugLog("Server failed: \(error)")
                default:
                    break
                }
            }

            listener?.start(queue: networkQueue)
        } catch {
            debugLog("Failed to start server: \(error)")
        }
    }

    private func handleConnection(_ newConnection: NWConnection) {
        debugLog("New connection incoming...")

        let session = ClientSession(connection: newConnection)
        addClient(session)

        newConnection.stateUpdateHandler = { [weak self, weak session] state in
            guard let self, let session else { return }
            debugLog("Connection state: \(state)")
            switch state {
            case .ready:
                self.onConnectionReady(session)
            case .failed(let error):
                debugLog("Connection failed: \(error)")
                self.removeClient(session, reason: "failed")
            case .cancelled:
                debugLog("Connection cancelled")
                self.removeClient(session, reason: "cancelled")
            default:
                break
            }
        }

        newConnection.start(queue: networkQueue)
    }

    private func onConnectionReady(_ session: ClientSession) {
        if session.connection.endpoint.isLoopback {
            debugLog("Client connected via loopback (USB) - skipping auth")
            beginExistingProtocol(on: session)
            return
        }
        guard let expected = expectedAuthToken else {
            debugLog("Rejecting non-loopback client: wireless mode not active")
            session.connection.cancel()
            return
        }
        debugLog("Client connected via LAN - running auth handshake")
        runAuthHandshake(session: session, expectedToken: expected)
    }

    private func beginExistingProtocol(on session: ClientSession) {
        startReceivingTouch(from: session)

        // Give new clients a short chance to opt in before the first frame.
        // Legacy clients send no capability message, so we continue shortly
        // after this window with the old frame type.
        networkQueue.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self, weak session] in
            guard let self, let session else { return }
            self.finishProtocolStartup(on: session)
        }
    }

    private func finishProtocolStartup(on session: ClientSession) {
        guard containsClient(session), !isStopped, !session.connectionReady else { return }

        debugLog("Client connected - sending display config first")
        sendDisplaySize(to: session)
        session.connectionReady = true
        debugLog("Connection ready for frames (metadata=\(session.clientSupportsFrameMetadata ? "on" : "off")); clients=\(clientCount)")
        onClientConnected?()
        onClientCountChanged?(clientCount)
    }

    private func runAuthHandshake(session: ClientSession, expectedToken: Data) {
        let conn = session.connection
        // Read fixed prefix [magic 4][token 32][name_len 1] = 37 bytes.
        conn.receive(minimumIncompleteLength: HandshakeCodec.fixedPrefixLen,
                     maximumLength: HandshakeCodec.fixedPrefixLen) { [weak self, weak session] prefixData, _, _, error in
            guard let self, let session else { return }
            if let error = error {
                debugLog("Auth read error: \(error)")
                session.connection.cancel()
                return
            }
            guard let prefix = prefixData, prefix.count == HandshakeCodec.fixedPrefixLen else {
                self.sendAuthResponse(session.connection, status: .invalidMagic, thenClose: true)
                return
            }
            let prefixBytes = Array(prefix)
            guard Array(prefixBytes[0..<4]) == HandshakeCodec.requestMagic else {
                self.sendAuthResponse(session.connection, status: .invalidMagic, thenClose: true)
                return
            }
            let nameLen = Int(prefixBytes[36])
            guard (1...64).contains(nameLen) else {
                self.sendAuthResponse(session.connection, status: .invalidName, thenClose: true)
                return
            }
            // Read variable name.
            session.connection.receive(minimumIncompleteLength: nameLen, maximumLength: nameLen) { nameData, _, _, error in
                if let error = error {
                    debugLog("Auth name read error: \(error)")
                    session.connection.cancel()
                    return
                }
                guard let nameData = nameData, nameData.count == nameLen else {
                    self.sendAuthResponse(session.connection, status: .invalidName, thenClose: true)
                    return
                }
                let full = prefix + nameData
                do {
                    let parsed = try HandshakeCodec.parseRequest(full)
                    if WirelessAuth.validate(parsed.token, expected: expectedToken) {
                        debugLog("Wireless auth OK - device: \(parsed.deviceName)")
                        self.sendAuthResponse(session.connection, status: .ok, thenClose: false)
                        self.onWirelessClientPaired?(parsed.deviceName)
                        self.beginExistingProtocol(on: session)
                    } else {
                        debugLog("Wireless auth rejected: token mismatch")
                        self.sendAuthResponse(session.connection, status: .invalidToken, thenClose: true)
                    }
                } catch HandshakeError.invalidMagic {
                    self.sendAuthResponse(session.connection, status: .invalidMagic, thenClose: true)
                } catch HandshakeError.invalidName {
                    self.sendAuthResponse(session.connection, status: .invalidName, thenClose: true)
                } catch {
                    self.sendAuthResponse(session.connection, status: .invalidMagic, thenClose: true)
                }
            }
        }
    }

    private func sendAuthResponse(_ conn: NWConnection, status: HandshakeStatus, thenClose: Bool) {
        let bytes = HandshakeCodec.encodeResponse(status: status)
        conn.send(content: bytes, completion: .contentProcessed { _ in
            if thenClose {
                debugLog("Auth rejected (\(status)), closing connection")
                conn.cancel()
            }
        })
    }

    func setDisplaySize(width: Int, height: Int, rotation: Int = 0) {
        displayWidth = width
        displayHeight = height
        self.rotation = rotation
    }

    /// Update rotation and send to connected clients.
    func updateRotation(_ rotation: Int) {
        self.rotation = rotation
        sendDisplaySize()
    }

    func sendDisplaySize() {
        for session in snapshotClients() where session.connectionReady {
            sendDisplaySize(to: session)
        }
    }

    private func sendDisplaySize(to session: ClientSession) {
        var data = Data()
        data.append(WireMessage.displayConfig)
        data.append(contentsOf: withUnsafeBytes(of: Int32(displayWidth).bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(displayHeight).bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(rotation).bigEndian) { Data($0) })

        session.connection.send(content: data, completion: .contentProcessed { _ in })
        debugLog("Sent display config to \(session.id): \(displayWidth)x\(displayHeight) @ \(rotation)deg")
    }

    private func startReceivingTouch(from session: ClientSession) {
        guard !session.isReceiving else {
            debugLog("Already receiving input for client \(session.id)")
            return
        }
        session.isReceiving = true
        debugLog("Starting input receive loop for client \(session.id)... (touch=\(touchEnabled ? "on" : "off"))")

        receiveQueue.async { [weak self, weak session] in
            guard let self, let session else { return }
            self.touchReceiveLoop(for: session)
        }
    }

    private func touchReceiveLoop(for session: ClientSession) {
        guard containsClient(session), session.isReceiving, !isStopped else {
            session.isReceiving = false
            return
        }

        session.connection.receive(minimumIncompleteLength: 1, maximumLength: 256) { [weak self, weak session] data, _, isComplete, error in
            guard let self, let session, session.isReceiving, !self.isStopped else { return }

            if error != nil || isComplete {
                session.isReceiving = false
                session.inputBuffer.removeAll(keepingCapacity: true)
                self.removeClient(session, reason: error.map { "receive error: \($0)" } ?? "receive complete")
                return
            }

            if let data = data, !data.isEmpty {
                session.inputBuffer.append(data)
                self.processInputBuffer(for: session)
            }

            self.receiveQueue.async { [weak self, weak session] in
                guard let self, let session else { return }
                self.touchReceiveLoop(for: session)
            }
        }
    }

    private func processInputBuffer(for session: ClientSession) {
        while let msgType = session.inputBuffer.first {
            switch msgType {
            case WireMessage.touchEvent:
                // Touch event: 1 type + 1 pointerCount + N*(4x+4y) + 4 action.
                // 1 finger: 14 bytes, 2 fingers: 22 bytes.
                guard session.inputBuffer.count >= 2 else { return }

                let pointerCount = Int(inputByte(in: session, at: 1))
                guard pointerCount == 1 || pointerCount == 2 else {
                    debugLog("Invalid touch pointer count: \(pointerCount)")
                    consumeInputBytes(1, in: session)
                    continue
                }

                let expectedSize = 2 + pointerCount * 8 + 4
                guard session.inputBuffer.count >= expectedSize else { return }

                let message = Data(session.inputBuffer.prefix(expectedSize))
                consumeInputBytes(expectedSize, in: session)

                // Drop early if host has touch disabled, after consuming exactly
                // this touch frame so coalesced ping/keyframe messages survive.
                if touchEnabled {
                    handleTouchMessage(message, pointerCount: pointerCount)
                }

            case WireMessage.ping:
                // Ping from client: echo back as pong (type=5) with client's timestamp.
                guard session.inputBuffer.count >= 9 else { return }

                let clientTimestamp = Data(session.inputBuffer.dropFirst().prefix(8))
                consumeInputBytes(9, in: session)

                var pong = Data(capacity: 9)
                pong.append(WireMessage.pong)
                pong.append(clientTimestamp)
                session.connection.send(content: pong, completion: .contentProcessed { _ in })

            case WireMessage.keyframeRequest:
                // Keyframe request from Android decoder. The client sends a
                // two-byte message: type + flags.
                guard session.inputBuffer.count >= 2 else { return }

                let flags = inputByte(in: session, at: 1)
                consumeInputBytes(2, in: session)
                onKeyframeRequested?((flags & 1) != 0)

            case WireMessage.clientSupportsFrameMetadata:
                // One-byte opt-in from newer clients. Keeping this payload-free
                // lets older hosts safely ignore it without misaligning input.
                consumeInputBytes(1, in: session)
                if !session.clientSupportsFrameMetadata {
                    session.clientSupportsFrameMetadata = true
                    debugLog("Client \(session.id) supports video frame metadata")
                }
                finishProtocolStartup(on: session)

            default:
                debugLog("Unknown client input type: \(msgType)")
                consumeInputBytes(1, in: session)
            }
        }
    }

    private func handleTouchMessage(_ data: Data, pointerCount: Int) {
        let x1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 2, as: Float.self) }
        let y1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 6, as: Float.self) }

        var x2: Float = 0
        var y2: Float = 0
        if pointerCount >= 2 {
            x2 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 10, as: Float.self) }
            y2 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 14, as: Float.self) }
        }

        let actionOffset = 2 + pointerCount * 8
        let action = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: actionOffset, as: Int32.self) }

        DispatchQueue.main.async {
            self.onTouchEvent?(x1, y1, Int(action), pointerCount, x2, y2)
        }
    }

    private func inputByte(in session: ClientSession, at offset: Int) -> UInt8 {
        session.inputBuffer[session.inputBuffer.index(session.inputBuffer.startIndex, offsetBy: offset)]
    }

    private func consumeInputBytes(_ count: Int, in session: ClientSession) {
        let endIndex = session.inputBuffer.index(session.inputBuffer.startIndex, offsetBy: count)
        session.inputBuffer.removeSubrange(session.inputBuffer.startIndex..<endIndex)
    }

    func sendFrame(_ data: Data, timestamp: UInt64, isKeyframe: Bool = false) {
        let readyClients = snapshotClients().filter { $0.connectionReady }
        guard !isStopped, !readyClients.isEmpty else { return }

        frameQueue.async { [weak self] in
            guard let self else { return }
            var deliveredClients = 0

            for session in readyClients {
                guard self.containsClient(session), session.connectionReady else { continue }

                // With short-GOP encoding, a fresh client must start on a keyframe.
                if session.waitingForSyncFrame {
                    guard isKeyframe else {
                        self.droppedFrames += 1
                        continue
                    }
                    session.waitingForSyncFrame = false
                    debugLog("First keyframe sent to client \(session.id)")
                }

                let packet = self.makeFramePacket(
                    data,
                    timestamp: timestamp,
                    isKeyframe: isKeyframe,
                    clientSupportsFrameMetadata: session.clientSupportsFrameMetadata
                )

                session.connection.send(content: packet, completion: .contentProcessed { [weak self] error in
                    if error != nil {
                        self?.droppedFrames += 1
                    }
                })

                deliveredClients += 1
            }

            if deliveredClients > 0 {
                let sendAge = DispatchTime.now().uptimeNanoseconds - timestamp
                self.updateStats(bytes: data.count * deliveredClients, frameAgeNs: sendAge)
            }
        }
    }

    private func makeFramePacket(_ data: Data, timestamp: UInt64, isKeyframe: Bool, clientSupportsFrameMetadata: Bool) -> Data {
        if clientSupportsFrameMetadata {
            var packet = Data(capacity: data.count + 14)
            packet.append(WireMessage.videoFrameWithMetadata)
            appendFrameSize(data.count, to: &packet)
            packet.append(isKeyframe ? 1 : 0)
            var captureTimestamp = timestamp.bigEndian
            withUnsafeBytes(of: &captureTimestamp) { packet.append(contentsOf: $0) }
            packet.append(data)
            return packet
        }

        // Keep legacy frame type 0 for clients that do not advertise
        // metadata support; remove after legacy clients age out.
        var packet = Data(capacity: data.count + 5)
        packet.append(WireMessage.legacyVideoFrame)
        appendFrameSize(data.count, to: &packet)
        packet.append(data)
        return packet
    }

    private func appendFrameSize(_ size: Int, to packet: inout Data) {
        var frameSize = Int32(size).bigEndian
        withUnsafeBytes(of: &frameSize) { packet.append(contentsOf: $0) }
    }

    // Pipeline profiling: track frame age at send time.
    private var totalFrameAgeNs: UInt64 = 0
    private var profiledFrameCount: UInt64 = 0

    private func updateStats(bytes: Int, frameAgeNs: UInt64 = 0) {
        bytesSent += UInt64(bytes)
        frameCount += 1
        if frameAgeNs > 0 {
            totalFrameAgeNs += frameAgeNs
            profiledFrameCount += 1
        }

        let now = DispatchTime.now()
        let elapsed = Double(now.uptimeNanoseconds - lastStatsTime.uptimeNanoseconds) / 1_000_000_000

        if elapsed >= 1.0 {
            let mbps = Double(bytesSent * 8) / elapsed / 1_000_000
            let fps = Double(frameCount) / elapsed
            onStats?(fps, mbps)

            // Log pipeline latency profile.
            if profiledFrameCount > 0 {
                let avgAgeMs = Double(totalFrameAgeNs) / Double(profiledFrameCount) / 1_000_000.0
                debugLog("Pipeline: \(String(format: "%.1f", fps))fps, \(String(format: "%.1f", mbps))Mbps, avg frame age: \(String(format: "%.1f", avgAgeMs))ms, clients: \(clientCount), dropped: \(droppedFrames)")
            }

            bytesSent = 0
            frameCount = 0
            droppedFrames = 0
            totalFrameAgeNs = 0
            profiledFrameCount = 0
            lastStatsTime = now
        }
    }

    func stop() {
        isStopped = true

        frameQueue.sync {}
        receiveQueue.sync {}

        let sessions = snapshotClients()
        clientsLock.lock()
        clients.removeAll()
        clientsLock.unlock()

        for session in sessions {
            session.isReceiving = false
            session.connectionReady = false
            session.connection.cancel()
        }

        listener?.cancel()
        listener = nil
        onClientCountChanged?(0)
    }

    private var clientCount: Int {
        clientsLock.lock()
        defer { clientsLock.unlock() }
        return clients.count
    }

    private func addClient(_ session: ClientSession) {
        clientsLock.lock()
        clients[session.id] = session
        let count = clients.count
        clientsLock.unlock()

        debugLog("Accepted client \(session.id); clients=\(count)")
        onClientCountChanged?(count)
    }

    private func removeClient(_ session: ClientSession, reason: String) {
        clientsLock.lock()
        let removed = clients.removeValue(forKey: session.id) != nil
        let remaining = clients.count
        clientsLock.unlock()

        guard removed else { return }

        session.isReceiving = false
        session.connectionReady = false
        session.inputBuffer.removeAll(keepingCapacity: true)
        session.connection.cancel()

        debugLog("Removed client \(session.id) (\(reason)); clients=\(remaining)")
        onClientCountChanged?(remaining)
        if remaining == 0 {
            onClientDisconnected?()
        }
    }

    private func containsClient(_ session: ClientSession) -> Bool {
        clientsLock.lock()
        defer { clientsLock.unlock() }
        return clients[session.id] === session
    }

    private func snapshotClients() -> [ClientSession] {
        clientsLock.lock()
        defer { clientsLock.unlock() }
        return Array(clients.values)
    }
}
