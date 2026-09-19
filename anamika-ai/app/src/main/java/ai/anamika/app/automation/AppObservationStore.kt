package ai.anamika.app.automation

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class ObservedUiEvent(
    val packageName: String,
    val className: String,
    val eventType: Int,
    val label: String,
    val timestamp: Long
)

class AppObservationStore(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_app_observations", Context.MODE_PRIVATE)

    fun add(event: ObservedUiEvent) {
        val array = readArray()
        array.put(
            JSONObject()
                .put("package", event.packageName)
                .put("class", event.className)
                .put("eventType", event.eventType)
                .put("label", event.label.take(200))
                .put("timestamp", event.timestamp)
        )

        val trimmed = JSONArray()
        val start = (array.length() - MAX_EVENTS).coerceAtLeast(0)
        for (i in start until array.length()) trimmed.put(array.getJSONObject(i))

        prefs.edit().putString(KEY_EVENTS, trimmed.toString()).apply()
    }

    fun summary(packageName: String): String {
        val array = readArray()
        val labels = linkedSetOf<String>()
        var count = 0

        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            if (item.optString("package") != packageName) continue
            count++
            val label = item.optString("label").trim()
            if (label.isNotBlank()) labels += label
        }

        return buildString {
            appendLine("Package: $packageName")
            appendLine("Observed events: $count")
            appendLine("Visible labels/actions:")
            labels.take(40).forEach { appendLine("• $it") }
        }.trim()
    }

    private fun readArray(): JSONArray =
        runCatching { JSONArray(prefs.getString(KEY_EVENTS, "[]")) }
            .getOrElse { JSONArray() }

    companion object {
        private const val KEY_EVENTS = "events"
        private const val MAX_EVENTS = 1000
    }
}
