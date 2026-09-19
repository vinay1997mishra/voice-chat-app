package ai.anamika.app.build

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

class ApkInstaller(private val activity: Activity) {
    fun openInstaller(apk: File) {
        require(apk.exists() && apk.length() > 0) { "APK file missing" }

        val uri = FileProvider.getUriForFile(
            activity,
            activity.packageName + ".files",
            apk
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }
}
