package com.anamika.ai.plugins;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Locale;
import com.anamika.ai.language.UniversalLanguageRouter;
import com.anamika.ai.OwnerSession;

/** Transparent speech capture launched from the accessibility overlay bubble. */
public final class VoiceCommandActivity extends Activity {
    private static final int REQ_SPEECH=4401;
    private static final int REQ_AUDIO=4402;
    @Override protected void onCreate(Bundle savedInstanceState){
        super.onCreate(savedInstanceState);
        if(!OwnerSession.isActive(this)){ Toast.makeText(this,"Owner session expired. Open Anamika and verify PIN again.",Toast.LENGTH_LONG).show(); finish(); return; }
        startSpeech();
    }

    private void startSpeech(){
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO); return;
        }
        Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION", true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH", true);
        i.putExtra(RecognizerIntent.EXTRA_PROMPT,"Anamika App Control command");
        try{ startActivityForResult(i,REQ_SPEECH); }
        catch(Exception e){ Toast.makeText(this,"Speech recognition unavailable",Toast.LENGTH_LONG).show(); finish(); }
    }

    @Override public void onRequestPermissionsResult(int requestCode,String[] permissions,int[] grants){
        super.onRequestPermissionsResult(requestCode,permissions,grants);
        if(requestCode==REQ_AUDIO && grants.length>0 && grants[0]==PackageManager.PERMISSION_GRANTED) startSpeech(); else finish();
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(requestCode==REQ_SPEECH && resultCode==RESULT_OK && data!=null){
            ArrayList<String> results=data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            if(results!=null && !results.isEmpty()){
                String raw=results.get(0);
                String target=getSharedPreferences("anamika_automation",MODE_PRIVATE).getString("target_package","");
                if(!target.isEmpty() && PluginRegistry.isEnabled(this,target)){
                    new Thread(() -> {
                        String normalized=UniversalLanguageRouter.normalize(VoiceCommandActivity.this,raw);
                        AppAutomationAccessibilityService.submitCommand(VoiceCommandActivity.this,target,normalized);
                        runOnUiThread(() -> Toast.makeText(VoiceCommandActivity.this,"Anamika: "+normalized,Toast.LENGTH_SHORT).show());
                    },"anamika-language-normalizer").start();
                }
            }
        }
        finish();
    }
}
