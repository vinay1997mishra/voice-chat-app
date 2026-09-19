package ai.anamika.app.core

import org.junit.Assert.assertTrue
import org.junit.Test

class CommandRouterTest {
    private val router = CommandRouter()

    @Test
    fun updateCommandIsDetected() {
        assertTrue(router.parse("Anamika update check karo") is Command.CheckUpdate)
    }

    @Test
    fun rememberCommandIsDetected() {
        assertTrue(router.parse("remember buy milk") is Command.Remember)
    }

    @Test
    fun linkCommandIsDetected() {
        assertTrue(router.parse("learn https://example.com/video") is Command.LearnFromLink)
    }

    @Test
    fun localGitCommandsAreDetected() {
        assertTrue(router.parse("git init anamika") is Command.GitInit)
        assertTrue(router.parse("git status") is Command.GitStatus)
        assertTrue(router.parse("git branch feature-x") is Command.GitBranch)
        assertTrue(router.parse("git checkout feature-x") is Command.GitCheckout)
        assertTrue(router.parse("git commit add feature") is Command.GitCommit)
        assertTrue(router.parse("git log") is Command.GitLog)
        assertTrue(router.parse("git diff") is Command.GitDiff)
        assertTrue(router.parse("git tag v1") is Command.GitTag)
        assertTrue(router.parse("git merge feature-x") is Command.GitMerge)
        assertTrue(router.parse("git push") is Command.GitPush)
        assertTrue(router.parse("git pull") is Command.GitPull)
    }

    @Test
    fun offlineFileCommandsAreDetected() {
        assertTrue(router.parse("file list") is Command.FileList)
        assertTrue(router.parse("file read app/src/main.kt") is Command.FileRead)
        assertTrue(router.parse("file write notes.txt :: hello") is Command.FileWrite)
        assertTrue(router.parse("file delete notes.txt") is Command.FileDelete)
    }

    @Test
    fun buildServerCommandsAreDetected() {
        assertTrue(router.parse("server set https://build.example.com") is Command.ServerSet)
        assertTrue(router.parse("server show") is Command.ServerShow)
        assertTrue(router.parse("build apk") is Command.BuildApk)
        assertTrue(router.parse("build status") is Command.BuildStatus)
        assertTrue(router.parse("build download") is Command.BuildDownload)
        assertTrue(router.parse("app banao video editor") is Command.MakeApp)
        assertTrue(router.parse("make app notes app") is Command.MakeApp)
    }

    @Test
    fun internetAndCrossAppCommandsAreDetected() {
        assertTrue(router.parse("internet chalu") is Command.InternetOn)
        assertTrue(router.parse("internet band") is Command.InternetOff)
        assertTrue(router.parse("internet status") is Command.InternetStatus)
        assertTrue(router.parse("app control settings") is Command.AppControlSettings)
        assertTrue(router.parse("app allow current") is Command.AppAllowCurrent)
        assertTrue(router.parse("app deny current") is Command.AppDenyCurrent)
        assertTrue(router.parse("app open com.example.app") is Command.AppOpen)
        assertTrue(router.parse("app click Login") is Command.AppClick)
        assertTrue(router.parse("app type hello") is Command.AppType)
        assertTrue(router.parse("app model current") is Command.AppModelCurrent)
    }
}
