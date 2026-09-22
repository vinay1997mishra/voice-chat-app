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

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Executes the owner-installed offline coding runtime.
 *
 * Runtime protocol:
 * bin/anamika-brain --model <model.gguf> --workspace <dir>
 *                   --request <request.txt> --output <edit-plan.json>
 */
public final class OfflineCodingBrain {
    private static final int MAX_CONTEXT_CHARS=32000;
    private static final int RETRY_CONTEXT_CHARS=18000;
    private static final int MAX_FILE_CHARS=12000;

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
            os.write(buildPrompt(workspace,request,MAX_CONTEXT_CHARS,false).getBytes(StandardCharsets.UTF_8));
            os.getFD().sync();
        }catch(Exception e){
            return new Result(false,"Cannot write brain request: "+safe(e),"");
        }

        HashMap<String,String> env=new HashMap<>();
        env.put("ANAMIKA_OFFLINE","1");
        env.put("HOME",root.getAbsolutePath());
        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        if(nativeDir!=null&&!nativeDir.trim().isEmpty())env.put("LD_LIBRARY_PATH",nativeDir);

        LocalProcessRunner.Result run=runModel(cli,model,req,schema,workspace,env,"0.10",15L*60L*1000L);
        if(!run.ok())
            return new Result(false,
                    "Offline brain failed. exit="+run.exitCode+(run.timedOut?" timeout":"")+
                            (run.stderr.isEmpty()?"":"\n"+trim(run.stderr)),"");

        try{
            String raw=run.stdout;
            String plan=extractEditPlanJson(raw);
            if(plan==null)plan=extractEditPlanJson(run.stderr);

            // Small local models can occasionally emit prose or an empty completion even
            // with JSON-schema constraints. Retry once with a shorter context and a
            // stricter JSON-only instruction instead of immediately failing the upgrade.
            if(plan==null){
                try(FileOutputStream os=new FileOutputStream(req,false)){
                    os.write(buildPrompt(workspace,request,RETRY_CONTEXT_CHARS,true).getBytes(StandardCharsets.UTF_8));
                    os.getFD().sync();
                }
                LocalProcessRunner.Result retry=runModel(cli,model,req,schema,workspace,env,"0.00",15L*60L*1000L);
                raw=raw+"\n\n--- RETRY STDOUT ---\n"+retry.stdout+"\n--- RETRY STDERR ---\n"+retry.stderr;
                if(retry.ok()){
                    plan=extractEditPlanJson(retry.stdout);
                    if(plan==null)plan=extractEditPlanJson(retry.stderr);
                }else{
                    return new Result(false,
                            "Offline brain JSON retry failed. exit="+retry.exitCode+
                                    (retry.timedOut?" timeout":"")+
                                    (retry.stderr.isEmpty()?"":"\n"+trim(retry.stderr)),raw);
                }
            }

            if(plan==null){
                try(FileOutputStream os=new FileOutputStream(req,false)){
                    os.write(buildPrompt(workspace,request,10000,true).getBytes(StandardCharsets.UTF_8));
                    os.getFD().sync();
                }
                LocalProcessRunner.Result finalRetry=runModel(cli,model,req,schema,workspace,env,"0.00",15L*60L*1000L);
                raw=raw+"\n\n--- FINAL RETRY STDOUT ---\n"+finalRetry.stdout+
                        "\n--- FINAL RETRY STDERR ---\n"+finalRetry.stderr;
                if(finalRetry.ok()){
                    plan=extractEditPlanJson(finalRetry.stdout);
                    if(plan==null)plan=extractEditPlanJson(finalRetry.stderr);
                }
            }

            try(FileOutputStream os=new FileOutputStream(out,false)){
                os.write(raw.getBytes(StandardCharsets.UTF_8));
                os.getFD().sync();
            }
            if(plan==null)
                return new Result(false,
                        "Offline brain ne valid edit-plan JSON nahi diya. Multiple automatic JSON retries fail hue. Raw output workspace me save hai.\nBrain output preview: "+preview(raw),
                        raw);
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

    private static LocalProcessRunner.Result runModel(
            File cli,File model,File req,File schema,File workspace,HashMap<String,String> env,
            String temperature,long timeoutMs){
        List<String> cmd=new ArrayList<>();
        cmd.add(cli.getAbsolutePath());
        cmd.add("--offline");
        cmd.add("-m");cmd.add(model.getAbsolutePath());
        cmd.add("-f");cmd.add(req.getAbsolutePath());
        cmd.add("-c");cmd.add("16384");
        cmd.add("-n");cmd.add("4096");
        cmd.add("--temp");cmd.add(temperature);
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
        return LocalProcessRunner.run(cmd,workspace,env,timeoutMs);
    }

    private static String buildPrompt(File workspace,String ownerRequest,int maxContextChars,boolean retry)throws Exception{
        StringBuilder b=new StringBuilder();
        b.append("You are the offline coding brain for Anamika AI 13.\n")
                .append("Work ONLY on the provided workspace snapshot. Never use shell commands.\n")
                .append(retry
                        ?"A previous attempt did not produce a usable JSON edit plan. This is the only retry. Output one JSON object and nothing else.\n"
                        :"")
                .append("Return ONLY one JSON object matching schema anamika13-edit-plan-v1. No markdown fences, no explanation, no preface, no suffix.\n")
                .append("Allowed operations: write and delete. For write, content must contain the complete replacement file.\n")
                .append("Keep package/application identity and existing features unless the owner explicitly requests a change.\n")
                .append("Do not claim success; the app will run structural and real build checks after applying your edits.\n")
                .append("Required shape example: {\"schema\":\"anamika13-edit-plan-v1\",\"edits\":[{\"op\":\"write\",\"path\":\"app13/src/main/java/...\",\"content\":\"complete file text\"}]}\n\n")
                .append("OWNER REQUEST:\n").append(ownerRequest==null?"":ownerRequest).append("\n\n")
                .append("WORKSPACE FILE TREE:\n");

        List<File> files=new ArrayList<>();
        collect(workspace,workspace,files);
        files.sort(Comparator.comparing(f->relative(workspace,f)));
        for(File f:files){
            if(b.length()>=Math.max(6000,maxContextChars/3))break;
            b.append(relative(workspace,f)).append("\n");
        }

        b.append("\nSELECTED FILE CONTENTS:\n");
        List<String> tokens=requestTokens(ownerRequest);
        files.sort((a,z)->Integer.compare(score(z,tokens),score(a,tokens)));
        for(File f:files){
            if(b.length()>=maxContextChars)break;
            if(!isTextCode(f))continue;
            String rel=relative(workspace,f);
            String s=AndroidCompat.readText(f,StandardCharsets.UTF_8);
            if(s.length()>MAX_FILE_CHARS)s=s.substring(0,MAX_FILE_CHARS)+"\n/* truncated for model context */\n";
            if(b.length()+s.length()+rel.length()+32>maxContextChars)continue;
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

    private static String extractEditPlanJson(String raw){
        if(raw==null||raw.isEmpty())return null;
        int search=0;
        while(search<raw.length()){
            int start=raw.indexOf('{',search);
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
                    if(depth==0){
                        String candidate=raw.substring(start,i+1);
                        try{
                            JSONObject o=new JSONObject(candidate);
                            JSONArray edits=o.optJSONArray("edits");
                            if("anamika13-edit-plan-v1".equals(o.optString("schema",""))
                                    &&edits!=null&&edits.length()>0)
                                return candidate;
                        }catch(Exception ignored){}
                        search=start+1;
                        break;
                    }
                }
                if(i==raw.length()-1)search=start+1;
            }
        }
        return null;
    }

    private static String preview(String s){
        if(s==null||s.trim().isEmpty())return "(empty output)";
        String v=s.replace('\n',' ').replaceAll("\\s+"," ").trim();
        return v.length()>700?v.substring(0,700)+"…":v;
    }

    private static String trim(String s){return s.length()>2000?s.substring(0,2000):s;}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
