package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Extracts the immutable build-time source snapshot shipped with Anamika into a
 * versioned private workspace. Existing workspaces are retained for review/rollback.
 */
public final class SelfUpgradeWorkspace {
    private SelfUpgradeWorkspace(){ }

    public static File prepare(Context c,String request)throws Exception{
        File base=new File(c.getFilesDir(),"self_upgrade");
        if(!base.exists()&&!base.mkdirs()) throw new IllegalStateException("Cannot create self-upgrade storage");
        String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(new Date());
        File root=new File(base,"workspace_"+stamp);
        if(!root.mkdirs()) throw new IllegalStateException("Cannot create self-upgrade workspace");
        boolean ok=false;
        try{
            copyAssetTree(c.getAssets(),"self_source",root);
            write(new File(root,"OWNER_UPGRADE_REQUEST.txt"),request==null?"":request);
            write(new File(root,"WORKSPACE_INFO.txt"),
                    "Created: "+new Date()+"\n"+
                    "Source: immutable snapshot bundled in the currently installed Anamika APK.\n"+
                    "Rule: generated changes require validation + owner approval + a separately built/signed APK before installation.\n");
            write(new File(base,"LATEST_WORKSPACE.txt"),root.getAbsolutePath()+"\n");
            pruneOldWorkspaces(base,8,root);
            ok=true;
            return root;
        } finally {
            if(!ok) delete(root);
        }
    }

    private static void copyAssetTree(AssetManager a,String path,File dest)throws Exception{
        String[] children=a.list(path);
        if(children!=null&&children.length>0){
            if(!dest.exists()&&!dest.mkdirs()) throw new IllegalStateException("Cannot create workspace folder");
            for(String ch:children) copyAssetTree(a,path+"/"+ch,new File(dest,ch));
            return;
        }
        File parent=dest.getParentFile(); if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create workspace folder");
        try(InputStream in=a.open(path); FileOutputStream out=new FileOutputStream(dest)){
            byte[] buf=new byte[65536]; int n; while((n=in.read(buf))>0) out.write(buf,0,n);
        }
    }

    private static void pruneOldWorkspaces(File base,int keep,File current){
        File[] all=base.listFiles(f->f.isDirectory()&&f.getName().startsWith("workspace_")&&!f.equals(current));
        if(all==null||all.length<=keep-1)return;
        java.util.Arrays.sort(all,(a,b)->Long.compare(b.lastModified(),a.lastModified()));
        for(int i=Math.max(0,keep-1);i<all.length;i++) delete(all[i]);
    }

    private static void write(File file,String text)throws Exception{
        try(FileOutputStream o=new FileOutputStream(file)){o.write(text.getBytes(StandardCharsets.UTF_8));}
    }
    private static void delete(File f){ if(f==null||!f.exists())return; if(f.isDirectory()){File[] a=f.listFiles();if(a!=null)for(File x:a)delete(x);} try{f.delete();}catch(Exception ignored){} }
}
