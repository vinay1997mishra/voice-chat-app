package com.anamika.ai;

import android.content.Context;
import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.BrainRuntimePaths;
import com.anamika.ai.runtime.LocalProcessRunner;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public final class NaturalLanguageBrain {
    private NaturalLanguageBrain(){}

    public static String reply(Context c,String instruction){
        if(!ComponentPackManager.brainInstalled(c)) return "Offline brain ready nahi hai.";
        File root=BrainRuntimePaths.root(c);
        File model=BrainRuntimePaths.model(c);
        File cli=BrainRuntimePaths.embeddedCli(c);
        if(!BrainRuntimePaths.runtimeReady(c)||!model.isFile()||!cli.isFile()) return "Offline brain runtime/model unavailable hai.";
        File io=new File(c.getCacheDir(),"natural_chat");
        if(!io.exists()&&!io.mkdirs()) return "Natural chat workspace create nahi ho saka.";
        File prompt=new File(io,"prompt.txt");
        BrainEffortStore.Mode effort=BrainEffortStore.get(c);
        String p="You are Anamika AI 13, the owner personal offline assistant.\n"+
                "Understand Hindi, Hinglish Roman Hindi, English and mixed-language sentences naturally.\n"+
                "Reply in the same language style as the owner. Be concise but useful.\n"+
                "Do not pretend an Android action was executed when it was not.\n"+
                "If this is normal conversation or a question, answer directly.\n\n"+
                "OWNER: "+(instruction==null?"":instruction)+"\nANAMIKA:";
        try(FileOutputStream out=new FileOutputStream(prompt,false)){
            out.write(p.getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }catch(Exception e){ return "Natural chat prompt create nahi ho saka: "+safe(e); }

        List<String> cmd=new ArrayList<>();
        cmd.add(cli.getAbsolutePath());
        cmd.add("--offline");
        cmd.add("-m"); cmd.add(model.getAbsolutePath());
        cmd.add("-f"); cmd.add(prompt.getAbsolutePath());
        cmd.add("-c"); cmd.add(String.valueOf(Math.min(4096,effort.contextTokens)));
        cmd.add("-n"); cmd.add(String.valueOf(Math.min(700,effort.maxTokens)));
        cmd.add("--temp"); cmd.add("0.20");
        cmd.add("-st");
        cmd.add("--simple-io");
        cmd.add("--no-display-prompt");
        cmd.add("--no-show-timings");
        cmd.add("--no-warmup");
        cmd.add("--log-colors"); cmd.add("off");
        cmd.add("--no-log-prefix");
        cmd.add("--no-log-timestamps");
        cmd.add("-lv"); cmd.add("1");

        HashMap<String,String> env=new HashMap<>();
        env.put("ANAMIKA_OFFLINE","1");
        env.put("HOME",root.getAbsolutePath());
        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        if(nativeDir!=null&&!nativeDir.trim().isEmpty()) env.put("LD_LIBRARY_PATH",nativeDir);

        LocalProcessRunner.Result r=LocalProcessRunner.run(cmd,io,env,effort.timeoutMs);
        if(!r.ok()) return "Offline natural-language reply fail hui. exit="+r.exitCode+(r.timedOut?" timeout":"");
        String raw=r.stdout==null?"":r.stdout.trim();
        if(raw.isEmpty()) raw=r.stderr==null?"":r.stderr.trim();
        return clean(raw);
    }

    private static String clean(String raw){
        if(raw==null||raw.trim().isEmpty()) return "Mujhe sentence mila, lekin offline model ne reply nahi diya.";
        String s=raw.trim();
        int marker=s.lastIndexOf("ANAMIKA:");
        if(marker>=0) s=s.substring(marker+"ANAMIKA:".length()).trim();
        return s.length()>1800?s.substring(0,1800):s;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
