package com.anamika.ai;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Owner-only Native App Test Lab.
 *
 * Flow:
 *  1) owner selects a built APK,
 *  2) Anamika copies it into private storage and validates package metadata,
 *  3) Android PackageInstaller performs the real install/update with the normal OS confirmation,
 *  4) Anamika can launch the last successfully selected test package for manual testing.
 *
 * This deliberately does not attempt silent installation or bypass Android's installer/security UI.
 */
public final class TestLabActivity extends Activity {
    private static final int REQ_PICK_APK = 4101;
    private static final int REQ_UNKNOWN_SOURCES = 4102;
    private static final String ACTION_INSTALL_RESULT = "com.anamika.ai.TEST_INSTALL_RESULT";
    private static final String PREF = "anamika_test_lab";
    private static final String KEY_PACKAGE = "last_package";

    private TextView status;
    private File stagedApk;
    private String stagedPackage = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (!OwnerSession.isActive(this)) {
            Toast.makeText(this, "Owner unlock required.", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        setContentView(R.layout.activity_test_lab);
        status = findViewById(R.id.testLabStatus);
        stagedApk = new File(new File(getFilesDir(), "test_lab"), "candidate.apk");

        Button pick = findViewById(R.id.pickApkButton);
        Button install = findViewById(R.id.installApkButton);
        Button launch = findViewById(R.id.launchTestAppButton);
        Button settings = findViewById(R.id.installPermissionButton);

        pick.setOnClickListener(v -> pickApk());
        install.setOnClickListener(v -> installStagedApk());
        launch.setOnClickListener(v -> launchLastTestApp());
        settings.setOnClickListener(v -> openInstallPermission());

        handleInstallResult(getIntent());
        refreshStatus();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleInstallResult(intent);
    }

    private void pickApk() {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/vnd.android.package-archive");
        try {
            startActivityForResult(i, REQ_PICK_APK);
        } catch (Exception e) {
            status.setText("APK picker unavailable: " + safe(e));
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PICK_APK && resultCode == RESULT_OK && data != null && data.getData() != null) {
            stageApk(data.getData());
        } else if (requestCode == REQ_UNKNOWN_SOURCES) {
            refreshStatus();
        }
    }

    private void stageApk(Uri source) {
        File dir = stagedApk.getParentFile();
        if (dir != null && !dir.exists() && !dir.mkdirs()) {
            status.setText("Cannot create Test Lab folder.");
            return;
        }
        File partial = new File(dir, "candidate.apk.partial");
        try (InputStream in = getContentResolver().openInputStream(source);
             OutputStream out = new FileOutputStream(partial)) {
            if (in == null) throw new IllegalStateException("Cannot open selected APK");
            byte[] buf = new byte[128 * 1024];
            long total = 0;
            int n;
            while ((n = in.read(buf)) >= 0) {
                if (n == 0) continue;
                total += n;
                if (total > 4L * 1024 * 1024 * 1024) throw new IllegalStateException("APK is too large for Test Lab");
                out.write(buf, 0, n);
            }
            out.flush();
            if (total < 1024) throw new IllegalStateException("Selected APK is empty or invalid");
        } catch (Exception e) {
            partial.delete();
            status.setText("APK copy failed: " + safe(e));
            return;
        }

        PackageInfo info = getPackageManager().getPackageArchiveInfo(partial.getAbsolutePath(), PackageManager.GET_ACTIVITIES);
        if (info == null || info.packageName == null || info.packageName.trim().isEmpty()) {
            partial.delete();
            status.setText("Selected file is not a valid Android APK.");
            return;
        }
        if (stagedApk.exists() && !stagedApk.delete()) {
            partial.delete();
            status.setText("Could not replace previous staged APK.");
            return;
        }
        if (!partial.renameTo(stagedApk)) {
            partial.delete();
            status.setText("Could not finalize staged APK.");
            return;
        }
        stagedPackage = info.packageName;
        getSharedPreferences(PREF, MODE_PRIVATE).edit().putString(KEY_PACKAGE, stagedPackage).apply();
        status.setText("APK ready for test install.\nPackage: " + stagedPackage + "\nSize: " + stagedApk.length() + " bytes");
    }

    private void installStagedApk() {
        if (!OwnerSession.isActive(this)) {
            status.setText("Owner session expired. Unlock Anamika again.");
            return;
        }
        if (!stagedApk.isFile() || stagedApk.length() < 1024) {
            status.setText("Select a valid APK first.");
            return;
        }
        if (!getPackageManager().canRequestPackageInstalls()) {
            status.setText("Android requires permission for Anamika to request APK installs. Open Install Permission, enable it, then return.");
            return;
        }

        PackageInstaller installer = getPackageManager().getPackageInstaller();
        PackageInstaller.Session session = null;
        try {
            PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
            if (stagedPackage != null && !stagedPackage.isEmpty()) params.setAppPackageName(stagedPackage);
            int sessionId = installer.createSession(params);
            session = installer.openSession(sessionId);
            try (InputStream in = new FileInputStream(stagedApk);
                 OutputStream out = session.openWrite("base.apk", 0, stagedApk.length())) {
                byte[] buf = new byte[128 * 1024];
                int n;
                while ((n = in.read(buf)) >= 0) {
                    if (n == 0) continue;
                    out.write(buf, 0, n);
                }
                session.fsync(out);
            }
            Intent callback = new Intent(this, TestLabActivity.class)
                    .setAction(ACTION_INSTALL_RESULT)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pending = PendingIntent.getActivity(this, sessionId, callback,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
            session.commit(pending.getIntentSender());
            status.setText("APK handed to Android installer. Complete the system confirmation to install/update the test app.");
        } catch (Exception e) {
            status.setText("Install request failed: " + safe(e));
            if (session != null) {
                try { session.abandon(); } catch (Exception ignored) { }
            }
        } finally {
            if (session != null) session.close();
        }
    }

    private void handleInstallResult(Intent intent) {
        if (intent == null || !ACTION_INSTALL_RESULT.equals(intent.getAction())) return;
        int state = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
        String msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
        if (state == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirm = intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirm != null) startActivity(confirm);
            return;
        }
        if (state == PackageInstaller.STATUS_SUCCESS) {
            status.setText("Test app installed successfully. Tap Launch Test App to use it.");
        } else {
            status.setText("Install failed/cancelled. Status=" + state + (msg == null ? "" : "\n" + msg));
        }
    }

    private void launchLastTestApp() {
        String pkg = getSharedPreferences(PREF, MODE_PRIVATE).getString(KEY_PACKAGE, "");
        if (pkg == null || pkg.isEmpty()) {
            status.setText("No test package recorded yet.");
            return;
        }
        Intent launch = getPackageManager().getLaunchIntentForPackage(pkg);
        if (launch == null) {
            status.setText("Package is not installed or has no launcher activity: " + pkg);
            return;
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(launch);
    }

    private void openInstallPermission() {
        try {
            Intent i = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + getPackageName()));
            startActivityForResult(i, REQ_UNKNOWN_SOURCES);
        } catch (Exception e) {
            startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS));
        }
    }

    private void refreshStatus() {
        String pkg = getSharedPreferences(PREF, MODE_PRIVATE).getString(KEY_PACKAGE, "");
        boolean canInstall = getPackageManager().canRequestPackageInstalls();
        if (status.getText() == null || status.getText().length() == 0) {
            status.setText("Install permission: " + (canInstall ? "ready" : "needs Android approval") +
                    (pkg == null || pkg.isEmpty() ? "" : "\nLast test package: " + pkg));
        }
    }

    private static String safe(Exception e) {
        String m = e.getMessage();
        return m == null || m.trim().isEmpty() ? e.getClass().getSimpleName() : m;
    }
}
