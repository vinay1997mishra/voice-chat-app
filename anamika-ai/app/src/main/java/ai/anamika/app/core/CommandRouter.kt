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

    data object InternetOn : Command()
    data object InternetOff : Command()
    data object InternetStatus : Command()

    data object AppControlSettings : Command()
    data object AppAllowCurrent : Command()
    data object AppDenyCurrent : Command()
    data class AppOpen(val packageName: String) : Command()
    data class AppClick(val text: String) : Command()
    data class AppType(val text: String) : Command()
    data object AppModelCurrent : Command()
    data object AppStudyStart : Command()
    data object AppStudyCapture : Command()
    data object AppStudyStop : Command()
    data object AppStudyReport : Command()
    data object AppStudyExport : Command()

    data object FeatureList : Command()
    data class FeatureOn(val name: String) : Command()
    data class FeatureOff(val name: String) : Command()
    data object FeatureAllOn : Command()
    data object FeatureAllOff : Command()

    data object PublicFeatureList : Command()
    data class PublicFeatureOn(val name: String) : Command()
    data class PublicFeatureOff(val name: String) : Command()
    data object PublicFeatureAllOn : Command()
    data object PublicFeatureAllOff : Command()
    data object PublicInstallationId : Command()

    data class SelfUpdateStage(val changes: String) : Command()

    data class Unknown(val text: String) : Command()
}

class CommandRouter {
    fun parse(input: String): Command {
        val text = input.trim()
        val lower = text.lowercase()

        return when {
            lower == "feature list" || lower == "features" -> Command.FeatureList
            lower == "feature all on" || lower == "all features on" -> Command.FeatureAllOn
            lower == "feature all off" || lower == "all features off" -> Command.FeatureAllOff
            lower.startsWith("feature on ") -> Command.FeatureOn(text.drop(11).trim())
            lower.startsWith("feature off ") -> Command.FeatureOff(text.drop(12).trim())
            lower == "voice reply on" -> Command.FeatureOn("voice_reply")
            lower == "voice reply off" -> Command.FeatureOff("voice_reply")
            lower == "voice input on" -> Command.FeatureOn("voice_input")
            lower == "voice input off" -> Command.FeatureOff("voice_input")
            lower == "chat on" -> Command.FeatureOn("chat")
            lower == "chat off" -> Command.FeatureOff("chat")

            lower == "public feature list" -> Command.PublicFeatureList
            lower == "public feature all on" -> Command.PublicFeatureAllOn
            lower == "public feature all off" -> Command.PublicFeatureAllOff
            lower.startsWith("public feature on ") -> Command.PublicFeatureOn(text.drop(18).trim())
            lower.startsWith("public feature off ") -> Command.PublicFeatureOff(text.drop(19).trim())
            lower == "public id" || lower == "installation id" -> Command.PublicInstallationId

            lower.startsWith("self update stage ") -> Command.SelfUpdateStage(text.drop(18).trim())

            lower == "internet on" || lower == "internet chalu" -> Command.InternetOn
            lower == "internet off" || lower == "internet band" -> Command.InternetOff
            lower == "internet status" -> Command.InternetStatus

            lower == "app control settings" || lower == "accessibility settings" -> Command.AppControlSettings
            lower == "app allow current" -> Command.AppAllowCurrent
            lower == "app deny current" -> Command.AppDenyCurrent
            lower.startsWith("app open ") -> Command.AppOpen(text.drop(9).trim())
            lower.startsWith("app click ") -> Command.AppClick(text.drop(10).trim())
            lower.startsWith("app type ") -> Command.AppType(text.drop(9).trim())
            lower == "app model current" -> Command.AppModelCurrent
            lower == "app study start" || lower == "scan app start" -> Command.AppStudyStart
            lower == "app study capture" || lower == "scan current screen" -> Command.AppStudyCapture
            lower == "app study stop" || lower == "scan app stop" -> Command.AppStudyStop
            lower == "app study report" || lower == "scan app report" -> Command.AppStudyReport
            lower == "app study export" || lower == "scan app export" -> Command.AppStudyExport

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
