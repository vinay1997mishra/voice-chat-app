package com.anamika.ai.phone;

import android.content.Context;
import android.os.Build;
import org.json.JSONObject;

public final class DeviceProfileStore {
    private static final String PREFS="anamika_device_profile";
    private static final String KEY="profile_json";
    private DeviceProfileStore(){}

    public static synchronized String ensureSaved(Context c){
        if(c==null)return "";
        String existing=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(KEY,"");
        if(!existing.isEmpty()) {
            try {
                JSONObject saved=new JSONObject(existing);
                if(safe(Build.FINGERPRINT).equals(saved.optString("fingerprint")) &&
                        safe(Build.MODEL).equals(saved.optString("model"))) return existing;
            } catch(Exception ignored) { }
        }
        try{
            JSONObject o=new JSONObject();
            o.put("manufacturer",safe(Build.MANUFACTURER));
            o.put("brand",safe(Build.BRAND));
            o.put("model",safe(Build.MODEL));
            o.put("device",safe(Build.DEVICE));
            o.put("product",safe(Build.PRODUCT));
            o.put("hardware",safe(Build.HARDWARE));
            o.put("board",safe(Build.BOARD));
            o.put("androidRelease",safe(Build.VERSION.RELEASE));
            o.put("sdkInt",Build.VERSION.SDK_INT);
            o.put("securityPatch",safe(Build.VERSION.SECURITY_PATCH));
            o.put("fingerprint",safe(Build.FINGERPRINT));
            o.put("savedAt",System.currentTimeMillis());
            String raw=o.toString();
            c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().putString(KEY,raw).apply();
            return raw;
        }catch(Exception e){return "";}
    }

    public static String searchContext(Context c){
        String raw=ensureSaved(c);
        try{
            JSONObject o=new JSONObject(raw);
            return clean(o.optString("manufacturer",""))+" "+
                    clean(o.optString("brand",""))+" "+
                    clean(o.optString("model",""))+" Android "+
                    clean(o.optString("androidRelease",""))+" SDK "+o.optInt("sdkInt",Build.VERSION.SDK_INT);
        }catch(Exception e){
            return Build.MANUFACTURER+" "+Build.MODEL+" Android "+Build.VERSION.RELEASE;
        }
    }

    public static String summary(Context c){
        String raw=ensureSaved(c);
        try{
            JSONObject o=new JSONObject(raw);
            return "Phone: "+clean(o.optString("manufacturer",""))+" "+clean(o.optString("model",""))+
                    " • Android "+clean(o.optString("androidRelease",""))+
                    " • SDK "+o.optInt("sdkInt",Build.VERSION.SDK_INT);
        }catch(Exception e){
            return "Phone: "+Build.MANUFACTURER+" "+Build.MODEL+" • Android "+Build.VERSION.RELEASE;
        }
    }

    private static String safe(String s){return s==null?"":s;}
    private static String clean(String s){
        if(s==null||s.isEmpty())return "";
        return s.substring(0,1).toUpperCase(java.util.Locale.ROOT)+s.substring(1);
    }
}
