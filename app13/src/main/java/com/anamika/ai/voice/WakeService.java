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
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import com.anamika.ai.MainActivity;
import com.anamika.ai.core.AndroidCompat;

import java.util.ArrayList;
import java.util.Locale;

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

    private final Handler handler=new Handler(Looper.getMainLooper());
    private SpeechRecognizer recognizer;
    private boolean stopping;
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
            return "Wake listener start requested. Keep Anamika unrestricted from battery optimization for better reliability.";
        }catch(Throwable e){
            return "Wake listener setting saved, but Android blocked background microphone service start: "+safe(e)+
                    ". Open Anamika and enable wake while the app is visible.";
        }
    }

    public static boolean isRunning(){return running;}

    public static void disable(Context c){
        c.getSharedPreferences(PREF,MODE_PRIVATE).edit().putBoolean(KEY,false).apply();
        Intent i=new Intent(c,WakeService.class).setAction(ACTION_STOP);
        try{c.startService(i);}catch(Exception ignored){c.stopService(new Intent(c,WakeService.class));}
    }

    @Override public void onCreate(){
        super.onCreate();
        running=true;
        createChannel();
        startForeground(NOTIFICATION_ID,notification("Wake listener starting…"));
        handler.post(this::startListening);
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null&&ACTION_STOP.equals(intent.getAction())){
            stopping=true;
            getSharedPreferences(PREF,MODE_PRIVATE).edit().putBoolean(KEY,false).apply();
            stopSelf();
            return START_NOT_STICKY;
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
            i.putExtra(RecognizerIntent.EXTRA_LANGUAGE,Locale.getDefault().toLanguageTag());
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
        if(pos<0){pos=lower.indexOf("anamika");len="anamika".length();}
        if(pos<0){pos=lower.indexOf("mika");len="mika".length();}
        if(pos>=0){
            String tail=raw.substring(Math.min(raw.length(),pos+len)).trim();
            Intent open=new Intent(this,MainActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra("wake_command",tail);
            startActivity(open);
            update(tail.isEmpty()?"Wake phrase heard":"Command received");
        }
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
        return b.setContentTitle("Anamika AI 13")
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
