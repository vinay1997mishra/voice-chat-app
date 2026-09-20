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

        Interpretation learned=loadLearned(context,original,style);
        if(learned!=null) return learned;

        Interpretation quick=quickInterpret(original,style);
        if(!"UNKNOWN".equals(quick.intent)) {
            remember(context,quick);
            return quick;
        }

        try{
            LocalModelBridge.ModelStatus st=LocalModelBridge.getStatus(context);
            if(st.ready){
                String prompt=
                        "You are Anamika's multilingual intent parser. Understand Hindi, Hinglish, English and any human language.\\n"+
                        "Return exactly four lines and nothing else:\\n"+
                        "INTENT=<CHAT|SEARCH|YOUTUBE_SEARCH|YOUTUBE_LEARN|OPEN_APP|PHONE_CONTROL|SYSTEM_SETTING|READ_SCREEN|EXPLAIN_SCREEN|CALCULATE|CALL|CONTACT_SEARCH|MESSAGE|FILE_SEARCH|VAULT_STATUS|FILE_EXPORT|FILE_DELETE|APP_AUDIT|CREATE_APP|CREATE_WEBSITE|CODE|RESEARCH|REMEMBER|RECALL|SELF_UPGRADE|UPDATE|SETTINGS|PLUGIN|MEDIA|UNKNOWN_LOOKUP|UNKNOWN>\\n"+
                        "ARG=<main target/query/message; preserve names, URLs, quoted text, numbers and filenames>\\n"+
                        "NORMALIZED=<one concise English command preserving meaning>\\n"+
                        "STYLE=<HINDI|HINGLISH|ENGLISH|OTHER>\\n"+
                        "If the user is talking or asking a general question use CHAT. Do not answer or explain.\\n"+
                        "User: "+original;
                Interpretation parsed=parseModel(original,LocalModelBridge.generate(context,prompt),style);
                if(parsed!=null) {
                    remember(context,parsed);
                    return parsed;
                }
            }
        }catch(Throwable ignored){}
        return new Interpretation(original,original,"UNKNOWN","",style,false);
    }

    private static final String LEARN_PREFS="anamika_language_learning";

    private static Interpretation loadLearned(Context context,String original,Style fallback){
        if(context==null || original==null) return null;
        String key="p_"+Integer.toHexString(normalizePhrase(original).hashCode());
        String packed=context.getSharedPreferences(LEARN_PREFS,Context.MODE_PRIVATE).getString(key,"");
        if(packed.isEmpty()) return null;
        String[] parts=packed.split("\\n",-1);
        if(parts.length<3) return null;
        try{
            String intent=parts[0];
            String normalized=parts[1];
            Style style=parts[2].isEmpty()?fallback:Style.valueOf(parts[2]);
            String arg=deriveLearnedArgument(intent,original,normalized);
            return new Interpretation(original,normalized,intent,arg,style,false);
        }catch(Exception e){
            return null;
        }
    }

    private static void remember(Context context,Interpretation i){
        if(context==null || i==null || i.original.trim().isEmpty() || isSensitiveLearning(i.original)) return;
        String intent=i.intent==null?"UNKNOWN":i.intent;
        if("UNKNOWN".equals(intent) || "EMPTY".equals(intent)) return;
        String key="p_"+Integer.toHexString(normalizePhrase(i.original).hashCode());
        String normalized=i.normalized==null?i.original:i.normalized;
        if(normalized.length()>700) normalized=normalized.substring(0,700);
        String packed=intent+"\n"+normalized.replace("\n"," ")+"\n"+i.style.name();
        context.getSharedPreferences(LEARN_PREFS,Context.MODE_PRIVATE).edit().putString(key,packed).apply();
    }

    private static String deriveLearnedArgument(String intent,String original,String normalized){
        if("SEARCH".equals(intent)){
            String q=extractSearch(original);
            return q==null?original:q;
        }
        if("YOUTUBE_SEARCH".equals(intent)){
            String q=extractYouTubeSearch(original);
            return q==null?original:q;
        }
        if("REMEMBER".equals(intent)) return stripPrefix(original,"yaad rakho","याद रखो","remember");
        if("CHAT".equals(intent)) return original;
        return normalized;
    }

    private static boolean isSensitiveLearning(String raw){
        String s=raw.toLowerCase(Locale.ROOT);
        return containsAny(s,"password","passcode","otp","one time password","pin ","cvv","card number",
                "पासवर्ड","ओटीपी","पिन","कार्ड नंबर","message bhejo","msg bhejo","send message");
    }

    private static String normalizePhrase(String raw){
        return raw.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+"," ");
    }

    private static Interpretation quickInterpret(String original,Style style){
        String s=original.toLowerCase(Locale.ROOT).trim();
        if(matchesAny(s,"नमस्ते","नमस्कार","hello","hi anamika","hello anamika","hey anamika","namaste"))
            return new Interpretation(original,original,"CHAT",original,style,false);

        if(containsAny(s,"youtube se sikho","youtube se seekho","youtube par seekho","youtube pe seekho",
                "यूट्यूब से सीखो","यूट्यूब पर सीखो","video se sikho","video se seekho"))
            return new Interpretation(original,original,"YOUTUBE_LEARN",original,style,false);

        if(containsAny(s,"screen padh","screen padho","padh ke suna","padhkar suna","read screen","read this screen",
                "यह स्क्रीन पढ़","स्क्रीन पढ़","पढ़कर सुनाओ","jo likha hai padh"))
            return new Interpretation(original,original,"READ_SCREEN",original,style,false);

        if(containsAny(s,"screen samjha","screen explain","samjha kya hai","explain this screen",
                "यह स्क्रीन समझा","स्क्रीन समझाओ"))
            return new Interpretation(original,original,"EXPLAIN_SCREEN",original,style,false);

        if(containsAny(s,"matlab kya","meaning kya","meaning of","iska matlab","word ka matlab",
                "का मतलब","इसका मतलब","अर्थ क्या","meaning bata","matlab bata"))
            return new Interpretation(original,original,"UNKNOWN_LOOKUP",extractMeaningTarget(original),style,false);

        if(containsAny(s,"calculate","hisaab","hisab","kitna hoga","गणना","हिसाब","कैलकुलेट"))
            return new Interpretation(original,original,"CALCULATE",original,style,false);

        if(containsAny(s," ko call","call karo","call kar","phone lagao","dial ","कॉल करो","फोन लगाओ"))
            return new Interpretation(original,original,"CALL",original,style,false);

        if(containsAny(s,"contact search","contact dhundo","number dhundo","number search","name search","naam dhundo",
                "कॉन्टैक्ट खोजो","नंबर ढूंढो","नाम ढूंढो"))
            return new Interpretation(original,original,"CONTACT_SEARCH",original,style,false);

        if(containsAny(s,"message bhejo","msg bhejo","sms bhejo","send message","मैसेज भेजो","संदेश भेजो"))
            return new Interpretation(original,original,"MESSAGE",original,style,false);

        if(containsAny(s,"personal space kitna","vault status","vault kitna","meri files kitni","kitni files save",
                "पर्सनल स्पेस","कितनी फाइल","फाइल काउंट"))
            return new Interpretation(original,original,"VAULT_STATUS",original,style,false);

        if(containsAny(s,"last file download","download last","export last","last file export","डाउनलोड करो","एक्सपोर्ट करो"))
            return new Interpretation(original,original,"FILE_EXPORT",original,style,false);

        if(containsAny(s,"file delete","file hata","file hta","trash file","delete file","फाइल डिलीट","फाइल हटाओ"))
            return new Interpretation(original,original,"FILE_DELETE",original,style,false);

        if((containsAny(s,"file","photo","pic","image","video","pdf","document","audio","फाइल","फोटो","वीडियो","पीडीएफ") &&
                containsAny(s,"dhundo","dhoondo","search","find","khojo","ढूंढो","खोजो","सर्च")))
            return new Interpretation(original,original,"FILE_SEARCH",original,style,false);

        if(containsAny(s,"brightness","volume","wifi","wi-fi","bluetooth","hotspot","mobile data","dark mode",
                "battery saver","location","airplane","screen timeout","ringtone","notification setting",
                "ब्राइटनेस","वॉल्यूम","वाईफाई","ब्लूटूथ","हॉटस्पॉट","मोबाइल डेटा","लोकेशन"))
            return new Interpretation(original,original,"SYSTEM_SETTING",original,style,false);

        String y=extractYouTubeSearch(original);
        if(y!=null) return new Interpretation(original,"youtube search "+y,"YOUTUBE_SEARCH",y,style,false);

        String q=extractSearch(original);
        if(q!=null) return new Interpretation(original,"search "+q,"SEARCH",q,style,false);

        if(containsAny(s,"पूरे app","पूरा app","सारे function","सारे functions","deep audit","full app check",
                "poora app","pura app","saare function","sare function","blueprint bana","auto audit"))
            return new Interpretation(original,original,"APP_AUDIT",original,style,false);

        if(containsAny(s,"photo edit","pic edit","image edit","photo resize","image resize","crop photo","rotate photo",
                "video edit","video trim","video cut","video mute","photo banao","pic banao","image banao","video banao",
                "create image","create photo","create video","फोटो एडिट","वीडियो एडिट","फोटो बनाओ","वीडियो बनाओ"))
            return new Interpretation(original,original,"MEDIA",original,style,false);

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
        if(style==Style.HINDI) return "Reply naturally in everyday Indian Hindi. Use simple Devanagari, normal Indian conversational phrasing, and avoid bookish/formal Hindi unless the user uses it.";
        if(style==Style.HINGLISH) return "Reply naturally in everyday Indian Hinglish using Roman letters, matching the user's casual vocabulary and sentence style. Sound like a normal Indian conversation, not a translated script.";
        if(style==Style.ENGLISH) return "Reply naturally in clear Indian English unless the user's wording suggests another English style.";
        return "Reply naturally in the same human language and conversational style as the user. Preserve culturally normal phrasing for that language.";
    }

    private static String extractMeaningTarget(String raw){
        if(raw==null) return "";
        String q=raw.replaceAll("(?i)(iska|is|word|shabd|शब्द|इसका|का|meaning|matlab|मतलब|अर्थ|kya|क्या|hai|है|batao|bata|बताओ)"," ")
                .replaceAll("\\s+"," ").trim();
        return q.isEmpty()?raw.trim():q;
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
