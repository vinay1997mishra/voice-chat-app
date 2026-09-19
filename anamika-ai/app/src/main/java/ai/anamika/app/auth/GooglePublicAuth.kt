package ai.anamika.app.auth

import android.app.Activity
import android.util.Base64
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import kotlin.concurrent.thread

data class GoogleLoginResult(
    val googleSubject: String,
    val email: String,
    val displayName: String?,
    val idToken: String
)

class GooglePublicAuth(
    private val activity: Activity
) {
    private val credentialManager = CredentialManager.create(activity)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun signIn(
        webClientId: String,
        callback: (Result<GoogleLoginResult>) -> Unit
    ) {
        if (webClientId.isBlank()) {
            callback(Result.failure(IllegalStateException("Google OAuth client ID configure nahi hai.")))
            return
        }

        val option = GetSignInWithGoogleOption.Builder(webClientId)
            .setNonce(generateNonce())
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build()

        scope.launch {
            callback(
                runCatching {
                    val result = credentialManager.getCredential(
                        context = activity,
                        request = request
                    )
                    val credential = result.credential
                    require(
                        credential is CustomCredential &&
                            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                    ) {
                        "Google credential response invalid"
                    }

                    val google = GoogleIdTokenCredential.createFrom(credential.data)
                    GoogleLoginResult(
                        googleSubject = google.uniqueId,
                        email = google.email.orEmpty(),
                        displayName = google.displayName,
                        idToken = google.idToken
                    )
                }
            )
        }
    }

    fun verifyWithServer(
        authUrl: String,
        idToken: String,
        callback: (Result<PublicUserSession>) -> Unit
    ) {
        thread {
            callback(
                runCatching {
                    require(authUrl.startsWith("https://")) {
                        "Public auth URL must use HTTPS"
                    }

                    val connection = (URL(authUrl).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 15_000
                        readTimeout = 30_000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept", "application/json")
                    }

                    val requestBody = JSONObject()
                        .put("idToken", idToken)
                        .toString()

                    connection.outputStream.use {
                        it.write(requestBody.toByteArray(Charsets.UTF_8))
                    }

                    val body = (
                        if (connection.responseCode in 200..299) {
                            connection.inputStream
                        } else {
                            connection.errorStream ?: connection.inputStream
                        }
                        ).bufferedReader().use { it.readText() }

                    if (connection.responseCode !in 200..299) {
                        error("Google login verification failed: ${connection.responseCode}")
                    }

                    val json = JSONObject(body)
                    PublicUserSession(
                        googleSubject = json.getString("subject"),
                        email = json.getString("email"),
                        displayName = json.optString("displayName").ifBlank { null }
                    )
                }
            )
        }
    }

    private fun generateNonce(byteLength: Int = 32): String {
        val bytes = ByteArray(byteLength)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(
            bytes,
            Base64.NO_WRAP or Base64.URL_SAFE or Base64.NO_PADDING
        )
    }
}
