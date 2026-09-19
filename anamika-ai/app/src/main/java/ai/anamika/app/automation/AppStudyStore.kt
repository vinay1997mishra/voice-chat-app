package ai.anamika.app.automation

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class StudyNode(
    val text: String,
    val viewId: String,
    val className: String,
    val clickable: Boolean,
    val editable: Boolean,
    val scrollable: Boolean
)

data class StudyScreen(
    val packageName: String,
    val className: String,
    val title: String,
    val nodes: List<StudyNode>,
    val timestamp: Long
)

class AppStudyStore(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_app_study", Context.MODE_PRIVATE)

    fun start(packageName: String) {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putString(KEY_PACKAGE, packageName)
            .putString(KEY_SCREENS, "[]")
            .apply()
    }

    fun stop() {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, false)
            .putBoolean(KEY_PAUSED, false)
            .remove(KEY_CHALLENGE)
            .apply()
    }

    fun pauseForChallenge(packageName: String, reason: String) {
        if (!isActiveFor(packageName)) return
        prefs.edit()
            .putBoolean(KEY_PAUSED, true)
            .putString(KEY_CHALLENGE, reason.take(200))
            .apply()
    }

    fun resumeAfterChallenge(packageName: String) {
        if (!isActiveFor(packageName)) return
        prefs.edit()
            .putBoolean(KEY_PAUSED, false)
            .remove(KEY_CHALLENGE)
            .apply()
    }

    fun isPaused(): Boolean = prefs.getBoolean(KEY_PAUSED, false)

    fun challengeReason(): String? = prefs.getString(KEY_CHALLENGE, null)

    fun isActiveFor(packageName: String): Boolean =
        prefs.getBoolean(KEY_ACTIVE, false) &&
            prefs.getString(KEY_PACKAGE, null) == packageName

    fun currentPackage(): String? = prefs.getString(KEY_PACKAGE, null)

    fun add(screen: StudyScreen) {
        if (!isActiveFor(screen.packageName) || isPaused()) return

        val array = readArray()
        val signature = signature(screen)

        for (i in 0 until array.length()) {
            if (array.getJSONObject(i).optString("signature") == signature) return
        }

        val nodes = JSONArray()
        screen.nodes.take(MAX_NODES_PER_SCREEN).forEach { node ->
            nodes.put(
                JSONObject()
                    .put("text", node.text.take(160))
                    .put("viewId", node.viewId.take(200))
                    .put("class", node.className.take(160))
                    .put("clickable", node.clickable)
                    .put("editable", node.editable)
                    .put("scrollable", node.scrollable)
            )
        }

        array.put(
            JSONObject()
                .put("signature", signature)
                .put("package", screen.packageName)
                .put("class", screen.className)
                .put("title", screen.title.take(200))
                .put("timestamp", screen.timestamp)
                .put("nodes", nodes)
        )

        val trimmed = JSONArray()
        val start = (array.length() - MAX_SCREENS).coerceAtLeast(0)
        for (i in start until array.length()) {
            trimmed.put(array.getJSONObject(i))
        }

        prefs.edit().putString(KEY_SCREENS, trimmed.toString()).apply()
    }

    fun report(packageName: String): String {
        val array = readArray()
        val lines = mutableListOf<String>()
        var screens = 0

        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            if (item.optString("package") != packageName) continue

            screens++
            val title = item.optString("title").ifBlank {
                item.optString("class").substringAfterLast('.')
            }
            lines += "Screen $screens: $title"

            val nodes = item.optJSONArray("nodes") ?: JSONArray()
            val controls = linkedSetOf<String>()
            for (j in 0 until nodes.length()) {
                val node = nodes.getJSONObject(j)
                val text = node.optString("text").trim()
                if (text.isBlank()) continue

                val kind = when {
                    node.optBoolean("editable") -> "input"
                    node.optBoolean("clickable") -> "action"
                    node.optBoolean("scrollable") -> "scroll"
                    else -> "text"
                }
                controls += "  - $kind: $text"
            }
            lines += controls.take(60)
        }

        if (screens == 0) {
            return "Study data nahi mila. App open karke study session me screens visit karo."
        }

        return buildString {
            appendLine("App package: $packageName")
            appendLine("Mapped screens: $screens")
            appendLine("Observed feature map:")
            lines.forEach { appendLine(it) }
        }.trim()
    }

    private fun signature(screen: StudyScreen): String {
        val core = screen.nodes
            .map { "${it.className}|${it.text}|${it.clickable}|${it.editable}" }
            .sorted()
            .joinToString("||")
        return (screen.className + "|" + screen.title + "|" + core).hashCode().toString()
    }

    private fun readArray(): JSONArray =
        runCatching { JSONArray(prefs.getString(KEY_SCREENS, "[]")) }
            .getOrElse { JSONArray() }

    companion object {
        private const val KEY_ACTIVE = "study_active"
        private const val KEY_PACKAGE = "study_package"
        private const val KEY_SCREENS = "study_screens"
        private const val KEY_PAUSED = "study_paused"
        private const val KEY_CHALLENGE = "study_challenge"
        private const val MAX_SCREENS = 250
        private const val MAX_NODES_PER_SCREEN = 300
    }
}
