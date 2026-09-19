package ai.anamika.app.auth

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class IdPublicAuth {
    fun signIn(
        policyBaseUrl: String,
        userId: String,
        password: String,
        callback: (Result<PublicUserSession>) -> Unit
    ) {
        thread {
            callback(
                runCatching {
                    require(policyBaseUrl.startsWith("https://")) {
                        "Login server must use HTTPS"
                    }
                    require(userId.isNotBlank()) { "ID required" }
                    require(password.length >= 6) { "Password required" }

                    val connection = (
                        URL(policyBaseUrl.trimEnd('/') + "/auth/id")
                            .openConnection() as HttpURLConnection
                        ).apply {
                        requestMethod = "POST"
                        connectTimeout = 15_000
                        readTimeout = 30_000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept", "application/json")
                    }

                    val request = JSONObject()
                        .put("userId", userId.trim())
                        .put("password", password)
                        .toString()

                    connection.outputStream.use {
                        it.write(request.toByteArray(Charsets.UTF_8))
                    }

                    val raw = (
                        if (connection.responseCode in 200..299) {
                            connection.inputStream
                        } else {
                            connection.errorStream ?: connection.inputStream
                        }
                        ).bufferedReader().use { it.readText() }

                    if (connection.responseCode !in 200..299) {
                        error("Invalid ID or password")
                    }

                    val json = JSONObject(raw)
                    PublicUserSession(
                        googleSubject = json.getString("subject"),
                        email = json.optString("email"),
                        displayName = json.optString("displayName").ifBlank { null },
                        role = json.getString("role"),
                        sessionToken = json.getString("sessionToken")
                    )
                }
            )
        }
    }
}
