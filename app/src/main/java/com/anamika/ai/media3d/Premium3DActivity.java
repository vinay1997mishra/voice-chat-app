package com.anamika.ai.media3d;

import android.app.Activity;
import android.os.Bundle;
import android.os.Environment;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.anamika.ai.R;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public final class Premium3DActivity extends Activity {
    private Premium3DSurfaceView glView;
    private Spinner presetSpinner;
    private Spinner qualitySpinner;
    private TextView exportStatus;
    private Button exportButton;
    private EditText animationBrief;
    private CinematicSceneConfig activeScene=CinematicSceneConfig.defaultDragon();

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_premium_3d);

        FrameLayout preview=findViewById(R.id.previewContainer);
        presetSpinner=findViewById(R.id.presetSpinner);
        qualitySpinner=findViewById(R.id.qualitySpinner);
        exportStatus=findViewById(R.id.exportStatus);
        exportButton=findViewById(R.id.export3dButton);
        animationBrief=findViewById(R.id.animationBrief);
        Button applyBriefButton=findViewById(R.id.applyBriefButton);

        glView=new Premium3DSurfaceView(this);
        preview.addView(glView,new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,FrameLayout.LayoutParams.MATCH_PARENT));
        glView.setScene(activeScene);

        ArrayAdapter<ScenePreset> presets=new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_dropdown_item,ScenePreset.values());
        presetSpinner.setAdapter(presets);
        presetSpinner.setSelection(ScenePreset.CINEMATIC_DRAGON.ordinal());
        presetSpinner.setOnItemSelectedListener(new SimpleItemSelectedListener(() -> {
            ScenePreset p=(ScenePreset)presetSpinner.getSelectedItem();
            activeScene=new CinematicSceneConfig(p,activeScene.subject,activeScene.fireBreath,
                    activeScene.cinematicFog,activeScene.impactShake,activeScene.intensity,activeScene.durationSeconds,activeScene.brief);
            glView.setScene(activeScene);
        }));

        ArrayAdapter<String> qualities=new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_dropdown_item,
                new String[]{"720p • 30 FPS","1080p • 30 FPS","1080p • 60 FPS","2K • 30 FPS","4K • 30 FPS (device dependent)"});
        qualitySpinner.setAdapter(qualities);
        qualitySpinner.setSelection(1);

        applyBriefButton.setOnClickListener(v -> applyBrief());
        exportButton.setOnClickListener(v -> startExport());
    }

    private void applyBrief() {
        activeScene=Cinematic3DDirector.fromBrief(animationBrief.getText().toString());
        presetSpinner.setSelection(activeScene.preset.ordinal());
        glView.setScene(activeScene);
        exportStatus.setText("Cinematic director ready: "+activeScene.preset.title+
                " • subject="+activeScene.subject.title+" • fog="+activeScene.cinematicFog+
                " • fire="+activeScene.fireBreath+
                " • "+activeScene.durationSeconds+"s");
    }

    private void startExport() {
        int pos=qualitySpinner.getSelectedItemPosition();
        int width,height,fps;
        switch(pos) {
            case 0: width=720; height=1280; fps=30; break;
            case 2: width=1080; height=1920; fps=60; break;
            case 3: width=1440; height=2560; fps=30; break;
            case 4: width=2160; height=3840; fps=30; break;
            default: width=1080; height=1920; fps=30; break;
        }

        File dir=getExternalFilesDir(Environment.DIRECTORY_MOVIES);
        if(dir==null) dir=getFilesDir();
        String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date());
        File out=new File(dir,"AnamikaCinematic3D_"+stamp+".mp4");

        exportButton.setEnabled(false);
        exportStatus.setText("Cinematic render starting… "+width+"×"+height+" @ "+fps+"fps");
        Premium3DVideoExporter.exportAsync(out,activeScene,width,height,fps,
                new Premium3DVideoExporter.Callback() {
                    @Override public void onProgress(int percent) {
                        runOnUiThread(() -> exportStatus.setText("Rendering cinematic frames: "+percent+"%"));
                    }
                    @Override public void onComplete(File file) {
                        runOnUiThread(() -> {
                            exportButton.setEnabled(true);
                            exportStatus.setText("Cinematic MP4 ready:\n"+file.getAbsolutePath());
                            Toast.makeText(Premium3DActivity.this,"Cinematic 3D video ready",Toast.LENGTH_LONG).show();
                        });
                    }
                    @Override public void onError(Throwable error) {
                        runOnUiThread(() -> {
                            exportButton.setEnabled(true);
                            exportStatus.setText("Export failed: "+error.getMessage()+"\nTry a lower resolution if the device encoder cannot handle this mode.");
                        });
                    }
                });
    }

    @Override protected void onResume() { super.onResume(); if(glView!=null) glView.onResume(); }
    @Override protected void onPause() { if(glView!=null) glView.onPause(); super.onPause(); }
}
