package com.anamika.ai.core;

import android.app.PendingIntent;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

/** Android 5.0+ compatibility helpers used by V13 runtime code. */
public final class AndroidCompat {
    private AndroidCompat(){}

    public static byte[] readAllBytes(File file) throws Exception {
        try(InputStream in=new FileInputStream(file);
            ByteArrayOutputStream out=new ByteArrayOutputStream((int)Math.min(file.length(),1024L*1024L))){
            byte[] b=new byte[64*1024];
            int n;
            while((n=in.read(b))>0)out.write(b,0,n);
            return out.toByteArray();
        }
    }

    public static String readText(File file,Charset charset) throws Exception {
        return new String(readAllBytes(file),charset);
    }

    public static boolean hasPermission(Context c,String permission){
        if(Build.VERSION.SDK_INT<23)return true;
        return c.checkSelfPermission(permission)==PackageManager.PERMISSION_GRANTED;
    }

    public static boolean canRequestPackageInstalls(Context c){
        if(Build.VERSION.SDK_INT<26)return true;
        return c.getPackageManager().canRequestPackageInstalls();
    }

    public static int mutablePendingIntentFlags(int base){
        return Build.VERSION.SDK_INT>=31 ? (base|PendingIntent.FLAG_MUTABLE) : base;
    }

    public static int immutablePendingIntentFlags(int base){
        return Build.VERSION.SDK_INT>=23 ? (base|PendingIntent.FLAG_IMMUTABLE) : base;
    }
}
