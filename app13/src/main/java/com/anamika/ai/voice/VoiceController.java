package com.anamika.ai.voice;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;

import com.anamika.ai.language.LanguageCommandInterpreter;
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
        if(!SpeechRecognizer.isRecognitionAvailable(activity)){
            listener.onVoiceState("Speech recognition is unavailable on this phone.");
            return;
        }
        stopRecognizer();
        recognizer=SpeechRecognizer.createSpeechRecognizer(activity);
        recognizer.setRecognitionListener(this);

        Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE,recognitionLanguage());
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,recognitionLanguage());
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,5);
        listener.onVoiceState("Listening… Hindi / Hinglish / English");
        recognizer.startListening(i);
    }

    public void speak(String text){
        if(!ttsReady||text==null||text.trim().isEmpty())return;
        try{
            if(containsDevanagari(text))tts.setLanguage(new Locale("hi","IN"));
            else tts.setLanguage(new Locale("en","IN"));
        }catch(Throwable ignored){}
        tts.speak(text,TextToSpeech.QUEUE_FLUSH,null,"anamika13_reply");
    }

    public void close(){
        stopRecognizer();
        if(tts!=null){tts.stop();tts.shutdown();tts=null;}
    }

    private String recognitionLanguage(){
        Locale d=Locale.getDefault();
        String lang=d.getLanguage();
        String country=d.getCountry();
        if("hi".equalsIgnoreCase(lang))return "hi-IN";
        if("en".equalsIgnoreCase(lang)&&"IN".equalsIgnoreCase(country))return "en-IN";
        // For Indian-style mixed commands, en-IN preserves many Roman/English app names.
        if("IN".equalsIgnoreCase(country))return "en-IN";
        return d.toLanguageTag();
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
    }
    @Override public void onResults(Bundle results){
        ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        String text=bestResult(list);
        stopRecognizer();
        if(!text.isEmpty())listener.onVoiceText(text);
        else listener.onVoiceState("Command clear nahi mili.");
    }
    @Override public void onPartialResults(Bundle partialResults){}
    @Override public void onEvent(int eventType,Bundle params){}
}
