package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.res.AssetManager;
import android.content.pm.PackageInfo;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/**
 * Extracts the immutable V13 source snapshot bundled at build time into private storage.
 * Every upgrade workspace is a disposable copy; the installed baseline is never edited.
 */
public final class SourceVault {
    private SourceVault(){}

    public static File ensureBaseline(Context c) throws Exception {
        String version=installedVersion(c);
        File base=new File(new File(c.getFilesDir(),"v13_source_vault"),version);
        File marker=new File(base,".complete");
        if(marker.isFile()) return base;

        File parent=base.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs())
            throw new IllegalStateException("Cannot create source vault.");

        File temp=new File(base.getParentFile(),version+".partial");
        deleteTree(temp);
        if(!temp.mkdirs()) throw new IllegalStateException("Cannot create source vault temp directory.");
        copyAssetTree(c.getAssets(),"self_source",temp);
        deleteTree(base);
        if(!temp.renameTo(base)) throw new IllegalStateException("Cannot finalize source vault.");
        if(!marker.createNewFile()) throw new IllegalStateException("Cannot seal source vault.");
        return base;
    }

    public static File createWorkspace(Context c,String request) throws Exception {
        return createWorkspaceFromSnapshot(c,ensureBaseline(c),request,true);
    }

    /**
     * Creates a workspace from an exact immutable snapshot. Used by rollback so recovery
     * never silently switches to the currently installed baseline.
     */
    public static File createWorkspaceFromSnapshot(Context c,File snapshot,String request,boolean bumpVersion) throws Exception {
        if(snapshot==null||!snapshot.isDirectory())
            throw new IllegalStateException("Source snapshot missing.");

        File root=new File(c.getFilesDir(),"v13_upgrade_workspaces");
        if(!root.exists()&&!root.mkdirs()) throw new IllegalStateException("Cannot create workspace storage.");
        File ws=new File(root,"workspace_"+System.currentTimeMillis());
        copyFileTree(snapshot,ws);
        writeText(new File(ws,"OWNER_REQUEST.txt"),request==null?"":request);

        long installed=currentVersionCode(c);
        long next=installed+1L;
        if(bumpVersion) prepareVersionForUpdate(ws,next);

        JSONObject meta=new JSONObject()
                .put("schema","anamika13-workspace-v2")
                .put("created_ms",System.currentTimeMillis())
                .put("installed_version_code",installed)
                .put("candidate_version_code",bumpVersion?next:installed)
                .put("source_snapshot",snapshot.getAbsolutePath())
                .put("owner_request",request==null?"":request);
        writeText(new File(ws,"ANAMIKA_WORKSPACE.json"),meta.toString(2));
        return ws;
    }

    /** Makes Android accept a locally built candidate as an update. */
    public static void prepareVersionForUpdate(File workspace,long nextVersionCode) throws Exception {
        File gradle=new File(workspace,"app13/build.gradle");
        if(!gradle.isFile()) throw new IllegalStateException("app13/build.gradle missing from self source.");
        String s=new String(readAll(gradle),StandardCharsets.UTF_8);
        String replaced=s.replaceFirst(
                "versionCode\\s+Integer\\.parseInt\\(System\\.getenv\\(\"ANAMIKA13_VERSION_CODE\"\\)\\s*\\?:\\s*\"[0-9]+\"\\)",
                "versionCode Integer.parseInt(System.getenv(\"ANAMIKA13_VERSION_CODE\") ?: \""+nextVersionCode+"\")");
        if(replaced.equals(s))
            throw new IllegalStateException("Could not locate V13 versionCode declaration in workspace.");
        writeText(gradle,replaced);

        File metaFile=new File(workspace,"ANAMIKA_WORKSPACE.json");
        if(metaFile.isFile()){
            JSONObject meta=new JSONObject(new String(readAll(metaFile),StandardCharsets.UTF_8));
            meta.put("candidate_version_code",nextVersionCode);
            writeText(metaFile,meta.toString(2));
        }
    }

    public static File snapshotBaseline(Context c,File destination) throws Exception {
        File baseline=ensureBaseline(c);
        deleteTree(destination);
        copyFileTree(baseline,destination);
        File marker=new File(destination,".checkpoint_complete");
        if(!marker.createNewFile()) throw new IllegalStateException("Cannot seal recovery snapshot.");
        return destination;
    }

    public static long currentVersionCode(Context c) throws Exception {
        PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        return android.os.Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
    }

    private static String installedVersion(Context c) throws Exception {
        PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        return "v"+p.versionName+"_"+currentVersionCode(c);
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

    static void copyFileTree(File src,File dst) throws Exception {
        if(src.isDirectory()){
            if(!dst.exists()&&!dst.mkdirs()) throw new IllegalStateException("Cannot create "+dst);
            File[] children=src.listFiles();
            if(children!=null) for(File c:children) copyFileTree(c,new File(dst,c.getName()));
            return;
        }
        File parent=dst.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create "+parent);
        try(InputStream in=new FileInputStream(src); FileOutputStream out=new FileOutputStream(dst)){
            byte[] buf=new byte[64*1024];
            int n;
            while((n=in.read(buf))>0) out.write(buf,0,n);
            out.getFD().sync();
        }
    }

    private static byte[] readAll(File f)throws Exception{
        try(FileInputStream in=new FileInputStream(f)){
            java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();
            byte[] buf=new byte[64*1024];int n;
            while((n=in.read(buf))>0)out.write(buf,0,n);
            return out.toByteArray();
        }
    }

    private static void writeText(File f,String s) throws Exception {
        File p=f.getParentFile();
        if(p!=null&&!p.exists()&&!p.mkdirs())throw new IllegalStateException("Cannot create "+p);
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(s.getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }
    }

    static void deleteTree(File f){
        if(f==null||!f.exists()) return;
        if(f.isDirectory()){
            File[] children=f.listFiles();
            if(children!=null) for(File c:children) deleteTree(c);
        }
        try{f.delete();}catch(Exception ignored){}
    }
}
