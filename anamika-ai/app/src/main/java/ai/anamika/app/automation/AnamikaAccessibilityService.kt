package ai.anamika.app.automation

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Bundle
import android.widget.Toast
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AnamikaAccessibilityService : AccessibilityService() {
    private lateinit var policy: AppAccessPolicy
    private lateinit var observations: AppObservationStore
    private lateinit var study: AppStudyStore

    override fun onServiceConnected() {
        policy = AppAccessPolicy(this)
        observations = AppObservationStore(this)
        study = AppStudyStore(this)

        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }

        active = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        val pkg = e.packageName?.toString().orEmpty()
        if (pkg.isBlank() || pkg == packageName) return

        lastForegroundPackage = pkg
        if (!policy.isAllowed(pkg)) return

        val source = e.source
        val challenge = detectHumanChallenge(source, e)
        if (study.isActiveFor(pkg) && challenge != null) {
            study.pauseForChallenge(pkg, challenge)
            Toast.makeText(
                this,
                "Anamika study paused: $challenge complete karo, phir scan continue hoga.",
                Toast.LENGTH_LONG
            ).show()
            return
        } else if (study.isActiveFor(pkg) && study.isPaused()) {
            study.resumeAfterChallenge(pkg)
            Toast.makeText(
                this,
                "Verification screen complete. Anamika study resumed.",
                Toast.LENGTH_SHORT
            ).show()
        }

        if (source?.isPassword == true) return

        val label = sanitizeLabel(
            listOfNotNull(
                source?.text?.toString(),
                source?.contentDescription?.toString(),
                e.text.joinToString(" ")
            ).firstOrNull { it.isNotBlank() }.orEmpty()
        )

        if (label.isBlank()) return

        observations.add(
            ObservedUiEvent(
                packageName = pkg,
                className = e.className?.toString().orEmpty(),
                eventType = e.eventType,
                label = label,
                timestamp = System.currentTimeMillis()
            )
        )

        if (
            study.isActiveFor(pkg) &&
            (
                e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                    e.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                    e.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED
                )
        ) {
            captureCurrentScreen(pkg, e.className?.toString().orEmpty())
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (active === this) active = null
        super.onDestroy()
    }

    fun clickByText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        if (!policy.isAllowed(root.packageName?.toString().orEmpty())) return false

        val matches = root.findAccessibilityNodeInfosByText(text)
        for (node in matches) {
            if (node.isPassword) continue
            var candidate: AccessibilityNodeInfo? = node
            repeat(4) {
                val current = candidate ?: return@repeat
                if (current.isClickable && current.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    return true
                }
                candidate = current.parent
            }
        }
        return false
    }

    fun setTextOnFocusedField(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val pkg = root.packageName?.toString().orEmpty()
        if (!policy.isAllowed(pkg)) return false

        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        if (focused.isPassword || looksSensitive(focused)) return false
        if (!focused.isEditable) return false

        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
        }
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun captureCurrentScreen(packageName: String, className: String = ""): Boolean {
        val root = rootInActiveWindow ?: return false
        val pkg = root.packageName?.toString().orEmpty()
        if (pkg != packageName || !policy.isAllowed(pkg) || !study.isActiveFor(pkg)) return false

        val nodes = mutableListOf<StudyNode>()
        collectStudyNodes(root, nodes, 0)

        val title = nodes
            .firstOrNull { it.text.isNotBlank() }
            ?.text
            .orEmpty()

        study.add(
            StudyScreen(
                packageName = pkg,
                className = className.ifBlank { root.className?.toString().orEmpty() },
                title = title,
                nodes = nodes,
                timestamp = System.currentTimeMillis()
            )
        )
        return true
    }

    private fun collectStudyNodes(
        node: AccessibilityNodeInfo?,
        out: MutableList<StudyNode>,
        depth: Int
    ) {
        val current = node ?: return
        if (depth > 30 || out.size >= 300) return
        if (current.isPassword || looksSensitive(current)) return

        val text = sanitizeLabel(
            listOfNotNull(
                current.text?.toString(),
                current.contentDescription?.toString(),
                current.hintText?.toString()
            ).firstOrNull { it.isNotBlank() }.orEmpty()
        )

        if (
            text.isNotBlank() ||
            current.isClickable ||
            current.isEditable ||
            current.isScrollable
        ) {
            out += StudyNode(
                text = text,
                viewId = current.viewIdResourceName.orEmpty(),
                className = current.className?.toString().orEmpty(),
                clickable = current.isClickable,
                editable = current.isEditable,
                scrollable = current.isScrollable
            )
        }

        for (i in 0 until current.childCount) {
            collectStudyNodes(current.getChild(i), out, depth + 1)
            if (out.size >= 300) break
        }
    }

    private fun detectHumanChallenge(
        node: AccessibilityNodeInfo?,
        event: AccessibilityEvent
    ): String? {
        val raw = buildString {
            append(event.text.joinToString(" "))
            append(' ')
            append(node?.text?.toString().orEmpty())
            append(' ')
            append(node?.contentDescription?.toString().orEmpty())
            append(' ')
            append(node?.hintText?.toString().orEmpty())
        }.lowercase()

        return when {
            "captcha" in raw || "i am not a robot" in raw || "verify you are human" in raw ->
                "CAPTCHA / human verification"
            "two-factor" in raw || "2fa" in raw || "two factor" in raw ->
                "two-factor authentication"
            "one-time password" in raw || "otp" in raw || "verification code" in raw ->
                "OTP / verification code"
            else -> null
        }
    }

    private fun looksSensitive(node: AccessibilityNodeInfo): Boolean {
        val combined = listOfNotNull(
            node.text,
            node.hintText,
            node.contentDescription,
            node.viewIdResourceName
        ).joinToString(" ").lowercase()

        return listOf("password", "passcode", "pin", "otp", "cvv", "secret").any(combined::contains)
    }

    private fun sanitizeLabel(value: String): String {
        val lower = value.lowercase()
        if (listOf("password", "passcode", "otp", "cvv", "secret").any(lower::contains)) {
            return ""
        }
        return value.trim().take(200)
    }

    companion object {
        @Volatile
        var active: AnamikaAccessibilityService? = null
            private set

        @Volatile
        var lastForegroundPackage: String? = null
            private set
    }
}
