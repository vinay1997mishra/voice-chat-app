package ai.anamika.app.storage

import android.content.Context

class MemoryStore(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_memory", Context.MODE_PRIVATE)

    fun remember(text: String) {
        val old = prefs.getStringSet("memories", emptySet())?.toMutableSet() ?: mutableSetOf()
        old.add(text)
        prefs.edit().putStringSet("memories", old).apply()
    }

    fun all(): List<String> =
        prefs.getStringSet("memories", emptySet())?.toList()?.sorted().orEmpty()
}
