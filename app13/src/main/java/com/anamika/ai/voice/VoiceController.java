package com.anamika.ai.voice;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;

import java.util.ArrayList;
import java.util.Locale;

/** Foreground screen voice capture + TTS. Wake-word listening lives in WakeService. */
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
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE,Locale.getDefault().toLanguageTag());
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,3);
        listener.onVoiceState("Listening…");
        recognizer.startListening(i);
    }

    public void speak(String text){
        if(ttsReady && text!=null && !text.trim().isEmpty())
            tts.speak(text,TextToSpeech.QUEUE_FLUSH,null,"anamika13_reply");
    }

    public void close(){
        stopRecognizer();
        if(tts!=null){tts.stop();tts.shutdown();tts=null;}
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
        if(ttsReady) tts.setLanguage(Locale.getDefault());
    }
    @Override public void onReadyForSpeech(Bundle params){listener.onVoiceState("Listening…");}
    @Override public void onBeginningOfSpeech(){}
    @Override public void onRmsChanged(float rmsdB){}
    @Override public void onBufferReceived(byte[] buffer){}
    @Override public void onEndOfSpeech(){listener.onVoiceState("Processing voice…");}
    @Override public void onError(int error){
        listener.onVoiceState("Voice recognition stopped ("+error+"). Tap mic to retry.");
        stopRecognizer();
    }
    @Override public void onResults(Bundle results){
        ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        String text=list==null||list.isEmpty()?"":list.get(0);
        stopRecognizer();
        if(!text.isEmpty()) listener.onVoiceText(text);
        else listener.onVoiceState("I did not hear a command.");
    }
    @Override public void onPartialResults(Bundle partialResults){}
    @Override public void onEvent(int eventType,Bundle params){}
}
