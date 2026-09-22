package com.anamika.ai;

import android.content.Context;
import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.BrainRuntimePaths;
import com.anamika.ai.memory.MemoryStore;
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
        String memory=MemoryStore.promptContext(c,14,10000);
        String p="You are Anamika AI 13, the owner's personal offline assistant.\n"+
                "Understand natural Indian Hindi, Roman Hindi/Hinglish, English, mixed-language sentences, casual spelling, speech-to-text mistakes and short local phrases.\n"+
                "Do NOT require fixed commands or perfect grammar for normal conversation. Infer the intended meaning from the current message plus recent chat context.\n"+
                "Common Roman-Hindi forms are equivalent, for example: nhi/nahi, h/hai, kr/kar/karo, bta/bata/batao, kyu/kyun, kya/ky, mje/mujhe, kse/kaise, "+
                "thik/theek, chl/chal/chalta, bna/bana, hta/hata, de/de do, bhej/send, add/jod, isme/ismein, usme/usmein.\n"+
                "A message such as 'ye kyu nhi chl rha', 'ab kya kru', 'isme ye bhi add kr de', or 'code galat hai to thik kr' must be understood from context, not rejected as unknown.\n"+
                "Reply in the same language style as the owner. Be concise but useful.\n"+
                "For coding questions, explain what will happen, why, risks and next steps conversationally before code when that is what the owner is asking.\n"+
                "Do not pretend an Android action was executed when it was not.\n"+
                "If this is normal conversation or a question, answer directly.\n"+
                "Use recent chat history and owner memory when relevant to references such as 'ye', 'isme', 'usme', 'ab', 'pehle wala'. Do not blindly repeat history.\n\n"+
                (memory.isEmpty()?"":memory+"\n\n")+
                "CURRENT OWNER MESSAGE: "+(instruction==null?"":instruction)+"\nANAMIKA:";
        try(FileOutputStream out=new FileOutputStream(prompt,false)){
            out.write(p.getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }catch(Exception e){ return "Natural chat prompt create nahi ho saka: "+safe(e); }

        List<String> cmd=new ArrayList<>();
        cmd.add(cli.getAbsolutePath());
        cmd.add("--offline");
        cmd.add("-m"); cmd.add(model.getAbsolutePath());
        cmd.add("-f"); cmd.add(prompt.getAbsolutePath());
        cmd.add("-c"); cmd.add(String.valueOf(Math.min(6144,effort.contextTokens)));
        cmd.add("-n"); cmd.add(String.valueOf(Math.min(900,effort.maxTokens)));
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
