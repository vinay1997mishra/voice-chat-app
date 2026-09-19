package ai.anamika.app.security

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context

class OwnerPermissionGate {
    companion object {
        const val REQUEST_OWNER_AUTH = 7001
    }

    fun requestDeviceCredential(activity: Activity, reason: String): Boolean {
        val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = keyguard.createConfirmDeviceCredentialIntent(
            "Anamika owner approval",
            reason
        ) ?: return false
        activity.startActivityForResult(intent, REQUEST_OWNER_AUTH)
        return true
    }
}
