package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.runtime.LocalProcessRunner;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * Phone-local V13 build executor.
 *
 * Toolchain pack protocol:
 * bin/anamika-builder --workspace <dir> --output <apk> --android-jar <jar>
 *                     --aapt2 <file> --d8 <jar> --compiler <jar>
 *                     --apksig <jar> --keystore <p12>
 *
 * The matching PKCS#12 password is provided only through ANAMIKA_KS_PASS env.
 */
public final class LocalBuildEngine {
    public static final class Capability {
        public final boolean ready;
        public final String detail;
        public Capability(boolean ready,String detail){this.ready=ready;this.detail=detail;}
    }

    public static final class BuildResult {
        public final boolean ok;
        public final File apk;
        public final String log;
        BuildResult(boolean ok,File apk,String log){this.ok=ok;this.apk=apk;this.log=log;}
    }

    private LocalBuildEngine(){}

    public static Capability capability(Context c){
        File root=new File(c.getFilesDir(),"v13_toolchain");
        File builder=new File(root,"bin/anamika-builder");
        File aapt2=new File(root,"bin/aapt2");
        File d8=new File(root,"lib/d8.jar");
        File androidJar=new File(root,"platforms/android-36/android.jar");
        File signer=new File(root,"lib/apksig.jar");
        File compiler=new File(root,"lib/java-compiler.jar");

        boolean files=builder.isFile()&&aapt2.isFile()&&d8.isFile()&&androidJar.isFile()&&signer.isFile()&&compiler.isFile();
        boolean storage=HealthMonitor.enoughForLocalBuild(c,2L*1024L*1024L*1024L);

        if(!files)return new Capability(false,
                "Local build toolchain incomplete. Required: anamika-builder, ARM64 aapt2, Java compiler runtime, D8, android-36.jar and APK signer.");
        if((!builder.canExecute()&&!builder.setExecutable(true,true))||(!aapt2.canExecute()&&!aapt2.setExecutable(true,true)))
            return new Capability(false,"Android blocked execution of the installed builder/aapt2 on this device.");
        if(!storage)return new Capability(false,"At least 2 GB free private storage is required for a safe local build.");
        if(!SignerVault.ready(c))return new Capability(false,"Build tools are present, but matching release signer is not provisioned.");
        return new Capability(true,"Phone-local compiler/build/sign pipeline is ready.");
    }

    public static BuildResult build(Context c,File workspace){
        Capability cap=capability(c);
        if(!cap.ready)return new BuildResult(false,null,cap.detail);
        if(workspace==null||!workspace.isDirectory())
            return new BuildResult(false,null,"Upgrade workspace is missing.");

        File root=new File(c.getFilesDir(),"v13_toolchain");
        File builder=new File(root,"bin/anamika-builder");
        File outputDir=new File(workspace,".anamika_build");
        if(!outputDir.exists()&&!outputDir.mkdirs())
            return new BuildResult(false,null,"Cannot create build output directory.");
        File output=new File(outputDir,"candidate.apk");
        if(output.exists())output.delete();

        try(SignerVault.TemporaryPkcs12 ks=SignerVault.materializeTemporary(c,outputDir)){
            List<String> cmd=new ArrayList<>();
            cmd.add(builder.getAbsolutePath());
            cmd.add("--workspace");cmd.add(workspace.getAbsolutePath());
            cmd.add("--output");cmd.add(output.getAbsolutePath());
            cmd.add("--android-jar");cmd.add(new File(root,"platforms/android-36/android.jar").getAbsolutePath());
            cmd.add("--aapt2");cmd.add(new File(root,"bin/aapt2").getAbsolutePath());
            cmd.add("--d8");cmd.add(new File(root,"lib/d8.jar").getAbsolutePath());
            cmd.add("--compiler");cmd.add(new File(root,"lib/java-compiler.jar").getAbsolutePath());
            cmd.add("--apksig");cmd.add(new File(root,"lib/apksig.jar").getAbsolutePath());
            cmd.add("--keystore");cmd.add(ks.file.getAbsolutePath());

            HashMap<String,String> env=new HashMap<>();
            env.put("ANAMIKA_KS_PASS",new String(ks.password));
            env.put("ANAMIKA_OFFLINE","1");
            env.put("HOME",outputDir.getAbsolutePath());

            LocalProcessRunner.Result run=LocalProcessRunner.run(cmd,workspace,env,15L*60L*1000L);
            String log="exit="+run.exitCode+(run.timedOut?" timeout":"")+
                    (run.stdout.isEmpty()?"":"\nOUT:\n"+trim(run.stdout))+
                    (run.stderr.isEmpty()?"":"\nERR:\n"+trim(run.stderr));
            if(!run.ok())return new BuildResult(false,null,"Local build failed.\n"+log);
            if(!output.isFile()||output.length()<1024)
                return new BuildResult(false,null,"Builder finished but candidate.apk was not produced.\n"+log);

            ApkVerifier.Result verify=ApkVerifier.verifySelfUpdate(c,output);
            if(!verify.ok)return new BuildResult(false,output,"Build produced an APK but verification failed:\n"+verify.message+"\n"+log);

            return new BuildResult(true,output,"LOCAL BUILD PASS\n"+verify.message+"\n"+log);
        }catch(Exception e){
            return new BuildResult(false,null,"Local build exception: "+safe(e));
        }
    }

    private static String trim(String s){return s.length()>4000?s.substring(0,4000):s;}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
