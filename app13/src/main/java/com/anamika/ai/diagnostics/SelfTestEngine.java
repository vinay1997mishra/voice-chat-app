package com.anamika.ai.diagnostics;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.StatFs;
import android.speech.SpeechRecognizer;

import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.messaging.MessagingAutomationEngine;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.AppPluginRegistry;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.LocalBuildEngine;
import com.anamika.ai.voice.WakeService;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Non-destructive V13 runtime self-test.
 * It checks capabilities/status only; it never sends messages, taps external apps,
 * changes settings, installs APKs or uploads data.
 */
public final class SelfTestEngine {
    public static final class Item {
        public final String id;
        public final boolean pass;
        public final boolean required;
        public final String detail;

        Item(String id,boolean pass,boolean required,String detail){
            this.id=id;
            this.pass=pass;
            this.required=required;
            this.detail=detail;
        }
    }

    public static final class Result {
        public final long timeMs;
        public final String versionName;
        public final long versionCode;
        public final List<Item> items;

        Result(long timeMs,String versionName,long versionCode,List<Item> items){
            this.timeMs=timeMs;
            this.versionName=versionName;
            this.versionCode=versionCode;
            this.items=items;
        }

        public int passed(){
            int n=0;
            for(Item i:items)if(i.pass)n++;
            return n;
        }

        public int failedRequired(){
            int n=0;
            for(Item i:items)if(i.required&&!i.pass)n++;
            return n;
        }

        public String summary(){
            StringBuilder b=new StringBuilder();
            b.append("Anamika 13 Self-Test\n")
                    .append("Passed: ").append(passed()).append("/").append(items.size())
                    .append("\nRequired failures: ").append(failedRequired());
            for(Item i:items){
                b.append("\n").append(i.pass?"PASS":"FAIL")
                        .append(" • ").append(i.id)
                        .append(" • ").append(i.detail);
            }
            return b.toString();
        }

        public JSONObject json() throws Exception {
            JSONArray arr=new JSONArray();
            for(Item i:items){
                arr.put(new JSONObject()
                        .put("id",i.id)
                        .put("pass",i.pass)
                        .put("required",i.required)
                        .put("detail",i.detail));
            }
            return new JSONObject()
                    .put("schema","anamika13-diagnostics-v1")
                    .put("time_ms",timeMs)
                    .put("package","com.anamika.ai13")
                    .put("version_name",versionName)
                    .put("version_code",versionCode)
                    .put("android_api",Build.VERSION.SDK_INT)
                    .put("android_release",Build.VERSION.RELEASE)
                    .put("manufacturer",Build.MANUFACTURER)
                    .put("model",Build.MODEL)
                    .put("abis",new JSONArray(Build.SUPPORTED_ABIS))
                    .put("passed",passed())
                    .put("required_failures",failedRequired())
                    .put("tests",arr);
        }
    }

    private SelfTestEngine(){}

    public static Result run(Context c){
        List<Item> items=new ArrayList<>();
        long now=System.currentTimeMillis();
        String versionName="unknown";
        long versionCode=-1L;

        try{
            PackageInfo pi=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
            versionName=pi.versionName==null?"unknown":pi.versionName;
            versionCode=Build.VERSION.SDK_INT>=28?pi.getLongVersionCode():pi.versionCode;
            items.add(item("package_identity","com.anamika.ai13".equals(c.getPackageName()),true,c.getPackageName()));
        }catch(Exception e){
            items.add(item("package_identity",false,true,safe(e)));
        }

        items.add(item("owner_pin",OwnerStore.hasPin(c),true,
                OwnerStore.hasPin(c)?"configured":"not configured"));
        items.add(item("owner_trust",OwnerStore.isTrusted(c),true,
                OwnerStore.isTrusted(c)?"trusted":"locked"));

        boolean speech=SpeechRecognizer.isRecognitionAvailable(c);
        items.add(item("speech_recognizer",speech,true,
                speech?"available":"not available"));

        boolean mic=AndroidCompat.hasPermission(c,Manifest.permission.RECORD_AUDIO);
        items.add(item("microphone_permission",mic,true,
                mic?"granted":"not granted"));

        items.add(item("wake_setting",true,false,
                WakeService.isEnabled(c)?"enabled":"disabled"));

        boolean accessibility=AppAutomationAccessibilityService.isConnected();
        items.add(item("accessibility_bridge",accessibility,false,
                accessibility?"connected":"not connected"));

        int plugins=AppPluginRegistry.enabled(c).size();
        items.add(item("plugin_registry",true,false,
                plugins+" app(s) enabled"));

        String msg=MessagingAutomationEngine.status(c);
        items.add(item("messaging_engine",true,false,compact(msg)));

        try{
            double v=CalculatorEngine.evaluate("2+3*4");
            items.add(item("calculator",Math.abs(v-14.0)<0.000001,true,"2+3*4="+v));
        }catch(Exception e){
            items.add(item("calculator",false,true,safe(e)));
        }

        try{
            File dir=new File(c.getFilesDir(),"diagnostics");
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("cannot create diagnostics directory");
            File probe=new File(dir,"write_probe.tmp");
            try(FileOutputStream out=new FileOutputStream(probe,false)){
                out.write("ok".getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            boolean ok=probe.isFile()&&probe.length()==2;
            if(!probe.delete())probe.deleteOnExit();
            items.add(item("private_storage_write",ok,true,ok?"write/read path healthy":"write verification failed"));
        }catch(Exception e){
            items.add(item("private_storage_write",false,true,safe(e)));
        }

        try{
            StatFs fs=new StatFs(c.getFilesDir().getAbsolutePath());
            long free=fs.getAvailableBytes();
            boolean ok=free>=100L*1024L*1024L;
            items.add(item("storage_free",ok,true,(free/(1024L*1024L))+" MB free"));
        }catch(Exception e){
            items.add(item("storage_free",false,true,safe(e)));
        }

        try{
            String[] source=c.getAssets().list("self_source");
            boolean ok=source!=null&&source.length>0;
            items.add(item("self_source_snapshot",ok,true,
                    ok?"bundled":"missing"));
        }catch(Exception e){
            items.add(item("self_source_snapshot",false,true,safe(e)));
        }

        LocalBuildEngine.Capability build=LocalBuildEngine.capability(c);
        items.add(item("local_apk_builder",build.ready,false,compact(build.detail)));

        boolean installPermission=AndroidCompat.canRequestPackageInstalls(c);
        items.add(item("package_install_permission",installPermission,false,
                installPermission?"allowed":"not allowed yet"));

        boolean launcher=c.getPackageManager().getLaunchIntentForPackage(c.getPackageName())!=null;
        items.add(item("launcher_intent",launcher,true,launcher?"available":"missing"));

        File crash=CrashJournal.file(c);
        items.add(item("last_crash_record",true,false,
                crash.isFile()?"present ("+crash.length()+" bytes)":"none"));

        items.add(item("runtime_watchdog",true,false,compact(RuntimeWatchdog.status(c))));

        return new Result(now,versionName,versionCode,items);
    }

    private static Item item(String id,boolean pass,boolean required,String detail){
        return new Item(id,pass,required,detail==null?"":detail);
    }

    private static String compact(String s){
        if(s==null)return "";
        return s.replace('\n',' ').replaceAll("\\s+"," ").trim();
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
