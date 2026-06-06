package com.openmultidisplay.app

import org.junit.Assert.assertEquals
import org.junit.Test

class InputPredictorTest {
    @Test
    fun emptyPredictorReturnsOrigin() {
        val predictor = InputPredictor { 0L }

        val position = predictor.predictPosition(latencyMs = 16f)

        assertEquals(0f, position.first, 0.0001f)
        assertEquals(0f, position.second, 0.0001f)
    }

    @Test
    fun singleSampleReturnsLastKnownPosition() {
        var now = 0L
        val predictor = InputPredictor { now }

        predictor.addSample(10f, 20f)
        val position = predictor.predictPosition(latencyMs = 16f)

        assertEquals(10f, position.first, 0.0001f)
        assertEquals(20f, position.second, 0.0001f)
    }

    @Test
    fun predictsLinearMotionUsingMostRecentVelocity() {
        var now = 0L
        val predictor = InputPredictor { now }

        predictor.addSample(10f, 20f)
        now += 10_000_000L
        predictor.addSample(20f, 40f)

        val position = predictor.predictPosition(latencyMs = 20f)

        assertEquals(40f, position.first, 0.0001f)
        assertEquals(80f, position.second, 0.0001f)
    }

    @Test
    fun returnsCurrentPositionWhenSamplesAreTooCloseTogether() {
        var now = 0L
        val predictor = InputPredictor { now }

        predictor.addSample(0f, 0f)
        now += 50_000L
        predictor.addSample(100f, 100f)

        val position = predictor.predictPosition(latencyMs = 20f)

        assertEquals(100f, position.first, 0.0001f)
        assertEquals(100f, position.second, 0.0001f)
    }

    @Test
    fun computesVelocityInUnitsPerSecond() {
        var now = 0L
        val predictor = InputPredictor { now }

        predictor.addSample(0f, 0f)
        now += 20_000_000L
        predictor.addSample(4f, 10f)

        val velocity = predictor.getCurrentVelocity()

        assertEquals(200f, velocity.first, 0.0001f)
        assertEquals(500f, velocity.second, 0.0001f)
    }

    @Test
    fun resetClearsHistory() {
        var now = 0L
        val predictor = InputPredictor { now }

        predictor.addSample(10f, 10f)
        now += 10_000_000L
        predictor.addSample(20f, 20f)
        predictor.reset()

        val position = predictor.predictPosition(latencyMs = 16f)
        val velocity = predictor.getCurrentVelocity()

        assertEquals(0f, position.first, 0.0001f)
        assertEquals(0f, position.second, 0.0001f)
        assertEquals(0f, velocity.first, 0.0001f)
        assertEquals(0f, velocity.second, 0.0001f)
    }

    @Test
    fun keepsOnlyMostRecentSamplesForPrediction() {
        var now = 0L
        val predictor = InputPredictor { now }

        for (i in 0..5) {
            predictor.addSample(i.toFloat(), i.toFloat())
            now += 10_000_000L
        }

        val position = predictor.predictPosition(latencyMs = 10f)

        assertEquals(6f, position.first, 0.0001f)
        assertEquals(6f, position.second, 0.0001f)
    }
}
