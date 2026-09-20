package com.anamika.ai

import dev.ffmpegkit.llama.Llama
import dev.ffmpegkit.llama.LlamaConfig
import kotlinx.coroutines.runBlocking

/** Local llama bridge with separate fast-chat and full coding modes. */
object KotlinLlamaRunner {
    @JvmStatic
    fun generateBlocking(modelPath: String, prompt: String): String = runBlocking {
        val threads = Runtime.getRuntime().availableProcessors().coerceIn(2, 6)
        val model = Llama.loadModel(
            modelPath = modelPath,
            config = LlamaConfig(contextSize = 4096, threads = threads),
        )
        try {
            val result = Llama.complete(
                model,
                prompt = prompt,
                systemPrompt = "You are Anamika AI's offline coding engine. Return original buildable code using the requested <<<FILE:path>>> format. Self-review before answering.",
                maxTokens = 4096,
            )
            result.text
        } finally {
            Llama.releaseModel(model)
        }
    }

    @JvmStatic
    fun generateFastChat(modelPath: String, prompt: String): String = runBlocking {
        val threads = Runtime.getRuntime().availableProcessors().coerceIn(2, 8)
        val model = Llama.loadModel(
            modelPath = modelPath,
            config = LlamaConfig(contextSize = 2048, threads = threads),
        )
        try {
            val result = Llama.complete(
                model,
                prompt = prompt,
                systemPrompt = "You are Anamika, a fast personal assistant. Reply directly and naturally in the user\'s language. Give a complete useful answer when needed; do not artificially shorten it. Do not output code unless explicitly asked.",
                maxTokens = 1024,
            )
            result.text
        } finally {
            Llama.releaseModel(model)
        }
    }
}
