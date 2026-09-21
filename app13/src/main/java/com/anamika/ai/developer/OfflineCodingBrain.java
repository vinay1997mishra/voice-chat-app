package com.anamika.ai.developer;

import android.content.Context;

import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.runtime.LocalProcessRunner;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;

/**
 * Executes the owner-installed offline coding runtime.
 *
 * Runtime protocol:
 * bin/anamika-brain --model <model.gguf> --workspace <dir>
 *                   --request <request.txt> --output <edit-plan.json>
 */
public final class OfflineCodingBrain {
    private static final int MAX_CONTEXT_CHARS=56000;
    private static final int MAX_FILE_CHARS=16000;

    public static final class Result{
        public final boolean ok;
        public final String message;
        public final String rawPlan;
        Result(boolean ok,String message,String rawPlan){this.ok=ok;this.message=message;this.rawPlan=rawPlan;}
    }

    private OfflineCodingBrain(){}

    public static Result repair(Context c,File workspace,String request){
        File root=BrainRuntimePaths.root(c);
        File cli=BrainRuntimePaths.embeddedCli(c);
        File model=BrainRuntimePaths.model(c);
        File schema=BrainRuntimePaths.schema(c);
        if(!BrainRuntimePaths.runtimeReady(c)||!model.isFile())
            return new Result(false,"Offline coding brain runtime/model is not installed or APK-native runtime is unavailable.","");
        if(workspace==null||!workspace.isDirectory())
            return new Result(false,"Upgrade workspace is missing.","");

        File io=new File(workspace,".anamika_brain");
        if(!io.exists()&&!io.mkdirs())return new Result(false,"Cannot create offline-brain workspace.","");
        File req=new File(io,"request.txt");
        File out=new File(io,"edit-plan.json");

        try(FileOutputStream os=new FileOutputStream(req,false)){
            os.write(buildPrompt(workspace,request).getBytes(StandardCharsets.UTF_8));
            os.getFD().sync();
        }catch(Exception e){
            return new Result(false,"Cannot write brain request: "+safe(e),"");
        }

        List<String> cmd=new ArrayList<>();
        cmd.add(cli.getAbsolutePath());
        cmd.add("--offline");
        cmd.add("-m");cmd.add(model.getAbsolutePath());
        cmd.add("-f");cmd.add(req.getAbsolutePath());
        cmd.add("-c");cmd.add("16384");
        cmd.add("-n");cmd.add("4096");
        cmd.add("--temp");cmd.add("0.15");
        cmd.add("-st");
        cmd.add("--simple-io");
        cmd.add("--no-display-prompt");
        cmd.add("--no-show-timings");
        cmd.add("--no-warmup");
        cmd.add("--log-colors");cmd.add("off");
        cmd.add("--no-log-prefix");
        cmd.add("--no-log-timestamps");
        cmd.add("-lv");cmd.add("1");
        cmd.add("-jf");cmd.add(schema.getAbsolutePath());

        HashMap<String,String> env=new HashMap<>();
        env.put("ANAMIKA_OFFLINE","1");
        env.put("HOME",root.getAbsolutePath());
        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        if(nativeDir!=null&&!nativeDir.trim().isEmpty())env.put("LD_LIBRARY_PATH",nativeDir);

        LocalProcessRunner.Result run=LocalProcessRunner.run(cmd,workspace,env,15L*60L*1000L);
        if(!run.ok())
            return new Result(false,
                    "Offline brain failed. exit="+run.exitCode+(run.timedOut?" timeout":"")+
                            (run.stderr.isEmpty()?"":"\n"+trim(run.stderr)),"");

        try{
            String raw=run.stdout;
            try(FileOutputStream os=new FileOutputStream(out,false)){
                os.write(raw.getBytes(StandardCharsets.UTF_8));
                os.getFD().sync();
            }
            String plan=extractJsonObject(raw);
            if(plan==null)return new Result(false,"Offline brain output contained no valid JSON object.",raw);
            WorkspacePatchApplier.Result applied=WorkspacePatchApplier.apply(workspace,plan);
            return new Result(applied.ok,applied.message,plan);
        }catch(Exception e){
            return new Result(false,"Cannot read offline edit plan: "+safe(e),"");
        }
    }

    public static String status(Context c){
        File model=BrainRuntimePaths.model(c);
        File cli=BrainRuntimePaths.embeddedCli(c);
        return "Offline coding brain\nRuntime metadata: "+(BrainRuntimePaths.runtimeMarker(c).isFile()?"present":"missing")+
                "\nAPK-native llama.cpp CLI: "+(cli.isFile()?"present":"missing")+
                "\nModel: "+(model.isFile()?(model.length()/1024/1024)+" MB":"missing")+
                "\nExecution: "+(BrainRuntimePaths.runtimeReady(c)?"ready":"not verified");
    }

    private static String buildPrompt(File workspace,String ownerRequest)throws Exception{
        StringBuilder b=new StringBuilder();
        b.append("You are the offline coding brain for Anamika AI 13.\n")
                .append("Work ONLY on the provided workspace snapshot. Never use shell commands.\n")
                .append("Return ONLY JSON matching schema anamika13-edit-plan-v1.\n")
                .append("Allowed operations: write and delete. For write, content must contain the complete replacement file.\n")
                .append("Keep package/application identity and existing features unless the owner explicitly requests a change.\n")
                .append("Do not claim success; the app will run structural and real build checks after applying your edits.\n\n")
                .append("OWNER REQUEST:\n").append(ownerRequest==null?"":ownerRequest).append("\n\n")
                .append("WORKSPACE FILE TREE:\n");

        List<File> files=new ArrayList<>();
        collect(workspace,workspace,files);
        files.sort(Comparator.comparing(f->relative(workspace,f)));
        for(File f:files)b.append(relative(workspace,f)).append("\n");

        b.append("\nSELECTED FILE CONTENTS:\n");
        List<String> tokens=requestTokens(ownerRequest);
        files.sort((a,z)->Integer.compare(score(z,tokens),score(a,tokens)));
        for(File f:files){
            if(b.length()>=MAX_CONTEXT_CHARS)break;
            if(!isTextCode(f))continue;
            String rel=relative(workspace,f);
            String s=AndroidCompat.readText(f,StandardCharsets.UTF_8);
            if(s.length()>MAX_FILE_CHARS)s=s.substring(0,MAX_FILE_CHARS)+"\n/* truncated for model context */\n";
            if(b.length()+s.length()+rel.length()+32>MAX_CONTEXT_CHARS)continue;
            b.append("\n--- FILE: ").append(rel).append(" ---\n").append(s).append("\n");
        }
        return b.toString();
    }

    private static void collect(File root,File f,List<File> out){
        if(f==null||!f.exists())return;
        if(f.getName().startsWith(".anamika_"))return;
        if(f.isDirectory()){
            File[] kids=f.listFiles();
            if(kids!=null)for(File k:kids)collect(root,k,out);
        }else if(f.length()<=512L*1024L)out.add(f);
    }

    private static boolean isTextCode(File f){
        String n=f.getName().toLowerCase(java.util.Locale.ROOT);
        return n.endsWith(".java")||n.endsWith(".kt")||n.endsWith(".xml")||n.endsWith(".gradle")||
                n.endsWith(".properties")||n.endsWith(".json")||n.endsWith(".md")||n.endsWith(".txt");
    }

    private static List<String> requestTokens(String s){
        if(s==null)return java.util.Collections.emptyList();
        String[] parts=s.toLowerCase(java.util.Locale.ROOT).split("[^a-z0-9_]+");
        List<String> out=new ArrayList<>();
        for(String p:parts)if(p.length()>=3)out.add(p);
        return out;
    }

    private static int score(File f,List<String> tokens){
        String n=f.getName().toLowerCase(java.util.Locale.ROOT);
        int score=0;
        for(String t:tokens)if(n.contains(t))score+=20;
        if(n.equals("commandrouter.java"))score+=4;
        if(n.equals("mainactivity.java"))score+=3;
        if(n.equals("androidmanifest.xml"))score+=3;
        if(n.equals("build.gradle"))score+=2;
        return score;
    }

    private static String relative(File root,File f){
        try{
            String rp=root.getCanonicalPath(),fp=f.getCanonicalPath();
            if(fp.startsWith(rp+File.separator))return fp.substring(rp.length()+1).replace('\\','/');
        }catch(Exception ignored){}
        return f.getName();
    }

    private static String extractJsonObject(String raw){
        if(raw==null)return null;
        int start=raw.indexOf('{');
        if(start<0)return null;
        boolean inString=false,escape=false;
        int depth=0;
        for(int i=start;i<raw.length();i++){
            char ch=raw.charAt(i);
            if(inString){
                if(escape){escape=false;continue;}
                if(ch=='\\'){escape=true;continue;}
                if(ch=='"')inString=false;
                continue;
            }
            if(ch=='"'){inString=true;continue;}
            if(ch=='{')depth++;
            else if(ch=='}'){
                depth--;
                if(depth==0)return raw.substring(start,i+1);
            }
        }
        return null;
    }

    private static String trim(String s){return s.length()>2000?s.substring(0,2000):s;}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
