package com.anamika.ai.voice;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;

import com.anamika.ai.language.AdaptiveLanguageLearner;
import com.anamika.ai.language.LanguageCommandInterpreter;
import com.anamika.ai.language.LocalLanguageText;
import com.anamika.ai.messaging.MessageCommandParser;

import java.util.ArrayList;
import java.util.Locale;

/** Foreground voice capture + TTS tuned for Indian Hindi/Hinglish/English commands. */
public final class VoiceController implements RecognitionListener, TextToSpeech.OnInitListener {
    public interface Listener {
        void onVoiceText(String text);
        void onVoiceState(String state);
    }

    private final Activity activity;
    private final Listener listener;
    private SpeechRecognizer recognizer;
    private TextToSpeech tts;
    private boolean ttsReady;

    public VoiceController(Activity activity,Listener listener){
        this.activity=activity;
        this.listener=listener;
        tts=new TextToSpeech(activity,this);
    }

    public void listen(){
        WakeService.pauseFor(activity,30000L);
        if(!SpeechRecognizer.isRecognitionAvailable(activity)){
            listener.onVoiceState("Speech recognition is unavailable on this phone.");
            return;
        }
        stopRecognizer();
        try{
            recognizer=SpeechRecognizer.createSpeechRecognizer(activity);
            recognizer.setRecognitionListener(this);

            Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            configureRecognitionLanguages(i);
            i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
            i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,5);
            listener.onVoiceState("Listening… Hindi / Hinglish / English");
            recognizer.startListening(i);
        }catch(Throwable e){
            stopRecognizer();
            listener.onVoiceState("Voice start failed: "+safe(e));
            WakeService.resume(activity);
        }
    }

    public void speak(String text){
        if(!ttsReady||text==null||text.trim().isEmpty())return;
        try{
            if(containsDevanagari(text))tts.setLanguage(new Locale("hi","IN"));
            else tts.setLanguage(new Locale("en","IN"));
        }catch(Throwable ignored){}
        try{
            if(tts!=null)tts.speak(text,TextToSpeech.QUEUE_FLUSH,null,"anamika13_reply");
        }catch(Throwable ignored){}
    }

    public void close(){
        stopRecognizer();
        WakeService.resume(activity);
        if(tts!=null){tts.stop();tts.shutdown();tts=null;}
    }

    private String recognitionLanguage(){
        Locale d=Locale.getDefault();
        String lang=d.getLanguage();
        String country=d.getCountry();
        if("hi".equalsIgnoreCase(lang))return "hi-IN";
        // Local-language update: on Indian devices prefer the Hindi recognizer.
        // It still accepts many English app names/Hinglish words, while older Android
        // versions do not provide true automatic Hindi/English language switching.
        if("IN".equalsIgnoreCase(country))return "hi-IN";
        return d.toLanguageTag();
    }

    private void configureRecognitionLanguages(Intent i){
        String primary=recognitionLanguage();
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE,primary);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,primary);

        // Android 14+ can switch/detect Hindi and Indian English during one session.
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

    private String bestResult(ArrayList<String> list){
        if(list==null||list.isEmpty())return "";
        String best=list.get(0);
        int bestScore=score(best);
        for(int i=1;i<list.size();i++){
            String candidate=list.get(i);
            int s=score(candidate);
            if(s>bestScore){
                best=candidate;
                bestScore=s;
            }
        }
        return best==null?"":best;
    }

    private int score(String candidate){
        if(candidate==null||candidate.trim().isEmpty())return -100;
        int score=0;
        String normalized=LanguageCommandInterpreter.normalize(candidate);
        if(!normalized.equals(candidate.trim()))score+=3;
        if(MessageCommandParser.parse(candidate)!=null)score+=5;
        if(LocalLanguageText.likelyHindiOrHinglish(candidate))score+=2;
        if(!AdaptiveLanguageLearner.semanticHint(activity,candidate).isEmpty())score+=4;
        String l=normalized.toLowerCase(Locale.ROOT);
        String[] known={"open ","search ","dial ","remember ","research ","scan app ","tap ","type ",
                "calculate ","save file ","settings","functions","wake ","upgrade ","self update",
                "message status","cancel message","health","memory","vault","back"};
        for(String k:known)if(l.startsWith(k)){score+=2;break;}
        return score;
    }

    private static boolean containsDevanagari(String s){
        for(int i=0;i<s.length();i++){
            char c=s.charAt(i);
            if(c>='\u0900'&&c<='\u097F')return true;
        }
        return false;
    }

    private void stopRecognizer(){
        if(recognizer!=null){
            try{recognizer.cancel();}catch(Throwable ignored){}
            try{recognizer.destroy();}catch(Throwable ignored){}
            recognizer=null;
        }
    }

    @Override public void onInit(int status){
        ttsReady=status==TextToSpeech.SUCCESS;
        if(ttsReady){
            try{tts.setLanguage(new Locale("en","IN"));}catch(Throwable ignored){}
        }
    }
    @Override public void onReadyForSpeech(Bundle params){listener.onVoiceState("Listening…");}
    @Override public void onBeginningOfSpeech(){}
    @Override public void onRmsChanged(float rmsdB){}
    @Override public void onBufferReceived(byte[] buffer){}
    @Override public void onEndOfSpeech(){listener.onVoiceState("Command samajh rahi hu…");}
    @Override public void onError(int error){
        listener.onVoiceState("Voice recognition stopped ("+error+"). Mic dubara tap karein.");
        stopRecognizer();
        WakeService.resume(activity);
    }
    @Override public void onResults(Bundle results){
        ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        String text=bestResult(list);
        stopRecognizer();
        WakeService.resume(activity);
        if(!text.isEmpty())listener.onVoiceText(text);
        else listener.onVoiceState("Command clear nahi mili.");
    }
    @Override public void onPartialResults(Bundle partialResults){}
    @Override public void onEvent(int eventType,Bundle params){}

    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
