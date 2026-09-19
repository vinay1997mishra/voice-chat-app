package ai.anamika.app.build

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class WorkspacePackager(private val context: Context) {
    private fun root(workspace: String): File {
        val safe = workspace.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return File(context.filesDir, "workspaces/$safe")
    }

    fun packageWorkspace(workspace: String): File {
        val source = root(workspace)
        require(source.exists() && source.isDirectory) { "Workspace not found: $workspace" }

        val outDir = File(context.cacheDir, "build-uploads").apply { mkdirs() }
        val out = File(outDir, "$workspace-project.zip")

        ZipOutputStream(FileOutputStream(out)).use { zip ->
            source.walkTopDown()
                .filter { it.isFile }
                .filterNot { file ->
                    val rel = file.relativeTo(source).invariantSeparatorsPath
                    rel.startsWith(".git/") ||
                        rel.startsWith(".gradle/") ||
                        rel.contains("/build/") ||
                        rel.startsWith("build/")
                }
                .forEach { file ->
                    val rel = file.relativeTo(source).invariantSeparatorsPath
                    zip.putNextEntry(ZipEntry(rel))
                    file.inputStream().use { it.copyTo(zip) }
                    zip.closeEntry()
                }
        }

        require(out.length() > 0) { "Workspace archive is empty" }
        return out
    }
}
