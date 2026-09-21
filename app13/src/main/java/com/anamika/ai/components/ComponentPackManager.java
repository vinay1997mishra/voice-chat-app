package com.anamika.ai.components;

import android.content.Context;

import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Iterator;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Installs owner-approved V13 component packs into private app storage.
 *
 * Pack format:
 * - manifest.json
 * - payload files
 *
 * manifest.json:
 * {
 *   "schema":"anamika13-component-pack-v1",
 *   "type":"brain" | "toolchain",
 *   "version":"...",
 *   "files": { "relative/path":"sha256hex", ... }
 * }
 */
public final class ComponentPackManager {
    public static final class Result {
        public final boolean ok;
        public final String message;
        Result(boolean ok,String message){this.ok=ok;this.message=message;}
    }

    private ComponentPackManager(){}

    public static Result installZip(Context c,InputStream raw){
        File staging=null;
        try{
            File root=new File(c.getFilesDir(),"v13_component_staging");
            if(!root.exists()&&!root.mkdirs())
                return new Result(false,"Cannot create component staging directory.");

            staging=new File(root,"pack_"+System.currentTimeMillis());
            if(!staging.mkdirs())return new Result(false,"Cannot create component staging folder.");

            unzipSafely(raw,staging);

            File manifestFile=new File(staging,"manifest.json");
            if(!manifestFile.isFile())return new Result(false,"Component pack manifest.json missing.");

            JSONObject manifest=new JSONObject(new String(
                    java.nio.file.Files.readAllBytes(manifestFile.toPath()),
                    java.nio.charset.StandardCharsets.UTF_8));

            if(!"anamika13-component-pack-v1".equals(manifest.optString("schema","")))
                return new Result(false,"Unsupported component pack schema.");

            String type=manifest.optString("type","").trim().toLowerCase(java.util.Locale.ROOT);
            String version=manifest.optString("version","").trim();
            if(!("brain".equals(type)||"toolchain".equals(type)))
                return new Result(false,"Component type must be brain or toolchain.");
            if(version.isEmpty())return new Result(false,"Component version missing.");

            JSONObject files=manifest.optJSONObject("files");
            if(files==null||files.length()==0)
                return new Result(false,"Component file hash list missing.");

            Iterator<String> keys=files.keys();
            while(keys.hasNext()){
                String rel=keys.next();
                File f=safeChild(staging,rel);
                if(!f.isFile())return new Result(false,"Pack file missing: "+rel);
                String expected=files.optString(rel,"");
                if(expected.length()!=64)return new Result(false,"Bad SHA-256 entry: "+rel);
                String actual=sha256(f);
                if(!expected.equalsIgnoreCase(actual))
                    return new Result(false,"SHA-256 mismatch: "+rel);
            }

            String structural=checkRequired(type,staging);
            if(structural!=null)return new Result(false,structural);

            File target=new File(c.getFilesDir(),"brain".equals(type)?"v13_brain":"v13_toolchain");
            File backup=new File(c.getFilesDir(),target.getName()+".previous");
            deleteTree(backup);
            if(target.exists()&&!target.renameTo(backup))
                return new Result(false,"Cannot preserve previous "+type+" component.");

            File payload=new File(staging,"payload");
            if(!payload.isDirectory())payload=staging;

            File tempTarget=new File(c.getFilesDir(),target.getName()+".installing");
            deleteTree(tempTarget);
            copyTree(payload,tempTarget);
            new File(tempTarget,"manifest.json").delete();

            if("toolchain".equals(type)){
                File aapt2=new File(tempTarget,"bin/aapt2");
                File builder=new File(tempTarget,"bin/anamika-builder");
                if(aapt2.isFile())aapt2.setExecutable(true,true);
                if(builder.isFile())builder.setExecutable(true,true);
            }else{
                File brain=new File(tempTarget,"bin/anamika-brain");
                if(brain.isFile())brain.setExecutable(true,true);
            }

            if(target.exists())deleteTree(target);
            if(!tempTarget.renameTo(target)){
                deleteTree(target);
                if(backup.exists())backup.renameTo(target);
                return new Result(false,"Cannot activate "+type+" component.");
            }

            writeText(new File(target,"component.version"),version);
            deleteTree(backup);
            deleteTree(staging);

            return new Result(true,
                    ("brain".equals(type)?"Offline coding brain":"Android build toolchain")+
                    " component installed. Version: "+version+
                    "\nStored privately inside Anamika.");
        }catch(Exception e){
            return new Result(false,"Component install failed: "+safe(e));
        }finally{
            if(staging!=null)deleteTree(staging);
        }
    }

    public static boolean brainInstalled(Context c){
        File root=new File(c.getFilesDir(),"v13_brain");
        return new File(root,"model.gguf").isFile()&&
                new File(root,"runtime.ready").isFile()&&
                new File(root,"bin/anamika-brain").isFile();
    }

    public static boolean toolchainInstalled(Context c){
        File root=new File(c.getFilesDir(),"v13_toolchain");
        return new File(root,"bin/anamika-builder").isFile()&&
                new File(root,"bin/aapt2").isFile()&&
                new File(root,"lib/java-compiler.jar").isFile()&&
                new File(root,"lib/d8.jar").isFile()&&
                new File(root,"lib/apksig.jar").isFile()&&
                new File(root,"platforms/android-36/android.jar").isFile();
    }

    public static boolean needsSetup(Context c){
        return !brainInstalled(c)||!toolchainInstalled(c);
    }

    public static String status(Context c){
        return describe(new File(c.getFilesDir(),"v13_brain"),"Brain pack")+
                "\n"+describe(new File(c.getFilesDir(),"v13_toolchain"),"Toolchain pack")+
                "\nOffline mode: "+(!needsSetup(c)?"READY":"COMPONENTS REQUIRED");
    }

    private static String checkRequired(String type,File staging)throws Exception{
        File base=new File(staging,"payload");
        if(!base.isDirectory())base=staging;
        if("brain".equals(type)){
            File model=new File(base,"model.gguf");
            if(!model.isFile()||model.length()<16L*1024L*1024L)
                return "Brain pack requires model.gguf larger than 16 MB.";
            File runtime=new File(base,"runtime.ready");
            if(!runtime.isFile())
                return "Brain pack inference runtime marker is missing.";
            File executor=new File(base,"bin/anamika-brain");
            if(!executor.isFile())
                return "Brain pack missing: bin/anamika-brain";
            return null;
        }

        String[] req={"bin/anamika-builder","bin/aapt2","lib/java-compiler.jar","lib/d8.jar",
                "lib/apksig.jar","platforms/android-36/android.jar"};
        for(String rel:req)if(!new File(base,rel).isFile())
            return "Toolchain pack missing: "+rel;
        return null;
    }

    private static void unzipSafely(InputStream raw,File root)throws Exception{
        try(ZipInputStream zin=new ZipInputStream(new BufferedInputStream(raw))){
            ZipEntry e;
            byte[] buf=new byte[128*1024];
            long total=0;
            while((e=zin.getNextEntry())!=null){
                String name=e.getName().replace('\\','/');
                if(name.startsWith("/")||name.contains("../")||name.equals(".."))
                    throw new IllegalStateException("Unsafe archive path: "+name);
                File out=safeChild(root,name);
                if(e.isDirectory()){
                    if(!out.exists()&&!out.mkdirs())throw new IllegalStateException("Cannot create "+name);
                }else{
                    File parent=out.getParentFile();
                    if(parent!=null&&!parent.exists()&&!parent.mkdirs())
                        throw new IllegalStateException("Cannot create "+parent);
                    try(FileOutputStream fos=new FileOutputStream(out,false)){
                        int n;
                        while((n=zin.read(buf))>0){
                            total+=n;
                            if(total>8L*1024L*1024L*1024L)
                                throw new IllegalStateException("Component pack exceeds 8 GB safety limit.");
                            fos.write(buf,0,n);
                        }
                        fos.getFD().sync();
                    }
                }
                zin.closeEntry();
            }
        }
    }

    private static File safeChild(File root,String rel)throws Exception{
        File f=new File(root,rel);
        String rp=root.getCanonicalPath();
        String fp=f.getCanonicalPath();
        if(!fp.equals(rp)&&!fp.startsWith(rp+File.separator))
            throw new IllegalStateException("Unsafe component path.");
        return f;
    }

    private static void copyTree(File src,File dst)throws Exception{
        if(src.isDirectory()){
            if(!dst.exists()&&!dst.mkdirs())throw new IllegalStateException("Cannot create "+dst);
            File[] children=src.listFiles();
            if(children!=null)for(File c:children)copyTree(c,new File(dst,c.getName()));
            return;
        }
        File parent=dst.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs())throw new IllegalStateException("Cannot create "+parent);
        try(FileInputStream in=new FileInputStream(src);FileOutputStream out=new FileOutputStream(dst,false)){
            byte[] buf=new byte[128*1024];int n;
            while((n=in.read(buf))>0)out.write(buf,0,n);
            out.getFD().sync();
        }
    }

    private static String sha256(File f)throws Exception{
        MessageDigest md=MessageDigest.getInstance("SHA-256");
        try(FileInputStream in=new FileInputStream(f)){
            byte[] b=new byte[128*1024];int n;
            while((n=in.read(b))>0)md.update(b,0,n);
        }
        StringBuilder s=new StringBuilder();
        for(byte x:md.digest())s.append(String.format("%02x",x));
        return s.toString();
    }

    private static String describe(File dir,String label){
        File version=new File(dir,"component.version");
        if(!dir.isDirectory())return label+": NOT INSTALLED";
        String v="unknown";
        try{
            if(version.isFile())v=new String(java.nio.file.Files.readAllBytes(version.toPath()),
                    java.nio.charset.StandardCharsets.UTF_8).trim();
        }catch(Exception ignored){}
        return label+": INSTALLED ("+v+")";
    }

    private static void writeText(File f,String s)throws Exception{
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(s.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            out.getFD().sync();
        }
    }

    private static void deleteTree(File f){
        if(f==null||!f.exists())return;
        if(f.isDirectory()){
            File[] children=f.listFiles();
            if(children!=null)for(File c:children)deleteTree(c);
        }
        try{f.delete();}catch(Exception ignored){}
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
