package com.optly.app.ai

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.sqrt

/**
 * TensorFlow Lite–backed on-device scoring. Falls back to a deterministic heuristic
 * when `assets/optly_ondevice.tflite` is not bundled yet.
 */
@Singleton
class OnDeviceAIEngine @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val interpreter: Interpreter? by lazy {
        runCatching {
            val model = context.assets.open("optly_ondevice.tflite").use { it.readBytes() }
            val buffer = ByteBuffer.allocateDirect(model.size).order(ByteOrder.nativeOrder())
            buffer.put(model)
            buffer.rewind()
            Interpreter(buffer)
        }.getOrNull()
    }

    fun energyScoreFromSignals(signals: FloatArray): Float {
        require(signals.size == INPUT_SIZE) { "Expected $INPUT_SIZE features" }
        val model = interpreter ?: return heuristicEnergy(signals)
        val input = ByteBuffer.allocateDirect(INPUT_SIZE * 4).order(ByteOrder.nativeOrder())
        signals.forEach { input.putFloat(it) }
        input.rewind()
        val output = Array(1) { FloatArray(1) }
        model.run(input, output)
        return output[0][0].coerceIn(0f, 1f)
    }

    private fun heuristicEnergy(signals: FloatArray): Float {
        val sleep = signals.getOrElse(0) { 0.7f }
        val stepsNorm = signals.getOrElse(1) { 0.5f }
        val stress = signals.getOrElse(2) { 0.3f }
        val raw = 0.45f * sleep + 0.35f * stepsNorm + 0.2f * (1f - stress)
        return raw.coerceIn(0f, 1f)
    }

    fun embeddingForText(text: String): FloatArray {
        val model = interpreter
        if (model == null) {
            return bagOfWordsEmbedding(text)
        }
        return bagOfWordsEmbedding(text)
    }

    private fun bagOfWordsEmbedding(text: String): FloatArray {
        val dim = 32
        val vec = FloatArray(dim)
        text.lowercase().forEachIndexed { index, c ->
            vec[index % dim] += (c.code % 13) / 130f
        }
        var sumSq = 0f
        for (v in vec) sumSq += v * v
        var norm = sqrt(sumSq.toDouble()).toFloat()
        if (norm < 1e-3f) norm = 1f
        for (i in vec.indices) vec[i] /= norm
        return vec
    }

    companion object {
        const val INPUT_SIZE = 8
    }
}
