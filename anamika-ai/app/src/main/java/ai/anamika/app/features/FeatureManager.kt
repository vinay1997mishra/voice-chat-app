package ai.anamika.app.features

import android.content.Context

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

class FeatureManager(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_features", Context.MODE_PRIVATE)

    fun isMasterEnabled(): Boolean = prefs.getBoolean(KEY_MASTER, true)

    fun setMasterEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_MASTER, enabled).apply()
    }

    fun isEnabled(feature: FeatureId): Boolean =
        isMasterEnabled() && prefs.getBoolean(ownerKey(feature), true)

    fun setEnabled(feature: FeatureId, enabled: Boolean) {
        prefs.edit().putBoolean(ownerKey(feature), enabled).apply()
    }

    fun setAll(enabled: Boolean) {
        val edit = prefs.edit().putBoolean(KEY_MASTER, enabled)
        FeatureId.entries.forEach { edit.putBoolean(ownerKey(it), enabled) }
        edit.apply()
    }

    fun ownerStatus(): String = FeatureId.entries.joinToString("\n") {
        "${it.key}: ${if (isEnabled(it)) "ON" else "OFF"}"
    }

    fun setPublicDefault(feature: FeatureId, enabled: Boolean) {
        prefs.edit().putBoolean(publicKey(feature), enabled).apply()
    }

    fun publicDefault(feature: FeatureId): Boolean =
        prefs.getBoolean(publicKey(feature), DEFAULT_PUBLIC_FEATURES.contains(feature))

    fun setAllPublicDefaults(enabled: Boolean) {
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
    }
}
