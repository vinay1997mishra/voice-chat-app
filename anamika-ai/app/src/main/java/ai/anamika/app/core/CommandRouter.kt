package ai.anamika.app.core

sealed class Command {
    data class Remember(val text: String) : Command()
    data class GenerateCode(val request: String) : Command()
    data class LearnFromLink(val url: String) : Command()
    data object CheckUpdate : Command()
    data object RequestUpgrade : Command()
    data class Search(val query: String) : Command()
    data class Unknown(val text: String) : Command()
}

class CommandRouter {
    fun parse(input: String): Command {
        val text = input.trim()
        val lower = text.lowercase()

        return when {
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
