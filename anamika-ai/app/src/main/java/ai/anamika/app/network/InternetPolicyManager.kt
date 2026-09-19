package ai.anamika.app.network

import android.content.Context

class InternetPolicyManager(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_internet_policy", Context.MODE_PRIVATE)

    fun isEnabled(): Boolean = prefs.getBoolean(KEY_ENABLED, true)

    fun setEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    companion object {
        private const val KEY_ENABLED = "internet_enabled"
    }
}
