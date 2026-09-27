package com.anamika.ai.plugins;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/** Owner-controlled package allow-list for Accessibility automation. */
public final class AppPluginRegistry {
    private static final String PREF="anamika13_plugins";
    private static final String ENABLED="enabled_packages";

    private AppPluginRegistry(){}

    public static Set<String> enabled(Context c){
        Set<String> s=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getStringSet(ENABLED,Collections.emptySet());
        return new HashSet<>(s);
    }

    public static boolean isEnabled(Context c,String pkg){
        return pkg!=null&&enabled(c).contains(pkg);
    }

    public static void setEnabled(Context c,String pkg,boolean on){
        if(pkg==null||pkg.trim().isEmpty())return;
        Set<String> set=enabled(c);
        if(on)set.add(pkg);else set.remove(pkg);
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().putStringSet(ENABLED,set).apply();
    }
}
