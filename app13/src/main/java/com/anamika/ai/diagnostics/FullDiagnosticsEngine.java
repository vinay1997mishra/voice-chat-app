package com.anamika.ai.diagnostics;

import android.Manifest;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.StatFs;
import android.provider.Settings;
import android.speech.SpeechRecognizer;

import com.anamika.ai.MainActivity;
import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.developer.OfflineCodingBrain;
import com.anamika.ai.developer.BrainRuntimePaths;
import com.anamika.ai.files.LocalVault;
import com.anamika.ai.language.LanguageCommandInterpreter;
import com.anamika.ai.messaging.MessageCommandParser;
import com.anamika.ai.messaging.MessagingAutomationEngine;
import com.anamika.ai.phone.AppLauncher;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.AppPluginRegistry;
import com.anamika.ai.runtime.LocalProcessRunner;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.LocalBuildEngine;
import com.anamika.ai.upgrade.RollbackManager;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.SignerProvisionActivity;
import com.anamika.ai.upgrade.SignerVault;
import com.anamika.ai.upgrade.SourceVault;
import com.anamika.ai.voice.WakeService;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * Full V13 diagnostics inventory.
 *
 * Every currently exposed function gets an explicit result. Functions that cannot be
 * safely proven without a real external side effect are never reported PASS merely
 * because a permission exists; they are marked LIVE_TEST_REQUIRED.
 */
public final class FullDiagnosticsEngine {
    public enum State { PASS, FAIL, LIVE_TEST_REQUIRED, NOT_INSTALLED }

    public static final class Check {
        public final String id;
        public final String area;
        public final State state;
        public final String detail;

        Check(String id,String area,State state,String detail){
            this.id=id;this.area=area;this.state=state;this.detail=detail;
        }

        JSONObject json() throws Exception {
            return new JSONObject()
                    .put("id",id)
                    .put("area",area)
                    .put("state",state.name())
                    .put("detail",detail);
        }
    }

    public static final class Result {
        public final long timeMs;
        public final String versionName;
        public final long versionCode;
        public final List<Check> checks;

        Result(long timeMs,String versionName,long versionCode,List<Check> checks){
            this.timeMs=timeMs;this.versionName=versionName;this.versionCode=versionCode;this.checks=checks;
        }

        public int count(State s){int n=0;for(Check c:checks)if(c.state==s)n++;return n;}
        public boolean allAutomaticallyVerified(){return count(State.FAIL)==0&&count(State.LIVE_TEST_REQUIRED)==0&&count(State.NOT_INSTALLED)==0;}

        public String summary(){
            StringBuilder b=new StringBuilder();
            b.append("Anamika • Full Functional Diagnostics")
                    .append("\nPASS: ").append(count(State.PASS))
                    .append(" | FAIL: ").append(count(State.FAIL))
                    .append(" | LIVE TEST: ").append(count(State.LIVE_TEST_REQUIRED))
                    .append(" | NOT INSTALLED: ").append(count(State.NOT_INSTALLED));
            for(Check c:checks){
                b.append("\n").append(c.state.name())
                        .append(" • ").append(c.area).append(" • ").append(c.id)
                        .append(" • ").append(c.detail);
            }
            if(count(State.LIVE_TEST_REQUIRED)>0)
                b.append("\n\nLIVE TEST ka matlab function ko jhootha PASS nahi diya gaya; real phone action/other app behavior ke bina end-to-end proof possible nahi tha.");
            return b.toString();
        }

        public JSONObject json() throws Exception {
            JSONArray a=new JSONArray();
            for(Check c:checks)a.put(c.json());
            return new JSONObject()
                    .put("schema","anamika13-full-functional-diagnostics-v2")
                    .put("time_ms",timeMs)
                    .put("package","com.anamika.ai13")
                    .put("version_name",versionName)
                    .put("version_code",versionCode)
                    .put("android_api",Build.VERSION.SDK_INT)
                    .put("android_release",Build.VERSION.RELEASE)
                    .put("manufacturer",Build.MANUFACTURER)
                    .put("model",Build.MODEL)
                    .put("abis",new JSONArray(Build.SUPPORTED_ABIS))
                    .put("pass",count(State.PASS))
                    .put("fail",count(State.FAIL))
                    .put("live_test_required",count(State.LIVE_TEST_REQUIRED))
                    .put("not_installed",count(State.NOT_INSTALLED))
                    .put("all_automatically_verified",allAutomaticallyVerified())
                    .put("checks",a);
        }
    }

    private FullDiagnosticsEngine(){}

    public static Result run(Context c){
        List<Check> x=new ArrayList<>();
        long now=System.currentTimeMillis();
        String versionName="unknown";
        long versionCode=-1;

        try{
            PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
            versionName=p.versionName==null?"unknown":p.versionName;
            versionCode=Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
            add(x,"package_identity","core",eq("com.anamika.ai13",c.getPackageName()),c.getPackageName());
        }catch(Exception e){add(x,"package_identity","core",false,safe(e));}

        add(x,"owner_pin","security",OwnerStore.hasPin(c),OwnerStore.hasPin(c)?"configured":"missing");
        add(x,"owner_trust","security",OwnerStore.isTrusted(c),OwnerStore.isTrusted(c)?"trusted":"locked");

        testLanguage(x);
        testMessagingParser(x);
        testCalculator(x);
        testStorage(c,x);
        testVault(c,x);
        testSelfSource(c,x);
        testAppDiscovery(c,x);
        testAndroidIntents(c,x);
        testActivities(c,x);
        testVoice(c,x);
        testAccessibility(c,x);
        testComponents(c,x);
        testOfflineBrain(c,x);
        testLocalBuilder(c,x);
        testSigner(c,x);
        testRecovery(c,x);
        testInstaller(c,x);

        String msg=MessagingAutomationEngine.status(c);
        state(x,"messaging_end_to_end","messaging",
                AppAutomationAccessibilityService.isConnected()?State.LIVE_TEST_REQUIRED:State.FAIL,
                AppAutomationAccessibilityService.isConnected()
                        ?"Accessibility connected; actual recipient/chat/type/send must be tested against a real enabled chat app."
                        :"Accessibility service is not connected.");

        state(x,"wake_phrase_end_to_end","voice",
                WakeService.isRunning()?State.LIVE_TEST_REQUIRED:
                        (WakeService.isEnabled(c)?State.FAIL:State.NOT_INSTALLED),
                WakeService.isRunning()
                        ?"Wake service is actually running; real phrase detection still needs a live microphone/background test."
                        :(WakeService.isEnabled(c)?"Wake setting is enabled but service is not running. Open Anamika and enable wake while visible.":"Wake service disabled."));

        state(x,"app_ui_tap_type_back_end_to_end","automation",
                AppAutomationAccessibilityService.isConnected()?State.LIVE_TEST_REQUIRED:State.FAIL,
                AppAutomationAccessibilityService.isConnected()
                        ?"Bridge connected; real target-app controls require a live UI test."
                        :"Accessibility service is not connected.");

        state(x,"blueprint_capture_end_to_end","automation",
                AppAutomationAccessibilityService.isConnected()?State.LIVE_TEST_REQUIRED:State.FAIL,
                AppAutomationAccessibilityService.isConnected()
                        ?"Capture engine available; needs owner-opened target screen for real node capture."
                        :"Accessibility service is not connected.");

        state(x,"research_capture_end_to_end","research",
                AppAutomationAccessibilityService.isConnected()?State.LIVE_TEST_REQUIRED:State.FAIL,
                AppAutomationAccessibilityService.isConnected()
                        ?"Research recorder available; needs real visible screen text to prove capture."
                        :"Accessibility service is not connected.");

        state(x,"phone_settings_launch","phone",State.LIVE_TEST_REQUIRED,
                "Intent support checked; opening Settings changes foreground UI, so end-to-end launch needs live confirmation.");
        state(x,"web_search_launch","phone",State.LIVE_TEST_REQUIRED,
                "Browser intent support checked; real browser/search result needs live confirmation.");
        state(x,"dialer_launch","phone",State.LIVE_TEST_REQUIRED,
                "Dial intent support checked; real dialer UI needs live confirmation.");
        state(x,"installed_app_launch","phone",State.LIVE_TEST_REQUIRED,
                "App discovery works; opening another app needs live confirmation.");

        File crash=CrashJournal.file(c);
        state(x,"crash_journal","runtime",State.PASS,
                crash.isFile()?"last crash record present ("+crash.length()+" bytes)":"journal available; no crash record");
        state(x,"runtime_watchdog","runtime",State.PASS,compact(RuntimeWatchdog.status(c)));
        state(x,"messaging_engine_status","messaging",State.PASS,compact(msg));

        return new Result(now,versionName,versionCode,x);
    }

    private static void testLanguage(List<Check>x){
        try{
            boolean ok=
                    LanguageCommandInterpreter.normalize("WhatsApp kholo").toLowerCase().startsWith("open ")&&
                    LanguageCommandInterpreter.normalize("Google pe weather search karo").toLowerCase().startsWith("search ")&&
                    LanguageCommandInterpreter.normalize("सेटिंग्स खोलो").equals("settings")&&
                    LanguageCommandInterpreter.normalize("saare function check karo").equals("run self test");
            add(x,"hindi_hinglish_english_commands","language",ok,ok?"sample intents normalized correctly":"one or more language samples failed");
        }catch(Exception e){add(x,"hindi_hinglish_english_commands","language",false,safe(e));}
    }

    private static void testMessagingParser(List<Check>x){
        try{
            boolean ok=MessageCommandParser.parse("WhatsApp me Rahul ko Hello bhejo")!=null&&
                    MessageCommandParser.parse("Send message on WhatsApp to Rahul: Hello")!=null&&
                    MessageCommandParser.parse("WhatsApp में Rahul को Hello भेजो")!=null;
            add(x,"message_command_parser","messaging",ok,ok?"English/Hinglish/Hindi samples parsed":"parser sample failed");
        }catch(Exception e){add(x,"message_command_parser","messaging",false,safe(e));}
    }

    private static void testCalculator(List<Check>x){
        try{
            double v=CalculatorEngine.evaluate("2+3*4");
            add(x,"calculator","core",Math.abs(v-14d)<0.000001,"2+3*4="+v);
        }catch(Exception e){add(x,"calculator","core",false,safe(e));}
    }

    private static void testStorage(Context c,List<Check>x){
        try{
            File dir=new File(c.getFilesDir(),"diagnostics");
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("cannot create diagnostics dir");
            File f=new File(dir,"rw_probe.tmp");
            byte[] expected="anamika13-probe".getBytes(StandardCharsets.UTF_8);
            try(FileOutputStream out=new FileOutputStream(f,false)){out.write(expected);out.getFD().sync();}
            byte[] got=AndroidCompat.readAllBytes(f);
            boolean ok=java.util.Arrays.equals(expected,got);
            f.delete();
            add(x,"private_storage_read_write","storage",ok,ok?"round-trip verified":"round-trip mismatch");
        }catch(Exception e){add(x,"private_storage_read_write","storage",false,safe(e));}

        try{
            long free=new StatFs(c.getFilesDir().getAbsolutePath()).getAvailableBytes();
            add(x,"storage_capacity","storage",free>=100L*1024L*1024L,(free/1024/1024)+" MB free");
        }catch(Exception e){add(x,"storage_capacity","storage",false,safe(e));}
    }

    private static void testVault(Context c,List<Check>x){
        File f=new File(LocalVault.root(c),"diagnostic_probe.txt");
        try{
            String r=LocalVault.saveText(c,"diagnostic_probe.txt","probe");
            boolean ok=f.isFile()&&"probe".equals(new String(AndroidCompat.readAllBytes(f),StandardCharsets.UTF_8));
            f.delete();
            add(x,"private_vault","storage",ok,ok?"save/read/delete verified":r);
        }catch(Exception e){f.delete();add(x,"private_vault","storage",false,safe(e));}
    }

    private static void testSelfSource(Context c,List<Check>x){
        try{
            String[] a=c.getAssets().list("self_source");
            boolean bundled=a!=null&&a.length>0;
            add(x,"self_source_asset","self_upgrade",bundled,bundled?"bundled":"missing");
            if(bundled){
                File base=SourceVault.ensureBaseline(c);
                add(x,"self_source_extract","self_upgrade",base.isDirectory(),"baseline="+base.getAbsolutePath());
            }
        }catch(Exception e){add(x,"self_source_extract","self_upgrade",false,safe(e));}
    }

    private static void testAppDiscovery(Context c,List<Check>x){
        try{
            AppLauncher.AppRef self=AppLauncher.resolve(c,"Anamika");
            add(x,"installed_app_discovery","phone",self!=null,self==null?"self not resolvable":self.label+" / "+self.packageName);
        }catch(Exception e){add(x,"installed_app_discovery","phone",false,safe(e));}
    }

    private static void testAndroidIntents(Context c,List<Check>x){
        PackageManager pm=c.getPackageManager();
        add(x,"settings_intent","phone",resolves(pm,new Intent(Settings.ACTION_SETTINGS)),"Android Settings intent");
        add(x,"web_intent","phone",resolves(pm,new Intent(Intent.ACTION_VIEW,Uri.parse("https://example.com"))),"HTTPS VIEW intent");
        add(x,"dial_intent","phone",resolves(pm,new Intent(Intent.ACTION_DIAL,Uri.parse("tel:123"))),"DIAL intent");
    }

    private static void testActivities(Context c,List<Check>x){
        add(x,"main_activity","ui",componentExists(c,MainActivity.class),"MainActivity declared");
        add(x,"component_packs_ui","ui",componentExists(c,ComponentPacksActivity.class),"ComponentPacksActivity declared");
        add(x,"self_update_ui","ui",componentExists(c,SelfUpdateActivity.class),"SelfUpdateActivity declared");
        add(x,"signer_setup_ui","ui",componentExists(c,SignerProvisionActivity.class),"SignerProvisionActivity declared");
    }

    private static void testVoice(Context c,List<Check>x){
        boolean speech=SpeechRecognizer.isRecognitionAvailable(c);
        add(x,"speech_recognizer","voice",speech,speech?"available":"unavailable");
        boolean mic=AndroidCompat.hasPermission(c,Manifest.permission.RECORD_AUDIO);
        add(x,"microphone_permission","voice",mic,mic?"granted":"not granted");
        State wakeState=!WakeService.isEnabled(c)?State.NOT_INSTALLED:
                (WakeService.isRunning()?State.PASS:State.FAIL);
        state(x,"wake_service_setting","voice",wakeState,
                !WakeService.isEnabled(c)?"disabled":
                        (WakeService.isRunning()?"enabled + service running":"enabled setting, service not running"));
    }

    private static void testAccessibility(Context c,List<Check>x){
        boolean connected=AppAutomationAccessibilityService.isConnected();
        add(x,"accessibility_bridge","automation",connected,connected?"connected":"not connected");
        try{
            int n=AppPluginRegistry.enabled(c).size();
            state(x,"plugin_registry","automation",State.PASS,n+" enabled app(s)");
        }catch(Exception e){state(x,"plugin_registry","automation",State.FAIL,safe(e));}
    }

    private static void testComponents(Context c,List<Check>x){
        state(x,"brain_component_pack","components",
                ComponentPackManager.brainInstalled(c)?State.PASS:State.NOT_INSTALLED,
                ComponentPackManager.brainInstalled(c)?"installed":"missing");
        state(x,"toolchain_component_pack","components",
                ComponentPackManager.toolchainInstalled(c)?State.PASS:State.NOT_INSTALLED,
                ComponentPackManager.toolchainInstalled(c)?"installed":"missing");
    }

    private static void testOfflineBrain(Context c,List<Check>x){
        File root=BrainRuntimePaths.root(c);
        File cli=BrainRuntimePaths.embeddedCli(c);
        File model=BrainRuntimePaths.model(c);
        if(!BrainRuntimePaths.runtimeReady(c)){
            state(x,"offline_coding_runtime","offline_ai",State.NOT_INSTALLED,
                    "APK-native llama runtime or runtime metadata/schema missing");
            state(x,"offline_code_repair_end_to_end","offline_ai",State.NOT_INSTALLED,
                    "Offline runtime setup is incomplete.");
            return;
        }
        List<String> cmd=new ArrayList<>();
        cmd.add(cli.getAbsolutePath());cmd.add("--version");
        HashMap<String,String> env=new HashMap<>();
        env.put("ANAMIKA_OFFLINE","1");
        env.put("HOME",root.getAbsolutePath());
        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        if(nativeDir!=null&&!nativeDir.trim().isEmpty())env.put("LD_LIBRARY_PATH",nativeDir);
        LocalProcessRunner.Result r=LocalProcessRunner.run(cmd,root,env,120000);
        state(x,"offline_coding_runtime","offline_ai",r.ok()?State.PASS:State.FAIL,
                r.ok()?"APK-native llama runtime version check passed":"exit="+r.exitCode+(r.timedOut?" timeout":"")+" "+compact(r.stderr));
        state(x,"offline_code_repair_end_to_end","offline_ai",
                !r.ok()?State.FAIL:(model.isFile()?State.LIVE_TEST_REQUIRED:State.NOT_INSTALLED),
                !r.ok()?"runtime self-test failed":
                        (model.isFile()?"Runtime is executable; a real repair still requires a disposable workspace test.":"GGUF model is not installed."));
    }

    private static void testLocalBuilder(Context c,List<Check>x){
        LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
        if(!ComponentPackManager.toolchainInstalled(c)){
            state(x,"local_builder_runtime","self_upgrade",State.NOT_INSTALLED,cap.detail);
            state(x,"source_to_signed_apk_end_to_end","self_upgrade",State.NOT_INSTALLED,"Toolchain is not installed.");
            return;
        }
        File root=new File(c.getFilesDir(),"v13_toolchain");
        File builder=new File(root,"bin/anamika-builder");
        List<String> syntax=new ArrayList<>();
        syntax.add("/system/bin/sh");syntax.add("-n");syntax.add(builder.getAbsolutePath());
        LocalProcessRunner.Result shell=LocalProcessRunner.run(syntax,root,null,30000);

        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        File aapt2=new File(nativeDir==null?"":nativeDir,"libanamika_aapt2.so");
        List<String> aaptCmd=new ArrayList<>();
        aaptCmd.add(aapt2.getAbsolutePath());aaptCmd.add("version");
        LocalProcessRunner.Result aapt=null;
        boolean aaptOk=false;
        String aaptError="";
        if(aapt2.isFile()){
            aapt=LocalProcessRunner.run(aaptCmd,root,null,30000);
            aaptOk=aapt.ok();
            aaptError=aapt.stderr;
        }else{
            aaptError="embedded AAPT2 missing";
        }

        boolean runtimeOk=shell.ok()&&aaptOk;
        int aaptExit=aapt==null?-1:aapt.exitCode;
        state(x,"local_builder_runtime","self_upgrade",runtimeOk?State.PASS:State.FAIL,
                runtimeOk?"builder shell syntax + APK-native AAPT2 execution passed":
                        "shell="+shell.exitCode+" aapt2="+aaptExit+" "+compact(shell.stderr+" "+aaptError));

        State e2e=!runtimeOk?State.FAIL:
                (cap.ready?State.LIVE_TEST_REQUIRED:
                        (SignerVault.ready(c)?State.FAIL:State.NOT_INSTALLED));
        state(x,"source_to_signed_apk_end_to_end","self_upgrade",e2e,
                cap.ready
                        ?"Builder, AAPT2 and signer are ready; complete proof requires a real disposable source→signed-APK build."
                        :cap.detail);
    }

    private static void testSigner(Context c,List<Check>x){
        boolean ready=SignerVault.ready(c);
        state(x,"release_signer_vault","security",ready?State.PASS:State.NOT_INSTALLED,compact(SignerVault.status(c)));
    }

    private static void testRecovery(Context c,List<Check>x){
        try{
            boolean ok=RollbackManager.checkpointReady(c);
            state(x,"recovery_checkpoint","rollback",ok?State.PASS:State.NOT_INSTALLED,
                    ok?compact(RollbackManager.status(c)):"No immutable recovery checkpoint yet.");
            state(x,"rollback_recovery_install_end_to_end","rollback",
                    ok?State.LIVE_TEST_REQUIRED:State.NOT_INSTALLED,
                    ok?"Exact checkpoint source is available; real recovery APK build/install still needs a deliberate owner-triggered recovery test.":"Create a checkpoint before recovery can be tested.");
        }catch(Exception e){add(x,"recovery_checkpoint","rollback",false,safe(e));}
    }

    private static void testInstaller(Context c,List<Check>x){
        boolean can=AndroidCompat.canRequestPackageInstalls(c);
        state(x,"unknown_app_install_permission","self_update",can?State.PASS:State.FAIL,can?"allowed":"not allowed");
        state(x,"verified_update_install_end_to_end","self_update",
                can?State.LIVE_TEST_REQUIRED:State.FAIL,
                can?"Installer permission ready; actual install would replace current app and therefore requires owner/system confirmation.":"install permission missing");
    }

    private static boolean componentExists(Context c,Class<?> cls){
        try{
            c.getPackageManager().getActivityInfo(new ComponentName(c,cls),0);
            return true;
        }catch(Exception e){return false;}
    }

    private static boolean resolves(PackageManager pm,Intent i){
        return i.resolveActivity(pm)!=null;
    }

    private static void add(List<Check>x,String id,String area,boolean pass,String detail){
        state(x,id,area,pass?State.PASS:State.FAIL,detail);
    }
    private static void state(List<Check>x,String id,String area,State s,String detail){
        x.add(new Check(id,area,s,detail==null?"":detail));
    }
    private static boolean eq(String a,String b){return a==null?b==null:a.equals(b);}
    private static String compact(String s){return s==null?"":s.replace('\n',' ').replaceAll("\\s+"," ").trim();}
    private static String safe(Exception e){String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;}
}
