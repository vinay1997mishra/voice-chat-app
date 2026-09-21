package com.anamika.ai.components;

import android.content.Context;
import android.os.Build;

import com.anamika.ai.core.AndroidCompat;

import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Iterator;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Installs owner-approved V13 component packs into private app storage.
 *
 * Supported schemas:
 * - brain-runtime: llama.cpp based Android runtime, no model bundled
 * - brain: legacy combined runtime + model pack
 * - toolchain: Android local builder toolchain
 *
 * The model can also be imported separately as a raw GGUF file.
 */
public final class ComponentPackManager {
    private static final long MAX_PACK_BYTES=8L*1024L*1024L*1024L;
    private static final long MIN_MODEL_BYTES=16L*1024L*1024L;

    public static final class Result {
        public final boolean ok;
        public final String message;
        public Result(boolean ok,String message){this.ok=ok;this.message=message;}
    }

    private ComponentPackManager(){}

    /**
     * Installs the toolchain bundled inside the signed APK, if present.
     * The APK asset is trusted only after its internal manifest hashes pass
     * the same verification path as a manually imported component pack.
     */
    public static Result installBundledToolchainIfNeeded(Context c){
        if(toolchainInstalled(c))
            return new Result(true,"Bundled toolchain already installed.");
        try(InputStream in=c.getAssets().open("components/AnamikaAI-13-Toolchain-arm64.zip")){
            Result r=installZip(c,in);
            if(!r.ok)return new Result(false,"Bundled toolchain install failed: "+r.message);
            return new Result(true,"Bundled Android toolchain installed from signed APK.\n"+r.message);
        }catch(java.io.FileNotFoundException e){
            return new Result(false,"This APK does not contain the bundled Android toolchain.");
        }catch(Exception e){
            return new Result(false,"Bundled toolchain bootstrap failed: "+safe(e));
        }
    }

    public static boolean bundledToolchainAvailable(Context c){
        try(InputStream in=c.getAssets().open("components/AnamikaAI-13-Toolchain-arm64.zip")){
            return in.read()!=-1;
        }catch(Exception e){return false;}
    }

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
                    AndroidCompat.readAllBytes(manifestFile),
                    java.nio.charset.StandardCharsets.UTF_8));

            if(!"anamika13-component-pack-v1".equals(manifest.optString("schema","")))
                return new Result(false,"Unsupported component pack schema.");

            String type=manifest.optString("type","").trim().toLowerCase(Locale.ROOT);
            String version=manifest.optString("version","").trim();
            if(!("brain".equals(type)||"brain-runtime".equals(type)||"toolchain".equals(type)))
                return new Result(false,"Component type must be brain, brain-runtime or toolchain.");
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

            if("brain".equals(type)||"brain-runtime".equals(type))
                return installBrainPayload(c,staging,type,version);

            return installToolchainPayload(c,staging,version);
        }catch(Exception e){
            return new Result(false,"Component install failed: "+safe(e));
        }finally{
            if(staging!=null)deleteTree(staging);
        }
    }

    public static Result installModel(Context c,InputStream raw){
        File root=new File(c.getFilesDir(),"v13_brain");
        File partial=new File(root,"model.gguf.partial");
        try{
            if(!root.exists()&&!root.mkdirs())return new Result(false,"Cannot create brain storage.");
            if(partial.exists())partial.delete();

            byte[] first=new byte[4];
            long total=0;
            try(FileOutputStream out=new FileOutputStream(partial,false)){
                byte[] buf=new byte[128*1024];
                int n;
                boolean firstFilled=false;
                while((n=raw.read(buf))>0){
                    if(!firstFilled){
                        int copy=Math.min(4,n);
                        System.arraycopy(buf,0,first,0,copy);
                        firstFilled=copy==4;
                    }
                    total+=n;
                    if(total>MAX_PACK_BYTES)throw new IllegalStateException("GGUF exceeds 8 GB safety limit.");
                    out.write(buf,0,n);
                }
                out.getFD().sync();
            }

            if(total<MIN_MODEL_BYTES){
                partial.delete();
                return new Result(false,"GGUF model is too small.");
            }
            if(first[0]!='G'||first[1]!='G'||first[2]!='U'||first[3]!='F'){
                partial.delete();
                return new Result(false,"Selected file is not a GGUF model.");
            }

            File model=new File(root,"model.gguf");
            if(model.exists()&&!model.delete()){
                partial.delete();
                return new Result(false,"Cannot replace previous model.");
            }
            if(!partial.renameTo(model)){
                partial.delete();
                return new Result(false,"Cannot finalize GGUF model.");
            }
            writeText(new File(root,"model.info"),
                    "size_bytes="+total+"\ninstalled_ms="+System.currentTimeMillis()+"\n");
            return new Result(true,"Offline coding model installed: "+(total/1024/1024)+" MB.");
        }catch(Exception e){
            partial.delete();
            return new Result(false,"Model import failed: "+safe(e));
        }
    }

    private static Result installBrainPayload(Context c,File staging,String type,String version)throws Exception{
        File payload=new File(staging,"payload");
        if(!payload.isDirectory())payload=staging;

        int minApi=readMinApi(payload);
        if(minApi>0&&Build.VERSION.SDK_INT<minApi)
            return new Result(false,"This brain runtime needs Android API "+minApi+
                    " or newer. This phone is API "+Build.VERSION.SDK_INT+".");

        File target=new File(c.getFilesDir(),"v13_brain");
        File temp=new File(c.getFilesDir(),"v13_brain.installing");
        deleteTree(temp);
        if(!temp.mkdirs())return new Result(false,"Cannot create brain install folder.");

        // Preserve an already imported model when installing/updating runtime-only pack.
        File existingModel=new File(target,"model.gguf");
        if("brain-runtime".equals(type)&&existingModel.isFile())
            copyFile(existingModel,new File(temp,"model.gguf"));

        copyTree(payload,temp);
        new File(temp,"manifest.json").delete();

        File brain=new File(temp,"bin/anamika-brain");
        File llama=new File(temp,"bin/llama-cli");
        if(brain.isFile())brain.setExecutable(true,true);
        if(llama.isFile())llama.setExecutable(true,true);

        File backup=new File(c.getFilesDir(),"v13_brain.previous");
        deleteTree(backup);
        if(target.exists()&&!target.renameTo(backup)){
            deleteTree(temp);
            return new Result(false,"Cannot preserve previous brain component.");
        }
        if(!temp.renameTo(target)){
            deleteTree(target);
            if(backup.exists())backup.renameTo(target);
            return new Result(false,"Cannot activate brain component.");
        }
        writeText(new File(target,"component.version"),version);
        deleteTree(backup);

        String state=brainInstalled(c)?"READY":"runtime installed; import GGUF model next";
        return new Result(true,"Offline brain runtime installed. Version: "+version+"\nBrain state: "+state);
    }

    private static Result installToolchainPayload(Context c,File staging,String version)throws Exception{
        File payload=new File(staging,"payload");
        if(!payload.isDirectory())payload=staging;

        File target=new File(c.getFilesDir(),"v13_toolchain");
        File backup=new File(c.getFilesDir(),"v13_toolchain.previous");
        File temp=new File(c.getFilesDir(),"v13_toolchain.installing");
        deleteTree(temp);
        copyTree(payload,temp);
        new File(temp,"manifest.json").delete();

        File builder=new File(temp,"bin/anamika-builder");
        // Builder is a shell script. AAPT2 is embedded in the installed APK
        // so Android 10+ never executes it from writable private storage.
        if(builder.isFile())builder.setReadable(true,true);

        deleteTree(backup);
        if(target.exists()&&!target.renameTo(backup)){
            deleteTree(temp);
            return new Result(false,"Cannot preserve previous toolchain component.");
        }
        if(!temp.renameTo(target)){
            deleteTree(target);
            if(backup.exists())backup.renameTo(target);
            return new Result(false,"Cannot activate toolchain component.");
        }
        writeText(new File(target,"component.version"),version);
        deleteTree(backup);
        return new Result(true,"Android build toolchain component installed. Version: "+version);
    }

    public static boolean brainRuntimeInstalled(Context c){
        File root=new File(c.getFilesDir(),"v13_brain");
        return new File(root,"runtime.ready").isFile()&&
                new File(root,"bin/anamika-brain").isFile()&&
                new File(root,"bin/llama-cli").isFile();
    }

    public static boolean modelInstalled(Context c){
        File f=new File(new File(c.getFilesDir(),"v13_brain"),"model.gguf");
        return f.isFile()&&f.length()>=MIN_MODEL_BYTES;
    }

    public static boolean brainInstalled(Context c){
        return brainRuntimeInstalled(c)&&modelInstalled(c);
    }

    public static boolean toolchainInstalled(Context c){
        File root=new File(c.getFilesDir(),"v13_toolchain");
        return new File(root,"bin/anamika-builder").isFile()&&
                new File(root,"lib/java-compiler.jar").isFile()&&
                new File(root,"lib/d8.jar").isFile()&&
                new File(root,"lib/apksig.jar").isFile()&&
                new File(root,"platforms/android-36/android.jar").isFile();
    }

    public static boolean needsSetup(Context c){return !brainInstalled(c)||!toolchainInstalled(c);}

    public static String status(Context c){
        File brain=new File(c.getFilesDir(),"v13_brain");
        File model=new File(brain,"model.gguf");
        return "Brain runtime: "+(brainRuntimeInstalled(c)?describeVersion(brain):"NOT INSTALLED")+
                "\nCoding model: "+(modelInstalled(c)?(model.length()/1024/1024)+" MB GGUF":"NOT INSTALLED")+
                "\nToolchain: "+(toolchainInstalled(c)?describeVersion(new File(c.getFilesDir(),"v13_toolchain")):"NOT INSTALLED")+
                "\nOffline coding: "+(brainInstalled(c)?"READY":"COMPONENTS REQUIRED");
    }

    private static String checkRequired(String type,File staging)throws Exception{
        File base=new File(staging,"payload");
        if(!base.isDirectory())base=staging;
        if("brain-runtime".equals(type)){
            String[] req={"runtime.ready","bin/anamika-brain","bin/llama-cli","edit-plan.schema.json"};
            for(String rel:req)if(!new File(base,rel).isFile())return "Brain runtime pack missing: "+rel;
            return null;
        }
        if("brain".equals(type)){
            if(!new File(base,"model.gguf").isFile()||new File(base,"model.gguf").length()<MIN_MODEL_BYTES)
                return "Brain pack requires model.gguf larger than 16 MB.";
            String[] req={"runtime.ready","bin/anamika-brain","bin/llama-cli","edit-plan.schema.json"};
            for(String rel:req)if(!new File(base,rel).isFile())return "Brain pack missing: "+rel;
            return null;
        }

        String[] req={"bin/anamika-builder","lib/java-compiler.jar","lib/d8.jar",
                "lib/apksig.jar","platforms/android-36/android.jar"};
        for(String rel:req)if(!new File(base,rel).isFile())return "Toolchain pack missing: "+rel;
        return null;
    }

    private static int readMinApi(File payload){
        try{
            File f=new File(payload,"runtime.min_api");
            if(!f.isFile())return 0;
            return Integer.parseInt(AndroidCompat.readText(f,java.nio.charset.StandardCharsets.UTF_8).trim());
        }catch(Exception ignored){return 0;}
    }

    private static void unzipSafely(InputStream raw,File root)throws Exception{
        try(ZipInputStream zin=new ZipInputStream(new BufferedInputStream(raw))){
            ZipEntry e; byte[] buf=new byte[128*1024]; long total=0;
            while((e=zin.getNextEntry())!=null){
                String name=e.getName().replace('\\','/');
                if(name.startsWith("/")||name.contains("../")||name.equals(".."))
                    throw new IllegalStateException("Unsafe archive path: "+name);
                File out=safeChild(root,name);
                if(e.isDirectory()){
                    if(!out.exists()&&!out.mkdirs())throw new IllegalStateException("Cannot create "+name);
                }else{
                    File parent=out.getParentFile();
                    if(parent!=null&&!parent.exists()&&!parent.mkdirs())throw new IllegalStateException("Cannot create "+parent);
                    try(FileOutputStream fos=new FileOutputStream(out,false)){
                        int n;
                        while((n=zin.read(buf))>0){
                            total+=n;
                            if(total>MAX_PACK_BYTES)throw new IllegalStateException("Component pack exceeds 8 GB safety limit.");
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
        String rp=root.getCanonicalPath(),fp=f.getCanonicalPath();
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
        copyFile(src,dst);
    }

    private static void copyFile(File src,File dst)throws Exception{
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

    private static String describeVersion(File dir){
        File version=new File(dir,"component.version");
        if(!version.isFile())return "INSTALLED";
        try{return "INSTALLED ("+AndroidCompat.readText(version,java.nio.charset.StandardCharsets.UTF_8).trim()+")";}
        catch(Exception ignored){return "INSTALLED";}
    }

    private static void writeText(File f,String s)throws Exception{
        File p=f.getParentFile();
        if(p!=null&&!p.exists()&&!p.mkdirs())throw new IllegalStateException("Cannot create "+p);
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
