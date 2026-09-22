package com.anamika.ai.components;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.upgrade.SignerProvisionActivity;

import java.io.BufferedInputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/** Owner-only installer for offline model/toolchain component packs. */
public final class ComponentPacksActivity extends Activity {
    private static final int PICK_ZIP=1320;
    private static final int PICK_GGUF=1321;
    private static final String BRAIN_RUNTIME_URL=
            "https://github.com/vinay1997mishra/voice-chat-app/releases/download/anamika-brain-v13-2/AnamikaAI-13-BrainRuntime-arm64.zip";
    private static final String QWEN_MODEL_URL=
            "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf?download=true";
    private TextView status;
    private EditText url;
    private Button completeButton;
    private Button runtimeButton;
    private Button qwenButton;
    private Button importModelButton;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        if(!OwnerStore.isTrusted(this)){finish();return;}
        buildUi();
    }

    private void buildUi(){
        int p=dp(16);
        LinearLayout box=new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(p,p,p,p);

        TextView title=new TextView(this);
        title.setText("Anamika 13 • Offline Components");
        title.setTextSize(23);
        box.addView(title);

        TextView note=new TextView(this);
        note.setText("Step 1: Offline Brain Runtime install karein.\nStep 2: Qwen2.5-Coder-1.5B-Instruct Q4_K_M model download/import karein.\nStep 3: Android toolchain signed V13 APK ke andar bundled hai aur owner unlock ke baad auto-install hota hai.");
        note.setPadding(0,dp(8),0,dp(12));
        box.addView(note);

        url=new EditText(this);
        url.setHint("Optional custom component-pack ZIP URL (normal setup ke liye blank chhodo)");
        url.setSingleLine(true);
        box.addView(url);

        completeButton=new Button(this); completeButton.setText("Complete Offline Setup • Toolchain + Brain + Qwen");
        runtimeButton=new Button(this); runtimeButton.setText("Install Offline Brain Runtime");
        qwenButton=new Button(this); qwenButton.setText("Download Qwen2.5-Coder 1.5B Q4_K_M");
        Button download=new Button(this); download.setText("Download Component ZIP from URL");
        Button importZip=new Button(this); importZip.setText("Import Runtime/Toolchain ZIP");
        importModelButton=new Button(this); importModelButton.setText("Select Downloaded Qwen GGUF from Phone");
        Button signer=new Button(this); signer.setText("Setup Release Signer");
        Button refresh=new Button(this); refresh.setText("Refresh Status");
        box.addView(completeButton);
        box.addView(runtimeButton);
        box.addView(qwenButton);
        box.addView(download);
        box.addView(importZip);
        box.addView(importModelButton);
        box.addView(signer);
        box.addView(refresh);

        status=new TextView(this);
        status.setText(ComponentPackManager.status(this));
        status.setTextIsSelectable(true);
        status.setPadding(0,dp(14),0,dp(24));
        box.addView(status);

        completeButton.setOnClickListener(v->completeOfflineSetup());
        runtimeButton.setOnClickListener(v->download(BRAIN_RUNTIME_URL));
        qwenButton.setOnClickListener(v->downloadModel(QWEN_MODEL_URL));
        download.setOnClickListener(v->download(url.getText().toString().trim()));
        importZip.setOnClickListener(v->pickZip());
        importModelButton.setOnClickListener(v->pickModel());
        signer.setOnClickListener(v->startActivity(new Intent(this,SignerProvisionActivity.class)));
        refresh.setOnClickListener(v->{status.setText(ComponentPackManager.status(this));updateInstalledUi();});

        updateInstalledUi();

        ScrollView scroll=new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    private void updateInstalledUi(){
        boolean tool=ComponentPackManager.toolchainInstalled(this);
        boolean brain=ComponentPackManager.brainRuntimeInstalled(this);
        boolean model=ComponentPackManager.modelInstalled(this);

        if(runtimeButton!=null){
            runtimeButton.setText(brain?"Brain Runtime ✓ Installed":"Install Offline Brain Runtime");
            runtimeButton.setEnabled(!brain);
        }
        if(qwenButton!=null){
            qwenButton.setText(model?"Qwen Model ✓ Installed":"Download Qwen2.5-Coder 1.5B Q4_K_M");
            qwenButton.setEnabled(!model);
        }
        if(importModelButton!=null){
            importModelButton.setText(model?"Replace / Re-import Qwen GGUF":"Select Downloaded Qwen GGUF from Phone");
        }
        if(completeButton!=null){
            boolean ready=tool&&brain&&model;
            completeButton.setText(ready?"Offline Setup READY ✓":"Complete Offline Setup • Toolchain + Brain + Qwen");
            completeButton.setEnabled(!ready);
        }
    }

    private void completeOfflineSetup(){
        status.setText("Full offline setup start ho raha hai… Toolchain → Brain Runtime → Qwen model.");
        new Thread(()->{
            try{
                if(!ComponentPackManager.toolchainInstalled(this)){
                    postProgress("Bundled Android toolchain install ho raha hai…");
                    ComponentPackManager.Result tool=ComponentPackManager.installBundledToolchainIfNeeded(this);
                    if(!tool.ok){post("Full setup stopped: "+tool.message);return;}
                }

                if(!ComponentPackManager.brainRuntimeInstalled(this)){
                    postProgress("Offline Brain Runtime download/install ho raha hai…");
                    ComponentPackManager.Result brain=downloadZipBlocking(BRAIN_RUNTIME_URL);
                    if(!brain.ok){post("Full setup stopped: "+brain.message);return;}
                }

                if(!ComponentPackManager.modelInstalled(this)){
                    postProgress("Qwen2.5-Coder-1.5B Q4_K_M download ho raha hai… 1 GB+ file hai.");
                    ComponentPackManager.Result model=downloadModelBlocking(QWEN_MODEL_URL);
                    if(!model.ok){post("Full setup stopped: "+model.message);return;}
                }

                post("FULL OFFLINE SETUP READY\nToolchain: READY\nBrain Runtime: READY\nQwen Model: READY");
            }catch(Exception e){
                post("Full offline setup failed: "+safe(e));
            }
        },"anamika-full-offline-setup").start();
    }

    private ComponentPackManager.Result downloadZipBlocking(String raw){
        HttpURLConnection con=null;
        try{
            URL u=new URL(raw);
            con=(HttpURLConnection)u.openConnection();
            con.setConnectTimeout(20000);
            con.setReadTimeout(120000);
            con.setInstanceFollowRedirects(true);
            con.setRequestProperty("User-Agent","AnamikaAI13-ComponentInstaller");
            int code=con.getResponseCode();
            if(code<200||code>=300)return new ComponentPackManager.Result(false,"Component download HTTP "+code);
            long len=con.getContentLengthLong();
            if(len>8L*1024L*1024L*1024L)
                return new ComponentPackManager.Result(false,"Component pack exceeds 8 GB safety limit.");
            try(InputStream in=new BufferedInputStream(con.getInputStream())){
                return ComponentPackManager.installZip(this,in);
            }
        }catch(Exception e){
            return new ComponentPackManager.Result(false,"Component download/install failed: "+safe(e));
        }finally{
            if(con!=null)con.disconnect();
        }
    }

    private ComponentPackManager.Result downloadModelBlocking(String raw){
        HttpURLConnection con=null;
        try{
            URL u=new URL(raw);
            con=(HttpURLConnection)u.openConnection();
            con.setConnectTimeout(20000);
            con.setReadTimeout(120000);
            con.setInstanceFollowRedirects(true);
            con.setRequestProperty("User-Agent","AnamikaAI13-ModelInstaller");
            int code=con.getResponseCode();
            if(code<200||code>=300)return new ComponentPackManager.Result(false,"Qwen download HTTP "+code);
            long len=con.getContentLengthLong();
            if(len>8L*1024L*1024L*1024L)
                return new ComponentPackManager.Result(false,"Model exceeds 8 GB safety limit.");
            try(InputStream in=new BufferedInputStream(con.getInputStream())){
                return ComponentPackManager.installModel(this,in);
            }
        }catch(Exception e){
            return new ComponentPackManager.Result(false,"Qwen model download/import failed: "+safe(e));
        }finally{
            if(con!=null)con.disconnect();
        }
    }

    private void postProgress(String text){
        new Handler(Looper.getMainLooper()).post(()->{
            status.setText(text+"\n\n"+ComponentPackManager.status(this));
            updateInstalledUi();
        });
    }

    private void pickZip(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/zip");
        startActivityForResult(i,PICK_ZIP);
    }

    private void pickModel(){
        status.setText("Phone storage picker khol rahi hu… Downloads me apni .gguf file select karo.");
        Intent open=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        open.addCategory(Intent.CATEGORY_OPENABLE);
        open.setType("*/*");
        open.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);

        Intent get=new Intent(Intent.ACTION_GET_CONTENT);
        get.addCategory(Intent.CATEGORY_OPENABLE);
        get.setType("*/*");
        get.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

        Intent chooser=Intent.createChooser(open,"Select Qwen GGUF model");
        chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS,new Intent[]{get});
        try{
            startActivityForResult(chooser,PICK_GGUF);
        }catch(Exception first){
            try{
                startActivityForResult(get,PICK_GGUF);
            }catch(Exception second){
                status.setText("Phone file picker open nahi hua. Files/Downloads app se .gguf file ko share/open-with karke Anamika select karein, ya Qwen download button use karein.");
            }
        }
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(resultCode!=RESULT_OK||data==null||data.getData()==null){
            if(requestCode==PICK_GGUF)status.setText("GGUF file selection cancel hui. “Select Downloaded Qwen GGUF from Phone” dobara dabao.");
            return;
        }
        Uri uri=data.getData();
        try{
            int flags=data.getFlags()&Intent.FLAG_GRANT_READ_URI_PERMISSION;
            if(flags!=0)getContentResolver().takePersistableUriPermission(uri,flags);
        }catch(Throwable ignored){}
        if(requestCode==PICK_ZIP)installZip(uri);
        else if(requestCode==PICK_GGUF)installModel(uri);
    }

    private void installZip(Uri uri){
        status.setText("Component pack verify/install ho raha hai…");
        new Thread(()->{
            ComponentPackManager.Result r;
            try(InputStream in=getContentResolver().openInputStream(uri)){
                if(in==null)throw new IllegalStateException("Cannot read selected pack.");
                r=ComponentPackManager.installZip(this,in);
            }catch(Exception e){r=new ComponentPackManager.Result(false,"Import failed: "+safe(e));}
            post(r.message);
        },"anamika-component-import").start();
    }

    private void installModel(Uri uri){
        String name=displayName(uri);
        status.setText("Selected: "+name+"\nGGUF model private storage me import ho raha hai… 1+ GB file me kuch minutes lag sakte hain. Screen close mat karein.");
        new Thread(()->{
            ComponentPackManager.Result r;
            try(InputStream in=getContentResolver().openInputStream(uri)){
                if(in==null)throw new IllegalStateException("Cannot read selected model.");
                r=ComponentPackManager.installModel(this,in);
            }catch(Exception e){r=new ComponentPackManager.Result(false,"Model import failed: "+safe(e));}
            post(r.message);
        },"anamika-model-import").start();
    }

    private String displayName(Uri uri){
        android.database.Cursor c=null;
        try{
            c=getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME},null,null,null);
            if(c!=null&&c.moveToFirst()){
                int i=c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if(i>=0){
                    String n=c.getString(i);
                    if(n!=null&&!n.trim().isEmpty())return n;
                }
            }
        }catch(Exception ignored){}finally{if(c!=null)c.close();}
        String last=uri==null?null:uri.getLastPathSegment();
        return last==null||last.trim().isEmpty()?"selected GGUF":last;
    }

    private void downloadModel(String raw){
        status.setText("Qwen2.5-Coder-1.5B-Instruct Q4_K_M download ho raha hai… file 1 GB+ hai.");
        new Thread(()->{
            HttpURLConnection con=null;
            try{
                URL u=new URL(raw);
                con=(HttpURLConnection)u.openConnection();
                con.setConnectTimeout(20000);
                con.setReadTimeout(120000);
                con.setInstanceFollowRedirects(true);
                con.setRequestProperty("User-Agent","AnamikaAI13-ModelInstaller");
                int code=con.getResponseCode();
                if(code<200||code>=300)throw new IllegalStateException("HTTP "+code);
                long len=con.getContentLengthLong();
                if(len>8L*1024L*1024L*1024L)throw new IllegalStateException("Model exceeds 8 GB safety limit.");
                try(InputStream in=new BufferedInputStream(con.getInputStream())){
                    ComponentPackManager.Result r=ComponentPackManager.installModel(this,in);
                    post(r.message);
                }
            }catch(Exception e){post("Qwen model download/import failed: "+safe(e));}
            finally{if(con!=null)con.disconnect();}
        },"anamika-qwen-download").start();
    }

    private void download(String raw){
        if(raw.isEmpty()){status.setText("HTTPS URL dalo.");return;}
        if(!raw.toLowerCase(java.util.Locale.ROOT).startsWith("https://")){
            status.setText("Security ke liye sirf HTTPS component URLs allowed hain.");
            return;
        }
        status.setText("Component pack download ho raha hai…");
        new Thread(()->{
            HttpURLConnection con=null;
            try{
                URL u=new URL(raw);
                con=(HttpURLConnection)u.openConnection();
                con.setConnectTimeout(15000);
                con.setReadTimeout(60000);
                con.setInstanceFollowRedirects(true);
                con.setRequestProperty("User-Agent","AnamikaAI13-ComponentInstaller");
                int code=con.getResponseCode();
                if(code<200||code>=300)throw new IllegalStateException("HTTP "+code);
                long len=con.getContentLength();
                if(len>8L*1024L*1024L*1024L)throw new IllegalStateException("Pack exceeds 8 GB safety limit.");
                try(InputStream in=new BufferedInputStream(con.getInputStream())){
                    ComponentPackManager.Result r=ComponentPackManager.installZip(this,in);
                    post(r.message);
                }
            }catch(Exception e){post("Download/install failed: "+safe(e));}
            finally{if(con!=null)con.disconnect();}
        },"anamika-component-download").start();
    }

    private void post(String text){
        new Handler(Looper.getMainLooper()).post(()->{
            status.setText(text+"\n\n"+ComponentPackManager.status(this));
            updateInstalledUi();
        });
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
