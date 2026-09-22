package com.anamika.ai;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;

import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.diagnostics.DiagnosticsActivity;
import com.anamika.ai.diagnostics.DiagnosticsController;
import com.anamika.ai.developer.AutonomyComponents;
import com.anamika.ai.files.LocalVault;
import com.anamika.ai.language.LanguageCommandInterpreter;
import com.anamika.ai.memory.MemoryStore;
import com.anamika.ai.messaging.MessageCommandParser;
import com.anamika.ai.messaging.MessagingAutomationEngine;
import com.anamika.ai.phone.AppLauncher;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.phone.PhoneActions;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.BlueprintStore;
import com.anamika.ai.plugins.PluginManagerActivity;
import com.anamika.ai.research.ResearchStore;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.RollbackManager;
import com.anamika.ai.upgrade.SignerVault;
import com.anamika.ai.upgrade.UpgradeCoordinator;
import com.anamika.ai.voice.WakeService;

import java.util.Locale;

/** Deterministic V13 command layer with Hindi/Hinglish/English normalization. */
public final class CommandRouter {
    private CommandRouter(){}

    public static String run(Activity a,String raw){
        String fast=runFast(a,raw);
        if(fast!=null)return fast;
        return runBrain(a,raw);
    }


    public static boolean requiresBackgroundFast(String raw){
        String original=raw==null?"":raw.trim();
        if(original.isEmpty())return false;
        String text=LanguageCommandInterpreter.normalize(original);
        String l=text.toLowerCase(Locale.ROOT);
        return l.equals("run self test")||l.equals("self test")||l.equals("full diagnostics")||
                l.equals("check all functions")||
                l.equals("local build")||l.equals("build upgrade")||
                l.startsWith("offline repair ")||
                l.startsWith("create function ")||l.startsWith("add function ")||l.startsWith("new function ")||
                l.startsWith("prepare upgrade")||l.startsWith("prepare self upgrade")||
                l.equals("validate upgrade")||l.equals("code doctor")||
                l.equals("create recovery checkpoint")||l.equals("recovery checkpoint");
    }

    public static String runFast(Activity a,String raw){
        String original=raw==null?"":raw.trim();
        if(original.isEmpty()) return "Command empty.";

        // Message parsing uses the untouched owner sentence so the message body is never rewritten.
        MessageCommandParser.Request messageRequest=MessageCommandParser.parse(original);
        if(messageRequest!=null){
            if(!AppAutomationAccessibilityService.isConnected())
                return "Accessibility service connected nahi hai. Plugin Center me Anamika Accessibility on karke command dobara bolo.";
            return MessagingAutomationEngine.start(a,messageRequest);
        }

        String text=LanguageCommandInterpreter.normalize(original);
        String l=text.toLowerCase(Locale.ROOT);

        if(l.equals("hello")||l.equals("hi")||l.equals("hey")||
                l.equals("hello anamika")||l.equals("hello mika")||
                l.equals("namaste")||l.equals("नमस्ते"))
            return "Ji, boliye. Anamika 13 ready hai.";

        if(l.equals("functions")){
            return "Main Hindi, Roman Hindi/Hinglish aur English style commands ko canonical V13 commands me samajh sakti hu: owner lock, text/voice reply, wake service, calculator, installed-app launch, web search, settings/dialer, health/crash/watchdog, local memory, private vault, Plugin Center, Accessibility tap/type/back, messaging, Deep Blueprint, research, diagnostics/self-test, self-upgrade workspace, Code Doctor, APK verification aur Android update installer.";
        }

        if(l.equals("component packs")||l.equals("component center")){
            a.startActivity(new Intent(a,ComponentPacksActivity.class));
            return "Component Packs khol rahi hu.";
        }
        if(l.equals("component status"))
            return ComponentPackManager.status(a);

        if(l.equals("autonomy status")||l.equals("self repair status")||l.equals("offline brain status"))
            return AutonomyComponents.status(a);
        if(l.equals("brain status"))
            return AutonomyComponents.brainStatus(a);
        if(l.equals("signer status"))
            return SignerVault.status(a);
        if(l.equals("rollback status"))
            return RollbackManager.status(a);
        if(l.equals("create recovery checkpoint")||l.equals("recovery checkpoint"))
            return RollbackManager.checkpoint(a);

        if(l.equals("diagnostics")||l.equals("diagnostics center")){
            a.startActivity(new Intent(a,DiagnosticsActivity.class));
            return "Diagnostics Center khol rahi hu.";
        }
        if(l.equals("run self test")||l.equals("self test")||l.equals("full diagnostics")||l.equals("check all functions"))
            return DiagnosticsController.runAndSave(a);
        if(l.equals("share diagnostics")||l.equals("share diagnostic report"))
            return DiagnosticsController.shareLatest(a);
        if(l.equals("show diagnostics")||l.equals("diagnostics report"))
            return DiagnosticsController.latest(a);

        if(l.equals("message status")||l.equals("messaging status"))
            return MessagingAutomationEngine.status(a);
        if(l.equals("cancel message")||l.equals("stop message"))
            return MessagingAutomationEngine.cancel(a);

        if(MessageCommandParser.looksLikeMessageCommand(original))
            return "Message command samajh nahi aaya. Aise bolo: WhatsApp me Rahul ko Hello bhejo. Ya: व्हाट्सऐप में राहुल को हेलो भेजो.";

        if(l.equals("plugins")||l.equals("plugin center")){
            a.startActivity(new Intent(a,PluginManagerActivity.class));
            return "Plugin Center khol rahi hu.";
        }

        if(l.startsWith("scan app ")){
            String name=text.substring(9).trim();
            AppLauncher.AppRef app=AppLauncher.resolve(a,name);
            if(app==null)return "Installed app nahi mila: "+name;
            String started=BlueprintStore.start(a,app.packageName,app.label);
            AppLauncher.open(a,app.label);
            return started+"\nJin screens ko observe karwana hai unhe kholo, phir “scan band karo” bolo.";
        }
        if(l.equals("stop scan")||l.equals("inspection complete")) return BlueprintStore.stop(a);
        if(l.equals("blueprint status")||l.equals("scan status")) return BlueprintStore.status(a);

        if(l.startsWith("research ")){
            String q=text.substring(9).trim();
            return ResearchStore.start(a,q);
        }
        if(l.equals("stop research")) return ResearchStore.stop(a);
        if(l.equals("research status")) return ResearchStore.status(a);

        if(l.startsWith("tap ")) return AppAutomationAccessibilityService.clickVisibleText(text.substring(4).trim());
        if(l.startsWith("type ")) return AppAutomationAccessibilityService.typeIntoFocused(text.substring(5));
        if(l.equals("back")) return AppAutomationAccessibilityService.back();

        if(l.startsWith("app open ")) return AppLauncher.open(a,text.substring(9).trim()).message;
        if(l.startsWith("open ")) return AppLauncher.open(a,text.substring(5).trim()).message;

        if(l.startsWith("search "))
            return PhoneActions.webSearch(a,text.substring(7).trim());
        if(l.startsWith("google "))
            return PhoneActions.webSearch(a,text.substring(7).trim());
        if(l.startsWith("open url ")) return PhoneActions.openUrl(a,text.substring(9).trim());
        if(l.equals("settings")) return PhoneActions.openSettings(a);
        if(l.equals("app settings")) return PhoneActions.openAppSettings(a);
        if(l.startsWith("dial ")) return PhoneActions.dial(a,text.substring(5).trim());

        if(l.startsWith("calculate ")||l.startsWith("calc ")){
            String q=text.substring(text.indexOf(' ')+1).trim();
            try{
                double v=CalculatorEngine.evaluate(q);
                long whole=(long)v;
                return q+" = "+(v==whole?String.valueOf(whole):String.valueOf(v));
            }catch(Exception e){return "Calculation error: "+safe(e);}
        }

        if(l.startsWith("remember "))
            return MemoryStore.saveNote(a,text.substring(9).trim());
        if(l.equals("memory")||l.equals("memory status")) return MemoryStore.summary(a);

        if(l.startsWith("save file ")){
            String body=text.substring(10);
            int split=body.indexOf('|');
            if(split<1)return "Aise bolo: file notes.txt me hello save karo";
            return LocalVault.saveText(a,body.substring(0,split).trim(),body.substring(split+1).trim());
        }
        if(l.equals("vault")||l.equals("vault status")) return LocalVault.summary(a);

        if(l.equals("health")||l.equals("phone health")||l.equals("anamika health"))
            return HealthMonitor.report(a);
        if(l.equals("last crash")||l.equals("crash report")) return CrashJournal.read(a);
        if(l.equals("watchdog")||l.equals("runtime status")) return RuntimeWatchdog.status(a);

        if(l.equals("wake on")||l.equals("wake enable")){
            return WakeService.enable(a);
        }
        if(l.equals("wake off")||l.equals("wake disable")){
            WakeService.disable(a);
            return "Wake listener off kar diya.";
        }

        if(l.equals("upgrade status")||l.equals("self upgrade status"))
            return UpgradeCoordinator.status(a);
        if(l.startsWith("offline repair ")){
            String request=text.substring("offline repair ".length()).trim();
            return UpgradeCoordinator.repairLatestOffline(a,request);
        }
        if(l.startsWith("create function ")||l.startsWith("add function ")||l.startsWith("new function ")){
            int p=text.indexOf(' ');
            String request=p>=0?text.substring(p+1).trim():text;
            if(request.toLowerCase(Locale.ROOT).startsWith("function "))
                request=request.substring("function ".length()).trim();
            return UpgradeCoordinator.createOrUpgradeFunction(a,request);
        }
        if(l.equals("local build")||l.equals("build upgrade"))
            return UpgradeCoordinator.buildLatest(a);
        if(l.startsWith("prepare upgrade")||l.startsWith("prepare self upgrade"))
            return UpgradeCoordinator.prepare(a,text);
        if(l.equals("validate upgrade")||l.equals("code doctor"))
            return UpgradeCoordinator.validateLatest(a);

        if(l.equals("install update")||l.equals("self update")){
            a.startActivity(new Intent(a,SelfUpdateActivity.class));
            return "Verified self-update installer khol rahi hu.";
        }

        if(l.equals("device info")){
            return "Android "+Build.VERSION.RELEASE+" (API "+Build.VERSION.SDK_INT+")\nDevice: "+
                    Build.MANUFACTURER+" "+Build.MODEL+"\nABI: "+String.join(", ",Build.SUPPORTED_ABIS);
        }

        return null;
    }

    public static String runBrain(Activity a,String raw){
        BrainCommandEngine.Plan p=BrainCommandEngine.plan(a.getApplicationContext(),raw);
        if(p==null||!p.ok){
            String fallback=NaturalLanguageBrain.reply(a.getApplicationContext(),raw);
            if(fallback!=null&&!fallback.trim().isEmpty())return fallback;
        }
        String result=BrainCommandEngine.execute(a,p);
        if((p==null||p.actions==null||p.actions.length()==0)
                &&(p==null||p.reply==null||p.reply.trim().isEmpty())){
            String fallback=NaturalLanguageBrain.reply(a.getApplicationContext(),raw);
            if(fallback!=null&&!fallback.trim().isEmpty())return fallback;
        }
        return result;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
