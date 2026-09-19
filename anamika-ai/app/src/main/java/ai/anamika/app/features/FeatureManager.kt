package ai.anamika.app.features

import android.content.Context
import ai.anamika.app.distribution.PublicEntitlementCache

enum class FeatureId(val key: String) {
    CHAT("chat"),
    VOICE_INPUT("voice_input"),
    VOICE_REPLY("voice_reply"),
    MEMORY("memory"),
    SEARCH("search"),
    INTERNET("internet"),
    LOCAL_CODING("local_coding"),
    LINK_ANALYSIS("link_analysis"),
    LOCAL_GIT("local_git"),
    GITHUB_REMOTE("github_remote"),
    APP_STUDY("app_study"),
    CROSS_APP_CONTROL("cross_app_control"),
    APK_BUILD("apk_build"),
    SELF_UPDATE("self_update")
}

class FeatureManager(
    context: Context,
    private val ownerMode: Boolean
) {
    private val prefs = context.getSharedPreferences("anamika_features", Context.MODE_PRIVATE)
    private val publicEntitlement = PublicEntitlementCache(context)

    fun isOwnerMode(): Boolean = ownerMode

    fun isMasterEnabled(): Boolean = prefs.getBoolean(KEY_MASTER, true)

    fun setMasterEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_MASTER, enabled).apply()
    }

    fun isEnabled(feature: FeatureId): Boolean =
        if (ownerMode) {
            isMasterEnabled() && prefs.getBoolean(ownerKey(feature), true)
        } else {
            if (!PUBLIC_CAPABLE_FEATURES.contains(feature)) {
                false
            } else {
                publicEntitlement.enabled(feature) ?: publicDefault(feature)
            }
        }

    fun setEnabled(feature: FeatureId, enabled: Boolean) {
        check(ownerMode) { "Owner feature policy is unavailable in public mode" }
        prefs.edit().putBoolean(ownerKey(feature), enabled).apply()
    }

    fun setAll(enabled: Boolean) {
        check(ownerMode) { "Owner feature policy is unavailable in public mode" }
        val edit = prefs.edit().putBoolean(KEY_MASTER, enabled)
        FeatureId.entries.forEach { edit.putBoolean(ownerKey(it), enabled) }
        edit.apply()
    }

    fun ownerStatus(): String = FeatureId.entries.joinToString("\n") {
        "${it.key}: ${if (isEnabled(it)) "ON" else "OFF"}"
    }

    fun setPublicDefault(feature: FeatureId, enabled: Boolean) {
        check(ownerMode) { "Public defaults can only be changed from owner mode" }
        prefs.edit().putBoolean(publicKey(feature), enabled).apply()
    }

    fun publicDefault(feature: FeatureId): Boolean =
        prefs.getBoolean(publicKey(feature), DEFAULT_PUBLIC_FEATURES.contains(feature))

    fun setAllPublicDefaults(enabled: Boolean) {
        check(ownerMode) { "Public defaults can only be changed from owner mode" }
        val edit = prefs.edit()
        FeatureId.entries.forEach { edit.putBoolean(publicKey(it), enabled) }
        edit.apply()
    }

    fun publicStatus(): String = FeatureId.entries.joinToString("\n") {
        "${it.key}: ${if (publicDefault(it)) "ON" else "OFF"}"
    }

    fun resolve(input: String): FeatureId? {
        val normalized = input.trim().lowercase().replace('-', '_').replace(' ', '_')
        return FeatureId.entries.firstOrNull {
            it.key == normalized || it.name.lowercase() == normalized
        }
    }

    private fun ownerKey(feature: FeatureId) = "owner.${feature.key}"
    private fun publicKey(feature: FeatureId) = "public.${feature.key}"

    companion object {
        private const val KEY_MASTER = "owner.master"
        private val DEFAULT_PUBLIC_FEATURES = setOf(
            FeatureId.CHAT,
            FeatureId.VOICE_INPUT,
            FeatureId.VOICE_REPLY
        )

        private val PUBLIC_CAPABLE_FEATURES = setOf(
            FeatureId.CHAT,
            FeatureId.VOICE_INPUT,
            FeatureId.VOICE_REPLY,
            FeatureId.MEMORY,
            FeatureId.SEARCH,
            FeatureId.INTERNET,
            FeatureId.LINK_ANALYSIS,
            FeatureId.LOCAL_CODING
        )
    }
}
