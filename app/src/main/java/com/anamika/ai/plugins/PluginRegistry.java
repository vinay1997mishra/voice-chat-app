package com.anamika.ai.plugins;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Owner-controlled registry of apps Anamika is allowed to launch/control. */
public final class PluginRegistry {
    private static final String PREFS = "anamika_plugins";
    private static final String ENABLED = "enabled_packages";

    public static final class AppPlugin {
        public final String label;
        public final String packageName;
        public final boolean enabled;
        public AppPlugin(String label, String packageName, boolean enabled) {
            this.label = label; this.packageName = packageName; this.enabled = enabled;
        }
    }

    private PluginRegistry() { }

    public static List<AppPlugin> discover(Context context) {
        PackageManager pm = context.getPackageManager();
        Intent launcher = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> matches = pm.queryIntentActivities(launcher, PackageManager.MATCH_ALL);
        Set<String> enabled = enabledSet(context);
        List<AppPlugin> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (ResolveInfo info : matches) {
            if (info.activityInfo == null || info.activityInfo.packageName == null) continue;
            String pkg = info.activityInfo.packageName;
            if (pkg.equals(context.getPackageName()) || !seen.add(pkg)) continue;
            CharSequence labelCs = info.loadLabel(pm);
            String label = labelCs == null ? pkg : labelCs.toString();
            out.add(new AppPlugin(label, pkg, enabled.contains(pkg)));
        }
        Collections.sort(out, Comparator.comparing(a -> a.label.toLowerCase(Locale.ROOT)));
        return out;
    }


    public static String findPackageByLabel(Context context, String requested) {
        if (requested == null) return null;
        String q=requested.trim().toLowerCase(Locale.ROOT); if(q.isEmpty()) return null;
        AppPlugin best=null;
        for(AppPlugin p:discover(context)) {
            String label=p.label.toLowerCase(Locale.ROOT);
            if(label.equals(q)) return p.packageName;
            if(label.contains(q) || q.contains(label)) { if(best==null || p.label.length()<best.label.length()) best=p; }
        }
        return best==null?null:best.packageName;
    }

    public static boolean isEnabled(Context context, String packageName) {
        return enabledSet(context).contains(packageName);
    }

    public static void setEnabled(Context context, String packageName, boolean enabled) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Set<String> next = new HashSet<>(prefs.getStringSet(ENABLED, Collections.emptySet()));
        if (enabled) next.add(packageName); else next.remove(packageName);
        prefs.edit().putStringSet(ENABLED, next).apply();
    }

    private static Set<String> enabledSet(Context context) {
        return new HashSet<>(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getStringSet(ENABLED, Collections.emptySet()));
    }
}
