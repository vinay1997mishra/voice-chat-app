package com.anamika.ai;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.memory.MemoryStore;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.voice.VoiceController;
import com.anamika.ai.voice.WakeService;

public final class MainActivity extends Activity implements VoiceController.Listener {
    private static final int REQ_AUDIO=131;
    private static final int REQ_NOTIFY=132;

    private LinearLayout root;
    private TextView status;
    private TextView transcript;
    private EditText input;
    private VoiceController voice;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        CrashJournal.install(this);
        RuntimeWatchdog.recordLaunch(this);
        voice=new VoiceController(this,this);
        showEntry();
        getWindow().getDecorView().postDelayed(()->RuntimeWatchdog.markHealthy(this),4000);
        handleWakeCommand();
    }

    @Override protected void onNewIntent(android.content.Intent intent){
        super.onNewIntent(intent);
        setIntent(intent);
        handleWakeCommand();
    }

    private void showEntry(){
        if(OwnerStore.isTrusted(this)) showAssistant();
        else showOwnerGate();
    }

    private void showOwnerGate(){
        root=baseRoot();
        root.addView(title("Anamika AI 13"));

        TextView info=new TextView(this);
        info.setText(OwnerStore.hasPin(this)
                ?"Owner PIN enter karke unlock karein."
                :"First launch: 4–12 digit Owner PIN set karein.");
        info.setTextSize(16);
        root.addView(info);

        EditText pin=new EditText(this);
        pin.setHint("Owner PIN");
        pin.setInputType(InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        root.addView(pin);

        Button go=new Button(this);
        go.setText(OwnerStore.hasPin(this)?"Unlock Owner":"Set Owner PIN");
        root.addView(go);
        go.setOnClickListener(v->{
            String p=pin.getText().toString().trim();
            try{
                boolean ok;
                if(OwnerStore.hasPin(this)) ok=OwnerStore.verify(this,p);
                else{OwnerStore.setPin(this,p);ok=true;}
                if(ok){
                    Toast.makeText(this,"Owner verified",Toast.LENGTH_SHORT).show();
                    showAssistant();
                    maybeOfferComponentSetup();
                }
                else Toast.makeText(this,"Wrong Owner PIN",Toast.LENGTH_LONG).show();
            }catch(Exception e){
                Toast.makeText(this,e.getMessage(),Toast.LENGTH_LONG).show();
            }
        });
        setContentView(root);
    }

    private void showAssistant(){
        root=baseRoot();
        root.addView(title("Anamika AI 13"));

        status=new TextView(this);
        status.setText(RuntimeWatchdog.recoverySuggested(this)
                ?"Owner verified • recovery check recommended"
                :"Owner verified • clean V13 core");
        status.setTextSize(14);
        root.addView(status);

        transcript=new TextView(this);
        transcript.setText("Anamika: Ji, boliye.\n");
        transcript.setTextIsSelectable(true);
        transcript.setTextSize(16);
        transcript.setPadding(0,dp(10),0,dp(10));
        ScrollView logScroll=new ScrollView(this);
        logScroll.addView(transcript);
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,0,1);
        root.addView(logScroll,lp);

        input=new EditText(this);
        input.setHint("Type command…");
        input.setSingleLine(false);
        input.setMinLines(1);
        input.setMaxLines(4);
        root.addView(input);

        LinearLayout row=new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        Button send=button("Send");
        Button mic=button("Mic");
        Button wake=button(WakeService.isEnabled(this)?"Wake ON":"Wake OFF");
        row.addView(send,new LinearLayout.LayoutParams(0,-2,1));
        row.addView(mic,new LinearLayout.LayoutParams(0,-2,1));
        row.addView(wake,new LinearLayout.LayoutParams(0,-2,1));
        root.addView(row);

        LinearLayout row2=new LinearLayout(this);
        row2.setOrientation(LinearLayout.HORIZONTAL);
        Button functions=button("Functions");
        Button components=button("Components");
        Button update=button("Self Update");
        Button lock=button("Lock");
        row2.addView(functions,new LinearLayout.LayoutParams(0,-2,1));
        row2.addView(components,new LinearLayout.LayoutParams(0,-2,1));
        row2.addView(update,new LinearLayout.LayoutParams(0,-2,1));
        row2.addView(lock,new LinearLayout.LayoutParams(0,-2,1));
        root.addView(row2);

        send.setOnClickListener(v->runInput());
        mic.setOnClickListener(v->startVoice());
        wake.setOnClickListener(v->{
            if(WakeService.isEnabled(this)){
                WakeService.disable(this);
                wake.setText("Wake OFF");
                append("Anamika","Wake listener disabled.");
            }else{
                if(Build.VERSION.SDK_INT>=23 && !AndroidCompat.hasPermission(this,Manifest.permission.RECORD_AUDIO)){
                    requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO);
                    return;
                }
                requestNotificationPermission();
                WakeService.enable(this);
                wake.setText("Wake ON");
                append("Anamika","Wake listener enabled.");
            }
        });
        functions.setOnClickListener(v->runCommand("functions"));
        components.setOnClickListener(v->startActivity(new Intent(this,ComponentPacksActivity.class)));
        update.setOnClickListener(v->runCommand("self update"));
        lock.setOnClickListener(v->{OwnerStore.forgetTrust(this);WakeService.disable(this);showOwnerGate();});

        setContentView(root);
        bootstrapBundledToolchain();
        getWindow().getDecorView().postDelayed(this::maybeOfferComponentSetup,500);
    }

    private void bootstrapBundledToolchain(){
        if(!OwnerStore.isTrusted(this)||ComponentPackManager.toolchainInstalled(this)
                ||!ComponentPackManager.bundledToolchainAvailable(this))return;
        if(status!=null)status.setText("Owner verified • bundled toolchain setup…");
        final Context app=getApplicationContext();
        new Thread(()->{
            ComponentPackManager.Result r=ComponentPackManager.installBundledToolchainIfNeeded(app);
            runOnUiThread(()->{
                if(status!=null)status.setText(r.ok
                        ?"Owner verified • bundled toolchain ready"
                        :"Owner verified • toolchain setup needs attention");
                if(transcript!=null)append("Anamika",r.message);
            });
        },"anamika-toolchain-bootstrap").start();
    }

    private void maybeOfferComponentSetup(){
        if(!OwnerStore.isTrusted(this))return;
        if(ComponentPackManager.bundledToolchainAvailable(this) && !ComponentPackManager.toolchainInstalled(this))
            return; // bootstrap thread is installing the signed-in APK toolchain.
        if(!ComponentPackManager.needsSetup(this))return;
        android.content.SharedPreferences p=getSharedPreferences("anamika13_component_onboarding",MODE_PRIVATE);
        if(p.getBoolean("shown_this_install",false))return;
        p.edit().putBoolean("shown_this_install",true).apply();

        new AlertDialog.Builder(this)
                .setTitle("Offline Components Setup")
                .setMessage("Offline coding brain aur Android build toolchain abhi install nahi hain. Inhe Anamika ke andar download/import karke private storage me rakhna hoga. Install hone ke baad ye offline use honge.")
                .setPositiveButton("Setup Now",(d,w)->startActivity(new Intent(this,ComponentPacksActivity.class)))
                .setNegativeButton("Later",null)
                .show();
    }

    private void startVoice(){
        if(Build.VERSION.SDK_INT>=23 && !AndroidCompat.hasPermission(this,Manifest.permission.RECORD_AUDIO)){
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO);
            return;
        }
        voice.listen();
    }

    private void requestNotificationPermission(){
        if(Build.VERSION.SDK_INT>=33 &&
                !AndroidCompat.hasPermission(this,Manifest.permission.POST_NOTIFICATIONS))
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},REQ_NOTIFY);
    }

    @Override public void onRequestPermissionsResult(int requestCode,String[] permissions,int[] results){
        super.onRequestPermissionsResult(requestCode,permissions,results);
        if(requestCode==REQ_AUDIO && results.length>0 &&
                results[0]==PackageManager.PERMISSION_GRANTED) voice.listen();
    }

    private void runInput(){
        String text=input.getText().toString().trim();
        if(text.isEmpty())return;
        input.setText("");
        runCommand(text);
    }

    private void runCommand(String text){
        append("You",text);
        MemoryStore.appendTurn(this,"owner",text);

        String fast=CommandRouter.runFast(this,text);
        if(fast!=null){
            finishReply(fast);
            return;
        }

        append("Anamika","Offline brain se instruction samajh rahi hu…");
        if(status!=null)status.setText("Offline brain planning…");
        final Context appContext=getApplicationContext();
        new Thread(()->{
            BrainCommandEngine.Plan plan=BrainCommandEngine.plan(appContext,text);
            if(BrainCommandEngine.requiresBackground(plan)){
                String reply=BrainCommandEngine.execute(this,plan);
                runOnUiThread(()->{
                    finishReply(reply);
                    if(status!=null)status.setText("Owner verified • brain command complete");
                });
            }else{
                runOnUiThread(()->{
                    String reply=BrainCommandEngine.execute(this,plan);
                    finishReply(reply);
                    if(status!=null)status.setText("Owner verified • brain command complete");
                });
            }
        },"anamika-brain-command").start();
    }

    private void finishReply(String reply){
        append("Anamika",reply);
        MemoryStore.appendTurn(this,"anamika",reply);
        voice.speak(reply);
    }

    private void append(String who,String text){
        if(transcript==null)return;
        transcript.append("\n"+who+": "+text+"\n");
    }

    private void handleWakeCommand(){
        if(!OwnerStore.isTrusted(this))return;
        String cmd=getIntent()==null?null:getIntent().getStringExtra("wake_command");
        if(getIntent()!=null)getIntent().removeExtra("wake_command");
        if(cmd==null)return;
        if(transcript==null)showAssistant();
        if(cmd.trim().isEmpty()){
            append("Anamika","Ji, boliye.");
            voice.speak("Ji, boliye.");
        }else runCommand(cmd.trim());
    }

    private LinearLayout baseRoot(){
        LinearLayout r=new LinearLayout(this);
        r.setOrientation(LinearLayout.VERTICAL);
        r.setPadding(dp(16),dp(18),dp(16),dp(16));
        r.setGravity(Gravity.TOP);
        return r;
    }

    private TextView title(String text){
        TextView t=new TextView(this);
        t.setText(text);
        t.setTextSize(25);
        t.setPadding(0,0,0,dp(14));
        return t;
    }

    private Button button(String text){
        Button b=new Button(this);
        b.setText(text);
        return b;
    }

    private int dp(int v){
        return (int)(v*getResources().getDisplayMetrics().density+0.5f);
    }

    @Override public void onVoiceText(String text){
        runOnUiThread(()->runCommand(text));
    }

    @Override public void onVoiceState(String state){
        runOnUiThread(()->{if(status!=null)status.setText(state);});
    }

    @Override protected void onDestroy(){
        if(voice!=null)voice.close();
        super.onDestroy();
    }
}
