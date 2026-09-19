package ai.anamika.app.github

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class PendingRemoteAction(
    val type: String,
    val payload: String,
    val createdAt: Long
)

class RemoteActionQueue(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_remote_queue", Context.MODE_PRIVATE)

    fun enqueue(type: String, payload: String) {
        val current = readArray()
        current.put(
            JSONObject()
                .put("type", type)
                .put("payload", payload)
                .put("createdAt", System.currentTimeMillis())
        )
        prefs.edit().putString("queue", current.toString()).apply()
    }

    fun all(): List<PendingRemoteAction> {
        val array = readArray()
        return buildList {
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                add(
                    PendingRemoteAction(
                        type = item.optString("type"),
                        payload = item.optString("payload"),
                        createdAt = item.optLong("createdAt")
                    )
                )
            }
        }
    }

    fun clear() {
        prefs.edit().remove("queue").apply()
    }

    private fun readArray(): JSONArray =
        runCatching { JSONArray(prefs.getString("queue", "[]")) }
            .getOrElse { JSONArray() }
}
