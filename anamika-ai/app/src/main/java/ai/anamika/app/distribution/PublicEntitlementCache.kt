package ai.anamika.app.distribution

import android.content.Context
import ai.anamika.app.features.FeatureId

class PublicEntitlementCache(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun apply(entitlement: PublicEntitlement) {
        val edit = prefs.edit()
            .putString(KEY_SUBJECT, entitlement.subject)
            .putLong(KEY_EXPIRES, entitlement.expiresAtEpochMs ?: Long.MAX_VALUE)

        entitlement.features.forEach { (key, enabled) ->
            edit.putBoolean(featureKey(key), enabled)
            edit.putBoolean(presentKey(key), true)
        }
        edit.apply()
    }

    fun enabled(feature: FeatureId): Boolean? = enabledKey(feature.key)

    fun enabledKey(key: String): Boolean? {
        val expires = prefs.getLong(KEY_EXPIRES, 0L)
        if (expires != Long.MAX_VALUE && System.currentTimeMillis() >= expires) return null
        if (!prefs.getBoolean(presentKey(key), false)) return null
        return prefs.getBoolean(featureKey(key), false)
    }

    fun moduleEnabled(moduleId: String): Boolean? =
        enabledKey("module:$moduleId")

    companion object {
        const val PREFS = "anamika_public_entitlement"
        private const val KEY_SUBJECT = "subject"
        private const val KEY_EXPIRES = "expires"

        private fun featureKey(key: String) = "feature.$key"
        private fun presentKey(key: String) = "present.$key"
    }
}
