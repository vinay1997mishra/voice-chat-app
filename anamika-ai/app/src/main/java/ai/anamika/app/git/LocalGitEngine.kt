package ai.anamika.app.git

import android.content.Context
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.storage.file.FileRepositoryBuilder
import java.io.ByteArrayOutputStream
import java.io.File

class LocalGitEngine(private val context: Context) {
    private fun workspace(name: String): File {
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return File(context.filesDir, "workspaces/$safe").apply { mkdirs() }
    }

    fun init(name: String): String {
        val dir = workspace(name)
        val gitDir = File(dir, ".git")
        if (!gitDir.exists()) {
            Git.init().setDirectory(dir).call().close()
        }
        return dir.absolutePath
    }

    private fun open(name: String): Git {
        val dir = workspace(name)
        val repository = FileRepositoryBuilder()
            .setGitDir(File(dir, ".git"))
            .setWorkTree(dir)
            .readEnvironment()
            .findGitDir()
            .build()
        return Git(repository)
    }

    fun status(name: String): String = open(name).use { git ->
        val s = git.status().call()
        buildString {
            appendLine("Branch: ${git.repository.branch}")
            appendLine("Added: ${s.added.joinToString()}")
            appendLine("Changed: ${s.changed.joinToString()}")
            appendLine("Modified: ${s.modified.joinToString()}")
            appendLine("Missing: ${s.missing.joinToString()}")
            appendLine("Removed: ${s.removed.joinToString()}")
            appendLine("Untracked: ${s.untracked.joinToString()}")
            appendLine("Conflicting: ${s.conflicting.joinToString()}")
        }.trim()
    }

    fun createBranch(name: String, branch: String): String = open(name).use { git ->
        git.branchCreate().setName(branch).call()
        "Branch created: $branch"
    }

    fun checkout(name: String, branch: String): String = open(name).use { git ->
        git.checkout().setName(branch).call()
        "Checked out: $branch"
    }

    fun commitAll(name: String, message: String): String = open(name).use { git ->
        git.add().addFilepattern(".").call()
        git.add().setUpdate(true).addFilepattern(".").call()
        val commit = git.commit()
            .setMessage(message)
            .setAuthor("Anamika Owner", "owner@local.anamika")
            .setCommitter("Anamika Owner", "owner@local.anamika")
            .call()
        commit.id.name
    }

    fun log(name: String, limit: Int = 20): String = open(name).use { git ->
        git.log().setMaxCount(limit).call().joinToString("\n") {
            "${it.id.abbreviate(8).name()}  ${it.shortMessage}"
        }
    }

    fun diff(name: String): String = open(name).use { git ->
        val out = ByteArrayOutputStream()
        DiffFormatter(out).use { formatter ->
            formatter.setRepository(git.repository)
            formatter.setDetectRenames(true)
            git.diff().call().forEach { entry ->
                formatter.format(entry)
            }
        }
        out.toString(Charsets.UTF_8.name()).ifBlank { "No unstaged diff." }
    }

    fun tag(name: String, tagName: String, message: String = tagName): String = open(name).use { git ->
        val ref = git.tag().setName(tagName).setMessage(message).call()
        ref.name
    }

    fun merge(name: String, branch: String): String = open(name).use { git ->
        val ref = git.repository.findRef(branch)
            ?: error("Branch not found: $branch")
        val result = git.merge().include(ref).call()
        "Merge status: ${result.mergeStatus}"
    }

    fun currentBranch(name: String): String = open(name).use { it.repository.branch }

    fun listBranches(name: String): List<String> = open(name).use { git ->
        git.branchList().call().map { it.name.removePrefix(Constants.R_HEADS) }
    }
}
