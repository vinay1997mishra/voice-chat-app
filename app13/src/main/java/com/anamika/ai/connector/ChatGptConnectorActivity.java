package com.anamika.ai.connector;

import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;

public final class ChatGptConnectorActivity extends Activity {
    private EditText url;
    private EditText pairing;
    private EditText deviceName;
    private TextView status;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        if(!OwnerStore.isTrusted(this)){finish();return;}
        build();
    }

    private void build(){
        LinearLayout box=new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(16),dp(16),dp(16),dp(20));

        TextView title=new TextView(this); title.setText("Anamika 13 • ChatGPT Connector"); title.setTextSize(22); box.addView(title);
        TextView info=new TextView(this);
        info.setText("ChatGPT ko Anamika se connect karne ke liye remote HTTPS MCP connector URL aur server pairing code chahiye. Pairing token phone ke private storage me protected rahega.");
        box.addView(info);

        url=new EditText(this);
        url.setHint("https://your-connector.example.com");
        url.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_URI);
        url.setText(ChatGptConnectorStore.serverUrl(this));
        box.addView(url);

        pairing=new EditText(this);
        pairing.setHint("Pairing code");
        pairing.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
        box.addView(pairing);

        CheckBox show=new CheckBox(this); show.setText("Show pairing code"); box.addView(show);
        show.setOnCheckedChangeListener((v,on)->{
            pairing.setInputType(InputType.TYPE_CLASS_TEXT|(on?InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD:InputType.TYPE_TEXT_VARIATION_PASSWORD));
            pairing.setSelection(pairing.length());
        });

        deviceName=new EditText(this);
        deviceName.setHint("Device name");
        deviceName.setText(android.os.Build.MANUFACTURER+" "+android.os.Build.MODEL);
        box.addView(deviceName);

        Button pair=new Button(this); pair.setText("Pair with ChatGPT Connector"); box.addView(pair);
        Button start=new Button(this); start.setText("Start Connector Bridge"); box.addView(start);
        Button stop=new Button(this); stop.setText("Stop Connector Bridge"); box.addView(stop);
        Button clear=new Button(this); clear.setText("Clear Connector Pairing"); box.addView(clear);

        status=new TextView(this);
        status.setText(ChatGptConnectorStore.status(this));
        status.setTextIsSelectable(true);
        box.addView(status);

        pair.setOnClickListener(v->pairNow());
        start.setOnClickListener(v->{
            if(!ChatGptConnectorStore.configured(this)){status.setText("Pehle connector pair karo.");return;}
            ChatGptConnectorService.start(this);
            status.setText(ChatGptConnectorStore.status(this)+"\nStart requested.");
        });
        stop.setOnClickListener(v->{
            ChatGptConnectorService.stop(this);
            status.setText(ChatGptConnectorStore.status(this)+"\nStopped.");
        });
        clear.setOnClickListener(v->{
            ChatGptConnectorService.stop(this);
            ChatGptConnectorStore.clear(this);
            pairing.setText(""); url.setText("");
            status.setText(ChatGptConnectorStore.status(this));
        });

        ScrollView scroll=new ScrollView(this); scroll.addView(box); setContentView(scroll);
    }

    private void pairNow(){
        String u=url.getText().toString().trim();
        String code=pairing.getText().toString();
        String name=deviceName.getText().toString().trim();
        if(u.isEmpty()||code.isEmpty()){status.setText("HTTPS connector URL aur pairing code dono chahiye.");return;}
        status.setText("Pairing…");
        new Thread(()->{
            ChatGptConnectorClient.PairResult r=ChatGptConnectorClient.pair(u,code,name);
            runOnUiThread(()->{
                if(r.ok){
                    try{
                        ChatGptConnectorStore.savePairing(this,u,r.deviceId,r.token);
                        pairing.setText("");
                        ChatGptConnectorService.start(this);
                        status.setText(ChatGptConnectorStore.status(this)+"\nPAIRING READY ✓");
                    }catch(Exception e){status.setText("Pairing save failed: "+safe(e));}
                }else status.setText(r.message);
            });
        },"anamika-connector-pair").start();
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private static String safe(Throwable e){String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;}
}
