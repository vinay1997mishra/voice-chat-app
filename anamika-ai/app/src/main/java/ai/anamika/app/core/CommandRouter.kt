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

    data class Unknown(val text: String) : Command()
}

class CommandRouter {
    fun parse(input: String): Command {
        val text = input.trim()
        val lower = text.lowercase()

        return when {
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
