package com.anamika.ai.phone;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/** Android intent-based phone actions which do not bypass OS permission/UI controls. */
public final class PhoneActions {
    private PhoneActions(){}

    public static String openSettings(Activity a){
        try{
            a.startActivity(new Intent(Settings.ACTION_SETTINGS));
            return "Opening Android Settings.";
        }catch(Exception e){return "Settings could not open: "+safe(e);}
    }

    public static String openAppSettings(Activity a){
        try{
            a.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:"+a.getPackageName())));
            return "Opening Anamika app settings.";
        }catch(Exception e){return "App settings could not open: "+safe(e);}
    }

    public static String dial(Activity a,String number){
        String n=number==null?"":number.replaceAll("[^0-9+*#]","");
        if(n.isEmpty())return "Phone number missing.";
        try{
            a.startActivity(new Intent(Intent.ACTION_DIAL,Uri.parse("tel:"+Uri.encode(n))));
            return "Opening dialer for "+n+".";
        }catch(Exception e){return "Dialer could not open: "+safe(e);}
    }

    public static String openUrl(Activity a,String url){
        String u=url==null?"":url.trim();
        if(u.isEmpty())return "URL missing.";
        if(!u.startsWith("http://")&&!u.startsWith("https://"))u="https://"+u;
        try{
            a.startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(u)));
            return "Opening "+u;
        }catch(Exception e){return "Browser could not open: "+safe(e);}
    }

    public static String webSearch(Activity a,String query){
        String q=query==null?"":query.trim();
        if(q.isEmpty())return "Search text missing.";
        try{
            String encoded=URLEncoder.encode(q,StandardCharsets.UTF_8.name());
            a.startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse("https://www.google.com/search?q="+encoded)));
            return "Searching for: "+q;
        }catch(Exception e){return "Search could not open: "+safe(e);}
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
