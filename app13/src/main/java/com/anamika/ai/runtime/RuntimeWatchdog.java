package com.anamika.ai.runtime;

import android.content.Context;
import android.content.SharedPreferences;

/** Detects launches which never reached a healthy checkpoint. */
public final class RuntimeWatchdog {
    private static final String PREF="anamika13_watchdog";
    private static final String PENDING="launch_pending";
    private static final String STREAK="failed_launch_streak";
    private static final String LAST_START="last_start_ms";
    private static final String LAST_HEALTHY="last_healthy_ms";

    private RuntimeWatchdog(){}

    public static void recordLaunch(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        int streak=p.getInt(STREAK,0);
        if(p.getBoolean(PENDING,false)) streak++;
        p.edit()
                .putBoolean(PENDING,true)
                .putInt(STREAK,streak)
                .putLong(LAST_START,System.currentTimeMillis())
                .apply();
    }

    public static void markHealthy(Context c){
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                .putBoolean(PENDING,false)
                .putInt(STREAK,0)
                .putLong(LAST_HEALTHY,System.currentTimeMillis())
                .apply();
    }

    public static boolean recoverySuggested(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getInt(STREAK,0)>=2;
    }

    public static String status(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        return "Runtime watchdog\nPending launch: "+p.getBoolean(PENDING,false)+
                "\nFailed-launch streak: "+p.getInt(STREAK,0)+
                "\nLast start: "+p.getLong(LAST_START,0L)+
                "\nLast healthy: "+p.getLong(LAST_HEALTHY,0L);
    }
}
