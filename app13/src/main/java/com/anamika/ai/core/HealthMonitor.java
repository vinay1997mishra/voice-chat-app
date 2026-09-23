package com.anamika.ai.core;

import android.app.ActivityManager;
import android.content.Context;
import android.os.BatteryManager;
import android.os.StatFs;

import java.io.File;
import java.util.Locale;

public final class HealthMonitor {
    private HealthMonitor(){}

    public static String report(Context c) {
        ActivityManager am=(ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo mi=new ActivityManager.MemoryInfo();
        if(am!=null) am.getMemoryInfo(mi);

        StatFs fs=new StatFs(c.getFilesDir().getAbsolutePath());
        long free=fs.getAvailableBytes();
        long total=fs.getTotalBytes();

        BatteryManager bm=(BatteryManager)c.getSystemService(Context.BATTERY_SERVICE);
        int battery=bm==null?-1:bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);

        return String.format(Locale.US,
                "Anamika health\nRAM available: %.1f GB\nLow-memory: %s\nPrivate storage free: %.1f GB / %.1f GB\nBattery: %s",
                mi.availMem/1073741824.0,
                mi.lowMemory?"YES":"no",
                free/1073741824.0,
                total/1073741824.0,
                battery<0?"unknown":battery+"%");
    }

    public static boolean enoughForLocalBuild(Context c,long requiredFreeBytes) {
        StatFs fs=new StatFs(c.getFilesDir().getAbsolutePath());
        return fs.getAvailableBytes()>=requiredFreeBytes;
    }
}
