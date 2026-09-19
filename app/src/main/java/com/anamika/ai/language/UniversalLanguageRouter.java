package com.anamika.ai.language;

import android.content.Context;

import com.anamika.ai.LocalModelBridge;

import java.util.Locale;

/**
 * Multilingual command normalizer.
 * Known English/Hindi/Hinglish commands pass through instantly. Other scripts and
 * other Latin-script languages are normalized by the bundled on-device model when available.
 */
public final class UniversalLanguageRouter {
    private UniversalLanguageRouter(){ }

    public static String normalize(Context context,String raw){
        if(raw==null) return "";
        String s=raw.trim();
        if(s.isEmpty()) return s;
        if(looksCanonical(s)) return s;
        try{
            LocalModelBridge.ModelStatus st=LocalModelBridge.getStatus(context);
            if(!st.ready) return s;
            String prompt="Normalize this user command into one concise English assistant command. " +
                    "Preserve app names, person names, URLs, search terms, quoted text, numbers and filenames exactly. " +
                    "Do not answer or explain the command. Output only the normalized command. Input: "+s;
            String out=LocalModelBridge.generate(context,prompt);
            if(out!=null){
                out=out.trim().replace("```","");
                int nl=out.indexOf('\n');
                if(nl>0) out=out.substring(0,nl).trim();
                if(!out.isEmpty() && out.length()<=1000) return out;
            }
        }catch(Exception ignored){}
        return s;
    }

    private static boolean looksCanonical(String raw){
        String s=raw.toLowerCase(Locale.ROOT);
        String[] terms={
                "hello","hi anamika","namaste","नमस्ते","weather","mausam","मौसम",
                "youtube","google","search ","find ","dhundo","ढूंढो","खोज",
                "research","seekho","sikho","study this","learn from search",
                "remember ","yaad rakho","याद रखो","what do you remember","kya yaad hai","क्या याद है",
                "open ","khol ","खोलो ","self upgrade","khud ko upgrade","upgrade yourself",
                "update check","developer mode","coding karo","code banao","app coding","कोड बनाओ",
                "3d ","4d ","cinematic","animation","video banao","plugin","app control","settings","setting kholo","सेटिंग"
        };
        for(String t:terms) if(s.contains(t)) return true;
        return false;
    }

    public static String capability(Context context){
        boolean local=LocalModelBridge.getStatus(context).ready;
        return "Universal language mode: device speech-recognizer coverage + " +
                (local?"on-device multilingual command normalization ready":"local multilingual model not bundled; unknown languages pass through unchanged") + ".";
    }
}
