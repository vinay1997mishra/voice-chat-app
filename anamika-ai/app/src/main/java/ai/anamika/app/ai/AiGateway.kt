package ai.anamika.app.ai

interface AiGateway {
    fun generateCode(request: String, callback: (Result<String>) -> Unit)
    fun learnFromLink(url: String, callback: (Result<String>) -> Unit)
}

/**
 * Phone-side AI/coding hook.
 *
 * APK compilation is intentionally NOT handled here. The build server is used
 * only after source code is complete.
 *
 * A production coding model can later be plugged in as an on-device model or
 * a phone-direct AI provider connection. No build-server dependency is needed.
 */
class DeviceAiGateway : AiGateway {
    override fun generateCode(request: String, callback: (Result<String>) -> Unit) {
        callback(
            Result.failure(
                IllegalStateException(
                    "Advanced coding model abhi phone-side configure nahi hai. " +
                        "Local project/file coding engine available hai; APK server sirf compile ke liye hai."
                )
            )
        )
    }

    override fun learnFromLink(url: String, callback: (Result<String>) -> Unit) {
        callback(
            Result.failure(
                IllegalStateException(
                    "Link/video analysis model abhi phone-side configure nahi hai. " +
                        "APK build server link analysis nahi karta."
                )
            )
        )
    }
}
