package com.openmultidisplay.app

import android.os.SystemClock

class InputPredictor(
    private val nowNanos: () -> Long = { SystemClock.elapsedRealtimeNanos() },
) {
    private data class TouchSample(
        val x: Float,
        val y: Float,
        val timestamp: Long,
    )

    private val history = ArrayDeque<TouchSample>(MAX_HISTORY_SIZE)
    private val minSamplesForPrediction = 2

    fun addSample(
        x: Float,
        y: Float,
    ) {
        val timestamp = nowNanos()
        history.addLast(TouchSample(x, y, timestamp))

        if (history.size > MAX_HISTORY_SIZE) {
            history.removeFirst()
        }
    }

    fun predictPosition(latencyMs: Float): Pair<Float, Float> {
        if (history.size < minSamplesForPrediction) {
            return if (history.isEmpty()) {
                Pair(0f, 0f)
            } else {
                Pair(history.last().x, history.last().y)
            }
        }

        // Calculate velocity from last 2 samples (most recent)
        val prev = history[history.size - 2]
        val curr = history.last()

        val elapsedMs = (curr.timestamp - prev.timestamp) / 1_000_000f

        if (elapsedMs < MIN_SAMPLE_INTERVAL_MS) {
            return Pair(curr.x, curr.y)
        }

        val velocityX = (curr.x - prev.x) / elapsedMs
        val velocityY = (curr.y - prev.y) / elapsedMs

        val predictedX = curr.x + velocityX * latencyMs
        val predictedY = curr.y + velocityY * latencyMs

        return Pair(predictedX, predictedY)
    }

    fun getCurrentVelocity(): Pair<Float, Float> {
        if (history.size < 2) return Pair(0f, 0f)

        val prev = history[history.size - 2]
        val curr = history.last()
        val elapsedSeconds = (curr.timestamp - prev.timestamp) / 1_000_000_000f

        return if (elapsedSeconds > 0) {
            Pair(
                (curr.x - prev.x) / elapsedSeconds,
                (curr.y - prev.y) / elapsedSeconds,
            )
        } else {
            Pair(0f, 0f)
        }
    }

    fun reset() {
        history.clear()
    }

    companion object {
        private const val MAX_HISTORY_SIZE = 5
        private const val MIN_SAMPLE_INTERVAL_MS = 0.1f
    }
}
