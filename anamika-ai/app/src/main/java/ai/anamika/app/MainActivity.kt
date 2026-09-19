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
import ai.anamika.app.core.Command
import ai.anamika.app.core.CommandRouter
import ai.anamika.app.security.OwnerPermissionGate
import ai.anamika.app.storage.MemoryStore
import ai.anamika.app.update.AnamikaRelease
import ai.anamika.app.update.GitHubReleaseChecker
import ai.anamika.app.voice.VoiceAssistant
import java.net.URLEncoder

class MainActivity : Activity() {
    private val router = CommandRouter()
    private val ai = BackendAiGateway()
    private val releaseChecker = GitHubReleaseChecker()
    private val permissionGate = OwnerPermissionGate()

    private lateinit var voice: VoiceAssistant
    private lateinit var memory: MemoryStore
    private lateinit var status: TextView
    private var releasePendingAuthorization: AnamikaRelease? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        memory = MemoryStore(this)
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
            text = "Ready. Hindi or English me command bol sakte ho."
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

        root.addView(title)
        root.addView(status)
        root.addView(speak)
        root.addView(updates)
        root.addView(memories)

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
            is Command.Unknown -> reply("Command samajh aaya, lekin is action ka module abhi connected nahi hai.")
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
            .setTitle("Owner approval required")
            .setMessage(
                "Update: ${release.name}\n\n" +
                    (release.notes.ifBlank { "No release notes were provided." }) +
                    "\n\nAnamika will not install anything automatically."
            )
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Authorize") { _, _ ->
                releasePendingAuthorization = release
                val started = permissionGate.requestDeviceCredential(
                    this,
                    "Approve opening the verified GitHub release page for this Anamika update."
                )
                if (!started) {
                    releasePendingAuthorization = null
                    reply("Secure device credential is not configured.")
                }
            }
            .show()
    }

    @Deprecated("Deprecated in Android API but kept for minSdk compatibility in this bootstrap.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OwnerPermissionGate.REQUEST_OWNER_AUTH) {
            val release = releasePendingAuthorization
            releasePendingAuthorization = null
            if (resultCode == RESULT_OK && release != null) {
                reply("Owner approval confirmed. GitHub release page open ho rahi hai.")
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(release.url)))
            } else {
                reply("Upgrade authorization cancelled.")
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
