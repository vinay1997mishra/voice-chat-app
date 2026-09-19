package ai.anamika.app.security

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context

class OwnerPermissionGate {
    companion object {
        const val REQUEST_OWNER_AUTH = 7001
    }

    fun request(
        activity: Activity,
        action: OwnerAction,
        summary: String
    ): Boolean {
        if (!OwnerPermissionPolicy.requiresDeviceCredential(action)) return true

        val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = keyguard.createConfirmDeviceCredentialIntent(
            "Anamika owner approval",
            "${action.name}: $summary"
        ) ?: return false

        activity.startActivityForResult(intent, REQUEST_OWNER_AUTH)
        return true
    }

    fun requestDeviceCredential(activity: Activity, reason: String): Boolean =
        request(activity, OwnerAction.SELF_UPDATE, reason)
}
