package com.anamika.ai.phone;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.provider.Settings;

import org.json.JSONObject;

import java.util.Locale;

/**
 * Stores only phone-function routes which passed a concrete local verification.
 * A web suggestion alone is never marked verified.
 */
public final class VerifiedFunctionMemory {
    public static final class Entry {
        public final String phrase;
        public final String action;
        public final String label;
        public final long verifiedAt;
        Entry(String phrase,String action,String label,long verifiedAt){
            this.phrase=phrase;this.action=action;this.label=label;this.verifiedAt=verifiedAt;
        }
    }

    private static final String PREFS="anamika_verified_functions";
    private VerifiedFunctionMemory(){}

    public static boolean verifyAndSaveIntent(Context c,String phrase,String action,String label){
        if(c==null||phrase==null||phrase.trim().isEmpty()||action==null||action.trim().isEmpty()) return false;
        Intent i=new Intent(action);
        PackageManager pm=c.getPackageManager();
        if(i.resolveActivity(pm)==null) return false;
        save(c,phrase,action,label);
        return true;
    }

    public static Entry find(Context c,String phrase){
        if(c==null||phrase==null)return null;
        String raw=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(key(phrase),"");
        if(raw.isEmpty())return null;
        try{
            JSONObject o=new JSONObject(raw);
            return new Entry(o.optString("phrase",phrase),o.optString("action",""),
                    o.optString("label",""),o.optLong("verifiedAt",0));
        }catch(Exception e){return null;}
    }

    private static void save(Context c,String phrase,String action,String label){
        try{
            JSONObject o=new JSONObject();
            o.put("phrase",phrase.trim());
            o.put("action",action);
            o.put("label",label==null?"":label);
            o.put("verifiedAt",System.currentTimeMillis());
            c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit()
                    .putString(key(phrase),o.toString()).apply();
        }catch(Exception ignored){}
    }

    private static String key(String phrase){
        String n=phrase.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+"," ");
        return "f_"+Integer.toHexString(n.hashCode());
    }

    public static String knownActionForKeyword(String q){
        if(q==null)return "";
        String s=q.toLowerCase(Locale.ROOT);
        if(has(s,"wifi","wi-fi","वाईफाई")) return Settings.ACTION_WIFI_SETTINGS;
        if(has(s,"bluetooth","ब्लूटूथ")) return Settings.ACTION_BLUETOOTH_SETTINGS;
        if(has(s,"brightness","display","ब्राइटनेस")) return Settings.ACTION_DISPLAY_SETTINGS;
        if(has(s,"location","gps","लोकेशन")) return Settings.ACTION_LOCATION_SOURCE_SETTINGS;
        if(has(s,"battery saver","बैटरी सेवर")) return Settings.ACTION_BATTERY_SAVER_SETTINGS;
        if(has(s,"sound","volume","ringtone","वॉल्यूम","रिंगटोन")) return Settings.ACTION_SOUND_SETTINGS;
        if(has(s,"airplane","flight mode","एयरप्लेन")) return Settings.ACTION_AIRPLANE_MODE_SETTINGS;
        if(has(s,"accessibility","एक्सेसिबिलिटी")) return Settings.ACTION_ACCESSIBILITY_SETTINGS;
        if(has(s,"notification","नोटिफिकेशन")) return "android.settings.NOTIFICATION_SETTINGS";
        return "";
    }

    private static boolean has(String s,String... xs){for(String x:xs)if(s.contains(x))return true;return false;}
}
