package com.anamika.ai.phone;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

public final class AppLauncher {
    public static final class Result {
        public final boolean launched;
        public final String message;
        Result(boolean launched,String message){this.launched=launched;this.message=message;}
    }

    public static final class AppRef {
        public final String packageName;
        public final String label;
        AppRef(String packageName,String label){this.packageName=packageName;this.label=label;}
    }

    private AppLauncher(){}

    private static List<ApplicationInfo> installed(PackageManager pm){
        if(Build.VERSION.SDK_INT>=33)
            return pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0));
        return pm.getInstalledApplications(0);
    }

    public static AppRef resolve(Context c,String requested) {
        String q=requested==null?"":requested.trim().toLowerCase(Locale.ROOT);
        if(q.isEmpty()) return null;
        PackageManager pm=c.getPackageManager();
        AppRef best=null;
        int bestLen=Integer.MAX_VALUE;
        for(ApplicationInfo a:installed(pm)){
            if(pm.getLaunchIntentForPackage(a.packageName)==null) continue;
            String label=String.valueOf(pm.getApplicationLabel(a));
            String lower=label.toLowerCase(Locale.ROOT);
            if(lower.equals(q)) return new AppRef(a.packageName,label);
            if(lower.contains(q)||q.contains(lower)){
                if(label.length()<bestLen){
                    best=new AppRef(a.packageName,label);
                    bestLen=label.length();
                }
            }
        }
        return best;
    }

    public static Result open(Context c,String requested) {
        String q=requested==null?"":requested.trim().toLowerCase(Locale.ROOT);
        if(q.isEmpty()) return new Result(false,"App name missing.");
        PackageManager pm=c.getPackageManager();
        List<ApplicationInfo> candidates=new ArrayList<>();
        for(ApplicationInfo a:installed(pm)){
            Intent launch=pm.getLaunchIntentForPackage(a.packageName);
            if(launch==null) continue;
            String label=String.valueOf(pm.getApplicationLabel(a)).toLowerCase(Locale.ROOT);
            if(label.equals(q)) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                try{
                    c.startActivity(launch);
                    return new Result(true,"Opening "+pm.getApplicationLabel(a)+".");
                }catch(Exception e){
                    return new Result(false,"App launch failed: "+safe(e));
                }
            }
            if(label.contains(q)||q.contains(label)) candidates.add(a);
        }
        candidates.sort(Comparator.comparingInt(a->String.valueOf(pm.getApplicationLabel(a)).length()));
        if(candidates.isEmpty()) return new Result(false,"I could not find an installed launchable app named "+requested+".");
        ApplicationInfo a=candidates.get(0);
        Intent launch=pm.getLaunchIntentForPackage(a.packageName);
        if(launch==null) return new Result(false,"That app cannot be launched.");
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try{
            c.startActivity(launch);
            return new Result(true,"Opening "+pm.getApplicationLabel(a)+".");
        }catch(Exception e){
            return new Result(false,"App launch failed: "+safe(e));
        }
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
