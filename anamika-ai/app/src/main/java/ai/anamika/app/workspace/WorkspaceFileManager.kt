package ai.anamika.app.workspace

import android.content.Context
import java.io.File

class WorkspaceFileManager(private val context: Context) {
    private fun root(workspace: String): File {
        val safe = workspace.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return File(context.filesDir, "workspaces/$safe").apply { mkdirs() }
    }

    private fun resolve(workspace: String, relativePath: String): File {
        require(relativePath.isNotBlank()) { "Path is empty" }
        val base = root(workspace).canonicalFile
        val target = File(base, relativePath).canonicalFile
        require(target.path == base.path || target.path.startsWith(base.path + File.separator)) {
            "Path escapes workspace"
        }
        return target
    }

    fun writeText(workspace: String, relativePath: String, content: String): String {
        val file = resolve(workspace, relativePath)
        file.parentFile?.mkdirs()
        file.writeText(content, Charsets.UTF_8)
        return file.relativeTo(root(workspace)).path
    }

    fun readText(workspace: String, relativePath: String): String =
        resolve(workspace, relativePath).readText(Charsets.UTF_8)

    fun delete(workspace: String, relativePath: String): Boolean {
        val file = resolve(workspace, relativePath)
        return if (file.isDirectory) file.deleteRecursively() else file.delete()
    }

    fun exists(workspace: String, relativePath: String): Boolean =
        resolve(workspace, relativePath).exists()

    fun list(workspace: String, relativePath: String = "."): List<String> {
        val base = root(workspace)
        val target = resolve(workspace, relativePath)
        if (!target.exists()) return emptyList()

        return if (target.isFile) {
            listOf(target.relativeTo(base).path)
        } else {
            target.walkTopDown()
                .filter { it.isFile }
                .map { it.relativeTo(base).path }
                .filterNot { it.startsWith(".git${File.separator}") }
                .toList()
                .sorted()
        }
    }
}
