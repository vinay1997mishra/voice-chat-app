package ai.anamika.app.update

import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

data class AnamikaRelease(
    val tag: String,
    val name: String,
    val url: String,
    val notes: String
)

class GitHubReleaseChecker(
    private val repo: String = "vinay1997mishra/voice-chat-app"
) {
    fun check(callback: (Result<AnamikaRelease?>) -> Unit) {
        thread {
            try {
                val connection = URL("https://api.github.com/repos/$repo/releases?per_page=30")
                    .openConnection() as HttpURLConnection
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                connection.setRequestProperty("Accept", "application/vnd.github+json")
                connection.setRequestProperty("User-Agent", "Anamika-AI-Android")

                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val releases = JSONArray(body)
                var found: AnamikaRelease? = null

                for (i in 0 until releases.length()) {
                    val item = releases.getJSONObject(i)
                    val tag = item.optString("tag_name")
                    if (tag.startsWith("anamika-v")) {
                        found = AnamikaRelease(
                            tag = tag,
                            name = item.optString("name", tag),
                            url = item.optString("html_url"),
                            notes = item.optString("body")
                        )
                        break
                    }
                }
                callback(Result.success(found))
            } catch (t: Throwable) {
                callback(Result.failure(t))
            }
        }
    }
}
