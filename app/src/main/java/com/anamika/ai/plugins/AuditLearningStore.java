package com.anamika.ai.plugins;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

/**
 * Persistent per-app audit learning. Stores only UI fingerprints/labels and outcomes,
 * never typed secrets, passwords, message bodies or private app data.
 */
public final class AuditLearningStore {
    private static final String PREFS="anamika_audit_learning";
    private static final int MAX_ENTRIES=1200;

    private AuditLearningStore(){}

    public static void learnSafe(Context c,String pkg,String fingerprint,String label){
        add(c,key(pkg,"safe"),compact(fingerprint,label));
    }

    public static void learnRisk(Context c,String pkg,String fingerprint,String label){
        add(c,key(pkg,"risk"),compact(fingerprint,label));
    }

    public static void learnFailed(Context c,String pkg,String fingerprint,String label){
        add(c,key(pkg,"failed"),compact(fingerprint,label));
    }

    public static boolean knownSafe(Context c,String pkg,String fingerprint){
        return containsFingerprint(c,key(pkg,"safe"),fingerprint);
    }

    public static boolean knownRisk(Context c,String pkg,String fingerprint){
        return containsFingerprint(c,key(pkg,"risk"),fingerprint);
    }

    public static String summary(Context c,String pkg){
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        int safe=p.getStringSet(key(pkg,"safe"),java.util.Collections.emptySet()).size();
        int risk=p.getStringSet(key(pkg,"risk"),java.util.Collections.emptySet()).size();
        int failed=p.getStringSet(key(pkg,"failed"),java.util.Collections.emptySet()).size();
        return "Learned audit profile: safe="+safe+", risky="+risk+", failed/unreachable="+failed;
    }

    private static void add(Context c,String key,String value){
        if(value==null||value.isEmpty()) return;
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        Set<String> next=new HashSet<>(p.getStringSet(key,java.util.Collections.emptySet()));
        if(next.size()>=MAX_ENTRIES){
            java.util.Iterator<String> it=next.iterator();
            while(next.size()>=MAX_ENTRIES && it.hasNext()){ it.next(); it.remove(); }
        }
        next.add(value);
        p.edit().putStringSet(key,next).apply();
    }

    private static boolean containsFingerprint(Context c,String key,String fingerprint){
        if(fingerprint==null||fingerprint.isEmpty()) return false;
        for(String v:c.getSharedPreferences(PREFS,Context.MODE_PRIVATE)
                .getStringSet(key,java.util.Collections.emptySet())){
            if(v.startsWith(fingerprint+"|")) return true;
        }
        return false;
    }

    private static String compact(String fp,String label){
        String f=fp==null?"":fp.replace("|","/");
        String l=label==null?"":label.replace("|","/").replace("\n"," ");
        if(l.length()>120) l=l.substring(0,120);
        return f+"|"+l;
    }

    private static String key(String pkg,String kind){
        String p=pkg==null?"app":pkg.replaceAll("[^A-Za-z0-9._-]","_");
        return p+"_"+kind;
    }
}
