package ai.anamika.app.build

import android.content.Context
import android.os.Environment
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import kotlin.concurrent.thread

data class BuildJob(
    val id: String,
    val status: String,
    val message: String? = null,
    val artifactReady: Boolean = false
)

class BuildServerGateway(
    private val context: Context,
    private val settings: BuildServerSettings
) {
    fun agentBuild(goal: String, callback: (Result<BuildJob>) -> Unit) {
        thread {
            callback(runCatching {
                val base = settings.baseUrl() ?: error("Build server configure nahi hai.")
                val connection = (URL("$base/v1/agent-builds").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 20_000
                    readTimeout = 120_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                }

                val payload = JSONObject().put("goal", goal).toString()
                connection.outputStream.use {
                    it.write(payload.toByteArray(Charsets.UTF_8))
                }

                val response = readResponse(connection)
                if (connection.responseCode !in 200..299) {
                    error("Server error ${connection.responseCode}: $response")
                }

                val json = JSONObject(response)
                val job = BuildJob(
                    id = json.getString("id"),
                    status = json.optString("status", "queued"),
                    message = json.optString("message").ifBlank { null },
                    artifactReady = json.optBoolean("artifact_ready", false)
                )
                settings.setLastJobId(job.id)
                job
            })
        }
    }

    fun submit(projectZip: File, callback: (Result<BuildJob>) -> Unit) {
        thread {
            callback(runCatching {
                val base = settings.baseUrl() ?: error("Build server configure nahi hai.")
                val boundary = "Anamika-${UUID.randomUUID()}"
                val connection = (URL("$base/v1/builds").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 20_000
                    readTimeout = 120_000
                    doOutput = true
                    setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                    setRequestProperty("Accept", "application/json")
                }

                BufferedOutputStream(connection.outputStream).use { out ->
                    fun textPart(name: String, value: String) {
                        out.write("--$boundary\r\n".toByteArray())
                        out.write("Content-Disposition: form-data; name=\"$name\"\r\n\r\n".toByteArray())
                        out.write(value.toByteArray())
                        out.write("\r\n".toByteArray())
                    }

                    textPart("build_type", "debug")
                    out.write("--$boundary\r\n".toByteArray())
                    out.write(
                        "Content-Disposition: form-data; name=\"project\"; filename=\"project.zip\"\r\n"
                            .toByteArray()
                    )
                    out.write("Content-Type: application/zip\r\n\r\n".toByteArray())
                    projectZip.inputStream().use { it.copyTo(out) }
                    out.write("\r\n--$boundary--\r\n".toByteArray())
                }

                val body = readResponse(connection)
                if (connection.responseCode !in 200..299) {
                    error("Server error ${connection.responseCode}: $body")
                }

                val json = JSONObject(body)
                val job = BuildJob(
                    id = json.getString("id"),
                    status = json.optString("status", "queued"),
                    message = json.optString("message").ifBlank { null },
                    artifactReady = json.optBoolean("artifact_ready", false)
                )
                settings.setLastJobId(job.id)
                job
            })
        }
    }

    fun status(jobId: String, callback: (Result<BuildJob>) -> Unit) {
        thread {
            callback(runCatching {
                val base = settings.baseUrl() ?: error("Build server configure nahi hai.")
                val connection = (URL("$base/v1/builds/$jobId").openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    setRequestProperty("Accept", "application/json")
                }
                val body = readResponse(connection)
                if (connection.responseCode !in 200..299) {
                    error("Server error ${connection.responseCode}: $body")
                }
                val json = JSONObject(body)
                BuildJob(
                    id = json.getString("id"),
                    status = json.getString("status"),
                    message = json.optString("message").ifBlank { null },
                    artifactReady = json.optBoolean("artifact_ready", false)
                )
            })
        }
    }

    fun downloadArtifact(jobId: String, callback: (Result<File>) -> Unit) {
        thread {
            callback(runCatching {
                val base = settings.baseUrl() ?: error("Build server configure nahi hai.")
                val connection = (URL("$base/v1/builds/$jobId/artifact").openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 15_000
                    readTimeout = 120_000
                    setRequestProperty("Accept", "application/vnd.android.package-archive")
                }
                if (connection.responseCode !in 200..299) {
                    val body = readResponse(connection)
                    error("Artifact error ${connection.responseCode}: $body")
                }

                val downloads = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: File(context.filesDir, "downloads")
                downloads.mkdirs()
                val apk = File(downloads, "Anamika-$jobId.apk")
                connection.inputStream.use { input ->
                    FileOutputStream(apk).use { output -> input.copyTo(output) }
                }
                require(apk.length() > 0) { "Downloaded APK is empty" }
                apk
            })
        }
    }

    private fun readResponse(connection: HttpURLConnection): String {
        val stream = if (connection.responseCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream ?: connection.inputStream
        }
        return stream.bufferedReader().use { it.readText() }
    }
}
