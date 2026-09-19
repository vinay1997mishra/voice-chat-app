package ai.anamika.app.ai

interface AiGateway {
    fun generateCode(request: String, callback: (Result<String>) -> Unit)
    fun learnFromLink(url: String, callback: (Result<String>) -> Unit)
}

class BackendAiGateway : AiGateway {
    override fun generateCode(request: String, callback: (Result<String>) -> Unit) {
        callback(Result.failure(IllegalStateException(
            "AI backend is not connected yet. Keep API keys on the server, never inside the APK."
        )))
    }

    override fun learnFromLink(url: String, callback: (Result<String>) -> Unit) {
        callback(Result.failure(IllegalStateException(
            "Link/video learning requires a backend fetch-and-analysis service."
        )))
    }
}
