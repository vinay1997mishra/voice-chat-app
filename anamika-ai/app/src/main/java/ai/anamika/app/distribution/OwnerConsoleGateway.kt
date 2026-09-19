package ai.anamika.app.distribution

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import kotlin.concurrent.thread

data class FunctionAccessItem(
    val key: String,
    val name: String,
    val ownerEnabled: Boolean,
    val userEnabled: Boolean,
    val builtin: Boolean
)

class OwnerConsoleGateway(
    private val baseUrl: String
) {
    fun loadCatalog(
        sessionToken: String,
        callback: (Result<List<FunctionAccessItem>>) -> Unit
    ) {
        thread {
            callback(runCatching {
                val json = request(
                    method = "GET",
                    path = "/owner/catalog",
                    sessionToken = sessionToken
                )
                val array = json.getJSONArray("features")
                buildList {
                    for (i in 0 until array.length()) {
                        val item = array.getJSONObject(i)
                        add(
                            FunctionAccessItem(
                                key = item.getString("key"),
                                name = item.getString("name"),
                                ownerEnabled = item.getBoolean("ownerEnabled"),
                                userEnabled = item.getBoolean("userEnabled"),
                                builtin = item.optBoolean("builtin", false)
                            )
                        )
                    }
                }
            })
        }
    }

    fun updateFeature(
        sessionToken: String,
        key: String,
        ownerEnabled: Boolean,
        userEnabled: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        thread {
            callback(runCatching {
                val body = JSONObject()
                    .put("ownerEnabled", ownerEnabled)
                    .put("userEnabled", userEnabled)

                request(
                    method = "PUT",
                    path = "/owner/catalog/${URLEncoder.encode(key, "UTF-8")}",
                    sessionToken = sessionToken,
                    body = body
                )
                Unit
            })
        }
    }

    fun registerFeature(
        sessionToken: String,
        key: String,
        name: String,
        callback: (Result<Unit>) -> Unit
    ) {
        thread {
            callback(runCatching {
                val body = JSONObject()
                    .put("key", key)
                    .put("name", name)

                request(
                    method = "POST",
                    path = "/owner/catalog/register",
                    sessionToken = sessionToken,
                    body = body
                )
                Unit
            })
        }
    }

    private fun request(
        method: String,
        path: String,
        sessionToken: String,
        body: JSONObject? = null
    ): JSONObject {
        require(baseUrl.startsWith("https://")) {
            "Owner policy base URL must use HTTPS"
        }

        val connection = (URL(baseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 30_000
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Authorization", "Bearer $sessionToken")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }

        if (body != null) {
            connection.outputStream.use {
                it.write(body.toString().toByteArray(Charsets.UTF_8))
            }
        }

        val raw = (
            if (connection.responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream ?: connection.inputStream
            }
            ).bufferedReader().use { it.readText() }

        if (connection.responseCode !in 200..299) {
            error("Owner console request failed: ${connection.responseCode}")
        }

        return if (raw.isBlank()) JSONObject() else JSONObject(raw)
    }
}
