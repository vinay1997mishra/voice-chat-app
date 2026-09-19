package ai.anamika.app.distribution

import android.content.Context
import ai.anamika.app.features.FeatureId

class PublicEntitlementCache(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun apply(entitlement: PublicEntitlement) {
        val edit = prefs.edit()
            .putString(KEY_SUBJECT, entitlement.subject)
            .putLong(KEY_EXPIRES, entitlement.expiresAtEpochMs ?: Long.MAX_VALUE)

        FeatureId.entries.forEach { feature ->
            entitlement.features[feature]?.let {
                edit.putBoolean(featureKey(feature), it)
                edit.putBoolean(presentKey(feature), true)
            }
        }
        edit.apply()
    }

    fun enabled(feature: FeatureId): Boolean? {
        val expires = prefs.getLong(KEY_EXPIRES, 0L)
        if (expires != Long.MAX_VALUE && System.currentTimeMillis() >= expires) return null
        if (!prefs.getBoolean(presentKey(feature), false)) return null
        return prefs.getBoolean(featureKey(feature), false)
    }

    companion object {
        const val PREFS = "anamika_public_entitlement"
        private const val KEY_SUBJECT = "subject"
        private const val KEY_EXPIRES = "expires"

        private fun featureKey(feature: FeatureId) = "feature.${feature.key}"
        private fun presentKey(feature: FeatureId) = "present.${feature.key}"
    }
}
