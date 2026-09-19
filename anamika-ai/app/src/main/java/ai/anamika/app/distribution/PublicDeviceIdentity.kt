package ai.anamika.app.distribution

import android.content.Context
import java.util.UUID

class PublicDeviceIdentity(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_public_identity", Context.MODE_PRIVATE)

    fun installationId(): String {
        val existing = prefs.getString(KEY_ID, null)
        if (!existing.isNullOrBlank()) return existing

        val created = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_ID, created).apply()
        return created
    }

    companion object {
        private const val KEY_ID = "installation_id"
    }
}
