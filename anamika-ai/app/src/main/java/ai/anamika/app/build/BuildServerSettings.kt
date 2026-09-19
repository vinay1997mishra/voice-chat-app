package ai.anamika.app.build

import android.content.Context
import java.net.URI

class BuildServerSettings(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_build_server", Context.MODE_PRIVATE)

    fun setBaseUrl(url: String) {
        val normalized = url.trim().trimEnd('/')
        val uri = URI(normalized)
        require(uri.scheme == "https" || uri.scheme == "http") {
            "Server URL must start with https:// or http://"
        }
        require(!uri.host.isNullOrBlank()) { "Server host missing" }
        prefs.edit().putString("base_url", normalized).apply()
    }

    fun baseUrl(): String? = prefs.getString("base_url", null)

    fun setLastJobId(id: String) {
        prefs.edit().putString("last_job_id", id).apply()
    }

    fun lastJobId(): String? = prefs.getString("last_job_id", null)
}
