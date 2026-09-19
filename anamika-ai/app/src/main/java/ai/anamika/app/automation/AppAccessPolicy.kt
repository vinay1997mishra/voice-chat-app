package ai.anamika.app.automation

import android.content.Context

class AppAccessPolicy(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_app_access", Context.MODE_PRIVATE)

    fun allow(packageName: String) {
        val set = prefs.getStringSet(KEY_ALLOWED, emptySet()).orEmpty().toMutableSet()
        set += packageName
        prefs.edit().putStringSet(KEY_ALLOWED, set).apply()
    }

    fun deny(packageName: String) {
        val set = prefs.getStringSet(KEY_ALLOWED, emptySet()).orEmpty().toMutableSet()
        set -= packageName
        prefs.edit().putStringSet(KEY_ALLOWED, set).apply()
    }

    fun isAllowed(packageName: String): Boolean =
        prefs.getStringSet(KEY_ALLOWED, emptySet()).orEmpty().contains(packageName)

    fun all(): Set<String> =
        prefs.getStringSet(KEY_ALLOWED, emptySet()).orEmpty().toSet()

    companion object {
        private const val KEY_ALLOWED = "allowed_packages"
    }
}
