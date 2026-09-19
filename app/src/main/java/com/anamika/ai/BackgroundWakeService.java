package com.anamika.ai;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.*;
import android.provider.Settings;
import android.speech.*;
import android.speech.tts.TextToSpeech;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.AppPluginEngine;
import com.anamika.ai.plugins.PluginRegistry;

import java.util.*;
import java.util.regex.*;

/**
 * Best-effort 24x7 foreground wake service.
 * Keeps an ongoing notification while microphone wake listening is active.
 * Android/OEM battery controls can still stop background microphone work.
 */
public final class BackgroundWakeService extends Service implements TextToSpeech.OnInitListener {
    public static final String ACTION_START="com.anamika.ai.action.START_WAKE";
    public static final String ACTION_STOP="com.anamika.ai.action.STOP_WAKE";
    public static final String ACTION_PAUSE="com.anamika.ai.action.PAUSE_WAKE";
    public static final String ACTION_RESUME="com.anamika.ai.action.RESUME_WAKE";
    private static final String CHANNEL="anamika_wake";
    private static final int NOTIFICATION_ID=782;
    private static final String PREFS="anamika_v7";
    private static volatile boolean running=false;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private SpeechRecognizer recognizer;
    private TextToSpeech tts;
    private boolean awaitingCommand=false;
    private boolean ttsReady=false;

    @Override public void onCreate(){
        super.onCreate();
        running=true;
        createChannel();
        tts=new TextToSpeech(this,this);
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        String action=intent==null?ACTION_START:intent.getAction();
        if(ACTION_STOP.equals(action)){
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",false).apply();
            stopListening();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }
        if(ACTION_PAUSE.equals(action)){
            stopListening();
            updateNotification("Paused while manual microphone is active");
            return START_STICKY;
        }
        if(ACTION_RESUME.equals(action)){
            if(getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false)){
                handler.postDelayed(this::startListening,350L);
            }
            return START_STICKY;
        }
        getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",true).apply();
        startForeground(NOTIFICATION_ID,notification("Listening for Hello Mika / Hello Anamika"));
        handler.postDelayed(this::startListening,500L);
        return START_STICKY;
    }

    private Notification notification(String text){
        Intent open=new Intent(this,MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent pi=PendingIntent.getActivity(this,1,open,
                PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Intent stop=new Intent(this,BackgroundWakeService.class).setAction(ACTION_STOP);
        PendingIntent stopPi=PendingIntent.getService(this,2,stop,
                PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,CHANNEL)
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle("Anamika AI • 24×7 Wake")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pi)
                .addAction(new Notification.Action.Builder(
                        android.R.drawable.ic_delete,"Stop",stopPi).build())
                .build();
    }

    private void createChannel(){
        if(Build.VERSION.SDK_INT>=26){
            NotificationChannel c=new NotificationChannel(
                    CHANNEL,"Anamika 24×7 Wake",NotificationManager.IMPORTANCE_LOW);
            c.setDescription("Keeps Anamika listening for the owner wake phrase.");
            ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);
        }
    }

    private void updateNotification(String text){
        ((NotificationManager)getSystemService(NOTIFICATION_SERVICE))
                .notify(NOTIFICATION_ID,notification(text));
    }

    private void startListening(){
        if(!getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false)){
            stopSelf(); return;
        }
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){
            updateNotification("Microphone permission required");
            return;
        }
        if(!SpeechRecognizer.isRecognitionAvailable(this)){
            updateNotification("Speech recognition unavailable");
            handler.postDelayed(this::startListening,5000L);
            return;
        }
        stopListening();
        recognizer=SpeechRecognizer.createSpeechRecognizer(this);
        recognizer.setRecognitionListener(new RecognitionListener(){
            @Override public void onReadyForSpeech(Bundle params){
                updateNotification(awaitingCommand?"Listening for your command":"Listening for Hello Mika / Hello Anamika");
            }
            @Override public void onBeginningOfSpeech(){}
            @Override public void onRmsChanged(float rmsdB){}
            @Override public void onBufferReceived(byte[] buffer){}
            @Override public void onEndOfSpeech(){}
            @Override public void onError(int error){ restart(900L); }
            @Override public void onResults(Bundle results){
                ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                handle(list==null||list.isEmpty()?"":list.get(0));
            }
            @Override public void onPartialResults(Bundle partialResults){}
            @Override public void onEvent(int eventType,Bundle params){}
        });
        Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION",true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH",true);
        try{ recognizer.startListening(i); }catch(Throwable t){ restart(1500L); }
    }

    private void handle(String heard){
        if(heard==null || heard.trim().isEmpty()){ restart(600L); return; }
        Matcher wake=Pattern.compile("(?i)(?:hello|hey|hi)\\s+(?:anamika|mika)").matcher(heard.trim());
        if(wake.find()){
            String after=heard.substring(wake.end()).replaceFirst("^[\\s,.:;-]+","").trim();
            if(after.isEmpty()){
                awaitingCommand=true;
                speakThen("Ji, boliye.",1800L);
            }else{
                awaitingCommand=false;
                speakThen("Ji.",500L);
                handler.postDelayed(() -> executeCommand(after),650L);
            }
            return;
        }
        if(awaitingCommand){
            awaitingCommand=false;
            executeCommand(heard.trim());
            return;
        }
        restart(500L);
    }

    private void executeCommand(String command){
        if(command==null || command.trim().isEmpty()){ restart(500L); return; }
        String lower=command.toLowerCase(Locale.ROOT).trim();

        // Owner explicitly enabled 24x7 mode after PIN. Refresh short session only while device is unlocked.
        try{
            android.app.KeyguardManager km=(android.app.KeyguardManager)getSystemService(KEYGUARD_SERVICE);
            if(km==null || !km.isDeviceLocked()) OwnerSession.grant(this);
        }catch(Throwable ignored){}

        if(AppAutomationAccessibilityService.performOwnerPhoneCommand(this,command)){
            speakThen("Done.",900L); return;
        }

        if(containsAny(lower,"whatsapp") && containsAny(lower,"message","msg","bhejo","send ")){
            if(!OwnerSession.isActive(this)){
                speakThen("Phone locked hai. Unlock ke baad message command dijiye.",1600L); return;
            }
            String[] parsed=parseWhatsApp(command);
            if(parsed!=null){
                String r=AppPluginEngine.openAndRunOneShot(this,"com.whatsapp",
                        "whatsapp-message|"+parsed[0]+"|"+parsed[1]);
                speakThen(r.startsWith("App opened")?"WhatsApp command chala diya.":r,1400L);
                return;
            }
        }

        Matcher m=Pattern.compile(
                "(?i)^(?:open|khol|kholo|खोलो)\\s+(.+?)(?:\\s+(?:aur|then|phir|fir|uske baad|and then)\\s+(.+))?$"
        ).matcher(command.trim());
        if(!m.find()){
            m=Pattern.compile(
                    "(?i)^(.+?)\\s+(?:app\\s+)?(?:open|khol|kholo|खोलो)\\s*(?:karo|kar|do)?(?:\\s+(?:aur|then|phir|fir|uske baad|and then)\\s+(.+))?$"
            ).matcher(command.trim());
        }
        if(m.find()){
            String app=m.group(1).trim().replaceFirst("(?i)\\s+app$","").trim();
            String action=m.group(2)==null?"":m.group(2).trim();
            String pkg=findPackage(app);
            if(pkg!=null){
                String r;
                if(action.isEmpty()) r=AppPluginEngine.openAny(this,pkg);
                else if(OwnerSession.isActive(this)) r=AppPluginEngine.openAndRunOneShot(this,pkg,action);
                else r=AppPluginEngine.openAny(this,pkg);
                speakThen(app+" khol diya.",1200L);
                return;
            }
        }

        // Fallback: bring the main command center forward with the recognized command.
        Intent open=new Intent(this,MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP);
        open.putExtra("background_voice_command",command);
        try{
            startActivity(open);
            speakThen("Command Anamika screen par bhej diya.",1200L);
        }catch(Throwable t){
            speakThen("Command mila, lekin Android ne screen open karne se roka.",1500L);
        }
    }

    private String findPackage(String appName){
        String n=appName==null?"":appName.toLowerCase(Locale.ROOT).trim();
        if(n.contains("whatsapp")) return "com.whatsapp";
        if(n.contains("youtube")) return "com.google.android.youtube";
        if(n.contains("chrome")) return "com.android.chrome";
        if(n.contains("instagram")) return "com.instagram.android";
        if(n.contains("telegram")) return "org.telegram.messenger";
        return PluginRegistry.findPackageByLabel(this,appName);
    }

    private String[] parseWhatsApp(String command){
        Matcher hi=Pattern.compile("(?i)([\\p{L}\\p{N}._ -]{1,45})\\s+ko\\s+(?:msg|message)\\s+(?:kar|karo|bhejo|send)?\\s*(.+)$").matcher(command);
        if(hi.find()){
            String who=hi.group(1).trim().replaceFirst("(?i)^.*(?:waha|wahaan|aur|then)\\s+","");
            String body=hi.group(2).trim();
            who=who.replaceFirst("(?i)^whatsapp\\s+(?:open|khol|kholo)\\s*(?:kar|karo)?\\s*","");
            if(!who.isEmpty()&&!body.isEmpty()) return new String[]{who,body};
        }
        return null;
    }

    private void speakThen(String text,long restartDelay){
        stopListening();
        if(ttsReady && tts!=null){
            tts.speak(text,TextToSpeech.QUEUE_FLUSH,null,"bg_wake");
        }
        handler.postDelayed(this::startListening,restartDelay);
    }

    private void restart(long delay){
        handler.postDelayed(this::startListening,delay);
    }

    private void stopListening(){
        if(recognizer!=null){
            try{ recognizer.cancel(); }catch(Throwable ignored){}
            try{ recognizer.destroy(); }catch(Throwable ignored){}
            recognizer=null;
        }
    }

    private static boolean containsAny(String text,String... terms){
        for(String t:terms) if(text.contains(t)) return true;
        return false;
    }

    @Override public void onInit(int status){
        ttsReady=status==TextToSpeech.SUCCESS;
        if(ttsReady){
            int r=tts.setLanguage(Locale.getDefault());
            if(r==TextToSpeech.LANG_MISSING_DATA||r==TextToSpeech.LANG_NOT_SUPPORTED)
                tts.setLanguage(new Locale("hi","IN"));
        }
    }

    public static boolean isRunning(){ return running; }

    @Override public void onDestroy(){
        running=false;
        handler.removeCallbacksAndMessages(null);
        stopListening();
        if(tts!=null){ try{tts.stop();tts.shutdown();}catch(Throwable ignored){} }
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent){ return null; }
}
