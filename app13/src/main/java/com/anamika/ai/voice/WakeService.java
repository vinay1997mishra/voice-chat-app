package com.anamika.ai.voice;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.media.AudioManager;
import android.media.AudioPlaybackConfiguration;
import android.media.AudioRecordingConfiguration;
import android.media.MediaRecorder;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import com.anamika.ai.MainActivity;
import com.anamika.ai.core.AndroidCompat;

import java.util.ArrayList;
import java.util.Locale;
import java.util.List;

/**
 * Owner-enabled foreground wake listener.
 * Android/recognizer vendors may still suspend continuous recognition; this service
 * restarts the recognizer after normal errors instead of pretending 24x7 is guaranteed.
 */
public final class WakeService extends Service implements RecognitionListener {
    private static final String PREF="anamika13_runtime";
    private static final String KEY="wake_enabled";
    private static final int NOTIFICATION_ID=1313;
    private static final String CHANNEL="anamika13_wake";
    public static final String ACTION_STOP="com.anamika.ai.v13.STOP_WAKE";
    public static final String ACTION_PAUSE="com.anamika.ai.v13.PAUSE_WAKE";
    public static final String ACTION_RESUME="com.anamika.ai.v13.RESUME_WAKE";
    private static final String KEY_PAUSE_UNTIL="wake_pause_until_ms";

    private final Handler handler=new Handler(Looper.getMainLooper());
    private SpeechRecognizer recognizer;
    private boolean stopping;
    private AudioManager audioManager;
    private AudioManager.AudioPlaybackCallback playbackCallback;
    private AudioManager.AudioRecordingCallback recordingCallback;
    private static volatile boolean running;

    public static boolean isEnabled(Context c){
        return c.getSharedPreferences(PREF,MODE_PRIVATE).getBoolean(KEY,false);
    }

    public static String enable(Context c){
        c.getSharedPreferences(PREF,MODE_PRIVATE).edit().putBoolean(KEY,true).apply();
        if(Build.VERSION.SDK_INT>=23&&!AndroidCompat.hasPermission(c,Manifest.permission.RECORD_AUDIO))
            return "Wake listener enabled setting saved, but microphone permission is not granted.";
        Intent i=new Intent(c,WakeService.class);
        try{
            if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i); else c.startService(i);
            return "Wake listener ON. Media-friendly mode active hai: song/video/call/voice-chat ke waqt Anamika mic release karegi aur baad me wake listener retry karegi. Battery optimization me Anamika ko unrestricted rakhna reliability ke liye better hai.";
        }catch(Throwable e){
            return "Wake listener setting saved, but Android blocked background microphone service start: "+safe(e)+
                    ". Open Anamika and enable wake while the app is visible.";
        }
    }

    public static boolean isRunning(){return running;}

    /** Temporarily releases the microphone for Anamika foreground speech recognition. */
    public static void pauseFor(Context c,long ms){
        long until=System.currentTimeMillis()+Math.max(1000L,ms);
        c.getSharedPreferences(PREF,MODE_PRIVATE).edit().putLong(KEY_PAUSE_UNTIL,until).apply();
        try{
            Intent i=new Intent(c,WakeService.class).setAction(ACTION_PAUSE);
            if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i); else c.startService(i);
        }catch(Throwable ignored){}
    }

    public static void resume(Context c){
        c.getSharedPreferences(PREF,MODE_PRIVATE).edit().remove(KEY_PAUSE_UNTIL).apply();
        if(!isEnabled(c))return;
        try{
            Intent i=new Intent(c,WakeService.class).setAction(ACTION_RESUME);
            if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i); else c.startService(i);
        }catch(Throwable ignored){}
    }

    public static void disable(Context c){
        c.getSharedPreferences(PREF,MODE_PRIVATE).edit().putBoolean(KEY,false).apply();
        Intent i=new Intent(c,WakeService.class).setAction(ACTION_STOP);
        try{c.startService(i);}catch(Exception ignored){c.stopService(new Intent(c,WakeService.class));}
    }

    @Override public void onCreate(){
        super.onCreate();
        running=true;
        createChannel();
        registerAudioObservers();
        startForeground(NOTIFICATION_ID,notification("Wake listener starting…"));
        handler.post(this::startListening);
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null&&ACTION_STOP.equals(intent.getAction())){
            stopping=true;
            getSharedPreferences(PREF,MODE_PRIVATE).edit()
                    .putBoolean(KEY,false)
                    .remove(KEY_PAUSE_UNTIL)
                    .apply();
            stopSelf();
            return START_NOT_STICKY;
        }
        if(intent!=null&&ACTION_PAUSE.equals(intent.getAction())){
            destroyRecognizer();
            update("Wake on • mic released temporarily");
            schedule(1200);
            return START_STICKY;
        }
        if(intent!=null&&ACTION_RESUME.equals(intent.getAction())){
            handler.post(this::startListening);
            return START_STICKY;
        }
        if(!isEnabled(this)){
            stopSelf();
            return START_NOT_STICKY;
        }
        handler.post(this::startListening);
        return START_STICKY;
    }

    private void startListening(){
        if(stopping||!isEnabled(this))return;

        long pauseUntil=getSharedPreferences(PREF,MODE_PRIVATE).getLong(KEY_PAUSE_UNTIL,0L);
        long now=System.currentTimeMillis();
        if(pauseUntil>now){
            destroyRecognizer();
            update("Wake on • temporarily paused");
            schedule(Math.min(2000L,Math.max(600L,pauseUntil-now)));
            return;
        }else if(pauseUntil!=0L){
            getSharedPreferences(PREF,MODE_PRIVATE).edit().remove(KEY_PAUSE_UNTIL).apply();
        }

        if(shouldYieldAudio()){
            destroyRecognizer();
            update("Wake on • media/call active, mic released");
            schedule(1500);
            return;
        }

        if(!SpeechRecognizer.isRecognitionAvailable(this)){
            update("Speech recognizer unavailable");
            schedule(5000);
            return;
        }
        destroyRecognizer();
        try{
            recognizer=SpeechRecognizer.createSpeechRecognizer(this);
            recognizer.setRecognitionListener(this);
            Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            configureRecognitionLanguages(i);
            i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,false);
            i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,3);
            recognizer.startListening(i);
            update("Say “Hello Anamika” or “Hello Mika”");
        }catch(Throwable t){
            destroyRecognizer();
            update("Wake recognizer retrying…");
            schedule(2000);
        }
    }

    private void schedule(long ms){
        handler.removeCallbacksAndMessages(null);
        if(!stopping)handler.postDelayed(this::startListening,ms);
    }

    private void handleText(String raw){
        String lower=raw==null?"":raw.toLowerCase(Locale.ROOT).trim();
        int pos=lower.indexOf("hello anamika");
        int len="hello anamika".length();
        if(pos<0){pos=lower.indexOf("hello mika");len="hello mika".length();}
        if(pos<0){pos=lower.indexOf("हेलो अनामिका");len="हेलो अनामिका".length();}
        if(pos<0){pos=lower.indexOf("हेलो मीका");len="हेलो मीका".length();}
        if(pos<0){pos=lower.indexOf("anamika");len="anamika".length();}
        if(pos<0){pos=lower.indexOf("mika");len="mika".length();}
        if(pos<0){pos=lower.indexOf("अनामिका");len="अनामिका".length();}
        if(pos<0){pos=lower.indexOf("मीका");len="मीका".length();}
        if(pos>=0){
            String tail=raw.substring(Math.min(raw.length(),pos+len)).trim();
            Intent open=new Intent(this,MainActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra("wake_command",tail);
            startActivity(open);
            update(tail.isEmpty()?"Wake phrase heard":"Command received");
        }
    }

    private String recognitionLanguage(){
        Locale d=Locale.getDefault();
        if("hi".equalsIgnoreCase(d.getLanguage()))return "hi-IN";
        if("IN".equalsIgnoreCase(d.getCountry()))return "hi-IN";
        return d.toLanguageTag();
    }

    private void configureRecognitionLanguages(Intent i){
        String primary=recognitionLanguage();
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE,primary);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,primary);
        if(Build.VERSION.SDK_INT>=34){
            ArrayList<String> allowed=new ArrayList<>();
            allowed.add("hi-IN");
            allowed.add("en-IN");
            i.putStringArrayListExtra(RecognizerIntent.EXTRA_LANGUAGE_DETECTION_ALLOWED_LANGUAGES,allowed);
            i.putStringArrayListExtra(RecognizerIntent.EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES,allowed);
            i.putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_DETECTION,true);
            i.putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH,RecognizerIntent.LANGUAGE_SWITCH_BALANCED);
        }
    }

    private boolean shouldYieldAudio(){
        try{
            AudioManager am=audioManager!=null?audioManager:(AudioManager)getSystemService(AUDIO_SERVICE);
            if(am==null)return false;
            int mode=am.getMode();
            if(mode==AudioManager.MODE_IN_CALL||mode==AudioManager.MODE_IN_COMMUNICATION)
                return true;
            if(am.isMusicActive())return true;
            if(Build.VERSION.SDK_INT>=24&&hasCompetingRecording(am.getActiveRecordingConfigurations()))
                return true;
            return false;
        }catch(Throwable ignored){
            return false;
        }
    }

    private void registerAudioObservers(){
        try{
            audioManager=(AudioManager)getSystemService(AUDIO_SERVICE);
            if(audioManager==null)return;

            if(Build.VERSION.SDK_INT>=26){
                playbackCallback=new AudioManager.AudioPlaybackCallback(){
                    @Override public void onPlaybackConfigChanged(List<AudioPlaybackConfiguration> configs){
                        if(stopping||!isEnabled(WakeService.this))return;
                        if(hasActivePlayback(configs)){
                            releaseForExternalAudio("media playback");
                        }else{
                            schedule(700);
                        }
                    }
                };
                audioManager.registerAudioPlaybackCallback(playbackCallback,handler);
            }

            if(Build.VERSION.SDK_INT>=24){
                recordingCallback=new AudioManager.AudioRecordingCallback(){
                    @Override public void onRecordingConfigChanged(List<AudioRecordingConfiguration> configs){
                        if(stopping||!isEnabled(WakeService.this))return;
                        if(hasCompetingRecording(configs)){
                            releaseForExternalAudio("voice/camera/social recording");
                        }else{
                            schedule(700);
                        }
                    }
                };
                audioManager.registerAudioRecordingCallback(recordingCallback,handler);
            }
        }catch(Throwable ignored){}
    }

    private boolean hasActivePlayback(List<AudioPlaybackConfiguration> configs){
        // AudioManager's playback callback supplies the currently active playback
        // configurations. Avoid hidden/system-only player-state APIs so this stays
        // compatible with the public Android SDK used by the local/CI builder.
        return configs!=null&&!configs.isEmpty();
    }

    private boolean hasCompetingRecording(List<AudioRecordingConfiguration> configs){
        if(Build.VERSION.SDK_INT<29||configs==null)return false;
        for(AudioRecordingConfiguration x:configs){
            if(x==null)continue;
            try{
                int source=x.getClientAudioSource();
                if(source==MediaRecorder.AudioSource.VOICE_RECOGNITION)
                    continue;
                return true;
            }catch(Throwable ignored){}
        }
        return false;
    }

    private void releaseForExternalAudio(String reason){
        destroyRecognizer();
        update("Wake on • "+reason+" active, mic released");
        schedule(1200);
    }

    private void unregisterAudioObservers(){
        try{
            if(audioManager!=null&&playbackCallback!=null&&Build.VERSION.SDK_INT>=26)
                audioManager.unregisterAudioPlaybackCallback(playbackCallback);
        }catch(Throwable ignored){}
        try{
            if(audioManager!=null&&recordingCallback!=null&&Build.VERSION.SDK_INT>=24)
                audioManager.unregisterAudioRecordingCallback(recordingCallback);
        }catch(Throwable ignored){}
        playbackCallback=null;
        recordingCallback=null;
        audioManager=null;
    }

    private void createChannel(){
        if(Build.VERSION.SDK_INT>=26){
            NotificationManager nm=getSystemService(NotificationManager.class);
            if(nm!=null) nm.createNotificationChannel(new NotificationChannel(
                    CHANNEL,"Anamika wake listener",NotificationManager.IMPORTANCE_LOW));
        }
    }

    private Notification notification(String text){
        Intent open=new Intent(this,MainActivity.class);
        PendingIntent pi=PendingIntent.getActivity(this,13,open,
                AndroidCompat.immutablePendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT));
        Notification.Builder b=Build.VERSION.SDK_INT>=26
                ?new Notification.Builder(this,CHANNEL):new Notification.Builder(this);
        return b.setContentTitle("Anamika")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentIntent(pi)
                .setOngoing(true)
                .build();
    }

    private void update(String text){
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(nm!=null)nm.notify(NOTIFICATION_ID,notification(text));
    }

    private void destroyRecognizer(){
        if(recognizer!=null){
            try{recognizer.cancel();}catch(Throwable ignored){}
            try{recognizer.destroy();}catch(Throwable ignored){}
            recognizer=null;
        }
    }

    @Override public void onDestroy(){
        running=false;
        stopping=true;
        handler.removeCallbacksAndMessages(null);
        destroyRecognizer();
        unregisterAudioObservers();
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent){return null;}
    @Override public void onReadyForSpeech(Bundle params){}
    @Override public void onBeginningOfSpeech(){}
    @Override public void onRmsChanged(float rmsdB){}
    @Override public void onBufferReceived(byte[] buffer){}
    @Override public void onEndOfSpeech(){}
    @Override public void onError(int error){destroyRecognizer();schedule(error==SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS?5000:1200);}
    @Override public void onResults(Bundle results){
        ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if(list!=null&&!list.isEmpty())handleText(list.get(0));
        destroyRecognizer();
        schedule(600);
    }
    @Override public void onPartialResults(Bundle partialResults){}
    @Override public void onEvent(int eventType,Bundle params){}

    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
