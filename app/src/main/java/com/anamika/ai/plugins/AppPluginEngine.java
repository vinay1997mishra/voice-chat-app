package com.anamika.ai.plugins;

import android.content.Context;
import android.content.Intent;

import com.anamika.ai.OwnerSession;

import java.util.UUID;

/**
 * App launcher/control bridge.
 * Plugin apps receive persistent advanced control.
 * Non-plugin apps may still be opened or receive a single explicit owner command
 * without ever being added to the plugin registry.
 */
public final class AppPluginEngine {
    private static final String PREFS="anamika_automation";
    private AppPluginEngine() { }

    public static String openAny(Context context,String packageName){
        if(context==null || packageName==null || packageName.trim().isEmpty()) return "App package missing.";
        Intent launch=context.getPackageManager().getLaunchIntentForPackage(packageName);
        if(launch==null) return "App launch activity not found.";
        // Opening an app alone must never replay a stale automation command.
        context.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit()
                .remove("pending_command").remove("pending_token").remove("one_shot_owner_command").apply();
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(launch);
        return "App opened.";
    }

    public static String openAndRun(Context context,String packageName,String command){
        if(!PluginRegistry.isEnabled(context,packageName)) return "Plugin disabled for this app.";
        return queueAndLaunch(context,packageName,command,false);
    }

    public static String openAndRunOneShot(Context context,String packageName,String command){
        if(!OwnerSession.isActive(context)) return "Owner session is not active.";
        return queueAndLaunch(context,packageName,command,true);
    }

    private static String queueAndLaunch(Context context,String packageName,String command,boolean oneShot){
        Intent launch=context.getPackageManager().getLaunchIntentForPackage(packageName);
        if(launch==null) return "App launch activity not found.";
        String token=UUID.randomUUID().toString();
        context.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit()
                .putString("target_package",packageName)
                .putString("pending_command",command==null?"":command.trim())
                .putString("pending_token",token)
                .putBoolean("one_shot_owner_command",oneShot)
                .apply();
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(launch);
        if(command==null || command.trim().isEmpty()) return "App opened.";
        return oneShot
                ? "App opened. One-time owner command queued; app was NOT added as a plugin."
                : "Plugin app opened. Command queued for visible UI control.";
    }
}
