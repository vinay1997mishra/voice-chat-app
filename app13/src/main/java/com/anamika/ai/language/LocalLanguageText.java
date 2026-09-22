package com.anamika.ai.language;

import java.util.Locale;

/**
 * Lightweight, deterministic normalizer for Indian Hindi/Hinglish shorthand.
 *
 * This never executes a command. It only creates an interpretation hint so
 * the existing command router/offline brain can understand casual local
 * wording and common speech-to-text spellings without requiring perfect
 * grammar.
 */
public final class LocalLanguageText {
    private LocalLanguageText(){}

    public static String intentHint(String raw){
        if(raw==null)return "";
        String s=raw.trim().replaceAll("\\s+"," ");
        if(s.isEmpty())return "";

        // Common Roman-Hindi shorthand produced by fast typing and STT.
        s=token(s,"nahin|nhi|nai","nahi");
        s=token(s,"mje|muje","mujhe");
        s=token(s,"kse","kaise");
        s=token(s,"kyu","kyun");
        s=token(s,"btao","batao");
        s=token(s,"bta","bata");
        s=token(s,"rhi","rahi");
        s=token(s,"rha","raha");
        s=token(s,"rhe","rahe");
        s=token(s,"rkho","rakho");
        s=token(s,"rkh","rakh");
        s=token(s,"krdo","kar do");
        s=token(s,"kardo","kar do");
        s=token(s,"kro","karo");
        s=token(s,"kr","kar");
        s=token(s,"chl","chal");
        s=token(s,"bna","bana");
        s=token(s,"hta","hata");
        s=token(s,"lgao","lagao");
        s=token(s,"gya","gaya");
        s=token(s,"gye","gaye");
        s=token(s,"gyi","gayi");
        s=token(s,"kru","karu");
        s=token(s,"kru?","karu");
        s=token(s,"pdega|padega","padega");
        s=token(s,"pdegi|padegi","padegi");
        s=token(s,"chahiye|chaiye|chahie","chahiye");
        s=token(s,"dubara|dobara","dobara");
        s=token(s,"hoga|huga","hoga");
        s=token(s,"huye|hue","hue");
        s=token(s,"faliure|failuer","failure");
        s=token(s,"funtion|funtions","function");
        s=token(s,"funtions|functions","functions");

        // Frequent casual command endings.
        s=s.replaceAll("(?iu)\\b(?:khol|khul)\\s+(?:de|do)\\b","kholo");
        s=s.replaceAll("(?iu)\\bband\\s+kar\\s+(?:de|do)\\b","band karo");
        s=s.replaceAll("(?iu)\\bchalu\\s+kar\\s+(?:de|do)\\b","chalu karo");
        s=s.replaceAll("(?iu)\\bopen\\s+kar\\s+(?:de|do)\\b","open kar do");
        s=s.replaceAll("(?iu)\\bsearch\\s+kar\\s+(?:de|do)\\b","search kar do");
        s=s.replaceAll("(?iu)\\bcall\\s+kar\\s+(?:de|do)\\b","call kar do");

        // Assistant-name / politeness fillers should not block intent matching.
        if(s.matches("(?iu)^(?:anamika|mika)[, ]+.+"))
            s=s.replaceFirst("(?iu)^(?:anamika|mika)[, ]+","");
        s=s.replaceFirst("(?iu)^(?:please|pls|plz|zara|jara)\\s+","");
        s=s.replaceFirst("(?iu)\\s+(?:please|pls|plz)$","");

        // Frequent compressed follow-up forms from fast mobile typing.
        s=s.replaceAll("(?iu)\\bho\\s+gaya\\b","ho gaya");
        s=s.replaceAll("(?iu)\\bkar\\s+diya\\b","kar diya");
        s=s.replaceAll("(?iu)\\bnew\\s+update\\b","new update");
        s=s.replaceAll("(?iu)\\bsab\\s+kuch\\s+(?:re)?check\\s+kar(?:o)?\\b","sab kuch recheck karo");

        return s.replaceAll("\\s+"," ").trim();
    }

    public static boolean likelyHindiOrHinglish(String raw){
        if(raw==null||raw.trim().isEmpty())return false;
        for(int i=0;i<raw.length();i++){
            char c=raw.charAt(i);
            if(c>='\u0900'&&c<='\u097F')return true;
        }
        String l=intentHint(raw).toLowerCase(Locale.ROOT);
        return l.matches(".*\\b(?:hai|ho|nahi|mujhe|mera|meri|kyun|kaise|karo|kar|kholo|chalao|band|bata|batao|yaad|dhundo|dhoondo|khojo|mein|me|wala|wali|raha|rahi|rahe|thik|theek)\\b.*");
    }

    private static String token(String s,String alternatives,String replacement){
        return s.replaceAll("(?iu)\\b(?:"+alternatives+")\\b",replacement);
    }
}
