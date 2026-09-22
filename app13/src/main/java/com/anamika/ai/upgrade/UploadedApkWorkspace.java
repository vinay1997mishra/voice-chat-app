package com.anamika.ai.upgrade;

import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/** Creates a disposable source workspace from an Anamika APK's bundled self_source. */
public final class UploadedApkWorkspace {
    private static final String PREFIX="assets/self_source/";
    private static final long MAX_SOURCE_BYTES=512L*1024L*1024L;

    private UploadedApkWorkspace(){}

    public static File create(Context c,File apk,long candidateVersion)throws Exception{
        if(apk==null||!apk.isFile())throw new IllegalStateException("Uploaded APK missing.");
        File tempRoot=new File(c.getFilesDir(),"v13_uploaded_source");
        if(!tempRoot.exists()&&!tempRoot.mkdirs())
            throw new IllegalStateException("Cannot create uploaded-source storage.");
        File snapshot=new File(tempRoot,"source_"+System.currentTimeMillis());
        if(!snapshot.mkdirs())throw new IllegalStateException("Cannot create source snapshot.");

        long total=0;int files=0;
        try(ZipFile zip=new ZipFile(apk)){
            Enumeration<? extends ZipEntry> entries=zip.entries();
            while(entries.hasMoreElements()){
                ZipEntry e=entries.nextElement();
                String name=e.getName().replace('\\','/');
                if(e.isDirectory()||!name.startsWith(PREFIX))continue;
                String rel=name.substring(PREFIX.length());
                if(rel.isEmpty()||rel.startsWith("/")||rel.contains("../")||rel.equals(".."))continue;
                File out=safeChild(snapshot,rel);
                File parent=out.getParentFile();
                if(parent!=null&&!parent.exists()&&!parent.mkdirs())
                    throw new IllegalStateException("Cannot create "+parent);
                try(InputStream in=zip.getInputStream(e);FileOutputStream fos=new FileOutputStream(out,false)){
                    byte[] b=new byte[128*1024];int n;
                    while((n=in.read(b))>0){
                        total+=n;
                        if(total>MAX_SOURCE_BYTES)
                            throw new IllegalStateException("Bundled source exceeds safety limit.");
                        fos.write(b,0,n);
                    }
                    fos.getFD().sync();
                }
                files++;
            }
        }

        if(files<10||!new File(snapshot,"app13/build.gradle").isFile()||
                !new File(snapshot,"app13/src/main/AndroidManifest.xml").isFile()){
            SourceVault.deleteTree(snapshot);
            throw new IllegalStateException("Complete bundled self_source missing; code-level verification/repair is not possible.");
        }

        try{
            File ws=SourceVault.createWorkspaceFromSnapshot(
                    c,snapshot,"uploaded APK strict validation v"+candidateVersion,false);
            SourceVault.prepareVersionForUpdate(ws,candidateVersion);
            UpgradeJournal.record(c,"UPLOADED_APK_SOURCE_READY",
                    "version="+candidateVersion+" files="+files+" bytes="+total);
            return ws;
        }finally{
            SourceVault.deleteTree(snapshot);
        }
    }

    private static File safeChild(File root,String rel)throws Exception{
        File f=new File(root,rel);
        String rp=root.getCanonicalPath(),fp=f.getCanonicalPath();
        if(!fp.startsWith(rp+File.separator))
            throw new IllegalStateException("Unsafe bundled source path.");
        return f;
    }
}
