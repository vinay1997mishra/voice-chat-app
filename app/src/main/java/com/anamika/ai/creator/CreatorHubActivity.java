package com.anamika.ai.creator;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.anamika.ai.R;
import com.anamika.ai.media3d.Premium3DActivity;

public final class CreatorHubActivity extends Activity {
    private EditText prompt,reference,endpoint,apiKey,model;
    private TextView status;
    private Button generate;
    @Override protected void onCreate(Bundle b){
        super.onCreate(b); setContentView(R.layout.activity_creator_hub);
        prompt=findViewById(R.id.creatorPrompt); reference=findViewById(R.id.creatorReference);
        endpoint=findViewById(R.id.creatorEndpoint); apiKey=findViewById(R.id.creatorApiKey); model=findViewById(R.id.creatorModel);
        status=findViewById(R.id.creatorStatus); generate=findViewById(R.id.creatorGenerate);
        endpoint.setText(getSharedPreferences("anamika_creator",MODE_PRIVATE).getString("endpoint",""));
        model.setText(getSharedPreferences("anamika_creator",MODE_PRIVATE).getString("model",""));
        findViewById(R.id.creatorLocal3d).setOnClickListener(v->startActivity(new Intent(this, Premium3DActivity.class)));
        generate.setOnClickListener(v->runGeneration());
    }
    private void runGeneration(){
        String ep=endpoint.getText().toString().trim();
        getSharedPreferences("anamika_creator",MODE_PRIVATE).edit().putString("endpoint",ep).putString("model",model.getText().toString().trim()).apply();
        generate.setEnabled(false); status.setText("Starting online cinematic job…");
        InternetCinematicCreator.generate(this,ep,apiKey.getText().toString().trim(),model.getText().toString().trim(),
                prompt.getText().toString(),reference.getText().toString(),new InternetCinematicCreator.Callback(){
                    public void onProgress(String m){runOnUiThread(()->status.setText(m));}
                    public void onComplete(java.io.File f, InternetCinematicCreator.Verification v){runOnUiThread(()->{
                        generate.setEnabled(true); apiKey.setText("");
                        status.setText("Video ready: "+v.width+"×"+v.height+", "+(v.durationMs/1000f)+"s\n"+f.getAbsolutePath()+
                                (v.fullHdOrBetter?"\nFull-HD-or-better verification: PASS":"\nWarning: provider returned below Full HD."));
                        Toast.makeText(CreatorHubActivity.this,"Cinematic video ready",Toast.LENGTH_LONG).show();
                    });}
                    public void onError(String e){runOnUiThread(()->{generate.setEnabled(true); apiKey.setText(""); status.setText("Generation failed: "+e);});}
                });
    }
}
