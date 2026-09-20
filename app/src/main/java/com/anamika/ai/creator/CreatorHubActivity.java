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
import com.anamika.ai.files.AnamikaVault;

public final class CreatorHubActivity extends Activity {
    private EditText prompt,reference,endpoint,apiKey,model;
    private TextView status;
    private Button generate;
    private String mediaType="video";
    private String workflow="standard";
    private String sourceVideoPath="";
    private int requestedWidth=1920,requestedHeight=1080;
    @Override protected void onCreate(Bundle b){
        super.onCreate(b); setContentView(R.layout.activity_creator_hub);
        prompt=findViewById(R.id.creatorPrompt); reference=findViewById(R.id.creatorReference);
        endpoint=findViewById(R.id.creatorEndpoint); apiKey=findViewById(R.id.creatorApiKey); model=findViewById(R.id.creatorModel);
        status=findViewById(R.id.creatorStatus); generate=findViewById(R.id.creatorGenerate);
        endpoint.setText(getSharedPreferences("anamika_creator",MODE_PRIVATE).getString("endpoint",""));
        model.setText(getSharedPreferences("anamika_creator",MODE_PRIVATE).getString("model",""));
        Intent incoming=getIntent();
        if(incoming!=null){
            mediaType=incoming.getStringExtra("media_type");
            if(mediaType==null||mediaType.trim().isEmpty()) mediaType="video";
            String wf=incoming.getStringExtra("workflow");
            if(wf!=null&&!wf.trim().isEmpty()) workflow=wf.trim();
            String sv=incoming.getStringExtra("source_video_path");
            if(sv!=null) sourceVideoPath=sv;
            requestedWidth=incoming.getIntExtra("width",mediaType.equalsIgnoreCase("image")?1024:1920);
            requestedHeight=incoming.getIntExtra("height",mediaType.equalsIgnoreCase("image")?1024:1080);
            String p=incoming.getStringExtra("prompt");
            if(p!=null&&!p.trim().isEmpty()) prompt.setText(p.trim());
        }
        if("video_to_anime".equalsIgnoreCase(workflow)){
            generate.setText("Convert Video to Anime "+requestedWidth+"×"+requestedHeight);
            status.setText(sourceVideoPath.isEmpty()
                    ?"Upload/select a source video in Anamika first."
                    :"Anime transform ready. Source: "+new java.io.File(sourceVideoPath).getName());
        }else if("story_to_anime".equalsIgnoreCase(workflow)){
            generate.setText("Create Anime Story Video "+requestedWidth+"×"+requestedHeight);
            status.setText("Story mode: scenes + dialogue + distinct natural character voices.");
        }else{
            generate.setText(mediaType.equalsIgnoreCase("image")
                    ?"Generate Image "+requestedWidth+"×"+requestedHeight
                    :"Generate Video "+requestedWidth+"×"+requestedHeight);
        }
        findViewById(R.id.creatorLocal3d).setOnClickListener(v->startActivity(new Intent(this, Premium3DActivity.class)));
        generate.setOnClickListener(v->runGeneration());
    }
    private void runGeneration(){
        String ep=endpoint.getText().toString().trim();
        String key=apiKey.getText().toString().trim();
        String modelName=model.getText().toString().trim();
        String textPrompt=prompt.getText().toString().trim();
        getSharedPreferences("anamika_creator",MODE_PRIVATE).edit().putString("endpoint",ep).putString("model",modelName).apply();
        generate.setEnabled(false);

        if("video_to_anime".equalsIgnoreCase(workflow)){
            java.io.File src=new java.io.File(sourceVideoPath==null?"":sourceVideoPath);
            if(!src.isFile()){
                generate.setEnabled(true);
                status.setText("Anime transform ke liye source video nahi mila. + se video upload karke command dobara do.");
                return;
            }
            status.setText("Starting anime video transformation…");
            AnimeVideoCreator.transformVideo(this,ep,key,modelName,src,textPrompt,requestedWidth,requestedHeight,
                    new AnimeVideoCreator.Callback(){
                        public void onProgress(String m){runOnUiThread(()->status.setText(m));}
                        public void onComplete(java.io.File f,AnimeVideoCreator.Verification v){runOnUiThread(()->{
                            generate.setEnabled(true);apiKey.setText("");
                            status.setText("Anime video ready: "+v.width+"×"+v.height+", "+(v.durationMs/1000f)+"s\n"+
                                    f.getAbsolutePath()+"\nSaved in Anamika Personal Space.");
                            Toast.makeText(CreatorHubActivity.this,"Anime video ready",Toast.LENGTH_LONG).show();
                        });}
                        public void onError(String e){runOnUiThread(()->{generate.setEnabled(true);apiKey.setText("");status.setText("Anime transform failed: "+e);});}
                    });
            return;
        }

        if("story_to_anime".equalsIgnoreCase(workflow)){
            status.setText("Starting anime story generation…");
            AnimeVideoCreator.storyToAnime(this,ep,key,modelName,textPrompt,requestedWidth,requestedHeight,
                    new AnimeVideoCreator.Callback(){
                        public void onProgress(String m){runOnUiThread(()->status.setText(m));}
                        public void onComplete(java.io.File f,AnimeVideoCreator.Verification v){runOnUiThread(()->{
                            generate.setEnabled(true);apiKey.setText("");
                            status.setText("Anime story video ready: "+v.width+"×"+v.height+", "+(v.durationMs/1000f)+"s\n"+
                                    f.getAbsolutePath()+"\nDistinct natural character voices requested. Saved in Personal Space.");
                            Toast.makeText(CreatorHubActivity.this,"Anime story video ready",Toast.LENGTH_LONG).show();
                        });}
                        public void onError(String e){runOnUiThread(()->{generate.setEnabled(true);apiKey.setText("");status.setText("Anime story generation failed: "+e);});}
                    });
            return;
        }

        generate.setEnabled(false); status.setText("Starting online cinematic job…");
        if(mediaType.equalsIgnoreCase("image")){
            InternetImageCreator.generate(this,ep,apiKey.getText().toString().trim(),model.getText().toString().trim(),
                    prompt.getText().toString(),reference.getText().toString(),requestedWidth,requestedHeight,
                    new InternetImageCreator.Callback(){
                        public void onProgress(String m){runOnUiThread(()->status.setText(m));}
                        public void onComplete(java.io.File f,int w,int h){runOnUiThread(()->{
                            generate.setEnabled(true);apiKey.setText("");
                            status.setText("Image ready: "+w+"×"+h+"\n"+f.getAbsolutePath()+"\nSaved in Anamika Personal Space.");
                            Toast.makeText(CreatorHubActivity.this,"Image ready",Toast.LENGTH_LONG).show();
                        });}
                        public void onError(String e){runOnUiThread(()->{generate.setEnabled(true);apiKey.setText("");status.setText("Generation failed: "+e);});}
                    });
        }else{
            InternetCinematicCreator.generate(this,ep,apiKey.getText().toString().trim(),model.getText().toString().trim(),
                    prompt.getText().toString(),reference.getText().toString(),requestedWidth,requestedHeight,
                    new InternetCinematicCreator.Callback(){
                        public void onProgress(String m){runOnUiThread(()->status.setText(m));}
                        public void onComplete(java.io.File f, InternetCinematicCreator.Verification v){runOnUiThread(()->{
                            generate.setEnabled(true); apiKey.setText("");
                            try{AnamikaVault.registerGeneratedFile(CreatorHubActivity.this,f,"video/mp4");}catch(Exception ignored){}
                            status.setText("Video ready: "+v.width+"×"+v.height+", "+(v.durationMs/1000f)+"s\n"+f.getAbsolutePath()+
                                    "\nSaved in Anamika Personal Space."+
                                    (v.fullHdOrBetter?"\nFull-HD-or-better verification: PASS":"\nWarning: provider returned below requested HD level."));
                            Toast.makeText(CreatorHubActivity.this,"Cinematic video ready",Toast.LENGTH_LONG).show();
                        });}
                        public void onError(String e){runOnUiThread(()->{generate.setEnabled(true); apiKey.setText(""); status.setText("Generation failed: "+e);});}
                    });
        }
    }
}
