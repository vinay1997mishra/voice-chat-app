package com.anamika.ai;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.*;
import android.media.AudioManager;
import android.media.AudioPlaybackConfiguration;
import android.media.AudioAttributes;
import android.provider.Settings;
import android.speech.*;
import android.speech.tts.TextToSpeech;
import com.anamika.ai.plugins.AppAutomationAccessibilityService;
import com.anamika.ai.plugins.AppPluginEngine;
import com.anamika.ai.plugins.PluginRegistry;
import com.anamika.ai.language.UniversalLanguageRouter;
import com.anamika.ai.voice.SoftVoiceProfile;
import com.anamika.ai.behavior.RuntimeBehaviorPreferences;

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
    private PowerManager.WakeLock wakeLock;
    private boolean awaitingCommand=false;
    private boolean conversationSession=false;
    private boolean silencedUntilExplicitWake=false;
    private boolean ttsReady=false;
    private String pendingSpeechText="";
    private final Runnable finalizeSpeech=this::finalizePendingSpeech;
    private AudioManager audioManager;
    private boolean mediaPlaybackActive=false;
    private AudioManager.AudioPlaybackCallback playbackCallback;
    private final Runnable mediaPoll=this::pollMediaPlayback;
    private boolean explicitStop=false;

    @Override public void onCreate(){
        super.onCreate();
        running=true;
        createChannel();
        try{
            PowerManager pm=(PowerManager)getSystemService(POWER_SERVICE);
            if(pm!=null){
                wakeLock=pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"AnamikaAI:BackgroundWake");
                wakeLock.setReferenceCounted(false);
            }
        }catch(Throwable ignored){}
        tts=new TextToSpeech(this,this);
        audioManager=(AudioManager)getSystemService(AUDIO_SERVICE);
        if(Build.VERSION.SDK_INT>=26 && audioManager!=null){
            playbackCallback=new AudioManager.AudioPlaybackCallback(){
                @Override public void onPlaybackConfigChanged(java.util.List<AudioPlaybackConfiguration> configs){
                    handleMediaPlaybackState(isSystemAudioBusy());
                }
            };
            try{ audioManager.registerAudioPlaybackCallback(playbackCallback,handler); }catch(Throwable ignored){}
        }
        RuntimeBehaviorPreferences.ensureDefaults(this);
        handler.postDelayed(mediaPoll,700L);
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        String action=intent==null?ACTION_START:intent.getAction();
        boolean enabled=getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false);
        if(!OwnerSession.isTrusted(this) && !ACTION_STOP.equals(action)){
            stopSelf();
            return START_NOT_STICKY;
        }
        if(ACTION_STOP.equals(action)){
            explicitStop=true;
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",false).apply();
            conversationSession=false;
            awaitingCommand=false;
            stopListening();
            releaseWakeLock();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }
        if(!enabled && OwnerSession.isTrusted(this)){
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",true).apply();
            enabled=true;
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
        acquireWakeLock();
        startForeground(NOTIFICATION_ID,notification("Listening for Hello Mika / Hello Anamika"));
        handler.postDelayed(this::startListening,500L);
        return START_STICKY;
    }

    private Notification notification(String text){
        Intent open=new Intent(this,MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent pi=PendingIntent.getActivity(this,1,open,
                PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,CHANNEL)
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle("Anamika AI • 24×7 Wake")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pi)
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
        if(isMediaPlaybackNow()){
            mediaPlaybackActive=true;
            stopListening();
            updateNotification("Media/voice chat active • wake mic parked to avoid audio or microphone conflict");
            return;
        }
        if(!OwnerSession.isTrusted(this)){
            stopSelf(); return;
        }
        if(!getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false)){
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",true).apply();
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
                updateNotification(conversationSession
                        ?"Conversation active • bolte rahiye"
                        :(awaitingCommand?"Listening for your command":"Listening for Hello Mika / Hello Anamika"));
            }
            @Override public void onBeginningOfSpeech(){
                handler.removeCallbacks(finalizeSpeech);
            }
            @Override public void onRmsChanged(float rmsdB){
                if(rmsdB>1.5f) handler.removeCallbacks(finalizeSpeech);
            }
            @Override public void onBufferReceived(byte[] buffer){}
            @Override public void onEndOfSpeech(){
                scheduleSpeechFinalize();
            }
            @Override public void onError(int error){
                if(!pendingSpeechText.trim().isEmpty()) scheduleSpeechFinalize();
                else restart(700L);
            }
            @Override public void onResults(Bundle results){
                ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if(list!=null&&!list.isEmpty()) pendingSpeechText=list.get(0).trim();
                scheduleSpeechFinalize();
            }
            @Override public void onPartialResults(Bundle partialResults){
                ArrayList<String> list=partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if(list!=null&&!list.isEmpty()){
                    pendingSpeechText=list.get(0).trim();
                    handler.removeCallbacks(finalizeSpeech);
                    handler.postDelayed(finalizeSpeech,RuntimeBehaviorPreferences.silenceMs(BackgroundWakeService.this));
                }
            }
            @Override public void onEvent(int eventType,Bundle params){}
        });
        Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,RuntimeBehaviorPreferences.silenceMs(BackgroundWakeService.this));
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,RuntimeBehaviorPreferences.silenceMs(BackgroundWakeService.this));
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,1000L);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION",true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH",true);
        try{ recognizer.startListening(i); }catch(Throwable t){ restart(1500L); }
    }

    private void scheduleSpeechFinalize(){
        handler.removeCallbacks(finalizeSpeech);
        handler.postDelayed(finalizeSpeech,RuntimeBehaviorPreferences.silenceMs(BackgroundWakeService.this));
    }

    private void finalizePendingSpeech(){
        String heard=pendingSpeechText==null?"":pendingSpeechText.trim();
        pendingSpeechText="";
        if(heard.isEmpty()){
            restart(350L);
            return;
        }
        handle(heard);
    }

    private void handle(String heard){
        if(heard==null || heard.trim().isEmpty()){ restart(350L); return; }
        String clean=heard.trim();
        String lower=clean.toLowerCase(Locale.ROOT);

        boolean explicitHelloWake=Pattern.compile("(?i)(?:hello|hey|hi)\\s+(?:anamika|mika)").matcher(clean).find();
        boolean shortWake=RuntimeBehaviorPreferences.shortWakeEnabled(this) &&
                (lower.equals("anamika") || lower.equals("mika"));

        if(silencedUntilExplicitWake){
            if(!explicitHelloWake){
                restart(250L);
                return;
            }
            silencedUntilExplicitWake=false;
            conversationSession=true;
        }

        if(conversationSession && isConversationStopCommand(lower)){
            conversationSession=false;
            awaitingCommand=false;
            silencedUntilExplicitWake=RuntimeBehaviorPreferences.explicitWakeAfterSilence(this);
            // Owner asked for silence: do not speak any acknowledgement.
            restart(250L);
            return;
        }

        Matcher wake=Pattern.compile("(?i)(?:(?:hello|hey|hi)\\s+)?(?:anamika|mika)").matcher(clean);
        if(wake.find() && (explicitHelloWake || shortWake || !conversationSession)){
            conversationSession=true;
            String after=clean.substring(wake.end()).replaceFirst("^[\\s,.:;-]+","").trim();
            if(after.isEmpty()){
                awaitingCommand=true;
                speakThen("Ji, boliye.",700L);
            }else{
                awaitingCommand=false;
                executeCommand(after);
            }
            return;
        }

        if(conversationSession || awaitingCommand){
            awaitingCommand=false;
            conversationSession=true;
            executeCommand(clean);
            return;
        }

        restart(250L);
    }

    private boolean isConversationStopCommand(String lower){
        if(lower==null) return false;
        return lower.equals("bas") ||
                lower.equals("bas karo") ||
                lower.equals("bas abhi chup hoja") ||
                lower.equals("bas ab chup hoja") ||
                lower.equals("abhi chup hoja") ||
                lower.equals("chup hoja") ||
                lower.equals("chup ho ja") ||
                lower.equals("خاموش ہو جاؤ") ||
                lower.equals("بس اب خاموش ہو جاؤ") ||
                lower.equals("stop listening") ||
                lower.equals("conversation band karo") ||
                lower.equals("baat band karo") ||
                lower.equals("so jao") ||
                lower.equals("sleep anamika") ||
                lower.equals("stop anamika") ||
                lower.equals("enough");
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
            SoftVoiceProfile.apply(this,tts,text);
            android.os.Bundle params=new android.os.Bundle();
            params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME,
                    Math.max(0.1f,Math.min(1.0f,SoftVoiceProfile.volumeHint(this))));
            tts.speak(text,TextToSpeech.QUEUE_FLUSH,params,"bg_wake");
        }
        handler.postDelayed(this::startListening,restartDelay);
    }

    private void restart(long delay){
        if(mediaPlaybackActive || isMediaPlaybackNow()){
            mediaPlaybackActive=true;
            stopListening();
            updateNotification("Media/voice chat active • wake mic parked to avoid audio or microphone conflict");
            return;
        }
        handler.postDelayed(this::startListening,delay);
    }

    private boolean isSystemAudioBusy(){
        try{
            if(audioManager!=null){
                if(audioManager.isMusicActive()) return true;
                int mode=audioManager.getMode();
                if(mode==AudioManager.MODE_IN_COMMUNICATION ||
                        mode==AudioManager.MODE_IN_CALL ||
                        mode==AudioManager.MODE_CALL_SCREENING){
                    return true;
                }
            }
        }catch(Throwable ignored){}
        return false;
    }

    private boolean isMediaPlaybackNow(){
        return isSystemAudioBusy();
    }

    private void handleMediaPlaybackState(boolean active){
        if(active){
            if(!mediaPlaybackActive){
                mediaPlaybackActive=true;
                stopListening();
                updateNotification("Media/voice chat active • wake mic parked to avoid audio or microphone conflict");
            }
            return;
        }
        if(mediaPlaybackActive){
            mediaPlaybackActive=false;
            updateNotification(conversationSession
                    ?"Media/voice chat ended • resuming conversation"
                    :"Media/voice chat ended • resuming Hello Mika / Hello Anamika");
            handler.postDelayed(() -> {
                if(!mediaPlaybackActive && getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false)){
                    startListening();
                }
            },700L);
        }
    }

    private void pollMediaPlayback(){
        boolean active=isSystemAudioBusy();
        handleMediaPlaybackState(active);
        handler.postDelayed(mediaPoll,1000L);
    }

    private void stopListening(){
        handler.removeCallbacks(finalizeSpeech);
        pendingSpeechText="";
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

    private void acquireWakeLock(){
        try{
            if(wakeLock!=null && !wakeLock.isHeld()) wakeLock.acquire();
        }catch(Throwable ignored){}
    }

    private void releaseWakeLock(){
        try{
            if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
        }catch(Throwable ignored){}
    }

    @Override public void onInit(int status){
        ttsReady=status==TextToSpeech.SUCCESS;
        if(ttsReady){
            SoftVoiceProfile.apply(this,tts,"Ji, boliye.");
        }
    }

    public static boolean isRunning(){ return running; }

    private void scheduleRecovery(long delayMs){
        if(explicitStop) return;
        if(!OwnerSession.isTrusted(this)) return;
        if(!getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean("wake_enabled",false)) return;
        try{
            Intent i=new Intent(this,WakeRecoveryReceiver.class);
            PendingIntent pi=PendingIntent.getBroadcast(this,7821,i,
                    PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
            AlarmManager am=(AlarmManager)getSystemService(ALARM_SERVICE);
            if(am!=null){
                long at=SystemClock.elapsedRealtime()+Math.max(1500L,delayMs);
                am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,at,pi);
            }
        }catch(Throwable ignored){}
    }

    @Override public void onTaskRemoved(Intent rootIntent){
        if(OwnerSession.isTrusted(this)){
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putBoolean("wake_enabled",true).apply();
            handler.postDelayed(this::startListening,300L);
            scheduleRecovery(2200L);
        }
        super.onTaskRemoved(rootIntent);
    }

    @Override public void onDestroy(){
        running=false;
        if(!explicitStop) scheduleRecovery(2500L);
        handler.removeCallbacksAndMessages(null);
        if(Build.VERSION.SDK_INT>=26 && audioManager!=null && playbackCallback!=null){
            try{audioManager.unregisterAudioPlaybackCallback(playbackCallback);}catch(Throwable ignored){}
        }
        stopListening();
        releaseWakeLock();
        if(tts!=null){ try{tts.stop();tts.shutdown();}catch(Throwable ignored){} }
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent){ return null; }
}
