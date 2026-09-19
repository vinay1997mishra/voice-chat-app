package ai.anamika.app

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import ai.anamika.app.ai.BackendAiGateway
import ai.anamika.app.build.ApkInstaller
import ai.anamika.app.build.BuildServerGateway
import ai.anamika.app.build.BuildServerSettings
import ai.anamika.app.build.WorkspacePackager
import ai.anamika.app.core.Command
import ai.anamika.app.core.CommandRouter
import ai.anamika.app.git.LocalGitEngine
import ai.anamika.app.github.BackendGitHubGateway
import ai.anamika.app.github.RemoteActionQueue
import ai.anamika.app.github.RemoteResult
import ai.anamika.app.security.OwnerAction
import ai.anamika.app.security.OwnerPermissionGate
import ai.anamika.app.security.OwnerPermissionPolicy
import ai.anamika.app.storage.MemoryStore
import ai.anamika.app.update.AnamikaRelease
import ai.anamika.app.update.GitHubReleaseChecker
import ai.anamika.app.voice.VoiceAssistant
import ai.anamika.app.workspace.WorkspaceFileManager
import java.net.URLEncoder

class MainActivity : Activity() {
    private val router = CommandRouter()
    private val ai = BackendAiGateway()
    private val releaseChecker = GitHubReleaseChecker()
    private val permissionGate = OwnerPermissionGate()

    private lateinit var voice: VoiceAssistant
    private lateinit var memory: MemoryStore
    private lateinit var localGit: LocalGitEngine
    private lateinit var remoteQueue: RemoteActionQueue
    private lateinit var githubGateway: BackendGitHubGateway
    private lateinit var workspaceFiles: WorkspaceFileManager
    private lateinit var buildSettings: BuildServerSettings
    private lateinit var buildGateway: BuildServerGateway
    private lateinit var workspacePackager: WorkspacePackager
    private lateinit var apkInstaller: ApkInstaller
    private lateinit var status: TextView

    private var currentWorkspace = "anamika"
    private var pendingOwnerAction: (() -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        memory = MemoryStore(this)
        localGit = LocalGitEngine(this)
        remoteQueue = RemoteActionQueue(this)
        githubGateway = BackendGitHubGateway(remoteQueue)
        workspaceFiles = WorkspaceFileManager(this)
        buildSettings = BuildServerSettings(this)
        buildGateway = BuildServerGateway(this, buildSettings)
        workspacePackager = WorkspacePackager(this)
        apkInstaller = ApkInstaller(this)

        voice = VoiceAssistant(
            activity = this,
            onText = { runOnUiThread { handleInput(it) } },
            onError = { runOnUiThread { reply(it) } }
        )
        setContentView(buildUi())
    }

    private fun buildUi(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 48, 32, 48)
        }

        val title = TextView(this).apply {
            text = "Anamika AI"
            textSize = 28f
        }

        status = TextView(this).apply {
            text = "Ready. Hindi/English voice commands aur local Git commands available hain."
            textSize = 17f
            setPadding(0, 24, 0, 24)
        }

        val speak = Button(this).apply {
            text = "Speak"
            setOnClickListener { startListeningWithPermission() }
        }

        val updates = Button(this).apply {
            text = "Check GitHub Update"
            setOnClickListener { checkForUpdate(false) }
        }

        val memories = Button(this).apply {
            text = "Show Memory"
            setOnClickListener {
                val items = memory.all()
                reply(if (items.isEmpty()) "Memory empty hai." else items.joinToString("\n"))
            }
        }

        val queue = Button(this).apply {
            text = "Offline GitHub Queue"
            setOnClickListener { showRemoteQueue() }
        }

        val buildApk = Button(this).apply {
            text = "Build APK on Server"
            setOnClickListener { handleInput("build apk") }
        }

        root.addView(title)
        root.addView(status)
        root.addView(speak)
        root.addView(updates)
        root.addView(memories)
        root.addView(queue)
        root.addView(buildApk)

        return ScrollView(this).apply { addView(root) }
    }

    private fun startListeningWithPermission() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            voice.listen()
        } else {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1001)
        }
    }

    private fun handleInput(text: String) {
        status.text = "You: $text"
        when (val command = router.parse(text)) {
            is Command.Remember -> {
                memory.remember(command.text)
                reply("Yaad rakh liya.")
            }

            is Command.GenerateCode -> ai.generateCode(command.request) {
                runOnUiThread { reply(it.getOrElse { e -> e.message ?: "AI error" }) }
            }

            is Command.LearnFromLink -> ai.learnFromLink(command.url) {
                runOnUiThread { reply(it.getOrElse { e -> e.message ?: "Link analysis error" }) }
            }

            is Command.CheckUpdate -> checkForUpdate(false)
            is Command.RequestUpgrade -> checkForUpdate(true)

            is Command.Search -> {
                val query = URLEncoder.encode(command.query, "UTF-8")
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$query")))
            }

            is Command.GitInit -> requestOwnerApproval(
                OwnerAction.WRITE_LOCAL_REPO,
                "Initialize local workspace '${command.workspace}'"
            ) {
                runGit {
                    currentWorkspace = command.workspace.ifBlank { "anamika" }
                    "Local Git workspace ready: ${localGit.init(currentWorkspace)}"
                }
            }

            Command.GitStatus -> runGit { localGit.status(currentWorkspace) }

            is Command.GitBranch -> requestOwnerApproval(
                OwnerAction.CREATE_BRANCH,
                "Create branch '${command.name}' in $currentWorkspace"
            ) {
                runGit { localGit.createBranch(currentWorkspace, command.name) }
            }

            is Command.GitCheckout -> requestOwnerApproval(
                OwnerAction.WRITE_LOCAL_REPO,
                "Switch to branch '${command.name}'"
            ) {
                runGit { localGit.checkout(currentWorkspace, command.name) }
            }

            is Command.GitCommit -> requestOwnerApproval(
                OwnerAction.COMMIT_CODE,
                "Commit local code: ${command.message}"
            ) {
                runGit {
                    val sha = localGit.commitAll(currentWorkspace, command.message)
                    "Committed: $sha"
                }
            }

            Command.GitLog -> runGit { localGit.log(currentWorkspace) }
            Command.GitDiff -> runGit { localGit.diff(currentWorkspace) }
            Command.GitBranches -> runGit { localGit.listBranches(currentWorkspace).joinToString("\n") }

            is Command.GitTag -> requestOwnerApproval(
                OwnerAction.CREATE_TAG,
                "Create tag '${command.name}'"
            ) {
                runGit { "Tag created: ${localGit.tag(currentWorkspace, command.name)}" }
            }

            is Command.GitMerge -> requestOwnerApproval(
                OwnerAction.MERGE_BRANCH,
                "Merge branch '${command.name}' into current branch"
            ) {
                runGit { localGit.merge(currentWorkspace, command.name) }
            }

            Command.GitPush -> requestOwnerApproval(
                OwnerAction.REMOTE_PUSH,
                "Push current branch to GitHub"
            ) {
                runGit {
                    val current = localGit.currentBranch(currentWorkspace)
                    githubGateway.push(currentWorkspace, current) { remote ->
                        runOnUiThread { reply(remoteMessage(remote)) }
                    }
                    "Remote action submitted."
                }
            }

            Command.GitPull -> requestOwnerApproval(
                OwnerAction.REMOTE_PULL,
                "Pull current branch from GitHub"
            ) {
                runGit {
                    val current = localGit.currentBranch(currentWorkspace)
                    githubGateway.pull(currentWorkspace, current) { remote ->
                        runOnUiThread { reply(remoteMessage(remote)) }
                    }
                    "Remote action submitted."
                }
            }

            Command.GitQueue -> showRemoteQueue()

            Command.FileList -> runGit {
                val files = workspaceFiles.list(currentWorkspace)
                if (files.isEmpty()) "Workspace me koi source file nahi hai."
                else files.joinToString("\n")
            }

            is Command.FileRead -> runGit {
                workspaceFiles.readText(currentWorkspace, command.path)
            }

            is Command.FileWrite -> requestOwnerApproval(
                OwnerAction.WRITE_LOCAL_FILE,
                "Write local file: ${command.path}"
            ) {
                runGit {
                    "Saved: ${workspaceFiles.writeText(currentWorkspace, command.path, command.content)}"
                }
            }

            is Command.FileDelete -> requestOwnerApproval(
                OwnerAction.DELETE_LOCAL_FILE,
                "Delete local file: ${command.path}"
            ) {
                runGit {
                    if (workspaceFiles.delete(currentWorkspace, command.path)) {
                        "Deleted: ${command.path}"
                    } else {
                        "File not found: ${command.path}"
                    }
                }
            }

            is Command.ServerSet -> requestOwnerApproval(
                OwnerAction.CONFIGURE_BUILD_SERVER,
                "Configure APK build server"
            ) {
                val result = runCatching {
                    buildSettings.setBaseUrl(command.url)
                    "Build server saved: " + command.url
                }
                reply(result.getOrElse { "Server config error: " + it.message })
            }

            Command.ServerShow -> {
                reply(buildSettings.baseUrl() ?: "Build server configure nahi hai.")
            }

            Command.BuildApk -> requestOwnerApproval(
                OwnerAction.BUILD_APK,
                "Upload current workspace to build server and create APK"
            ) {
                startServerBuild()
            }

            Command.BuildStatus -> checkServerBuildStatus()

            Command.BuildDownload -> requestOwnerApproval(
                OwnerAction.BUILD_APK,
                "Download completed APK from build server"
            ) {
                downloadBuiltApk()
            }

            is Command.Unknown ->
                reply("Command samajh aaya, lekin is action ka module abhi connected nahi hai.")
        }
    }

    private fun startServerBuild() {
        reply("Project package karke build server ko bhej rahi hoon.")
        Thread {
            val packaged = runCatching { workspacePackager.packageWorkspace(currentWorkspace) }
            val archive = packaged.getOrElse {
                runOnUiThread { reply("Project package error: " + it.message) }
                return@Thread
            }

            buildGateway.submit(archive) { result ->
                runOnUiThread {
                    result.onSuccess { job ->
                        reply(
                            "Build submitted. Job: " + job.id +
                                "\nStatus: " + job.status +
                                (job.message?.let { "\n" + it } ?: "")
                        )
                    }.onFailure {
                        reply("Build submit failed: " + it.message)
                    }
                }
            }
        }.start()
    }

    private fun checkServerBuildStatus() {
        val jobId = buildSettings.lastJobId()
        if (jobId.isNullOrBlank()) {
            reply("Koi build job saved nahi hai.")
            return
        }

        buildGateway.status(jobId) { result ->
            runOnUiThread {
                result.onSuccess { job ->
                    reply(
                        "Build " + job.id +
                            "\nStatus: " + job.status +
                            "\nAPK ready: " + job.artifactReady +
                            (job.message?.let { "\n" + it } ?: "")
                    )
                }.onFailure {
                    reply("Build status failed: " + it.message)
                }
            }
        }
    }

    private fun downloadBuiltApk() {
        val jobId = buildSettings.lastJobId()
        if (jobId.isNullOrBlank()) {
            reply("Koi build job saved nahi hai.")
            return
        }

        reply("APK download ho rahi hai.")
        buildGateway.downloadArtifact(jobId) { result ->
            runOnUiThread {
                result.onSuccess { apk ->
                    reply("APK ready: " + apk.absolutePath)
                    AlertDialog.Builder(this)
                        .setTitle("APK ready")
                        .setMessage("APK phone me save ho gayi hai. Install screen open karein?")
                        .setNegativeButton("Later", null)
                        .setPositiveButton("Install") { _, _ ->
                            requestOwnerApproval(
                                OwnerAction.INSTALL_APK,
                                "Install downloaded APK: " + apk.name
                            ) {
                                runCatching { apkInstaller.openInstaller(apk) }
                                    .onFailure { reply("Installer error: " + it.message) }
                            }
                        }
                        .show()
                }.onFailure {
                    reply("APK download failed: " + it.message)
                }
            }
        }
    }

    private fun remoteMessage(result: RemoteResult): String = when (result) {
        is RemoteResult.Success -> result.message
        is RemoteResult.Queued -> result.message
        is RemoteResult.Failure -> result.message
    }

    private fun showRemoteQueue() {
        val queued = remoteQueue.all()
        val text = if (queued.isEmpty()) {
            "Offline remote queue empty hai."
        } else {
            queued.joinToString("\n") { "• ${it.type}: ${it.payload}" }
        }
        reply(text)
    }

    private fun runGit(block: () -> String) {
        Thread {
            val result = runCatching(block)
            runOnUiThread {
                reply(result.getOrElse { "Git error: ${it.message}" })
            }
        }.start()
    }

    private fun requestOwnerApproval(
        action: OwnerAction,
        summary: String,
        execute: () -> Unit
    ) {
        if (!OwnerPermissionPolicy.requiresDeviceCredential(action)) {
            execute()
            return
        }

        val startCredential: () -> Unit = {
            pendingOwnerAction = execute
            val started = permissionGate.request(this, action, summary)
            if (!started) {
                pendingOwnerAction = null
                reply("Secure device credential configure nahi hai; protected action blocked hai.")
            }
        }

        val showPrimary: () -> Unit = {
            AlertDialog.Builder(this)
                .setTitle("Owner approval required")
                .setMessage("Action: ${action.name}\nRisk: ${action.risk}\n\n$summary")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Approve") { _, _ -> startCredential() }
                .show()
        }

        if (OwnerPermissionPolicy.requiresSecondConfirmation(action)) {
            AlertDialog.Builder(this)
                .setTitle("High-risk action")
                .setMessage("Ye action repository/security ko permanently affect kar sakta hai. Continue?")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Continue") { _, _ -> showPrimary() }
                .show()
        } else {
            showPrimary()
        }
    }

    private fun checkForUpdate(requestUpgrade: Boolean) {
        reply("GitHub release check kar rahi hoon.")
        releaseChecker.check { result ->
            runOnUiThread {
                result.onSuccess { release ->
                    if (release == null) {
                        reply("Anamika release abhi GitHub par nahi mili.")
                    } else if (requestUpgrade) {
                        showUpgradeApproval(release)
                    } else {
                        status.text = "Latest: ${release.name}\n\n${release.notes.ifBlank { "No release notes." }}"
                        voice.speak("Latest Anamika update details screen par dikha di hain.")
                    }
                }.onFailure {
                    reply("Update check failed: ${it.message}")
                }
            }
        }
    }

    private fun showUpgradeApproval(release: AnamikaRelease) {
        AlertDialog.Builder(this)
            .setTitle("Update details")
            .setMessage(
                "Update: ${release.name}\n\n" +
                    (release.notes.ifBlank { "No release notes were provided." }) +
                    "\n\nInstallation will never happen silently."
            )
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Request owner approval") { _, _ ->
                requestOwnerApproval(
                    OwnerAction.SELF_UPDATE,
                    "Open verified GitHub release page for ${release.name}"
                ) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(release.url)))
                }
            }
            .show()
    }

    @Deprecated("Deprecated in Android API but kept for minSdk compatibility in this bootstrap.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == OwnerPermissionGate.REQUEST_OWNER_AUTH) {
            val action = pendingOwnerAction
            pendingOwnerAction = null

            if (resultCode == RESULT_OK && action != null) {
                reply("Owner verification successful.")
                action()
            } else {
                reply("Owner authorization cancelled.")
            }
        }
    }

    private fun reply(text: String) {
        status.text = text
        voice.speak(text)
    }

    override fun onDestroy() {
        voice.destroy()
        super.onDestroy()
    }
}
