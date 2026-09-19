package ai.anamika.app.automation

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AnamikaAccessibilityService : AccessibilityService() {
    private lateinit var policy: AppAccessPolicy
    private lateinit var observations: AppObservationStore

    override fun onServiceConnected() {
        policy = AppAccessPolicy(this)
        observations = AppObservationStore(this)

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
