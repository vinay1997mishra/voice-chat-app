package com.anamika.ai.developer;

import android.content.Context;

import com.anamika.ai.runtime.LocalProcessRunner;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * Executes the owner-installed offline coding runtime.
 *
 * Component protocol:
 * bin/anamika-brain --model <model.gguf> --workspace <dir>
 *                   --request <request.txt> --output <edit-plan.json>
 */
public final class OfflineCodingBrain {
    public static final class Result{
        public final boolean ok;
        public final String message;
        public final String rawPlan;
        Result(boolean ok,String message,String rawPlan){this.ok=ok;this.message=message;this.rawPlan=rawPlan;}
    }

    private OfflineCodingBrain(){}

    public static Result repair(Context c,File workspace,String request){
        File root=new File(c.getFilesDir(),"v13_brain");
        File runtime=new File(root,"bin/anamika-brain");
        File model=new File(root,"model.gguf");
        if(!runtime.isFile()||!model.isFile())
            return new Result(false,"Offline coding brain component is not installed.","");
        if(!runtime.canExecute()&&!runtime.setExecutable(true,true))
            return new Result(false,"Offline coding runtime is not executable on this Android build.","");
        if(workspace==null||!workspace.isDirectory())
            return new Result(false,"Upgrade workspace is missing.","");

        File io=new File(workspace,".anamika_brain");
        if(!io.exists()&&!io.mkdirs())return new Result(false,"Cannot create offline-brain workspace.","");
        File req=new File(io,"request.txt");
        File out=new File(io,"edit-plan.json");
        try(FileOutputStream os=new FileOutputStream(req,false)){
            os.write((request==null?"":request).getBytes(StandardCharsets.UTF_8));
            os.getFD().sync();
        }catch(Exception e){
            return new Result(false,"Cannot write brain request: "+safe(e),"");
        }

        List<String> cmd=new ArrayList<>();
        cmd.add(runtime.getAbsolutePath());
        cmd.add("--model");cmd.add(model.getAbsolutePath());
        cmd.add("--workspace");cmd.add(workspace.getAbsolutePath());
        cmd.add("--request");cmd.add(req.getAbsolutePath());
        cmd.add("--output");cmd.add(out.getAbsolutePath());

        HashMap<String,String> env=new HashMap<>();
        env.put("ANAMIKA_OFFLINE","1");
        env.put("HOME",root.getAbsolutePath());

        LocalProcessRunner.Result run=LocalProcessRunner.run(cmd,workspace,env,10L*60L*1000L);
        if(!run.ok())
            return new Result(false,
                    "Offline brain failed. exit="+run.exitCode+(run.timedOut?" timeout":"")+
                            (run.stderr.isEmpty()?"":"\n"+trim(run.stderr)),"");

        try{
            if(!out.isFile())return new Result(false,"Offline brain produced no edit plan.","");
            String plan=new String(java.nio.file.Files.readAllBytes(out.toPath()),StandardCharsets.UTF_8);
            WorkspacePatchApplier.Result applied=WorkspacePatchApplier.apply(workspace,plan);
            return new Result(applied.ok,applied.message,plan);
        }catch(Exception e){
            return new Result(false,"Cannot read offline edit plan: "+safe(e),"");
        }
    }

    public static String status(Context c){
        File root=new File(c.getFilesDir(),"v13_brain");
        File runtime=new File(root,"bin/anamika-brain");
        File model=new File(root,"model.gguf");
        return "Offline coding brain\nRuntime: "+(runtime.isFile()?"present":"missing")+
                "\nModel: "+(model.isFile()?(model.length()/1024/1024)+" MB":"missing")+
                "\nExecution: "+(runtime.isFile()&&runtime.canExecute()?"ready":"not verified");
    }

    private static String trim(String s){return s.length()>1500?s.substring(0,1500):s;}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
