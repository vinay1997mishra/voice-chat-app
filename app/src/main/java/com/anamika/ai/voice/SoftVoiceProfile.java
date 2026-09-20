package com.anamika.ai.voice;

import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;

import com.anamika.ai.language.UniversalLanguageRouter;

import java.util.*;

public final class SoftVoiceProfile {
    private SoftVoiceProfile(){}

    public static void apply(TextToSpeech tts,String text){
        if(tts==null)return;
        Locale target=UniversalLanguageRouter.speechLocaleFor(text);
        try{
            int r=tts.setLanguage(target);
            if(r==TextToSpeech.LANG_MISSING_DATA||r==TextToSpeech.LANG_NOT_SUPPORTED){
                target=new Locale("hi","IN");
                r=tts.setLanguage(target);
                if(r==TextToSpeech.LANG_MISSING_DATA||r==TextToSpeech.LANG_NOT_SUPPORTED){
                    target=Locale.US;tts.setLanguage(target);
                }
            }
            Voice best=pickBest(tts.getVoices(),target);
            if(best!=null) tts.setVoice(best);
        }catch(Throwable ignored){}
        try{tts.setPitch(1.08f);}catch(Throwable ignored){}
        try{tts.setSpeechRate(0.92f);}catch(Throwable ignored){}
    }

    private static Voice pickBest(Set<Voice> voices,Locale target){
        if(voices==null||voices.isEmpty())return null;
        Voice best=null;int bestScore=Integer.MIN_VALUE;
        String lang=target==null?"":target.getLanguage();
        String country=target==null?"":target.getCountry();
        for(Voice v:voices){
            if(v==null||v.getLocale()==null)continue;
            Locale l=v.getLocale();
            int score=0;
            if(!lang.isEmpty()&&lang.equalsIgnoreCase(l.getLanguage()))score+=100;
            else continue;
            if(!country.isEmpty()&&country.equalsIgnoreCase(l.getCountry()))score+=25;
            String n=v.getName()==null?"":v.getName().toLowerCase(Locale.ROOT);
            if(n.contains("female")||n.contains("woman")||n.contains("girl")||n.contains("fem"))score+=18;
            if(n.contains("india")||n.contains("hi-in")||n.contains("en-in"))score+=12;
            if(n.contains("local")||!v.isNetworkConnectionRequired())score+=6;
            Set<String> f=v.getFeatures();
            if(f!=null && (f.contains("notInstalled")||f.contains("networkTts")))score-=4;
            if(score>bestScore){bestScore=score;best=v;}
        }
        return best;
    }
}
