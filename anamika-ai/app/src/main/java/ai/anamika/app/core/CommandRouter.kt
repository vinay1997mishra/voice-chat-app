package ai.anamika.app.core

sealed class Command {
    data class Remember(val text: String) : Command()
    data class GenerateCode(val request: String) : Command()
    data class LearnFromLink(val url: String) : Command()
    data object CheckUpdate : Command()
    data object RequestUpgrade : Command()
    data class Search(val query: String) : Command()

    data class GitInit(val workspace: String) : Command()
    data object GitStatus : Command()
    data class GitBranch(val name: String) : Command()
    data class GitCheckout(val name: String) : Command()
    data class GitCommit(val message: String) : Command()
    data object GitLog : Command()
    data object GitDiff : Command()
    data class GitTag(val name: String) : Command()
    data class GitMerge(val name: String) : Command()
    data object GitPush : Command()
    data object GitPull : Command()
    data object GitBranches : Command()
    data object GitQueue : Command()

    data object FileList : Command()
    data class FileRead(val path: String) : Command()
    data class FileWrite(val path: String, val content: String) : Command()
    data class FileDelete(val path: String) : Command()

    data class ServerSet(val url: String) : Command()
    data object ServerShow : Command()
    data object BuildApk : Command()
    data object BuildStatus : Command()
    data object BuildDownload : Command()
    data class MakeApp(val goal: String) : Command()

    data class Unknown(val text: String) : Command()
}

class CommandRouter {
    fun parse(input: String): Command {
        val text = input.trim()
        val lower = text.lowercase()

        return when {
            lower.startsWith("server set ") -> Command.ServerSet(text.drop(11).trim())
            lower == "server show" -> Command.ServerShow
            lower == "build apk" || lower == "apk build" || lower == "apk banao" -> Command.BuildApk
            lower == "build status" -> Command.BuildStatus
            lower == "build download" || lower == "apk download" -> Command.BuildDownload
            lower.startsWith("app banao ") -> Command.MakeApp(text.drop(10).trim())
            lower.startsWith("make app ") -> Command.MakeApp(text.drop(9).trim())

            lower == "file list" -> Command.FileList
            lower.startsWith("file read ") -> Command.FileRead(text.drop(10).trim())
            lower.startsWith("file delete ") -> Command.FileDelete(text.drop(12).trim())
            lower.startsWith("file write ") -> {
                val payload = text.drop(11)
                val parts = payload.split("::", limit = 2)
                if (parts.size == 2) Command.FileWrite(parts[0].trim(), parts[1].trim())
                else Command.Unknown(text)
            }

            lower.startsWith("git init ") -> Command.GitInit(text.drop(9).trim())
            lower == "git status" -> Command.GitStatus
            lower.startsWith("git branch ") -> Command.GitBranch(text.drop(11).trim())
            lower.startsWith("git checkout ") -> Command.GitCheckout(text.drop(13).trim())
            lower.startsWith("git commit ") -> Command.GitCommit(text.drop(11).trim())
            lower == "git log" -> Command.GitLog
            lower == "git diff" -> Command.GitDiff
            lower.startsWith("git tag ") -> Command.GitTag(text.drop(8).trim())
            lower.startsWith("git merge ") -> Command.GitMerge(text.drop(10).trim())
            lower == "git push" || lower == "github push" -> Command.GitPush
            lower == "git pull" || lower == "github pull" -> Command.GitPull
            lower == "git branches" || lower == "git branch list" -> Command.GitBranches
            lower == "github queue" || lower == "git queue" -> Command.GitQueue

            lower.startsWith("remember ") -> Command.Remember(text.drop(9).trim())
            lower.startsWith("yaad rakho ") -> Command.Remember(text.drop(10).trim())
            lower.contains("update check") || lower.contains("update dekho") -> Command.CheckUpdate
            lower.contains("upgrade") || lower.contains("update karo") -> Command.RequestUpgrade
            lower.startsWith("code ") || lower.contains("coding kar") -> Command.GenerateCode(text)
            lower.contains("http://") || lower.contains("https://") -> {
                val url = Regex("""https?://\S+""").find(text)?.value.orEmpty()
                Command.LearnFromLink(url)
            }
            lower.startsWith("search ") -> Command.Search(text.drop(7).trim())
            lower.startsWith("dhundo ") -> Command.Search(text.drop(6).trim())
            else -> Command.Unknown(text)
        }
    }
}
