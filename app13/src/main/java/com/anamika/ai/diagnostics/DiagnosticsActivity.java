package com.anamika.ai.diagnostics;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;

/** Owner-only diagnostics dashboard for on-device testing and explicit report sharing. */
public final class DiagnosticsActivity extends Activity {
    private TextView output;

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
        title.setText("Anamika 13 • Diagnostics");
        title.setTextSize(23);
        box.addView(title);

        TextView note=new TextView(this);
        note.setText("Full diagnostics har current V13 function ko inventory me check karti hai. Safe automated probes actually run hote hain. Jo function real external side effect ke bina prove nahi ho sakta, use PASS nahi diya jata; LIVE_TEST_REQUIRED report hota hai.");
        note.setPadding(0,dp(8),0,dp(12));
        box.addView(note);

        Button run=new Button(this);
        run.setText("Run Full Functional Diagnostics");
        Button share=new Button(this);
        share.setText("Share Latest Report");
        Button show=new Button(this);
        show.setText("Show Latest JSON");

        box.addView(run);
        box.addView(share);
        box.addView(show);

        output=new TextView(this);
        output.setText("Run Full Functional Diagnostics dabao.");
        output.setTextIsSelectable(true);
        output.setPadding(0,dp(14),0,dp(24));
        box.addView(output);

        run.setOnClickListener(v->{
            run.setEnabled(false);
            output.setText("Saare functions check ho rahe hain… offline runtime/toolchain self-test me time lag sakta hai.");
            new Thread(()->{
                String result=DiagnosticsController.runAndSave(this);
                runOnUiThread(()->{
                    output.setText(result);
                    run.setEnabled(true);
                });
            },"anamika-full-diagnostics").start();
        });
        share.setOnClickListener(v->output.setText(DiagnosticsController.shareLatest(this)));
        show.setOnClickListener(v->output.setText(DiagnosticsController.latest(this)));

        ScrollView scroll=new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    private int dp(int v){
        return (int)(v*getResources().getDisplayMetrics().density+0.5f);
    }
}
