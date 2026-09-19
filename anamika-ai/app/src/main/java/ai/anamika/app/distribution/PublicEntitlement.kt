package ai.anamika.app.distribution

import ai.anamika.app.features.FeatureId
import android.util.Base64
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import kotlin.concurrent.thread

data class PublicEntitlement(
    val subject: String,
    val features: Map<FeatureId, Boolean>,
    val expiresAtEpochMs: Long?,
    val signature: String?
)

interface PublicEntitlementProvider {
    fun fetch(subject: String, callback: (Result<PublicEntitlement>) -> Unit)
}

/**
 * Fetches a per-install entitlement and verifies it with the owner's public key.
 * The corresponding private signing key must remain outside public APKs.
 */
class SignedOwnerPolicyGateway(
    private val policyUrl: String,
    private val ownerPublicKeyBase64: String
) : PublicEntitlementProvider {

    override fun fetch(subject: String, callback: (Result<PublicEntitlement>) -> Unit) {
        thread {
            callback(runCatching {
                require(policyUrl.startsWith("https://")) {
                    "Owner policy URL must use HTTPS"
                }
                require(ownerPublicKeyBase64.isNotBlank()) {
                    "Owner policy public key is not configured"
                }

                val encodedSubject = URLEncoder.encode(subject, "UTF-8")
                val separator = if ("?" in policyUrl) "&" else "?"
                val connection = (
                    URL("$policyUrl${separator}subject=$encodedSubject")
                        .openConnection() as HttpURLConnection
                    ).apply {
                    requestMethod = "GET"
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    setRequestProperty("Accept", "application/json")
                }

                val body = (
                    if (connection.responseCode in 200..299) {
                        connection.inputStream
                    } else {
                        connection.errorStream ?: connection.inputStream
                    }
                    ).bufferedReader().use { it.readText() }

                if (connection.responseCode !in 200..299) {
                    error("Policy server error ${connection.responseCode}")
                }

                parseAndVerify(subject, JSONObject(body))
            })
        }
    }

    private fun parseAndVerify(
        requestedSubject: String,
        json: JSONObject
    ): PublicEntitlement {
        val subject = json.getString("subject")
        require(subject == requestedSubject) { "Policy subject mismatch" }

        val expires = if (json.isNull("expiresAtEpochMs")) {
            null
        } else {
            json.getLong("expiresAtEpochMs")
        }

        if (expires != null) {
            require(System.currentTimeMillis() < expires) { "Owner policy expired" }
        }

        val featureJson = json.getJSONObject("features")
        val features = linkedMapOf<FeatureId, Boolean>()
        FeatureId.entries.sortedBy { it.key }.forEach { feature ->
            if (featureJson.has(feature.key)) {
                features[feature] = featureJson.getBoolean(feature.key)
            }
        }

        val signatureBase64 = json.getString("signature")
        val canonical = canonicalPayload(subject, expires, features)

        require(verify(canonical, signatureBase64)) {
            "Owner policy signature invalid"
        }

        return PublicEntitlement(
            subject = subject,
            features = features,
            expiresAtEpochMs = expires,
            signature = signatureBase64
        )
    }

    private fun canonicalPayload(
        subject: String,
        expires: Long?,
        features: Map<FeatureId, Boolean>
    ): ByteArray {
        val lines = mutableListOf(
            "subject=$subject",
            "expires=${expires ?: "none"}"
        )
        FeatureId.entries.sortedBy { it.key }.forEach { feature ->
            features[feature]?.let { enabled ->
                lines += "${feature.key}=$enabled"
            }
        }
        return lines.joinToString("\n").toByteArray(Charsets.UTF_8)
    }

    private fun verify(payload: ByteArray, signatureBase64: String): Boolean {
        val publicKeyBytes = Base64.decode(ownerPublicKeyBase64, Base64.DEFAULT)
        val publicKey = KeyFactory.getInstance("EC")
            .generatePublic(X509EncodedKeySpec(publicKeyBytes))

        val signatureBytes = Base64.decode(signatureBase64, Base64.DEFAULT)
        return Signature.getInstance("SHA256withECDSA").run {
            initVerify(publicKey)
            update(payload)
            verify(signatureBytes)
        }
    }
}
