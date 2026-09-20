package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.res.AssetManager;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/** Extracts the immutable V13 source snapshot bundled at build time into private storage. */
public final class SourceVault {
    private SourceVault(){}

    public static File ensureBaseline(Context c) throws Exception {
        String version=installedVersion(c);
        File base=new File(new File(c.getFilesDir(),"v13_source_vault"),version);
        File marker=new File(base,".complete");
        if(marker.isFile()) return base;

        File temp=new File(base.getParentFile(),version+".partial");
        deleteTree(temp);
        if(!temp.mkdirs()) throw new IllegalStateException("Cannot create source vault temp directory.");
        copyAssetTree(c.getAssets(),"self_source",temp);
        File parent=base.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create source vault.");
        deleteTree(base);
        if(!temp.renameTo(base)) throw new IllegalStateException("Cannot finalize source vault.");
        if(!marker.createNewFile()) throw new IllegalStateException("Cannot seal source vault.");
        return base;
    }

    public static File createWorkspace(Context c,String request) throws Exception {
        File baseline=ensureBaseline(c);
        File root=new File(c.getFilesDir(),"v13_upgrade_workspaces");
        if(!root.exists()&&!root.mkdirs()) throw new IllegalStateException("Cannot create workspace storage.");
        File ws=new File(root,"workspace_"+System.currentTimeMillis());
        copyFileTree(baseline,ws);
        writeText(new File(ws,"OWNER_REQUEST.txt"),request==null?"":request);
        return ws;
    }

    private static String installedVersion(Context c) throws Exception {
        PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        long code=android.os.Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
        return "v"+p.versionName+"_"+code;
    }

    private static void copyAssetTree(AssetManager am,String assetPath,File out) throws Exception {
        String[] children=am.list(assetPath);
        if(children!=null&&children.length>0){
            if(!out.exists()&&!out.mkdirs()) throw new IllegalStateException("Cannot create "+out);
            for(String ch:children) copyAssetTree(am,assetPath+"/"+ch,new File(out,ch));
            return;
        }
        File parent=out.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create "+parent);
        try(InputStream in=am.open(assetPath); FileOutputStream os=new FileOutputStream(out)){
            byte[] buf=new byte[64*1024];
            int n;
            while((n=in.read(buf))>0) os.write(buf,0,n);
            os.getFD().sync();
        }
    }

    private static void copyFileTree(File src,File dst) throws Exception {
        if(src.isDirectory()){
            if(!dst.exists()&&!dst.mkdirs()) throw new IllegalStateException("Cannot create "+dst);
            File[] children=src.listFiles();
            if(children!=null) for(File c:children) copyFileTree(c,new File(dst,c.getName()));
            return;
        }
        File parent=dst.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create "+parent);
        try(InputStream in=new java.io.FileInputStream(src); FileOutputStream out=new FileOutputStream(dst)){
            byte[] buf=new byte[64*1024];
            int n;
            while((n=in.read(buf))>0) out.write(buf,0,n);
        }
    }

    private static void writeText(File f,String s) throws Exception {
        try(FileOutputStream out=new FileOutputStream(f)){out.write(s.getBytes(java.nio.charset.StandardCharsets.UTF_8));}
    }

    private static void deleteTree(File f){
        if(f==null||!f.exists()) return;
        if(f.isDirectory()){
            File[] children=f.listFiles();
            if(children!=null) for(File c:children) deleteTree(c);
        }
        try{f.delete();}catch(Exception ignored){}
    }
}
