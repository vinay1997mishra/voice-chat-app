package com.anamika.ai;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.diagnostics.DiagnosticsActivity;
import com.anamika.ai.memory.MemoryStore;
import com.anamika.ai.plugins.PluginManagerActivity;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.SelfUpdateActivity;
import com.anamika.ai.upgrade.SignerProvisionActivity;
import com.anamika.ai.upgrade.SignerVault;
import com.anamika.ai.voice.VoiceController;
import com.anamika.ai.voice.WakeService;

public final class MainActivity extends Activity implements VoiceController.Listener {
    private static final int REQ_AUDIO=131;
    private static final int REQ_NOTIFY=132;

    private static final int BG=Color.rgb(18,18,20);
    private static final int PANEL=Color.rgb(28,28,31);
    private static final int PANEL_2=Color.rgb(38,38,42);
    private static final int TEXT=Color.rgb(244,244,245);
    private static final int MUTED=Color.rgb(170,170,178);

    private TextView status;
    private EditText input;
    private VoiceController voice;
    private LinearLayout messages;
    private ScrollView chatScroll;
    private FrameLayout shell;
    private LinearLayout drawer;
    private View drawerScrim;
    private Button effortButton;
    private boolean startupSetupDialogVisible;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        CrashJournal.install(this);
        RuntimeWatchdog.recordLaunch(this);
        voice=new VoiceController(this,this);
        showEntry();
        getWindow().getDecorView().postDelayed(()->RuntimeWatchdog.markHealthy(this),4000);
        handleWakeCommand();
    }

    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);
        setIntent(intent);
        handleWakeCommand();
    }

    private void showEntry(){
        if(OwnerStore.isTrusted(this))showAssistant();
        else showOwnerGate();
    }

    private void showOwnerGate(){
        LinearLayout root=new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24),dp(36),dp(24),dp(24));
        root.setGravity(Gravity.CENTER_VERTICAL);
        root.setBackgroundColor(BG);

        TextView title=title("Anamika AI 13");
        root.addView(title);

        TextView info=new TextView(this);
        info.setText(OwnerStore.hasPin(this)
                ?"Owner PIN enter karke unlock karein."
                :"First launch: 4–12 digit Owner PIN set karein.");
        info.setTextColor(MUTED);
        info.setTextSize(16);
        info.setPadding(0,0,0,dp(14));
        root.addView(info);

        EditText pin=new EditText(this);
        pin.setHint("Owner PIN");
        pin.setTextColor(TEXT);
        pin.setHintTextColor(MUTED);
        pin.setInputType(InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        pin.setBackground(rounded(PANEL_2,16));
        pin.setPadding(dp(14),dp(12),dp(14),dp(12));
        root.addView(pin,new LinearLayout.LayoutParams(-1,-2));

        Button go=new Button(this);
        go.setText(OwnerStore.hasPin(this)?"Unlock Owner":"Set Owner PIN");
        go.setTextColor(Color.WHITE);
        go.setBackground(rounded(Color.rgb(16,130,104),16));
        LinearLayout.LayoutParams gp=new LinearLayout.LayoutParams(-1,-2);
        gp.topMargin=dp(14);
        root.addView(go,gp);

        go.setOnClickListener(v->{
            String p=pin.getText().toString().trim();
            try{
                boolean ok;
                if(OwnerStore.hasPin(this))ok=OwnerStore.verify(this,p);
                else{OwnerStore.setPin(this,p);ok=true;}
                if(ok){
                    Toast.makeText(this,"Owner verified",Toast.LENGTH_SHORT).show();
                    showAssistant();
                    maybeOfferStartupSetup();
                }else Toast.makeText(this,"Wrong Owner PIN",Toast.LENGTH_LONG).show();
            }catch(Exception e){
                Toast.makeText(this,e.getMessage(),Toast.LENGTH_LONG).show();
            }
        });
        setContentView(root);
    }

    private void showAssistant(){
        shell=new FrameLayout(this);
        shell.setBackgroundColor(BG);

        LinearLayout main=new LinearLayout(this);
        main.setOrientation(LinearLayout.VERTICAL);
        main.setBackgroundColor(BG);
        shell.addView(main,new FrameLayout.LayoutParams(-1,-1));

        LinearLayout top=new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(dp(8),dp(5),dp(8),dp(5));
        top.setBackgroundColor(PANEL);

        ImageButton menu=iconButton(com.anamika.ai.R.drawable.ic_anamika_menu);
        top.addView(menu,new LinearLayout.LayoutParams(dp(46),dp(46)));

        TextView header=new TextView(this);
        header.setText("Anamika");
        header.setTextColor(TEXT);
        header.setTextSize(19);
        header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams hp=new LinearLayout.LayoutParams(0,dp(46),1);
        hp.leftMargin=dp(4);
        top.addView(header,hp);

        effortButton=new Button(this);
        effortButton.setAllCaps(false);
        effortButton.setTextColor(TEXT);
        effortButton.setTextSize(13);
        effortButton.setBackground(rounded(PANEL_2,18));
        effortButton.setPadding(dp(12),0,dp(12),0);
        updateEffortButton();
        top.addView(effortButton,new LinearLayout.LayoutParams(-2,dp(38)));
        main.addView(top,new LinearLayout.LayoutParams(-1,-2));

        status=new TextView(this);
        status.setText(RuntimeWatchdog.recoverySuggested(this)
                ?"Recovery check recommended"
                :"Owner verified • "+BrainEffortStore.describe(this));
        status.setTextColor(MUTED);
        status.setTextSize(12);
        status.setPadding(dp(16),dp(5),dp(16),dp(5));
        status.setBackgroundColor(PANEL);
        main.addView(status,new LinearLayout.LayoutParams(-1,-2));

        messages=new LinearLayout(this);
        messages.setOrientation(LinearLayout.VERTICAL);
        messages.setPadding(dp(12),dp(14),dp(12),dp(14));

        chatScroll=new ScrollView(this);
        chatScroll.setFillViewport(true);
        chatScroll.addView(messages,new ScrollView.LayoutParams(-1,-2));
        main.addView(chatScroll,new LinearLayout.LayoutParams(-1,0,1));

        LinearLayout composer=new LinearLayout(this);
        composer.setOrientation(LinearLayout.HORIZONTAL);
        composer.setGravity(Gravity.BOTTOM|Gravity.CENTER_VERTICAL);
        composer.setPadding(dp(8),dp(8),dp(8),dp(10));
        composer.setBackgroundColor(BG);

        ImageButton mic=iconButton(com.anamika.ai.R.drawable.ic_anamika_mic);
        mic.setBackground(rounded(PANEL_2,22));
        composer.addView(mic,new LinearLayout.LayoutParams(dp(48),dp(48)));

        input=new EditText(this);
        input.setHint("Message Anamika…");
        input.setTextColor(TEXT);
        input.setHintTextColor(MUTED);
        input.setTextSize(16);
        input.setSingleLine(false);
        input.setMinLines(1);
        input.setMaxLines(5);
        input.setPadding(dp(14),dp(10),dp(14),dp(10));
        input.setBackground(rounded(PANEL_2,22));
        LinearLayout.LayoutParams ip=new LinearLayout.LayoutParams(0,-2,1);
        ip.leftMargin=dp(8);
        ip.rightMargin=dp(8);
        composer.addView(input,ip);

        ImageButton send=iconButton(com.anamika.ai.R.drawable.ic_anamika_send);
        send.setBackground(rounded(Color.rgb(16,130,104),22));
        composer.addView(send,new LinearLayout.LayoutParams(dp(48),dp(48)));
        main.addView(composer,new LinearLayout.LayoutParams(-1,-2));

        createDrawer();
        shell.addView(drawerScrim,new FrameLayout.LayoutParams(-1,-1));
        FrameLayout.LayoutParams dp=new FrameLayout.LayoutParams(
                (int)(getResources().getDisplayMetrics().widthPixels*0.88f),-1,Gravity.START);
        shell.addView(drawer,dp);
        drawerScrim.setVisibility(View.GONE);
        drawer.setVisibility(View.GONE);

        menu.setOnClickListener(v->openDrawer());
        effortButton.setOnClickListener(v->showEffortMenu());
        send.setOnClickListener(v->runInput());
        mic.setOnClickListener(v->startVoice());

        setContentView(shell);
        append("Anamika","Ji, boliye.");
        bootstrapBundledToolchain();
        getWindow().getDecorView().postDelayed(this::maybeOfferStartupSetup,700);
    }

    private void createDrawer(){
        drawerScrim=new View(this);
        drawerScrim.setBackgroundColor(Color.argb(150,0,0,0));
        drawerScrim.setOnClickListener(v->closeDrawer());

        drawer=new LinearLayout(this);
        drawer.setOrientation(LinearLayout.VERTICAL);
        drawer.setPadding(dp(12),dp(10),dp(12),dp(12));
        drawer.setBackgroundColor(PANEL);

        LinearLayout head=new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);

        TextView t=new TextView(this);
        t.setText("Anamika Functions");
        t.setTextColor(TEXT);
        t.setTextSize(20);
        t.setPadding(dp(8),0,0,0);
        head.addView(t,new LinearLayout.LayoutParams(0,dp(48),1));

        ImageButton close=iconButton(com.anamika.ai.R.drawable.ic_anamika_close);
        close.setOnClickListener(v->closeDrawer());
        head.addView(close,new LinearLayout.LayoutParams(dp(46),dp(46)));
        drawer.addView(head);

        ScrollView scroll=new ScrollView(this);
        LinearLayout list=new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(0,dp(4),0,dp(20));

        drawerSection(list,"Core");
        drawerActivity(list,"Components",ComponentPacksActivity.class);
        drawerActivity(list,"Plugins / Accessibility",PluginManagerActivity.class);
        drawerActivity(list,"Diagnostics",DiagnosticsActivity.class);
        drawerActivity(list,"Self Update",SelfUpdateActivity.class);
        drawerActivity(list,"Release Signer",SignerProvisionActivity.class);
        drawerCommand(list,"Device Info","device info",true);
        drawerCommand(list,"Functions Status","functions",true);

        drawerSection(list,"Offline Brain & Self Upgrade");
        drawerCommand(list,"Brain Status","brain status",true);
        drawerCommand(list,"Component Status","component status",true);
        drawerCommand(list,"Autonomy Status","autonomy status",true);
        drawerCommand(list,"Upgrade Status","upgrade status",true);
        drawerPrefill(list,"Create / Add Function","create function ");
        drawerCommand(list,"Code Doctor / Validate","code doctor",true);
        drawerCommand(list,"Local Build","local build",true);
        drawerCommand(list,"Self Test","self test",true);
        drawerCommand(list,"Diagnostics Report","diagnostics report",true);
        drawerCommand(list,"Recovery Checkpoint","recovery checkpoint",true);
        drawerCommand(list,"Rollback Status","rollback status",true);
        drawerCommand(list,"Signer Status","signer status",true);

        drawerSection(list,"Phone & Apps");
        drawerPrefill(list,"Open App","open ");
        drawerPrefill(list,"Search Web","search ");
        drawerPrefill(list,"Open URL","open url ");
        drawerPrefill(list,"Dial","dial ");
        drawerPrefill(list,"Calculate","calculate ");
        drawerCommand(list,"Phone Settings","settings",true);
        drawerCommand(list,"Anamika App Settings","app settings",true);

        drawerSection(list,"Automation / Blueprint");
        drawerPrefill(list,"Scan App / Deep Blueprint","scan app ");
        drawerCommand(list,"Stop Scan","stop scan",true);
        drawerCommand(list,"Blueprint Status","blueprint status",true);
        drawerPrefill(list,"Tap Visible Control","tap ");
        drawerPrefill(list,"Type into Focused Field","type ");
        drawerCommand(list,"Back","back",true);
        drawerPrefill(list,"Send Message","send message ");
        drawerCommand(list,"Message Status","message status",true);
        drawerCommand(list,"Cancel Message","cancel message",true);

        drawerSection(list,"Memory & Files");
        drawerPrefill(list,"Remember","remember ");
        drawerCommand(list,"Memory Status","memory status",true);
        drawerCommand(list,"Vault Status","vault status",true);
        drawerPrefill(list,"Save File","save file ");

        drawerSection(list,"Research");
        drawerPrefill(list,"Research","research ");
        drawerCommand(list,"Research Status","research status",true);
        drawerCommand(list,"Stop Research","stop research",true);

        drawerSection(list,"Voice & Runtime");
        drawerCommand(list,"Wake Listener ON","wake on",true);
        drawerCommand(list,"Wake Listener OFF","wake off",true);
        drawerCommand(list,"Health","health",true);
        drawerCommand(list,"Last Crash","last crash",true);
        drawerCommand(list,"Watchdog","watchdog",true);

        Button lock=drawerButton("Lock Anamika");
        lock.setOnClickListener(v->{
            closeDrawer();
            OwnerStore.forgetTrust(this);
            WakeService.disable(this);
            showOwnerGate();
        });
        list.addView(lock);

        scroll.addView(list,new ScrollView.LayoutParams(-1,-2));
        drawer.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
    }

    private void drawerSection(LinearLayout list,String name){
        TextView v=new TextView(this);
        v.setText(name);
        v.setTextColor(MUTED);
        v.setTextSize(12);
        v.setAllCaps(true);
        v.setPadding(dp(10),dp(15),dp(8),dp(5));
        list.addView(v);
    }

    private void drawerCommand(LinearLayout list,String label,String command,boolean autoRun){
        Button b=drawerButton(label);
        b.setOnClickListener(v->{
            closeDrawer();
            if(autoRun)runCommand(command);
            else prefillCommand(command);
        });
        list.addView(b);
    }

    private void drawerPrefill(LinearLayout list,String label,String prefix){
        drawerCommand(list,label,prefix,false);
    }

    private void drawerActivity(LinearLayout list,String label,Class<?> activity){
        Button b=drawerButton(label);
        b.setOnClickListener(v->{
            closeDrawer();
            startActivity(new Intent(this,activity));
        });
        list.addView(b);
    }

    private Button drawerButton(String label){
        Button b=new Button(this);
        b.setAllCaps(false);
        b.setText(label);
        b.setTextColor(TEXT);
        b.setTextSize(15);
        b.setGravity(Gravity.START|Gravity.CENTER_VERTICAL);
        b.setPadding(dp(12),0,dp(12),0);
        b.setBackground(rounded(PANEL_2,13));
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(48));
        lp.bottomMargin=dp(6);
        b.setLayoutParams(lp);
        return b;
    }

    private void openDrawer(){
        if(drawer==null)return;
        drawerScrim.setVisibility(View.VISIBLE);
        drawer.setVisibility(View.VISIBLE);
    }

    private void closeDrawer(){
        if(drawer==null)return;
        drawer.setVisibility(View.GONE);
        drawerScrim.setVisibility(View.GONE);
    }

    private void showEffortMenu(){
        PopupMenu p=new PopupMenu(this,effortButton);
        p.getMenu().add(0,1,0,"Instant");
        p.getMenu().add(0,2,1,"Medium");
        p.getMenu().add(0,3,2,"Hard");
        p.setOnMenuItemClickListener(item->{
            BrainEffortStore.Mode mode=item.getItemId()==3
                    ?BrainEffortStore.Mode.HARD
                    :item.getItemId()==2?BrainEffortStore.Mode.MEDIUM:BrainEffortStore.Mode.INSTANT;
            BrainEffortStore.set(this,mode);
            updateEffortButton();
            if(status!=null)status.setText("Owner verified • "+BrainEffortStore.describe(this));
            append("Anamika",mode.label+" effort selected.");
            return true;
        });
        p.show();
    }

    private void updateEffortButton(){
        if(effortButton!=null)effortButton.setText(BrainEffortStore.get(this).label+" ▾");
    }

    private void prefillCommand(String prefix){
        if(input==null)return;
        input.setText(prefix);
        input.setSelection(input.length());
        input.requestFocus();
    }

    private void bootstrapBundledToolchain(){
        if(!OwnerStore.isTrusted(this)||ComponentPackManager.toolchainInstalled(this)
                ||!ComponentPackManager.bundledToolchainAvailable(this))return;
        if(status!=null)status.setText("Bundled toolchain setup…");
        final Context app=getApplicationContext();
        new Thread(()->{
            ComponentPackManager.Result r=ComponentPackManager.installBundledToolchainIfNeeded(app);
            runOnUiThread(()->{
                if(status!=null)status.setText(r.ok
                        ?"Owner verified • toolchain ready"
                        :"Owner verified • toolchain setup needs attention");
                append("Anamika",r.message);
            });
        },"anamika-toolchain-bootstrap").start();
    }

    private void maybeOfferStartupSetup(){
        if(!OwnerStore.isTrusted(this)||startupSetupDialogVisible)return;

        boolean signerReady=SignerVault.ready(this);
        boolean toolchainReady=ComponentPackManager.toolchainInstalled(this);
        boolean runtimeReady=ComponentPackManager.brainRuntimeInstalled(this);
        boolean modelReady=ComponentPackManager.modelInstalled(this);
        if(signerReady&&toolchainReady&&runtimeReady&&modelReady)return;

        StringBuilder missing=new StringBuilder();
        if(!signerReady)missing.append("• Permanent .p12 signer + password\n");
        if(!toolchainReady)missing.append("• Android local-build toolchain\n");
        if(!runtimeReady)missing.append("• Offline Brain Runtime\n");
        if(!modelReady)missing.append("• Qwen2.5-Coder-1.5B-Instruct Q4_K_M model\n");

        startupSetupDialogVisible=true;
        new AlertDialog.Builder(this)
                .setTitle("Anamika 13 • First Setup")
                .setMessage("Full offline coding/self-upgrade ke liye ye setup chahiye:\n\n"+
                        missing+
                        "\nToolchain signed V13 APK me bundled hai. Signer aur Brain/Qwen setup Anamika aapse khud mangegi.")
                .setPositiveButton("Continue Setup",(d,w)->{
                    startupSetupDialogVisible=false;
                    if(!SignerVault.ready(this))startActivity(new Intent(this,SignerProvisionActivity.class));
                    else startActivity(new Intent(this,ComponentPacksActivity.class));
                })
                .setNegativeButton("Later",(d,w)->startupSetupDialogVisible=false)
                .setOnCancelListener(d->startupSetupDialogVisible=false)
                .show();
    }

    @Override protected void onResume(){
        super.onResume();
        if(OwnerStore.isTrusted(this)){
            if(WakeService.isEnabled(this)&&!WakeService.isRunning()&&
                    (Build.VERSION.SDK_INT<23||AndroidCompat.hasPermission(this,Manifest.permission.RECORD_AUDIO))){
                WakeService.enable(this);
            }
            if(status!=null)getWindow().getDecorView().postDelayed(this::maybeOfferStartupSetup,900);
        }
    }

    private void startVoice(){
        if(Build.VERSION.SDK_INT>=23&&!AndroidCompat.hasPermission(this,Manifest.permission.RECORD_AUDIO)){
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO);
            return;
        }
        voice.listen();
    }

    private void requestNotificationPermission(){
        if(Build.VERSION.SDK_INT>=33&&!AndroidCompat.hasPermission(this,Manifest.permission.POST_NOTIFICATIONS))
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},REQ_NOTIFY);
    }

    @Override public void onRequestPermissionsResult(int requestCode,String[] permissions,int[] results){
        super.onRequestPermissionsResult(requestCode,permissions,results);
        if(requestCode==REQ_AUDIO&&results.length>0&&results[0]==PackageManager.PERMISSION_GRANTED)
            voice.listen();
    }

    private void runInput(){
        String text=input==null?"":input.getText().toString().trim();
        if(text.isEmpty())return;
        input.setText("");
        runCommand(text);
    }

    private void runCommand(String text){
        append("You",text);
        MemoryStore.appendTurn(this,"owner",text);

        if(CommandRouter.requiresBackgroundFast(text)){
            if(status!=null)status.setText("Working in background…");
            final String command=text;
            new Thread(()->{
                String reply=CommandRouter.runFast(this,command);
                runOnUiThread(()->{
                    if(isFinishing()||(Build.VERSION.SDK_INT>=17&&isDestroyed()))return;
                    finishReply(reply==null?"Command could not be completed.":reply);
                    if(status!=null)status.setText("Owner verified • "+BrainEffortStore.describe(this));
                });
            },"anamika-heavy-command").start();
            return;
        }

        String fast=CommandRouter.runFast(this,text);
        if(fast!=null){
            finishReply(fast);
            return;
        }

        append("Anamika","Offline brain se instruction samajh rahi hu…");
        if(status!=null)status.setText("Offline brain planning • "+BrainEffortStore.get(this).label);
        final Context appContext=getApplicationContext();
        new Thread(()->{
            BrainCommandEngine.Plan plan=BrainCommandEngine.plan(appContext,text);
            if(BrainCommandEngine.requiresBackground(plan)){
                String reply=BrainCommandEngine.execute(this,plan);
                runOnUiThread(()->{
                    if(isFinishing()||(Build.VERSION.SDK_INT>=17&&isDestroyed()))return;
                    finishReply(reply);
                    if(status!=null)status.setText("Owner verified • "+BrainEffortStore.describe(this));
                });
            }else{
                runOnUiThread(()->{
                    if(isFinishing()||(Build.VERSION.SDK_INT>=17&&isDestroyed()))return;
                    String reply=BrainCommandEngine.execute(this,plan);
                    finishReply(reply);
                    if(status!=null)status.setText("Owner verified • "+BrainEffortStore.describe(this));
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
        if(messages==null)return;
        TextView bubble=new TextView(this);
        bubble.setText((who.equals("You")?"You":"Anamika")+"\n"+text);
        bubble.setTextColor(TEXT);
        bubble.setTextSize(15);
        bubble.setTextIsSelectable(true);
        bubble.setPadding(dp(13),dp(10),dp(13),dp(10));
        bubble.setBackground(rounded(who.equals("You")?Color.rgb(45,72,68):PANEL_2,16));
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(
                (int)(getResources().getDisplayMetrics().widthPixels*0.86f),-2);
        lp.bottomMargin=dp(10);
        lp.gravity=who.equals("You")?Gravity.END:Gravity.START;
        messages.addView(bubble,lp);
        if(chatScroll!=null)chatScroll.post(()->chatScroll.fullScroll(View.FOCUS_DOWN));
    }

    private void handleWakeCommand(){
        if(!OwnerStore.isTrusted(this))return;
        String cmd=getIntent()==null?null:getIntent().getStringExtra("wake_command");
        if(getIntent()!=null)getIntent().removeExtra("wake_command");
        if(cmd==null)return;
        if(messages==null)showAssistant();
        if(cmd.trim().isEmpty()){
            append("Anamika","Ji, boliye.");
            voice.speak("Ji, boliye.");
        }else runCommand(cmd.trim());
    }

    private TextView title(String text){
        TextView t=new TextView(this);
        t.setText(text);
        t.setTextColor(TEXT);
        t.setTextSize(26);
        t.setPadding(0,0,0,dp(16));
        return t;
    }

    private ImageButton iconButton(int icon){
        ImageButton b=new ImageButton(this);
        b.setImageResource(icon);
        b.setBackgroundColor(Color.TRANSPARENT);
        b.setPadding(dp(11),dp(11),dp(11),dp(11));
        b.setScaleType(ImageButton.ScaleType.CENTER_INSIDE);
        return b;
    }

    private GradientDrawable rounded(int color,int radiusDp){
        GradientDrawable g=new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radiusDp));
        return g;
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

    @Override public void onBackPressed(){
        if(drawer!=null&&drawer.getVisibility()==View.VISIBLE){
            closeDrawer();
            return;
        }
        super.onBackPressed();
    }

    @Override protected void onDestroy(){
        if(voice!=null)voice.close();
        super.onDestroy();
    }
}
