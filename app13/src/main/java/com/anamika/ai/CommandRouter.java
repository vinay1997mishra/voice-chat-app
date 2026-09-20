package com.anamika.ai;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;

import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.phone.AppLauncher;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.BlueprintStore;
import com.anamika.ai.plugins.PluginManagerActivity;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.UpgradeCoordinator;
import com.anamika.ai.voice.WakeService;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/** Deterministic V13 command layer. AI reasoning is intentionally a separate adapter. */
public final class CommandRouter {
    private CommandRouter(){}

    public static String run(Activity a,String raw){
        String text=raw==null?"":raw.trim();
        if(text.isEmpty()) return "Command empty.";
        String l=text.toLowerCase(Locale.ROOT);

        if(l.equals("hello")||l.equals("hi")||l.equals("hey")||l.equals("hello anamika")||l.equals("hello mika"))
            return "Ji, boliye. Anamika 13 ready hai.";

        if(l.equals("functions")||l.contains("what can you do")||l.contains("kya kar sakti")){
            return "Working V13 core: owner lock, text commands, voice input/reply, calculator, installed-app launch, Google search, health/crash report, wake service, owner-controlled Plugin Center, Accessibility tap/type/back, Deep Blueprint recording, source-vault workspace, APK verification and Android update installer.";
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

        if(l.startsWith("tap ")){
            return AppAutomationAccessibilityService.clickVisibleText(text.substring(4).trim());
        }
        if(l.startsWith("type ")){
            return AppAutomationAccessibilityService.typeIntoFocused(text.substring(5));
        }
        if(l.equals("back")) return AppAutomationAccessibilityService.back();

        if(l.startsWith("open ")){
            return AppLauncher.open(a,text.substring(5).trim()).message;
        }
        if(l.startsWith("app open ")){
            return AppLauncher.open(a,text.substring(9).trim()).message;
        }
        if(l.startsWith("search ")||l.startsWith("google ")){
            String q=text.substring(text.indexOf(' ')+1).trim();
            if(q.isEmpty())return "Search text missing.";
            try{
                String encoded=URLEncoder.encode(q, StandardCharsets.UTF_8.name());
                a.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q="+encoded)));
                return "Searching for: "+q;
            }catch(Exception e){return "Search could not open: "+safe(e);}
        }
        if(l.startsWith("calculate ")||l.startsWith("calc ")){
            String q=text.substring(text.indexOf(' ')+1).trim();
            try{
                double v=CalculatorEngine.evaluate(q);
                long whole=(long)v;
                return q+" = "+(v==whole?String.valueOf(whole):String.valueOf(v));
            }catch(Exception e){return "Calculation error: "+safe(e);}
        }

        if(l.equals("health")||l.equals("phone health")||l.equals("anamika health"))
            return HealthMonitor.report(a);

        if(l.equals("last crash")||l.equals("crash report"))
            return CrashJournal.read(a);

        if(l.equals("wake on")||l.equals("wake enable")){
            WakeService.enable(a);
            return "Wake listener enabled. Android/recognizer restrictions can still pause background recognition.";
        }
        if(l.equals("wake off")||l.equals("wake disable")){
            WakeService.disable(a);
            return "Wake listener disabled.";
        }

        if(l.equals("upgrade status")||l.equals("self upgrade status"))
            return UpgradeCoordinator.status(a);

        if(l.startsWith("prepare upgrade")||l.startsWith("prepare self upgrade")){
            return UpgradeCoordinator.prepare(a,text);
        }

        if(l.equals("install update")||l.equals("self update")){
            a.startActivity(new Intent(a,SelfUpdateActivity.class));
            return "Opening verified self-update installer.";
        }

        if(l.equals("device info")){
            return "Android "+Build.VERSION.RELEASE+" (API "+Build.VERSION.SDK_INT+")\nDevice: "+
                    Build.MANUFACTURER+" "+Build.MODEL+"\nABI: "+String.join(", ",Build.SUPPORTED_ABIS);
        }

        return "Ye command V13 ke deterministic core me abhi mapped nahi hai. “functions” bolo. AI/reasoning layer ko core phone functions se alag rebuild kiya ja raha hai taaki ek AI failure se poori app band na ho.";
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
