package ai.anamika.app.features

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class LearnedModule(
    val id: String,
    val name: String,
    val sourcePackage: String,
    val enabled: Boolean,
    val status: String
)

class LearnedModuleRegistry(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_learned_modules", Context.MODE_PRIVATE)

    fun registerPending(
        id: String,
        name: String,
        sourcePackage: String
    ) {
        val modules = read().associateBy { it.id }.toMutableMap()
        modules[id] = LearnedModule(
            id = id,
            name = name,
            sourcePackage = sourcePackage,
            enabled = false,
            status = "PENDING_UPDATE"
        )
        write(modules.values.toList())
    }

    fun markInstalled(id: String) {
        update(id) { it.copy(status = "INSTALLED") }
    }

    fun setEnabled(id: String, enabled: Boolean) {
        update(id) { module ->
            require(module.status == "INSTALLED") {
                "Module install/update complete nahi hai"
            }
            module.copy(enabled = enabled)
        }
    }

    fun isEnabled(id: String): Boolean =
        read().firstOrNull { it.id == id }?.let {
            it.status == "INSTALLED" && it.enabled
        } ?: false

    fun all(): List<LearnedModule> = read()

    fun statusText(): String {
        val modules = read()
        if (modules.isEmpty()) return "No learned modules."
        return modules.joinToString("\n") {
            "${it.id}: ${it.status}, ${if (it.enabled) "ON" else "OFF"}"
        }
    }

    private fun update(id: String, transform: (LearnedModule) -> LearnedModule) {
        val modules = read().toMutableList()
        val index = modules.indexOfFirst { it.id == id }
        require(index >= 0) { "Unknown module: $id" }
        modules[index] = transform(modules[index])
        write(modules)
    }

    private fun read(): List<LearnedModule> {
        val array = runCatching {
            JSONArray(prefs.getString(KEY_MODULES, "[]"))
        }.getOrElse { JSONArray() }

        return buildList {
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                add(
                    LearnedModule(
                        id = item.getString("id"),
                        name = item.optString("name"),
                        sourcePackage = item.optString("sourcePackage"),
                        enabled = item.optBoolean("enabled", false),
                        status = item.optString("status", "PENDING_UPDATE")
                    )
                )
            }
        }
    }

    private fun write(modules: List<LearnedModule>) {
        val array = JSONArray()
        modules.forEach { module ->
            array.put(
                JSONObject()
                    .put("id", module.id)
                    .put("name", module.name)
                    .put("sourcePackage", module.sourcePackage)
                    .put("enabled", module.enabled)
                    .put("status", module.status)
            )
        }
        prefs.edit().putString(KEY_MODULES, array.toString()).apply()
    }

    companion object {
        private const val KEY_MODULES = "modules"
    }
}
