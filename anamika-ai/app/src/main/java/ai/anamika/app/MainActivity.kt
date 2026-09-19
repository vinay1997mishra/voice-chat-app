package ai.anamika.app

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import ai.anamika.app.ai.DeviceAiGateway
import ai.anamika.app.automation.AnamikaAccessibilityService
import ai.anamika.app.automation.AppAccessPolicy
import ai.anamika.app.automation.AppObservationStore
import ai.anamika.app.automation.AppStudyStore
import ai.anamika.app.build.ApkInstaller
import ai.anamika.app.build.BuildServerGateway
import ai.anamika.app.build.BuildServerSettings
import ai.anamika.app.build.WorkspacePackager
import ai.anamika.app.coding.LocalAndroidProjectGenerator
import ai.anamika.app.core.Command
import ai.anamika.app.core.CommandRouter
import ai.anamika.app.git.LocalGitEngine
import ai.anamika.app.features.FeatureId
import ai.anamika.app.features.FeatureManager
import ai.anamika.app.features.LearnedModuleRegistry
import ai.anamika.app.distribution.PublicDeviceIdentity
import ai.anamika.app.distribution.PublicEntitlementCache
import ai.anamika.app.distribution.SignedOwnerPolicyGateway
import ai.anamika.app.network.InternetPolicyManager
import ai.anamika.app.github.BackendGitHubGateway
import ai.anamika.app.github.RemoteActionQueue
import ai.anamika.app.github.RemoteResult
import ai.anamika.app.security.OwnerAction
import ai.anamika.app.security.OwnerPermissionGate
import ai.anamika.app.security.OwnerPermissionPolicy
import ai.anamika.app.storage.MemoryStore
import ai.anamika.app.update.AnamikaRelease
import ai.anamika.app.update.GitHubReleaseChecker
import ai.anamika.app.update.SelfUpdateStager
import ai.anamika.app.voice.VoiceAssistant
import ai.anamika.app.workspace.WorkspaceFileManager
import java.net.URLEncoder

class MainActivity : Activity() {
    private val router = CommandRouter()
    private val ai = DeviceAiGateway()
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
    private lateinit var localProjectGenerator: LocalAndroidProjectGenerator
    private lateinit var internetPolicy: InternetPolicyManager
    private lateinit var appAccessPolicy: AppAccessPolicy
    private lateinit var appObservations: AppObservationStore
    private lateinit var appStudy: AppStudyStore
    private lateinit var features: FeatureManager
    private lateinit var selfUpdateStager: SelfUpdateStager
    private lateinit var learnedModules: LearnedModuleRegistry
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
        localProjectGenerator = LocalAndroidProjectGenerator(workspaceFiles)
        internetPolicy = InternetPolicyManager(this)
        appAccessPolicy = AppAccessPolicy(this)
        appObservations = AppObservationStore(this)
        appStudy = AppStudyStore(this)
        features = FeatureManager(this, BuildConfig.ANAMIKA_DISTRIBUTION_MODE == "OWNER")
        selfUpdateStager = SelfUpdateStager(workspaceFiles)
        learnedModules = LearnedModuleRegistry(this)

        voice = VoiceAssistant(
            activity = this,
            onText = { runOnUiThread { handleInput(it) } },
            onError = { runOnUiThread { reply(it) } }
        )
        setContentView(buildUi())
        syncPublicEntitlementsIfNeeded()
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

        val featureControl = Button(this).apply {
            text = "Owner Feature Control"
            setOnClickListener { showFeatureControlDialog() }
        }

        root.addView(title)
        root.addView(status)
        root.addView(speak)
        root.addView(updates)
        root.addView(memories)
        root.addView(queue)
        root.addView(buildApk)
        if (features.isOwnerMode()) {
            root.addView(featureControl)
        }

        return ScrollView(this).apply { addView(root) }
    }

    private fun startListeningWithPermission() {
        if (!features.isEnabled(FeatureId.VOICE_INPUT)) {
            reply("Voice input owner policy se OFF hai.")
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            voice.listen()
        } else {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1001)
        }
    }

    private fun handleInput(text: String) {
        status.text = "You: $text"
        val command = router.parse(text)

        val requiredFeature = featureFor(command)
        if (requiredFeature != null && !features.isEnabled(requiredFeature)) {
            reply("Feature '${requiredFeature.key}' owner policy se OFF hai.")
            return
        }

        when (command) {
            is Command.Remember -> {
                memory.remember(command.text)
                reply("Yaad rakh liya.")
            }

            is Command.GenerateCode -> ai.generateCode(command.request) {
                runOnUiThread { reply(it.getOrElse { e -> e.message ?: "AI error" }) }
            }

            is Command.LearnFromLink -> withInternet {
                ai.learnFromLink(command.url) {
                    runOnUiThread { reply(it.getOrElse { e -> e.message ?: "Link analysis error" }) }
                }
            }

            is Command.CheckUpdate -> checkForUpdate(false)
            is Command.RequestUpgrade -> checkForUpdate(true)

            is Command.Search -> withInternet {
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

            Command.GitPush -> withInternet {
                requestOwnerApproval(
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
            }

            Command.GitPull -> withInternet {
                requestOwnerApproval(
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

            Command.BuildApk -> withInternet {
                requestOwnerApproval(
                    OwnerAction.BUILD_APK,
                    "Upload current workspace to build server and create APK"
                ) {
                    startServerBuild()
                }
            }

            Command.BuildStatus -> withInternet { checkServerBuildStatus() }

            Command.BuildDownload -> withInternet {
                requestOwnerApproval(
                    OwnerAction.BUILD_APK,
                    "Download completed APK from build server"
                ) {
                    downloadBuiltApk()
                }
            }

            is Command.MakeApp -> requestOwnerApproval(
                OwnerAction.WRITE_LOCAL_FILE,
                "Generate Android project locally on this phone"
            ) {
                generateProjectLocally(command.goal)
            }

            Command.InternetOn -> requestOwnerApproval(
                OwnerAction.CHANGE_INTERNET_POLICY,
                "Allow Anamika to use this phone's internet connection"
            ) {
                internetPolicy.setEnabled(true)
                reply("Anamika internet access ON hai.")
            }

            Command.InternetOff -> requestOwnerApproval(
                OwnerAction.CHANGE_INTERNET_POLICY,
                "Block Anamika-initiated internet requests"
            ) {
                internetPolicy.setEnabled(false)
                reply("Anamika internet access OFF hai. Local coding kaam chalta rahega.")
            }

            Command.InternetStatus -> {
                reply(if (internetPolicy.isEnabled()) "Internet policy: ON" else "Internet policy: OFF")
            }

            Command.AppControlSettings -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                reply("Accessibility settings khol di hain. Anamika service owner ko manually enable karni hogi.")
            }

            Command.AppAllowCurrent -> {
                val pkg = AnamikaAccessibilityService.lastForegroundPackage
                if (pkg.isNullOrBlank()) {
                    reply("Pehle target app ek baar open karo, phir Anamika me wapas aakar 'app allow current' bolo.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.AUTHORIZE_OTHER_APP,
                        "Allow Anamika to observe/control app: $pkg"
                    ) {
                        appAccessPolicy.allow(pkg)
                        reply("Authorized app: $pkg")
                    }
                }
            }

            Command.AppDenyCurrent -> {
                val pkg = AnamikaAccessibilityService.lastForegroundPackage
                if (pkg.isNullOrBlank()) {
                    reply("Recent target app nahi mila.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.AUTHORIZE_OTHER_APP,
                        "Remove Anamika access for app: $pkg"
                    ) {
                        appAccessPolicy.deny(pkg)
                        reply("Access removed: $pkg")
                    }
                }
            }

            is Command.AppOpen -> openExternalApp(command.packageName)

            is Command.AppClick -> controlLastApp("click '${command.text}'") {
                AnamikaAccessibilityService.active?.clickByText(command.text) == true
            }

            is Command.AppType -> controlLastApp("type text in focused non-sensitive field") {
                AnamikaAccessibilityService.active?.setTextOnFocusedField(command.text) == true
            }

            Command.AppModelCurrent -> {
                val pkg = AnamikaAccessibilityService.lastForegroundPackage
                if (pkg.isNullOrBlank()) {
                    reply("Recent target app nahi mila.")
                } else if (!appAccessPolicy.isAllowed(pkg)) {
                    reply("Ye app owner-authorized nahi hai.")
                } else {
                    reply(appObservations.summary(pkg))
                }
            }

            Command.AppStudyStart -> startAppStudy()

            Command.AppStudyCapture -> captureAppStudyScreen()

            Command.AppStudyStop -> {
                val pkg = appStudy.currentPackage()
                appStudy.stop()
                reply(
                    if (pkg.isNullOrBlank()) {
                        "Active app study session nahi tha."
                    } else {
                        "App study stop ho gaya: $pkg"
                    }
                )
            }

            Command.AppStudyReport -> showAppStudyReport()

            Command.AppStudyExport -> exportAppStudyReport()

            Command.FeatureList -> {
                if (features.isOwnerMode()) reply(features.ownerStatus())
                else reply("Owner feature controls public build me available nahi hain.")
            }

            is Command.FeatureOn -> changeOwnerFeature(command.name, true)

            is Command.FeatureOff -> changeOwnerFeature(command.name, false)

            Command.FeatureAllOn -> {
                if (!features.isOwnerMode()) {
                    reply("Owner feature controls public build me available nahi hain.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.CHANGE_FEATURE_POLICY,
                        "Enable all Anamika owner features"
                    ) {
                        features.setAll(true)
                        reply("All owner features ON.")
                    }
                }
            }

            Command.FeatureAllOff -> {
                if (!features.isOwnerMode()) {
                    reply("Owner feature controls public build me available nahi hain.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.CHANGE_FEATURE_POLICY,
                        "Disable all Anamika owner features"
                    ) {
                        features.setAll(false)
                        status.text = "All owner features OFF. Owner Feature Control button remains available."
                    }
                }
            }

            Command.PublicFeatureList -> {
                if (features.isOwnerMode()) reply(features.publicStatus())
                else reply("Current public entitlements owner policy se controlled hain.")
            }

            is Command.PublicFeatureOn -> changePublicFeature(command.name, true)

            is Command.PublicFeatureOff -> changePublicFeature(command.name, false)

            Command.PublicFeatureAllOn -> {
                if (!features.isOwnerMode()) {
                    reply("Public entitlement editing public build me blocked hai.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.CHANGE_PUBLIC_ENTITLEMENTS,
                        "Enable all default public features"
                    ) {
                        features.setAllPublicDefaults(true)
                        reply("All public default features ON.")
                    }
                }
            }

            Command.PublicFeatureAllOff -> {
                if (!features.isOwnerMode()) {
                    reply("Public entitlement editing public build me blocked hai.")
                } else {
                    requestOwnerApproval(
                        OwnerAction.CHANGE_PUBLIC_ENTITLEMENTS,
                        "Disable all default public features"
                    ) {
                        features.setAllPublicDefaults(false)
                        reply("All public default features OFF.")
                    }
                }
            }

            Command.PublicInstallationId -> {
                reply("Installation ID: " + PublicDeviceIdentity(this).installationId())
            }

            is Command.SelfUpdateStage -> stageSelfUpdate(command.changes)

            Command.ModuleList -> reply(learnedModules.statusText())

            is Command.ModuleOn -> changeLearnedModule(command.id, true)

            is Command.ModuleOff -> changeLearnedModule(command.id, false)

            is Command.Unknown ->
                reply("Command samajh aaya, lekin is action ka module abhi connected nahi hai.")
        }
    }

    private fun syncPublicEntitlementsIfNeeded() {
        if (features.isOwnerMode()) return

        val policyUrl = BuildConfig.ANAMIKA_OWNER_POLICY_URL
        val publicKey = BuildConfig.ANAMIKA_OWNER_POLICY_PUBLIC_KEY
        if (policyUrl.contains("example.invalid") || publicKey.isBlank()) return

        val subject = PublicDeviceIdentity(this).installationId()
        val cache = PublicEntitlementCache(this)
        SignedOwnerPolicyGateway(policyUrl, publicKey).fetch(subject) { result ->
            result.onSuccess { entitlement ->
                cache.apply(entitlement)
                runOnUiThread {
                    status.text = "Owner public policy synced."
                }
            }.onFailure {
                runOnUiThread {
                    status.text = "Public policy sync failed; cached/default entitlements remain active."
                }
            }
        }
    }

    private fun featureFor(command: Command): FeatureId? = when (command) {
        is Command.GenerateCode -> FeatureId.CHAT
        is Command.Remember -> FeatureId.MEMORY
        is Command.Search -> FeatureId.SEARCH
        is Command.LearnFromLink -> FeatureId.LINK_ANALYSIS

        is Command.GitInit,
        Command.GitStatus,
        is Command.GitBranch,
        is Command.GitCheckout,
        is Command.GitCommit,
        Command.GitLog,
        Command.GitDiff,
        is Command.GitTag,
        is Command.GitMerge,
        Command.GitBranches -> FeatureId.LOCAL_GIT

        Command.GitPush,
        Command.GitPull,
        Command.GitQueue -> FeatureId.GITHUB_REMOTE

        Command.BuildApk,
        Command.BuildStatus,
        Command.BuildDownload -> FeatureId.APK_BUILD

        is Command.MakeApp,
        is Command.FileWrite,
        is Command.FileRead,
        is Command.FileDelete,
        Command.FileList -> FeatureId.LOCAL_CODING

        Command.AppStudyStart,
        Command.AppStudyCapture,
        Command.AppStudyStop,
        Command.AppStudyReport,
        Command.AppStudyExport,
        Command.AppModelCurrent -> FeatureId.APP_STUDY

        is Command.AppOpen,
        is Command.AppClick,
        is Command.AppType,
        Command.AppAllowCurrent,
        Command.AppDenyCurrent,
        Command.AppControlSettings -> FeatureId.CROSS_APP_CONTROL

        is Command.CheckUpdate,
        is Command.RequestUpgrade,
        is Command.SelfUpdateStage -> FeatureId.SELF_UPDATE

        is Command.InternetOn,
        is Command.InternetOff,
        is Command.InternetStatus,
        Command.FeatureList,
        is Command.FeatureOn,
        is Command.FeatureOff,
        Command.FeatureAllOn,
        Command.FeatureAllOff,
        Command.PublicFeatureList,
        is Command.PublicFeatureOn,
        is Command.PublicFeatureOff,
        Command.PublicFeatureAllOn,
        Command.PublicFeatureAllOff,
        Command.PublicInstallationId,
        Command.ModuleList,
        is Command.ModuleOn,
        is Command.ModuleOff,
        is Command.ServerSet,
        Command.ServerShow,
        is Command.Unknown -> null
    }

    private fun changeOwnerFeature(name: String, enabled: Boolean) {
        if (!features.isOwnerMode()) {
            reply("Owner feature controls public build me available nahi hain.")
            return
        }
        val feature = features.resolve(name)
        if (feature == null) {
            reply("Unknown feature: $name")
            return
        }

        requestOwnerApproval(
            OwnerAction.CHANGE_FEATURE_POLICY,
            "Set ${feature.key} = $enabled"
        ) {
            features.setEnabled(feature, enabled)
            if (feature == FeatureId.VOICE_REPLY && !enabled) {
                status.text = "voice_reply: OFF"
            } else {
                reply("${feature.key}: ${if (enabled) "ON" else "OFF"}")
            }
        }
    }

    private fun changePublicFeature(name: String, enabled: Boolean) {
        if (!features.isOwnerMode()) {
            reply("Public entitlement editing public build me blocked hai.")
            return
        }
        val feature = features.resolve(name)
        if (feature == null) {
            reply("Unknown public feature: $name")
            return
        }

        requestOwnerApproval(
            OwnerAction.CHANGE_PUBLIC_ENTITLEMENTS,
            "Set public default ${feature.key} = $enabled"
        ) {
            features.setPublicDefault(feature, enabled)
            reply("Public ${feature.key}: ${if (enabled) "ON" else "OFF"}")
        }
    }

    private fun changeLearnedModule(id: String, enabled: Boolean) {
        requestOwnerApproval(
            OwnerAction.CHANGE_FEATURE_POLICY,
            "Set learned module $id = $enabled"
        ) {
            val result = runCatching {
                learnedModules.setEnabled(id, enabled)
                "$id: " + if (enabled) "ON" else "OFF"
            }
            reply(result.getOrElse { "Module control failed: " + it.message })
        }
    }

    private fun stageSelfUpdate(changes: String) {
        val pkg = appStudy.currentPackage()
            ?: AnamikaAccessibilityService.lastForegroundPackage
        if (pkg.isNullOrBlank()) {
            reply("Self-update stage ke liye studied source app nahi mila.")
            return
        }
        if (changes.isBlank()) {
            reply("Update me kya change chahiye wo bolo.")
            return
        }

        requestOwnerApproval(
            OwnerAction.STAGE_SELF_UPDATE,
            "Stage learned features from $pkg into next Anamika update"
        ) {
            runGit {
                val safeName = pkg.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val featureMapPath = "study/$safeName-FEATURE_MAP.txt"
                workspaceFiles.writeText(currentWorkspace, featureMapPath, appStudy.report(pkg))
                val staged = selfUpdateStager.stage(
                    workspace = currentWorkspace,
                    sourcePackage = pkg,
                    featureMapPath = featureMapPath,
                    requestedChanges = changes
                )
                val moduleId = (
                    pkg.substringAfterLast('.') + "-" +
                        changes.lowercase()
                            .replace(Regex("[^a-z0-9]+"), "-")
                            .trim('-')
                            .take(32)
                    ).trim('-').ifBlank { "learned-feature" }

                learnedModules.registerPending(
                    id = moduleId,
                    name = changes.take(80),
                    sourcePackage = pkg
                )

                "Self-update staged: ${staged.stagedPath}. Module: $moduleId (PENDING_UPDATE). Code install nahi hua; tests/build/owner approval ke baad update banega."
            }
        }
    }

    private fun showFeatureControlDialog() {
        if (!features.isOwnerMode()) {
            reply("Owner Feature Control public build me available nahi hai.")
            return
        }
        val items = FeatureId.entries.toTypedArray()
        val labels = items.map { it.key }.toTypedArray()
        val checked = BooleanArray(items.size) { index ->
            features.isEnabled(items[index])
        }

        AlertDialog.Builder(this)
            .setTitle("Owner Feature Control")
            .setMultiChoiceItems(labels, checked) { _, which, isChecked ->
                checked[which] = isChecked
            }
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Apply") { _, _ ->
                requestOwnerApproval(
                    OwnerAction.CHANGE_FEATURE_POLICY,
                    "Apply Anamika feature switches"
                ) {
                    features.setMasterEnabled(checked.any { it })
                    items.forEachIndexed { index, feature ->
                        features.setEnabled(feature, checked[index])
                    }
                    status.text = "Owner feature policy updated."
                }
            }
            .show()
    }

    private fun startAppStudy() {
        val pkg = AnamikaAccessibilityService.lastForegroundPackage
        if (pkg.isNullOrBlank()) {
            reply("Pehle target app open karo aur login complete karo, phir Anamika me wapas aao.")
            return
        }
        if (!appAccessPolicy.isAllowed(pkg)) {
            reply("Pehle owner se app authorize karo: 'app allow current'.")
            return
        }
        if (AnamikaAccessibilityService.active == null) {
            reply("Anamika Accessibility service enabled nahi hai.")
            return
        }

        requestOwnerApproval(
            OwnerAction.OBSERVE_OTHER_APP,
            "Start feature study for $pkg"
        ) {
            appStudy.start(pkg)
            reply("App study ON: $pkg. Screens aur menus visit karo; Anamika feature map capture karegi.")
            packageManager.getLaunchIntentForPackage(pkg)?.let(::startActivity)
        }
    }

    private fun captureAppStudyScreen() {
        val pkg = appStudy.currentPackage()
        if (pkg.isNullOrBlank() || !appStudy.isActiveFor(pkg)) {
            reply("App study active nahi hai.")
            return
        }

        val ok = AnamikaAccessibilityService.active?.captureCurrentScreen(pkg) == true
        reply(if (ok) "Current screen study map me add ho gayi." else "Current target screen capture nahi ho saki.")
    }

    private fun showAppStudyReport() {
        val pkg = appStudy.currentPackage()
            ?: AnamikaAccessibilityService.lastForegroundPackage
        if (pkg.isNullOrBlank()) {
            reply("Study report ke liye target app nahi mila.")
            return
        }
        reply(appStudy.report(pkg))
    }

    private fun exportAppStudyReport() {
        val pkg = appStudy.currentPackage()
            ?: AnamikaAccessibilityService.lastForegroundPackage
        if (pkg.isNullOrBlank()) {
            reply("Export ke liye study data nahi mila.")
            return
        }

        requestOwnerApproval(
            OwnerAction.WRITE_LOCAL_FILE,
            "Export observed feature map of $pkg into local coding workspace"
        ) {
            runGit {
                val report = appStudy.report(pkg)
                val safeName = pkg.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val path = "study/$safeName-FEATURE_MAP.txt"
                workspaceFiles.writeText(currentWorkspace, path, report)
                "Feature map exported: $path"
            }
        }
    }

    private fun withInternet(action: () -> Unit) {
        if (!features.isEnabled(FeatureId.INTERNET)) {
            reply("Internet feature owner policy se OFF hai.")
            return
        }
        if (!internetPolicy.isEnabled()) {
            reply("Internet owner policy se OFF hai. Local kaam available hai.")
            return
        }
        action()
    }

    private fun openExternalApp(packageName: String) {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch == null) {
            reply("Installed app nahi mila: $packageName")
            return
        }
        startActivity(launch)
    }

    private fun controlLastApp(summary: String, action: () -> Boolean) {
        val pkg = AnamikaAccessibilityService.lastForegroundPackage
        if (pkg.isNullOrBlank()) {
            reply("Recent target app nahi mila.")
            return
        }
        if (!appAccessPolicy.isAllowed(pkg)) {
            reply("Owner ne is app ko authorize nahi kiya: $pkg")
            return
        }
        if (AnamikaAccessibilityService.active == null) {
            reply("Anamika Accessibility service enabled nahi hai.")
            return
        }

        requestOwnerApproval(
            OwnerAction.CONTROL_OTHER_APP,
            "$summary in $pkg"
        ) {
            val launch = packageManager.getLaunchIntentForPackage(pkg)
            if (launch == null) {
                reply("App launch nahi ho saki: $pkg")
                return@requestOwnerApproval
            }
            startActivity(launch)
            Handler(Looper.getMainLooper()).postDelayed({
                val ok = runCatching(action).getOrDefault(false)
                reply(if (ok) "Cross-app action complete." else "Target control nahi mila ya secure field/action blocked hai.")
            }, 900)
        }
    }

    private fun generateProjectLocally(goal: String) {
        reply("Code phone ke local workspace me generate ho rahi hai.")
        Thread {
            val result = runCatching {
                localGit.init(currentWorkspace)
                localProjectGenerator.generate(currentWorkspace, goal)
            }

            runOnUiThread {
                result.onSuccess { project ->
                    reply(
                        "Coding local workspace me ready hai." +
                            "\nWorkspace: " + project.workspace +
                            "\nFiles: " + project.filesWritten +
                            "\nServer use nahi hua." +
                            "\nAPK ke liye 'build apk' bolo."
                    )
                }.onFailure {
                    reply("Local coding failed: " + it.message)
                }
            }
        }.start()
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
        if (!internetPolicy.isEnabled()) {
            reply("Internet owner policy se OFF hai.")
            return
        }
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
        if (::features.isInitialized && features.isEnabled(FeatureId.VOICE_REPLY)) {
            voice.speak(text)
        }
    }

    override fun onDestroy() {
        voice.destroy()
        super.onDestroy()
    }
}
