package com.anamika.ai.voice;

import android.content.Context;
import android.content.SharedPreferences;
import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;

import com.anamika.ai.language.UniversalLanguageRouter;

import java.util.*;

public final class SoftVoiceProfile {
    private static final String PREFS="anamika_voice_profile";
    private static final String PITCH="pitch";
    private static final String RATE="rate";
    private static final String VOLUME_HINT="volume_hint";
    private static final String STYLE="style";
    private SoftVoiceProfile(){}

    public static void ensureDefaults(Context c){
        if(c==null)return;
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        if(!p.contains(PITCH)){
            p.edit().putFloat(PITCH,1.08f).putFloat(RATE,0.92f).putFloat(VOLUME_HINT,1.0f).putString(STYLE,"soft-young").apply();
        }
    }

    public static void apply(Context c,TextToSpeech tts,String text){
        if(tts==null)return;
        ensureDefaults(c);
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
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        try{tts.setPitch(clamp(p.getFloat(PITCH,1.08f),0.65f,1.45f));}catch(Throwable ignored){}
        try{tts.setSpeechRate(clamp(p.getFloat(RATE,0.92f),0.65f,1.30f));}catch(Throwable ignored){}
    }

    public static String tune(Context c,String command){
        ensureDefaults(c);
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        float pitch=p.getFloat(PITCH,1.08f);
        float rate=p.getFloat(RATE,0.92f);
        float volume=p.getFloat(VOLUME_HINT,1.0f);
        String style=p.getString(STYLE,"soft-young");
        String s=command==null?"":command.toLowerCase(Locale.ROOT);

        if(has(s,"soft","softer","aur soft","हल्की","सॉफ्ट")){ pitch-=0.02f; rate-=0.03f; volume-=0.08f; style="soft"; }
        if(has(s,"deep","deeper","gehri","गहरी")){ pitch-=0.10f; rate-=0.04f; style="deep"; }
        if(has(s,"loud","louder","tez awaaz","जोर","लाउड")){ volume+=0.12f; style="loud"; }
        if(has(s,"quiet","kam loud","halki awaaz","धीमी")){ volume-=0.12f; }
        if(has(s,"childish","child","bacchi","bachchi","बच्ची","cute voice")){ pitch+=0.13f; rate+=0.02f; style="childish"; }
        if(has(s,"young","youthful","20 year","20yrs","20 yrs")){ pitch=Math.max(pitch,1.07f); rate=Math.min(rate,0.96f); style="young"; }
        if(has(s,"mature","adult","serious")){ pitch-=0.07f; rate-=0.02f; style="mature"; }
        if(has(s,"slow","dheere","धीरे")) rate-=0.08f;
        if(has(s,"fast","jaldi bolo","तेज बोल")) rate+=0.08f;
        if(has(s,"normal voice","reset voice","default voice","voice reset")){
            pitch=1.08f;rate=0.92f;volume=1.0f;style="soft-young";
        }

        pitch=clamp(pitch,0.65f,1.45f);
        rate=clamp(rate,0.65f,1.30f);
        volume=clamp(volume,0.35f,1.50f);
        p.edit().putFloat(PITCH,pitch).putFloat(RATE,rate).putFloat(VOLUME_HINT,volume).putString(STYLE,style).apply();
        return summary(c);
    }

    public static void setFromReference(Context c,float detectedPitchHz,float energy,float syllablesPerSecond){
        ensureDefaults(c);
        float pitchFactor=1.0f;
        if(detectedPitchHz>0){
            pitchFactor=detectedPitchHz<150?0.88f:detectedPitchHz<190?0.98f:detectedPitchHz<240?1.08f:1.18f;
        }
        float rate=syllablesPerSecond<=0?0.92f:clamp(0.72f+(syllablesPerSecond*0.07f),0.72f,1.18f);
        float volume=energy<=0?1.0f:clamp(0.65f+energy*0.6f,0.55f,1.35f);
        c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit()
                .putFloat(PITCH,pitchFactor).putFloat(RATE,rate).putFloat(VOLUME_HINT,volume)
                .putString(STYLE,"reference-style").apply();
    }

    public static float volumeHint(Context c){
        ensureDefaults(c);
        return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getFloat(VOLUME_HINT,1.0f);
    }

    public static String summary(Context c){
        ensureDefaults(c);
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        return "Voice profile: "+p.getString(STYLE,"soft-young")+
                " • pitch "+String.format(Locale.US,"%.2f",p.getFloat(PITCH,1.08f))+
                " • rate "+String.format(Locale.US,"%.2f",p.getFloat(RATE,0.92f))+
                " • loudness "+String.format(Locale.US,"%.2f",p.getFloat(VOLUME_HINT,1.0f));
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
            if(!lang.isEmpty()&&lang.equalsIgnoreCase(l.getLanguage()))score+=100; else continue;
            if(!country.isEmpty()&&country.equalsIgnoreCase(l.getCountry()))score+=25;
            String n=v.getName()==null?"":v.getName().toLowerCase(Locale.ROOT);
            if(n.contains("female")||n.contains("woman")||n.contains("girl")||n.contains("fem"))score+=18;
            if(n.contains("india")||n.contains("hi-in")||n.contains("en-in"))score+=12;
            if(!v.isNetworkConnectionRequired())score+=6;
            if(score>bestScore){bestScore=score;best=v;}
        }
        return best;
    }

    private static boolean has(String s,String... terms){for(String t:terms)if(s.contains(t))return true;return false;}
    private static float clamp(float v,float lo,float hi){return Math.max(lo,Math.min(hi,v));}
}
