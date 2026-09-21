package com.anamika.ai.components;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;

import java.io.BufferedInputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/** Owner-only installer for offline model/toolchain component packs. */
public final class ComponentPacksActivity extends Activity {
    private static final int PICK_ZIP=1320;
    private TextView status;
    private EditText url;

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
        title.setText("Anamika 13 • Component Packs");
        title.setTextSize(23);
        box.addView(title);

        TextView note=new TextView(this);
        note.setText("Brain/model aur Android toolchain Anamika ki private storage me install honge. Separate app ki zarurat nahi. Pack hashes verify hone ke baad hi activate hoga.");
        note.setPadding(0,dp(8),0,dp(12));
        box.addView(note);

        url=new EditText(this);
        url.setHint("HTTPS component-pack ZIP URL");
        url.setSingleLine(true);
        box.addView(url);

        Button download=new Button(this);
        download.setText("Download + Verify + Install");
        Button importZip=new Button(this);
        importZip.setText("Import Component Pack ZIP");
        Button refresh=new Button(this);
        refresh.setText("Refresh Status");
        box.addView(download);
        box.addView(importZip);
        box.addView(refresh);

        status=new TextView(this);
        status.setText(ComponentPackManager.status(this));
        status.setTextIsSelectable(true);
        status.setPadding(0,dp(14),0,dp(24));
        box.addView(status);

        download.setOnClickListener(v->download(url.getText().toString().trim()));
        importZip.setOnClickListener(v->pick());
        refresh.setOnClickListener(v->status.setText(ComponentPackManager.status(this)));

        ScrollView scroll=new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    private void pick(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/zip");
        startActivityForResult(i,PICK_ZIP);
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(requestCode!=PICK_ZIP||resultCode!=RESULT_OK||data==null||data.getData()==null)return;
        Uri uri=data.getData();
        status.setText("Component pack verify/install ho raha hai…");
        new Thread(()->{
            ComponentPackManager.Result r;
            try(InputStream in=getContentResolver().openInputStream(uri)){
                if(in==null)throw new IllegalStateException("Cannot read selected pack.");
                r=ComponentPackManager.installZip(this,in);
            }catch(Exception e){
                r=new ComponentPackManager.Result(false,"Import failed: "+safe(e));
            }
            post(r.message);
        },"anamika-component-import").start();
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
                long len=con.getContentLengthLong();
                if(len>8L*1024L*1024L*1024L)throw new IllegalStateException("Pack exceeds 8 GB safety limit.");
                try(InputStream in=new BufferedInputStream(con.getInputStream())){
                    ComponentPackManager.Result r=ComponentPackManager.installZip(this,in);
                    post(r.message);
                }
            }catch(Exception e){
                post("Download/install failed: "+safe(e));
            }finally{
                if(con!=null)con.disconnect();
            }
        },"anamika-component-download").start();
    }

    private void post(String text){
        new Handler(Looper.getMainLooper()).post(()->status.setText(text+"\n\n"+ComponentPackManager.status(this)));
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
