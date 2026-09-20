package com.anamika.ai.behavior;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Owner-controlled runtime preferences that do not require source-code edits.
 * These settings are local, persistent, and can be changed by natural language.
 */
public final class RuntimeBehaviorPreferences {
    private static final String PREFS="anamika_runtime_behavior";
    private static final String SILENCE_MS="silence_ms";
    private static final String FULL_REPLY="full_reply";
    private static final String SHORT_WAKE="short_wake";
    private static final String EXPLICIT_AFTER_SILENCE="explicit_after_silence";

    private RuntimeBehaviorPreferences(){}

    public static void ensureDefaults(Context c){
        if(c==null)return;
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        if(!p.contains(SILENCE_MS)){
            p.edit()
                    .putLong(SILENCE_MS,3000L)
                    .putBoolean(FULL_REPLY,true)
                    .putBoolean(SHORT_WAKE,true)
                    .putBoolean(EXPLICIT_AFTER_SILENCE,true)
                    .apply();
        }
    }

    public static long silenceMs(Context c){
        ensureDefaults(c);
        return clamp(c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getLong(SILENCE_MS,3000L),1200L,7000L);
    }

    public static boolean fullReply(Context c){
        ensureDefaults(c);
        return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getBoolean(FULL_REPLY,true);
    }

    public static boolean shortWakeEnabled(Context c){
        ensureDefaults(c);
        return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getBoolean(SHORT_WAKE,true);
    }

    public static boolean explicitWakeAfterSilence(Context c){
        ensureDefaults(c);
        return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getBoolean(EXPLICIT_AFTER_SILENCE,true);
    }

    public static String applyOwnerCommand(Context c,String raw){
        if(c==null||raw==null)return "";
        ensureDefaults(c);
        String s=raw.toLowerCase(Locale.ROOT).trim();
        SharedPreferences.Editor e=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit();
        boolean changed=false;

        Matcher sec=Pattern.compile("(\\d+(?:\\.\\d+)?)\\s*(?:sec|second|seconds|सेकंड)").matcher(s);
        if(sec.find() && containsAny(s,"reply","jawab","जवाब","silence","chup","रुक","ruk")){
            double v=Double.parseDouble(sec.group(1));
            e.putLong(SILENCE_MS,clamp((long)(v*1000.0),1200L,7000L));
            changed=true;
        }

        if(containsAny(s,"full reply","pura reply","poora reply","पूरा जवाब","detail me reply","detail mein reply")){
            e.putBoolean(FULL_REPLY,true);changed=true;
        }
        if(containsAny(s,"short reply","chota reply","छोटा जवाब")){
            e.putBoolean(FULL_REPLY,false);changed=true;
        }

        if(containsAny(s,"mika bolne se","anamika bolne se","sirf mika","sirf anamika","mika se wake","anamika se wake")){
            e.putBoolean(SHORT_WAKE,true);changed=true;
        }

        if(containsAny(s,"sirf hello mika","sirf hello anamika","only hello mika","only hello anamika")){
            e.putBoolean(SHORT_WAKE,false);changed=true;
        }

        if(containsAny(s,"chup hone ke baad hello se","silent ke baad hello","chup mode ke baad hello")){
            e.putBoolean(EXPLICIT_AFTER_SILENCE,true);changed=true;
        }

        if(!changed)return "";
        e.apply();
        return summary(c);
    }

    public static String summary(Context c){
        ensureDefaults(c);
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        return "Behavior: reply after "+(p.getLong(SILENCE_MS,3000L)/1000.0)+"s silence"+
                " • full reply "+(p.getBoolean(FULL_REPLY,true)?"ON":"OFF")+
                " • Mika/Anamika wake "+(p.getBoolean(SHORT_WAKE,true)?"ON":"OFF")+
                " • explicit Hello after silent mode "+(p.getBoolean(EXPLICIT_AFTER_SILENCE,true)?"ON":"OFF");
    }

    private static boolean containsAny(String s,String... xs){for(String x:xs)if(s.contains(x))return true;return false;}
    private static long clamp(long v,long lo,long hi){return Math.max(lo,Math.min(hi,v));}
}
