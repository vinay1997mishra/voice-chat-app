package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.os.Build;

import java.io.File;
import java.io.FileInputStream;
import java.security.MessageDigest;
import java.util.Arrays;

public final class ApkVerifier {
    public static final class Result {
        public final boolean ok;
        public final String message;
        public final long versionCode;
        Result(boolean ok,String message,long versionCode){this.ok=ok;this.message=message;this.versionCode=versionCode;}
    }

    private ApkVerifier(){}

    public static Result verifySelfUpdate(Context c,File apk){
        try{
            if(apk==null||!apk.isFile()||apk.length()<1024) return new Result(false,"APK missing or empty.",-1);
            PackageManager pm=c.getPackageManager();
            int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
            PackageInfo current=pm.getPackageInfo(c.getPackageName(),flags);
            PackageInfo candidate=pm.getPackageArchiveInfo(apk.getAbsolutePath(),flags);
            if(candidate==null||candidate.packageName==null) return new Result(false,"Not a readable Android APK.",-1);
            if(!c.getPackageName().equals(candidate.packageName)) return new Result(false,"Package mismatch: "+candidate.packageName,-1);

            long cur=Build.VERSION.SDK_INT>=28?current.getLongVersionCode():current.versionCode;
            long next=Build.VERSION.SDK_INT>=28?candidate.getLongVersionCode():candidate.versionCode;
            if(next<=cur) return new Result(false,"Update version must be newer. Installed="+cur+", candidate="+next,next);

            byte[] a=certDigest(current);
            byte[] b=certDigest(candidate);
            if(a==null||b==null||!Arrays.equals(a,b)) return new Result(false,"Signing certificate does not match installed Anamika.",next);

            return new Result(true,"Verified self-update\nVersion: "+next+"\nSHA-256: "+sha256(apk),next);
        }catch(Exception e){
            return new Result(false,"Verification failed: "+safe(e),-1);
        }
    }

    private static byte[] certDigest(PackageInfo p) throws Exception {
        Signature sig=null;
        if(Build.VERSION.SDK_INT>=28){
            SigningInfo info=p.signingInfo;
            if(info!=null){
                Signature[] s=info.hasMultipleSigners()?info.getApkContentsSigners():info.getSigningCertificateHistory();
                if(s!=null&&s.length>0)sig=s[0];
            }
        }else if(p.signatures!=null&&p.signatures.length>0)sig=p.signatures[0];
        return sig==null?null:MessageDigest.getInstance("SHA-256").digest(sig.toByteArray());
    }

    public static String sha256(File f) throws Exception {
        MessageDigest md=MessageDigest.getInstance("SHA-256");
        try(FileInputStream in=new FileInputStream(f)){
            byte[] b=new byte[128*1024]; int n;
            while((n=in.read(b))>0)md.update(b,0,n);
        }
        StringBuilder s=new StringBuilder();
        for(byte x:md.digest())s.append(String.format("%02x",x));
        return s.toString();
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
