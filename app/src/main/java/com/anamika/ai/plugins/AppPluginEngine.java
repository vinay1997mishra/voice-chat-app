package com.anamika.ai.plugins;

import android.content.Context;
import android.content.Intent;

import java.util.UUID;

/** Launches an owner-enabled app and queues a visible-UI command for the accessibility assistant. */
public final class AppPluginEngine {
    private AppPluginEngine() { }
    public static String openAndRun(Context context, String packageName, String command) {
        if (!PluginRegistry.isEnabled(context, packageName)) return "Plugin disabled for this app.";
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(packageName);
        if (launch == null) return "App launch activity not found.";
        context.getSharedPreferences("anamika_automation",Context.MODE_PRIVATE).edit()
                .putString("target_package",packageName)
                .putString("pending_command",command == null ? "" : command)
                .putString("pending_token",UUID.randomUUID().toString())
                .apply();
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(launch);
        return command == null || command.trim().isEmpty()
                ? "App opened." : "App opened. Command queued for visible UI control.";
    }
}
