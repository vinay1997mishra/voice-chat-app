package com.anamika.ai;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.developer.AutonomyComponents;
import com.anamika.ai.developer.BrainRuntimePaths;
import com.anamika.ai.diagnostics.DiagnosticsActivity;
import com.anamika.ai.diagnostics.DiagnosticsController;
import com.anamika.ai.files.LocalVault;
import com.anamika.ai.language.LocalLanguageText;
import com.anamika.ai.language.OwnerConversationProfile;
import com.anamika.ai.language.UnderstandingPackStore;
import com.anamika.ai.memory.MemoryStore;
import com.anamika.ai.messaging.MessageCommandParser;
import com.anamika.ai.messaging.MessagingAutomationEngine;
import com.anamika.ai.phone.AppLauncher;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.phone.PhoneActions;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.BlueprintStore;
import com.anamika.ai.plugins.FunctionPackStore;
import com.anamika.ai.plugins.PluginManagerActivity;
import com.anamika.ai.research.ResearchStore;
import com.anamika.ai.runtime.LocalProcessRunner;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.RollbackManager;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.SignerVault;
import com.anamika.ai.upgrade.UpgradeCoordinator;
import com.anamika.ai.voice.WakeService;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;

/**
 * Offline natural-language planner for all V13 owner-facing actions.
 *
 * The model never receives shell access. It may only return a structured action plan
 * from a fixed allow-list. Android permission checks and each feature's own owner/safety
 * checks still remain authoritative at execution time.
 */
public final class BrainCommandEngine {
    public static final class Plan {
        public final boolean ok;
        public final String message;
        public final JSONArray actions;
        public final String reply;
        Plan(boolean ok,String message,JSONArray actions,String reply){
            this.ok=ok;this.message=message;this.actions=actions;this.reply=reply;
        }
    }

    private BrainCommandEngine(){}

    public static boolean ready(Context c){
        return ComponentPackManager.brainInstalled(c);
    }

    public static Plan plan(Context c,String ownerInstruction){
        FunctionPackStore.Match packed=FunctionPackStore.match(c,ownerInstruction);
        if(packed!=null)
            return new Plan(true,"FUNCTION_PACK:"+packed.packId+"/"+packed.functionId,packed.actions,packed.reply);

        if(!ready(c))
            return new Plan(false,
                    "Offline brain abhi ready nahi hai. Runtime aur GGUF model Components me install karein.",
                    new JSONArray(),"");

        File root=BrainRuntimePaths.root(c);
        File cli=BrainRuntimePaths.embeddedCli(c);
        File model=BrainRuntimePaths.model(c);
        if(!BrainRuntimePaths.runtimeReady(c)||!model.isFile())
            return new Plan(false,"Offline brain files or APK-native runtime missing hain.",new JSONArray(),"");

        File io=new File(c.getCacheDir(),"brain_command");
        if(!io.exists()&&!io.mkdirs())
            return new Plan(false,"Brain command cache create nahi ho saka.",new JSONArray(),"");
        File promptFile=new File(io,"prompt.txt");
        File schemaFile=new File(io,"schema.json");

        try{
            BrainEffortStore.Mode effort=BrainEffortStore.get(c);
            write(promptFile,buildPrompt(c,ownerInstruction)+"\n\nLOCAL EFFORT MODE: "+effort.label+"\n");
            write(schemaFile,schema());

            List<String> cmd=new ArrayList<>();
            cmd.add(cli.getAbsolutePath());
            cmd.add("--offline");
            cmd.add("-m");cmd.add(model.getAbsolutePath());
            cmd.add("-f");cmd.add(promptFile.getAbsolutePath());
            cmd.add("-c");cmd.add(String.valueOf(effort.contextTokens));
            cmd.add("-n");cmd.add(String.valueOf(effort.maxTokens));
            cmd.add("--temp");cmd.add(effort.temperature);
            cmd.add("-st");
            cmd.add("--simple-io");
            cmd.add("--no-display-prompt");
            cmd.add("--no-show-timings");
            cmd.add("--no-warmup");
            cmd.add("--log-colors");cmd.add("off");
            cmd.add("--no-log-prefix");
            cmd.add("--no-log-timestamps");
            cmd.add("-lv");cmd.add("1");
            cmd.add("-jf");cmd.add(schemaFile.getAbsolutePath());

            HashMap<String,String> env=new HashMap<>();
            env.put("ANAMIKA_OFFLINE","1");
            env.put("HOME",root.getAbsolutePath());
            String nativeDir=c.getApplicationInfo().nativeLibraryDir;
            if(nativeDir!=null&&!nativeDir.trim().isEmpty())env.put("LD_LIBRARY_PATH",nativeDir);

            LocalProcessRunner.Result run=LocalProcessRunner.run(cmd,io,env,effort.timeoutMs);
            if(!run.ok())
                return new Plan(false,"Offline brain command planning failed. exit="+run.exitCode+
                        (run.timedOut?" timeout":"")+
                        (run.stderr.isEmpty()?"":"\n"+trim(run.stderr)),new JSONArray(),"");

            String json=extractJsonObject(run.stdout);
            if(json==null)json=extractJsonObject(run.stderr);

            if(json==null){
                write(promptFile,buildRetryPrompt(c,ownerInstruction));
                LocalProcessRunner.Result retry=LocalProcessRunner.run(cmd,io,env,effort.timeoutMs);
                if(retry.ok()){
                    json=extractJsonObject(retry.stdout);
                    if(json==null)json=extractJsonObject(retry.stderr);
                }
            }

            if(json==null)
                return new Plan(false,"Offline brain ne valid action plan nahi diya.",new JSONArray(),"");

            JSONObject o=new JSONObject(json);
            JSONArray actions=o.optJSONArray("actions");
            if(actions==null)actions=new JSONArray();
            String reply=o.optString("reply","");
            if(actions.length()>8)
                return new Plan(false,"Brain action plan limit se zyada bada tha.",new JSONArray(),"");
            return new Plan(true,"OK",actions,reply);
        }catch(Exception e){
            return new Plan(false,"Brain planning error: "+safe(e),new JSONArray(),"");
        }
    }

    public static boolean requiresBackground(Plan p){
        if(p==null||p.actions==null)return false;
        for(int i=0;i<p.actions.length();i++){
            JSONObject x=p.actions.optJSONObject(i);
            if(x==null)continue;
            String a=x.optString("action","").toLowerCase(Locale.ROOT);
            if(a.equals("create_function")||a.equals("offline_repair")||a.equals("self_repair")||a.equals("local_build")||
                    a.equals("self_test")||a.equals("prepare_upgrade")||a.equals("validate_upgrade")||
                    a.equals("recovery_checkpoint"))return true;
        }
        return false;
    }

    public static String execute(Activity a,Plan p){
        if(p==null||!p.ok)return p==null?"Brain plan missing.":p.message;
        ArrayList<String> results=new ArrayList<>();
        for(int i=0;i<p.actions.length();i++){
            JSONObject x=p.actions.optJSONObject(i);
            if(x==null)continue;
            String action=x.optString("action","").trim().toLowerCase(Locale.ROOT);
            String a1=x.optString("arg1","");
            String a2=x.optString("arg2","");
            String text=x.optString("text","");
            String r=executeOne(a,action,a1,a2,text);
            if(r!=null&&!r.trim().isEmpty())results.add(r);
        }

        StringBuilder out=new StringBuilder();
        if(!p.reply.trim().isEmpty())out.append(p.reply.trim());
        for(String r:results){
            if(out.length()>0)out.append("\n");
            out.append(r);
        }
        if(out.length()==0)
            out.append("Instruction samajh aayi, lekin executable V13 action plan nahi bana.");
        return out.toString();
    }

    private static String executeOne(Activity a,String action,String arg1,String arg2,String text){
        switch(action){
            case "reply": return text;
            case "open_app": return AppLauncher.open(a,arg1).message;
            case "search_web": return PhoneActions.webSearch(a,text.isEmpty()?arg1:text);
            case "open_url": return PhoneActions.openUrl(a,arg1);
            case "open_settings": return PhoneActions.openSettings(a);
            case "open_app_settings": return PhoneActions.openAppSettings(a);
            case "dial": return PhoneActions.dial(a,arg1);
            case "calculate":
                try{
                    double v=CalculatorEngine.evaluate(text.isEmpty()?arg1:text);
                    long w=(long)v;
                    return (text.isEmpty()?arg1:text)+" = "+(v==w?String.valueOf(w):String.valueOf(v));
                }catch(Exception e){return "Calculation error: "+safe(e);}
            case "remember": return MemoryStore.saveNote(a,text.isEmpty()?arg1:text);
            case "memory_status": return MemoryStore.summary(a);
            case "save_file": return LocalVault.saveText(a,arg1,text);
            case "vault_status": return LocalVault.summary(a);
            case "open_plugins":
                a.startActivity(new Intent(a,PluginManagerActivity.class)); return "Plugin Center khol rahi hu.";
            case "open_components":
                a.startActivity(new Intent(a,ComponentPacksActivity.class)); return "Components khol rahi hu.";
            case "component_status": return ComponentPackManager.status(a);
            case "autonomy_status": return AutonomyComponents.status(a);
            case "brain_status": return AutonomyComponents.brainStatus(a);
            case "diagnostics":
                a.startActivity(new Intent(a,DiagnosticsActivity.class)); return "Diagnostics Center khol rahi hu.";
            case "self_test": return DiagnosticsController.runAndSave(a);
            case "diagnostics_report": return DiagnosticsController.latest(a);
            case "message":
                if(!AppAutomationAccessibilityService.isConnected())
                    return "Accessibility service connected nahi hai. Plugin Center me Anamika Accessibility on karein.";
                return MessagingAutomationEngine.start(a,new MessageCommandParser.Request(arg1,arg2,text));
            case "message_status": return MessagingAutomationEngine.status(a);
            case "cancel_message": return MessagingAutomationEngine.cancel(a);
            case "scan_app": {
                AppLauncher.AppRef app=AppLauncher.resolve(a,arg1);
                if(app==null)return "Installed app nahi mila: "+arg1;
                String started=BlueprintStore.start(a,app.packageName,app.label);
                AppLauncher.open(a,app.label);
                return started;
            }
            case "stop_scan": return BlueprintStore.stop(a);
            case "blueprint_status": return BlueprintStore.status(a);
            case "research": return ResearchStore.start(a,text.isEmpty()?arg1:text);
            case "stop_research": return ResearchStore.stop(a);
            case "research_status": return ResearchStore.status(a);
            case "tap": return AppAutomationAccessibilityService.clickVisibleText(text.isEmpty()?arg1:text);
            case "type": return AppAutomationAccessibilityService.typeIntoFocused(text);
            case "back": return AppAutomationAccessibilityService.back();
            case "wake_on": return WakeService.enable(a);
            case "wake_off": WakeService.disable(a); return "Wake listener off kar diya.";
            case "health": return HealthMonitor.report(a);
            case "last_crash": return CrashJournal.read(a);
            case "watchdog": return RuntimeWatchdog.status(a);
            case "upgrade_status": return UpgradeCoordinator.status(a);
            case "offline_repair": return UpgradeCoordinator.repairLatestOffline(a,text.isEmpty()?arg1:text);
            case "self_repair": return UpgradeCoordinator.selfRepair(a,text.isEmpty()?arg1:text);
            case "local_build": return UpgradeCoordinator.buildLatest(a);
            case "prepare_upgrade": return UpgradeCoordinator.prepare(a,text.isEmpty()?arg1:text);
            case "create_function": return UpgradeCoordinator.createOrUpgradeFunction(a,text.isEmpty()?arg1:text);
            case "validate_upgrade": return UpgradeCoordinator.validateLatest(a);
            case "install_update":
                a.startActivity(new Intent(a,SelfUpdateActivity.class)); return "Verified self-update installer khol rahi hu.";
            case "recovery_checkpoint": return RollbackManager.checkpoint(a);
            case "rollback_status": return RollbackManager.status(a);
            case "signer_status": return SignerVault.status(a);
            case "run_function_pack": return runFunctionPack(a,arg1,text);
            case "device_info":
                return "Android "+Build.VERSION.RELEASE+" (API "+Build.VERSION.SDK_INT+")\nDevice: "+
                        Build.MANUFACTURER+" "+Build.MODEL+"\nABI: "+joinAbis();
            default: return "Unsupported brain action ignored: "+action;
        }
    }

    private static String runFunctionPack(Activity a,String functionId,String input){
        FunctionPackStore.Match packed=FunctionPackStore.byId(a,functionId,input);
        if(packed==null)return "Function Pack function nahi mila: "+functionId;
        StringBuilder out=new StringBuilder();
        if(packed.reply!=null&&!packed.reply.trim().isEmpty())out.append(packed.reply.trim());
        int limit=Math.min(8,packed.actions.length());
        for(int i=0;i<limit;i++){
            JSONObject x=packed.actions.optJSONObject(i);
            if(x==null)continue;
            String action=x.optString("action","").trim().toLowerCase(Locale.ROOT);
            if("run_function_pack".equals(action))continue;
            String r=executeOne(a,action,x.optString("arg1",""),x.optString("arg2",""),x.optString("text",""));
            if(r!=null&&!r.trim().isEmpty()){
                if(out.length()>0)out.append("\n");
                out.append(r);
            }
        }
        return out.length()==0?"Function Pack command complete.":out.toString();
    }

    private static String buildRetryPrompt(Context c,String instruction){
        String memory=MemoryStore.promptContext(c,10,7000);
        String ownerInstruction=instruction==null?"":instruction.trim();
        String localHint=LocalLanguageText.intentHint(ownerInstruction);
        String conversationHint=UnderstandingPackStore.semanticHint(c,ownerInstruction);
        StringBuilder hintBuilder=new StringBuilder();
        if(!localHint.isEmpty()&&!localHint.equalsIgnoreCase(ownerInstruction))
            hintBuilder.append("LOCAL LANGUAGE INTERPRETATION HINT: ").append(localHint).append("\n");
        if(!conversationHint.isEmpty())
            hintBuilder.append("RECENT-CONVERSATION FOLLOW-UP HINT: ").append(conversationHint).append("\n");
        String hintLine=hintBuilder.toString();
        return "You are Anamika AI 13 command planner.\n"+
                "Return exactly ONE JSON object and nothing else.\n"+
                "Required top-level keys: actions and reply.\n"+
                "actions must be an array. Each action item must contain action, arg1, arg2 and text.\n"+
                "For normal conversation or a normal question, return actions=[] and put the natural answer in reply.\n"+
                "For a supported device/app command, choose only an action allowed by the JSON schema.\n"+
                "If an installed Function Pack matches the request, use run_function_pack with arg1=function id and text=the remaining owner input.\n"+
                "Understand Hindi, casual Roman Hindi/Hinglish, English, mixed-language sentences, shorthand and common speech-to-text mistakes.\n"+
                "Treat local forms such as nhi/nahi, kr/kar/karo, bta/batao, kyu/kyun, mje/mujhe, kse/kaise, thik/theek, chl/chal, bna/bana, hta/hata as normal language.\n"+
                "Do not require exact command wording. Use recent chat history and owner memory to resolve references/follow-ups such as ye, isme, usme, ab and pehle wala.\n"+
                UnderstandingPackStore.promptGuide(c)+"\n"+
                (memory.isEmpty()?"":"\n"+memory+"\n")+
                hintLine+
                "CURRENT OWNER INSTRUCTION: "+ownerInstruction;
    }

    private static String buildPrompt(Context c,String instruction){
        String memory=MemoryStore.promptContext(c,12,9000);
        String ownerInstruction=instruction==null?"":instruction.trim();
        String localHint=LocalLanguageText.intentHint(ownerInstruction);
        String conversationHint=UnderstandingPackStore.semanticHint(c,ownerInstruction);
        StringBuilder hintBuilder=new StringBuilder();
        if(!localHint.isEmpty()&&!localHint.equalsIgnoreCase(ownerInstruction))
            hintBuilder.append("LOCAL LANGUAGE INTERPRETATION HINT: ").append(localHint).append("\n");
        if(!conversationHint.isEmpty())
            hintBuilder.append("RECENT-CONVERSATION FOLLOW-UP HINT: ").append(conversationHint).append("\n");
        String hintLine=hintBuilder.toString();
        return "You are Anamika AI 13's OFFLINE command planner.\n"+
                "Understand Hindi, casual Roman Hindi/Hinglish, English, mixed app names, shorthand, imperfect grammar, speech-to-text mistakes, short commands and multi-step owner instructions.\n"+
                "Do not require exact command words. Infer intent from natural local phrasing. Treat nhi/nahi, kr/kar/karo, bta/batao, kyu/kyun, mje/mujhe, kse/kaise, thik/theek, chl/chal, bna/bana, hta/hata as ordinary equivalent forms.\n"+
                "Use conversation history for references such as ye, isme, usme, ab, pehle wala and jo abhi bola.\n"+
                UnderstandingPackStore.promptGuide(c)+"\n"+
                "Convert the owner's request into ONLY the allowed structured actions below.\n"+
                "Never invent shell commands, hidden permissions, root access, or capabilities outside this list.\n"+
                "Do not bypass Android confirmation or permission screens. Keep names, message bodies, URLs and numbers exactly as intended.\n"+
                "If one request needs multiple steps, return them in order, max 8 actions.\n"+
                "If the owner is chatting or asking a normal question, return actions=[] and answer naturally in reply.\n"+
                "If nothing can be executed, return no actions and explain briefly in reply.\n"+
                "For self-upgrade requests, use prepare_upgrade/offline_repair/self_repair/local_build/validate_upgrade/install_update only; existing owner confirmation remains mandatory.\n"+
                "If the owner asks Anamika to fix herself, repair her own functions, or correct a broken internal behavior, use self_repair with the problem description.\n\n"+
                "ACTIONS:\n"+
                "reply(text); open_app(arg1=app); search_web(text=query); open_url(arg1=url); open_settings; open_app_settings; dial(arg1=number); calculate(text=expression); "+
                "remember(text); memory_status; save_file(arg1=filename,text=content); vault_status; open_plugins; open_components; component_status; autonomy_status; brain_status; "+
                "diagnostics; self_test; diagnostics_report; message(arg1=app,arg2=recipient,text=message); message_status; cancel_message; "+
                "scan_app(arg1=app); stop_scan; blueprint_status; research(text=query); stop_research; research_status; tap(text=visible control); type(text); back; "+
                "wake_on; wake_off; health; last_crash; watchdog; upgrade_status; offline_repair(text=request); self_repair(text=problem); local_build; prepare_upgrade(text=request); create_function(text=request); "+
                "validate_upgrade; install_update; recovery_checkpoint; rollback_status; signer_status; run_function_pack(arg1=function_id,text=input); device_info.\n\n"+
                "INSTALLED FUNCTION PACKS:\n"+FunctionPackStore.catalog(c)+"\n\n"+
                "INSTALLED LAUNCHABLE APPS:\n"+installedApps(c)+"\n\n"+
                (memory.isEmpty()?"":"CONVERSATION/MEMORY CONTEXT:\n"+memory+"\n\n")+
                hintLine+
                "The local hint is semantic only; preserve exact names, numbers, URLs and message text from the original instruction.\n"+
                "CURRENT OWNER INSTRUCTION:\n"+ownerInstruction+"\n\n"+
                "Return JSON only.";
    }

    private static String installedApps(Context c){
        try{
            PackageManager pm=c.getPackageManager();
            List<ApplicationInfo> list;
            if(Build.VERSION.SDK_INT>=33)
                list=pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0));
            else list=pm.getInstalledApplications(0);
            StringBuilder b=new StringBuilder();
            int count=0;
            for(ApplicationInfo info:list){
                if(pm.getLaunchIntentForPackage(info.packageName)==null)continue;
                if(count++>=120)break;
                b.append(pm.getApplicationLabel(info)).append(" | ").append(info.packageName).append("\n");
            }
            return b.toString();
        }catch(Exception e){return "(app list unavailable)";}
    }

    private static String schema(){
        return "{"+
                "\"type\":\"object\",\"additionalProperties\":false,"+
                "\"required\":[\"actions\",\"reply\"],"+
                "\"properties\":{"+
                "\"reply\":{\"type\":\"string\"},"+
                "\"actions\":{\"type\":\"array\",\"maxItems\":8,\"items\":{"+
                "\"type\":\"object\",\"additionalProperties\":false,"+
                "\"required\":[\"action\",\"arg1\",\"arg2\",\"text\"],"+
                "\"properties\":{"+
                "\"action\":{\"enum\":[\"reply\",\"open_app\",\"search_web\",\"open_url\",\"open_settings\",\"open_app_settings\",\"dial\",\"calculate\",\"remember\",\"memory_status\",\"save_file\",\"vault_status\",\"open_plugins\",\"open_components\",\"component_status\",\"autonomy_status\",\"brain_status\",\"diagnostics\",\"self_test\",\"diagnostics_report\",\"message\",\"message_status\",\"cancel_message\",\"scan_app\",\"stop_scan\",\"blueprint_status\",\"research\",\"stop_research\",\"research_status\",\"tap\",\"type\",\"back\",\"wake_on\",\"wake_off\",\"health\",\"last_crash\",\"watchdog\",\"upgrade_status\",\"offline_repair\",\"self_repair\",\"local_build\",\"prepare_upgrade\",\"create_function\",\"validate_upgrade\",\"install_update\",\"recovery_checkpoint\",\"rollback_status\",\"signer_status\",\"device_info\"]},"+
                "\"arg1\":{\"type\":\"string\"},\"arg2\":{\"type\":\"string\"},\"text\":{\"type\":\"string\"}"+
                "}}}}}";
    }

    private static void write(File f,String s)throws Exception{
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(s.getBytes(StandardCharsets.UTF_8)); out.getFD().sync();
        }
    }

    private static String extractJsonObject(String raw){
        if(raw==null)return null;
        int start=raw.indexOf('{');
        if(start<0)return null;
        boolean in=false,esc=false; int depth=0;
        for(int i=start;i<raw.length();i++){
            char ch=raw.charAt(i);
            if(in){
                if(esc){esc=false;continue;}
                if(ch=='\\'){esc=true;continue;}
                if(ch=='"')in=false;
                continue;
            }
            if(ch=='"'){in=true;continue;}
            if(ch=='{')depth++;
            else if(ch=='}'&&--depth==0)return raw.substring(start,i+1);
        }
        return null;
    }

    private static String joinAbis(){
        StringBuilder b=new StringBuilder();
        for(String abi:Build.SUPPORTED_ABIS){if(b.length()>0)b.append(", ");b.append(abi);}
        return b.toString();
    }

    private static String trim(String s){return s.length()>2000?s.substring(0,2000):s;}
    private static String safe(Throwable e){
        String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
