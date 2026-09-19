package ai.anamika.app.distribution

import ai.anamika.app.features.FeatureId

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
 * Production public copies must accept only policies signed by the real Anamika owner.
 * A local phone PIN is not proof of global Anamika ownership.
 */
class SignedOwnerPolicyGateway : PublicEntitlementProvider {
    override fun fetch(subject: String, callback: (Result<PublicEntitlement>) -> Unit) {
        callback(
            Result.failure(
                IllegalStateException(
                    "Owner policy service/signature verification is not configured yet."
                )
            )
        )
    }
}
