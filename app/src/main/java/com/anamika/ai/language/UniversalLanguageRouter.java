package com.anamika.ai.language;

import android.content.Context;
import com.anamika.ai.LocalModelBridge;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class UniversalLanguageRouter {
    public enum Style { HINDI, HINGLISH, ENGLISH, OTHER }

    public static final class Interpretation {
        public final String original, normalized, intent, argument;
        public final Style style;
        public final boolean modelUsed;
        public Interpretation(String original,String normalized,String intent,String argument,Style style,boolean modelUsed){
            this.original=original==null?"":original;
            this.normalized=normalized==null?"":normalized;
            this.intent=intent==null?"UNKNOWN":intent;
            this.argument=argument==null?"":argument;
            this.style=style==null?Style.OTHER:style;
            this.modelUsed=modelUsed;
        }
    }

    private UniversalLanguageRouter(){}

    public static String normalize(Context context,String raw){
        return interpret(context,raw).normalized;
    }

    public static Interpretation interpret(Context context,String raw){
        String original=raw==null?"":raw.trim();
        if(original.isEmpty()) return new Interpretation("","","EMPTY","",Style.OTHER,false);
        Style style=detectStyle(original);
        Interpretation quick=quickInterpret(original,style);
        if(!"UNKNOWN".equals(quick.intent)) return quick;

        try{
            LocalModelBridge.ModelStatus st=LocalModelBridge.getStatus(context);
            if(st.ready){
                String prompt=
                        "You are Anamika's multilingual intent parser. Understand Hindi, Hinglish, English and any human language.\\n"+
                        "Return exactly four lines and nothing else:\\n"+
                        "INTENT=<CHAT|SEARCH|YOUTUBE_SEARCH|OPEN_APP|PHONE_CONTROL|APP_AUDIT|CREATE_APP|CREATE_WEBSITE|CODE|RESEARCH|REMEMBER|RECALL|SELF_UPGRADE|UPDATE|SETTINGS|PLUGIN|MEDIA|UNKNOWN>\\n"+
                        "ARG=<main target/query/message; preserve names, URLs, quoted text, numbers and filenames>\\n"+
                        "NORMALIZED=<one concise English command preserving meaning>\\n"+
                        "STYLE=<HINDI|HINGLISH|ENGLISH|OTHER>\\n"+
                        "If the user is talking or asking a general question use CHAT. Do not answer or explain.\\n"+
                        "User: "+original;
                Interpretation parsed=parseModel(original,LocalModelBridge.generate(context,prompt),style);
                if(parsed!=null) return parsed;
            }
        }catch(Throwable ignored){}
        return new Interpretation(original,original,"UNKNOWN","",style,false);
    }

    private static Interpretation quickInterpret(String original,Style style){
        String s=original.toLowerCase(Locale.ROOT).trim();
        if(matchesAny(s,"नमस्ते","नमस्कार","hello","hi anamika","hello anamika","hey anamika","namaste"))
            return new Interpretation(original,original,"CHAT",original,style,false);

        String y=extractYouTubeSearch(original);
        if(y!=null) return new Interpretation(original,"youtube search "+y,"YOUTUBE_SEARCH",y,style,false);

        String q=extractSearch(original);
        if(q!=null) return new Interpretation(original,"search "+q,"SEARCH",q,style,false);

        if(containsAny(s,"पूरे app","पूरा app","सारे function","सारे functions","deep audit","full app check",
                "poora app","pura app","saare function","sare function","blueprint bana","auto audit"))
            return new Interpretation(original,original,"APP_AUDIT",original,style,false);

        if(containsAny(s,"app banao","app bana","एप बनाओ","ऐप बनाओ","create app","make app"))
            return new Interpretation(original,original,"CREATE_APP",original,style,false);
        if(containsAny(s,"website banao","वेबसाइट बनाओ","create website","make website"))
            return new Interpretation(original,original,"CREATE_WEBSITE",original,style,false);
        if(containsAny(s,"code likho","कोड लिखो","coding karo","code banao","write code"))
            return new Interpretation(original,original,"CODE",original,style,false);

        if(containsAny(s,"yaad rakho","याद रखो","remember "))
            return new Interpretation(original,original,"REMEMBER",stripPrefix(original,"yaad rakho","याद रखो","remember"),style,false);
        if(containsAny(s,"kya yaad hai","क्या याद है","what do you remember"))
            return new Interpretation(original,original,"RECALL","",style,false);

        if(containsAny(s,"self upgrade","khud ko upgrade","खुद को अपग्रेड","upgrade yourself"))
            return new Interpretation(original,original,"SELF_UPGRADE",original,style,false);
        if(containsAny(s,"plugin","प्लगइन"))
            return new Interpretation(original,original,"PLUGIN",original,style,false);
        if(containsAny(s,"settings","setting kholo","सेटिंग","सेटिंग्स"))
            return new Interpretation(original,original,"SETTINGS",original,style,false);
        if(looksOpenApp(s))
            return new Interpretation(original,original,"OPEN_APP",original,style,false);

        return new Interpretation(original,original,"UNKNOWN","",style,false);
    }

    private static Interpretation parseModel(String original,String out,Style fallback){
        if(out==null||out.trim().isEmpty()) return null;
        String intent="",arg="",norm="",styleText="";
        for(String rawLine:out.split("\\r?\\n")){
            String line=rawLine.trim();
            int eq=line.indexOf('=');
            if(eq<=0) continue;
            String k=line.substring(0,eq).trim().toUpperCase(Locale.ROOT);
            String v=line.substring(eq+1).trim();
            if("INTENT".equals(k)) intent=v.toUpperCase(Locale.ROOT);
            else if("ARG".equals(k)) arg=v;
            else if("NORMALIZED".equals(k)) norm=v;
            else if("STYLE".equals(k)) styleText=v.toUpperCase(Locale.ROOT);
        }
        if(intent.isEmpty()) return null;
        if(norm.isEmpty()) norm=original;
        Style style=fallback;
        try{ if(!styleText.isEmpty()) style=Style.valueOf(styleText); }catch(Exception ignored){}
        return new Interpretation(original,norm,intent,arg,style,true);
    }

    public static Style detectStyle(String raw){
        if(raw==null||raw.trim().isEmpty()) return Style.OTHER;
        int devanagari=0,latin=0;
        String lower=raw.toLowerCase(Locale.ROOT);
        for(int i=0;i<raw.length();i++){
            char ch=raw.charAt(i);
            if(ch>=0x0900 && ch<=0x097F) devanagari++;
            else if((ch>='a'&&ch<='z')||(ch>='A'&&ch<='Z')) latin++;
        }
        if(devanagari>0) return Style.HINDI;
        if(latin>0 && containsAny(lower,"kya","kaise","kar","karo","karna","mujhe","mera","meri","hai","ho","nahi","nhi",
                "bata","bta","dhundo","dhoondo","khol","kholo","yaad","rakho","bolo","bol","chahiye","wala","wali","waha",
                "yaha","isme","usme","sab","saare","sare","fir","phir","aur","abhi")) return Style.HINGLISH;
        if(latin>0) return Style.ENGLISH;
        return Style.OTHER;
    }

    public static Locale speechLocaleFor(String text){
        Style s=detectStyle(text);
        if(s==Style.HINDI || s==Style.HINGLISH) return new Locale("hi","IN");
        if(s==Style.ENGLISH) return Locale.US;
        return Locale.getDefault();
    }

    public static String replyInstruction(Style style){
        if(style==Style.HINDI) return "Reply naturally in simple Hindi using Devanagari script.";
        if(style==Style.HINGLISH) return "Reply naturally in easy conversational Hinglish using Roman letters, like the user.";
        if(style==Style.ENGLISH) return "Reply naturally in English.";
        return "Reply naturally in the same language as the user.";
    }

    private static String extractSearch(String raw){
        String s=raw.trim(), lower=s.toLowerCase(Locale.ROOT);
        String[] prefixes={"search ","google ","dhundo ","dhoondo ","khojo ","find ","खोजो ","ढूंढो ","ढूँढो ","सर्च ","गूगल "};
        for(String p:prefixes) if(lower.startsWith(p.toLowerCase(Locale.ROOT))) return clean(s.substring(p.length()));

        String[] suffixes={" search karo"," search kar"," google karo"," google par search karo"," dhundo"," dhoondo"," khojo",
                " pata karo"," ke bare me pata karo"," सर्च करो"," खोजो"," ढूंढो"," ढूँढो"," पता करो"};
        for(String suf:suffixes){
            String l=suf.toLowerCase(Locale.ROOT);
            if(lower.endsWith(l) && s.length()>suf.length()) return clean(s.substring(0,s.length()-suf.length()));
        }

        Matcher m=Pattern.compile("(?i)(?:google|internet|web)\\\\s+(?:par|pe|में|पर)?\\\\s*(?:search|सर्च|खोज)\\\\s*(?:karo|kar|करो)?\\\\s*(.+)").matcher(s);
        if(m.find()) return clean(m.group(1));
        return null;
    }

    private static String extractYouTubeSearch(String raw){
        String lower=raw.toLowerCase(Locale.ROOT);
        if(!lower.contains("youtube") && !lower.contains("यूट्यूब")) return null;
        Matcher m=Pattern.compile("(?i)(?:youtube|यूट्यूब)(?:\\\\s+(?:par|pe|में|पर))?\\\\s*(?:search|सर्च|dhundo|dhoondo|ढूंढो|खोजो)?\\\\s*(?:karo|kar|करो)?\\\\s*(.*)").matcher(raw.trim());
        if(m.matches()){
            String q=clean(m.group(1));
            if(!q.isEmpty()) return q;
        }
        return null;
    }

    private static String clean(String q){
        if(q==null) return "";
        return q.trim().replaceFirst("(?i)^(?:ki|ke|ka|about|for)\\\\s+","");
    }

    private static boolean looksOpenApp(String s){
        return s.startsWith("open ")||s.startsWith("khol ")||s.startsWith("kholo ")||s.startsWith("खोलो ")||
                s.contains(" app kholo")||s.contains(" app open");
    }

    private static String stripPrefix(String raw,String... prefixes){
        String lower=raw.toLowerCase(Locale.ROOT);
        for(String p:prefixes){
            int i=lower.indexOf(p.toLowerCase(Locale.ROOT));
            if(i>=0) return raw.substring(i+p.length()).trim();
        }
        return raw;
    }

    private static boolean matchesAny(String text,String... values){ for(String v:values) if(text.equals(v)) return true; return false; }
    private static boolean containsAny(String text,String... terms){ for(String t:terms) if(text.contains(t)) return true; return false; }

    public static String capability(Context context){
        boolean local=LocalModelBridge.getStatus(context).ready;
        return "Universal human-language mode: Hindi + Hinglish + English fast routing; "+
                (local
                        ?"bundled local AI intent understanding and same-language conversation are ready. Other languages use the same local intent/reply path."
                        :"local AI model is unavailable, so deterministic Hindi/Hinglish/English commands remain available but free conversation is limited.");
    }
}
