package com.anamika.ai;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;

import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.files.LocalVault;
import com.anamika.ai.memory.MemoryStore;
import com.anamika.ai.phone.AppLauncher;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.phone.PhoneActions;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.BlueprintStore;
import com.anamika.ai.plugins.PluginManagerActivity;
import com.anamika.ai.research.ResearchStore;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.UpgradeCoordinator;
import com.anamika.ai.voice.WakeService;

import java.util.Locale;

/** Deterministic V13 command layer. AI reasoning remains isolated from phone-control functions. */
public final class CommandRouter {
    private CommandRouter(){}

    public static String run(Activity a,String raw){
        String text=raw==null?"":raw.trim();
        if(text.isEmpty()) return "Command empty.";
        String l=text.toLowerCase(Locale.ROOT);

        if(l.equals("hello")||l.equals("hi")||l.equals("hey")||
                l.equals("hello anamika")||l.equals("hello mika"))
            return "Ji, boliye. Anamika 13 ready hai.";

        if(l.equals("functions")||l.contains("what can you do")||l.contains("kya kar sakti")){
            return "V13 core: owner lock, text/voice reply, wake service, calculator, installed-app launch, web search, settings/dialer, health/crash/watchdog, local memory, private vault, owner-controlled Plugin Center, Accessibility tap/type/back, Deep Blueprint, research notebook, source-vault self-upgrade workspace, Code Doctor validation, APK verification and Android update installer.";
        }

        if(l.equals("plugins")||l.equals("plugin center")){
            a.startActivity(new Intent(a,PluginManagerActivity.class));
            return "Opening Plugin Center.";
        }

        if(l.startsWith("scan app ")||l.startsWith("blueprint ")){
            String name=l.startsWith("scan app ")?text.substring(9).trim():text.substring(10).trim();
            AppLauncher.AppRef app=AppLauncher.resolve(a,name);
            if(app==null)return "Installed app not found: "+name;
            String started=BlueprintStore.start(a,app.packageName,app.label);
            AppLauncher.open(a,app.label);
            return started+"\nOpen the screens you want Anamika to observe, then say “stop scan”.";
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

        if(l.startsWith("open ")) return AppLauncher.open(a,text.substring(5).trim()).message;
        if(l.startsWith("app open ")) return AppLauncher.open(a,text.substring(9).trim()).message;

        if(l.startsWith("search ")||l.startsWith("google "))
            return PhoneActions.webSearch(a,text.substring(text.indexOf(' ')+1).trim());
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

        if(l.startsWith("remember ")){
            return MemoryStore.saveNote(a,text.substring(9).trim());
        }
        if(l.equals("memory")||l.equals("memory status")) return MemoryStore.summary(a);

        if(l.startsWith("save file ")){
            String body=text.substring(10);
            int split=body.indexOf('|');
            if(split<1)return "Use: save file NAME | CONTENT";
            return LocalVault.saveText(a,body.substring(0,split).trim(),body.substring(split+1).trim());
        }
        if(l.equals("vault")||l.equals("vault status")) return LocalVault.summary(a);

        if(l.equals("health")||l.equals("phone health")||l.equals("anamika health"))
            return HealthMonitor.report(a);
        if(l.equals("last crash")||l.equals("crash report")) return CrashJournal.read(a);
        if(l.equals("watchdog")||l.equals("runtime status")) return RuntimeWatchdog.status(a);

        if(l.equals("wake on")||l.equals("wake enable")){
            WakeService.enable(a);
            return "Wake listener enabled. Android or the speech-recognition provider may still pause continuous background recognition.";
        }
        if(l.equals("wake off")||l.equals("wake disable")){
            WakeService.disable(a);
            return "Wake listener disabled.";
        }

        if(l.equals("upgrade status")||l.equals("self upgrade status"))
            return UpgradeCoordinator.status(a);
        if(l.startsWith("prepare upgrade")||l.startsWith("prepare self upgrade"))
            return UpgradeCoordinator.prepare(a,text);
        if(l.equals("validate upgrade")||l.equals("code doctor"))
            return UpgradeCoordinator.validateLatest(a);

        if(l.equals("install update")||l.equals("self update")){
            a.startActivity(new Intent(a,SelfUpdateActivity.class));
            return "Opening verified self-update installer.";
        }

        if(l.equals("device info")){
            return "Android "+Build.VERSION.RELEASE+" (API "+Build.VERSION.SDK_INT+")\nDevice: "+
                    Build.MANUFACTURER+" "+Build.MODEL+"\nABI: "+String.join(", ",Build.SUPPORTED_ABIS);
        }

        return "Ye command V13 deterministic core me abhi mapped nahi hai. “functions” bolo. AI/reasoning layer ko alag rakha gaya hai taaki AI fail hone par phone functions band na hon.";
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
