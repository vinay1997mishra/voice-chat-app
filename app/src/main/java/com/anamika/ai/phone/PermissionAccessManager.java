package com.anamika.ai.phone;

import android.Manifest;
import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.text.TextUtils;

import java.util.ArrayList;
import java.util.List;

public final class PermissionAccessManager {
    public static final int REQ_ALL_RUNTIME=1701;
    private PermissionAccessManager(){}

    public static String[] missingRuntimePermissions(Activity a){
        List<String> p=new ArrayList<>();
        addIfMissing(a,p,Manifest.permission.RECORD_AUDIO);
        addIfMissing(a,p,Manifest.permission.READ_CONTACTS);
        addIfMissing(a,p,Manifest.permission.CALL_PHONE);
        if(Build.VERSION.SDK_INT>=33){
            addIfMissing(a,p,Manifest.permission.POST_NOTIFICATIONS);
            addIfMissing(a,p,Manifest.permission.READ_MEDIA_IMAGES);
            addIfMissing(a,p,Manifest.permission.READ_MEDIA_VIDEO);
            addIfMissing(a,p,Manifest.permission.READ_MEDIA_AUDIO);
        }else{
            addIfMissing(a,p,Manifest.permission.READ_EXTERNAL_STORAGE);
        }
        return p.toArray(new String[0]);
    }

    public static boolean hasAllFilesAccess(){
        return Build.VERSION.SDK_INT<30 || Environment.isExternalStorageManager();
    }

    public static void openAllFilesAccess(Activity a){
        if(Build.VERSION.SDK_INT<30)return;
        try{
            Intent i=new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:"+a.getPackageName()));
            a.startActivity(i);
        }catch(Throwable t){
            a.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
        }
    }

    public static boolean canWriteSystemSettings(Context c){
        return Build.VERSION.SDK_INT<23 || Settings.System.canWrite(c);
    }

    public static void openWriteSettings(Activity a){
        try{
            Intent i=new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    Uri.parse("package:"+a.getPackageName()));
            a.startActivity(i);
        }catch(Throwable t){
            a.startActivity(new Intent(Settings.ACTION_SETTINGS));
        }
    }

    public static boolean isAccessibilityEnabled(Context c){
        int enabled=0;
        try{enabled=Settings.Secure.getInt(c.getContentResolver(),Settings.Secure.ACCESSIBILITY_ENABLED);}catch(Exception ignored){}
        if(enabled!=1)return false;
        String list=Settings.Secure.getString(c.getContentResolver(),Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if(list==null)return false;
        TextUtils.SimpleStringSplitter sp=new TextUtils.SimpleStringSplitter(':');
        sp.setString(list);
        ComponentName mine=new ComponentName(c,"com.anamika.ai.plugins.AppAutomationAccessibilityService");
        while(sp.hasNext()){
            ComponentName n=ComponentName.unflattenFromString(sp.next());
            if(n!=null && n.equals(mine)) return true;
        }
        return false;
    }

    public static void openAccessibility(Activity a){
        a.startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
    }

    public static String status(Context c){
        int runtime=0,total=0;
        String[] common={Manifest.permission.RECORD_AUDIO,Manifest.permission.READ_CONTACTS,Manifest.permission.CALL_PHONE};
        for(String p:common){total++;if(c.checkSelfPermission(p)==PackageManager.PERMISSION_GRANTED)runtime++;}
        if(Build.VERSION.SDK_INT>=33){
            String[] newer={Manifest.permission.POST_NOTIFICATIONS,Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,Manifest.permission.READ_MEDIA_AUDIO};
            for(String p:newer){total++;if(c.checkSelfPermission(p)==PackageManager.PERMISSION_GRANTED)runtime++;}
        }else{
            total++;if(c.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE)==PackageManager.PERMISSION_GRANTED)runtime++;
        }
        return "Runtime permissions "+runtime+"/"+total+
                " • All-files "+(hasAllFilesAccess()?"ON":"OFF")+
                " • Modify settings "+(canWriteSystemSettings(c)?"ON":"OFF")+
                " • App Control "+(isAccessibilityEnabled(c)?"ON":"OFF");
    }

    private static void addIfMissing(Activity a,List<String> list,String p){
        if(a.checkSelfPermission(p)!=PackageManager.PERMISSION_GRANTED) list.add(p);
    }
}
