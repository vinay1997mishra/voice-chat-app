package com.anamika.ai.language;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Hindi + Hinglish + English command normalizer for V13.
 *
 * It converts common natural owner phrases into the deterministic command grammar
 * without changing free-form arguments such as app names, search text or notes.
 */
public final class LanguageCommandInterpreter {
    private LanguageCommandInterpreter(){}

    public static String normalize(String raw){
        if(raw==null)return "";
        String s=raw.trim().replaceAll("\\s+"," ");
        if(s.isEmpty())return "";
        String l=s.toLowerCase(Locale.ROOT);

        // Exact intent phrases.
        if(any(l,"kya kar sakti ho","kya kya kar sakti ho","tum kya kar sakti ho",
                "क्या कर सकती हो","क्या क्या कर सकती हो","what can you do","functions","function"))
            return "functions";

        if(any(l,"plugin kholo","plugins kholo","plugin center kholo","plugin open karo",
                "प्लगइन खोलो","प्लगइन सेंटर खोलो","plugins","plugin center"))
            return "plugins";

        if(any(l,"diagnostics","diagnostics center","diagnostic center","diagnostics kholo",
                "self test kholo","डायग्नोस्टिक्स","डायग्नोस्टिक्स खोलो"))
            return "diagnostics";

        if(any(l,"component packs","component center","components kholo","component packs kholo",
                "कंपोनेंट पैक्स","कंपोनेंट सेंटर","कंपोनेंट पैक्स खोलो"))
            return "component packs";

        if(any(l,"component status","components status","packs status",
                "कंपोनेंट स्टेटस","पैक स्टेटस"))
            return "component status";

        if(any(l,"autonomy status","self repair status","khud ko thik karne ka status",
                "offline brain status","ऑटोनॉमी स्टेटस","सेल्फ रिपेयर स्टेटस"))
            return "autonomy status";

        if(any(l,"brain status","brain ka status","offline brain","offline brain status",
                "coding brain status","brain ready hai","brain ready hai kya",
                "ब्रेन स्टेटस","ब्रेन का स्टेटस","ऑफलाइन ब्रेन"))
            return "brain status";

        if(any(l,"signer status","singer status","signing status","signer ka status",
                "singer ka status","release signer status","key status","signing key status",
                "signer ready hai","signer ready hai kya","साइनर स्टेटस","साइनिंग स्टेटस"))
            return "signer status";

        if(any(l,"rollback status","recovery status","रोलबैक स्टेटस","रिकवरी स्टेटस"))
            return "rollback status";

        if(any(l,"recovery checkpoint","create recovery checkpoint","rollback point banao",
                "recovery point banao","रिकवरी पॉइंट बनाओ","रोलबैक पॉइंट बनाओ"))
            return "create recovery checkpoint";


        if(any(l,"self test","run self test","self test chalao","full self test chalao",
                "full diagnostics","check all functions","apne saare function check karo",
                "saare function check karo","sabhi functions check karo","pura diagnostics chalao",
                "सेल्फ टेस्ट","सेल्फ टेस्ट चलाओ","सारे फंक्शन चेक करो","पूरा डायग्नोस्टिक्स चलाओ"))
            return "full diagnostics";

        if(any(l,"share diagnostics","diagnostics share karo","diagnostic report share karo",
                "report mujhe bhejo","डायग्नोस्टिक्स शेयर करो","रिपोर्ट शेयर करो"))
            return "share diagnostics";

        if(any(l,"diagnostics report","diagnostic report","latest diagnostics","report dikhao",
                "डायग्नोस्टिक्स रिपोर्ट","रिपोर्ट दिखाओ"))
            return "diagnostics report";


        if(any(l,"message status","msg status","message ka status","message kaha tak hua",
                "मैसेज स्टेटस","मैसेज का स्टेटस","messaging status"))
            return "message status";

        if(any(l,"message cancel karo","msg cancel karo","message rok do","message band karo",
                "मैसेज कैंसल करो","मैसेज रोक दो","cancel message","stop message"))
            return "cancel message";

        if(any(l,"scan band karo","scan rok do","स्कैन बंद करो","स्कैन रोक दो","stop scan"))
            return "stop scan";

        if(any(l,"scan status","scan ka status","स्कैन स्टेटस","स्कैन का स्टेटस","blueprint status"))
            return "scan status";

        if(any(l,"research band karo","research rok do","रिसर्च बंद करो","रिसर्च रोक दो","stop research"))
            return "stop research";

        if(any(l,"research status","research ka status","रिसर्च स्टेटस","research status"))
            return "research status";

        if(any(l,"settings kholo","setting kholo","phone settings kholo","सेटिंग खोलो","सेटिंग्स खोलो","settings"))
            return "settings";

        if(any(l,"anamika settings kholo","app settings kholo","ऐप सेटिंग खोलो","app settings"))
            return "app settings";

        if(any(l,"memory dikhao","meri memory dikhao","memory status","मेमोरी दिखाओ","मेमोरी स्टेटस","memory"))
            return "memory";

        if(any(l,"vault dikhao","vault status","वॉल्ट दिखाओ","वॉल्ट स्टेटस","vault"))
            return "vault";

        if(any(l,"health check karo","health dikhao","phone health","anamika health",
                "हेल्थ चेक करो","फोन हेल्थ","health"))
            return "health";

        if(any(l,"last crash dikhao","crash report dikhao","आखिरी क्रैश दिखाओ","क्रैश रिपोर्ट","last crash","crash report"))
            return "crash report";

        if(any(l,"runtime status","watchdog status","watchdog","रनटाइम स्टेटस"))
            return "runtime status";

        if(any(l,"wake on","wake chalu karo","wake start karo","sunna chalu karo",
                "वेक ऑन","वेक चालू करो","wake enable"))
            return "wake on";

        if(any(l,"wake off","wake band karo","sunna band karo","वेक ऑफ","वेक बंद करो","wake disable"))
            return "wake off";

        if(any(l,"upgrade status","self upgrade status","upgrade ka status",
                "अपग्रेड स्टेटस","अपग्रेड का स्टेटस"))
            return "upgrade status";

        if(any(l,"local build","build upgrade","apk build karo","upgrade build karo",
                "लोकल बिल्ड","एपीके बिल्ड करो"))
            return "local build";

        String repairArg=matchArg(s,
                "^(?iu)(?:offline repair|code repair|khud ka code thik karo|khud ko thik karo|ऑफलाइन रिपेयर|कोड ठीक करो)\\s+(.+)$");
        if(repairArg!=null)return "offline repair "+repairArg;


        if(any(l,"upgrade validate karo","code check karo","code doctor chalao",
                "कोड चेक करो","कोड डॉक्टर चलाओ","validate upgrade","code doctor"))
            return "validate upgrade";

        if(any(l,"update install karo","self update karo","अपडेट इंस्टॉल करो","self update","install update"))
            return "self update";

        if(any(l,"device info","phone info","device ki info","फोन की जानकारी","डिवाइस जानकारी"))
            return "device info";

        if(any(l,"back","wapas","wapas jao","पीछे","वापस","वापस जाओ"))
            return "back";

        // Prefix/suffix intents with preserved arguments.
        String arg;

        arg=matchArg(s,
                "^(?iu)(?:open|khol|kholo|khol do|खोलो|खोल दो)\\s+(.+)$");
        if(arg!=null)return "open "+arg;

        arg=matchArg(s,
                "^(?iu)(.+?)\\s+(?:open karo|open kar do|khol|kholo|khol do|खोलो|खोल दो)$");
        if(arg!=null&&!looksLikeSettings(arg))return "open "+arg;

        arg=matchArg(s,
                "^(?iu)(?:app\\s+)?(.+?)\\s+(?:app\\s+)?(?:open karo|khol do|kholo)$");
        if(arg!=null)return "open "+arg;

        arg=matchArg(s,
                "^(?iu)(?:search|google|dhundo|dhoondo|khojo|खोजो|ढूंढो|सर्च करो)\\s+(.+)$");
        if(arg!=null)return "search "+arg;

        arg=matchArg(s,
                "^(?iu)(?:google|गूगल)(?:\\s+par|\\s+pe|\\s+पे|\\s+पर)?\\s+(.+?)\\s+(?:search karo|search kar|dhundo|dhoondo|khojo|सर्च करो|खोजो|ढूंढो)$");
        if(arg!=null)return "search "+arg;

        arg=matchArg(s,
                "^(?iu)(.+?)\\s+(?:search karo|search kar do|dhundo|dhoondo|khojo|सर्च करो|खोजो|ढूंढो)$");
        if(arg!=null)return "search "+arg;

        arg=matchArg(s,
                "^(?iu)(?:dial|call|phone karo|number lagao|कॉल करो|डायल करो|नंबर लगाओ)\\s+(.+)$");
        if(arg!=null)return "dial "+arg;

        arg=matchArg(s,
                "^(?iu)(?:remember|yaad rakh|yaad rakho|yaad rakhna|याद रखो|याद रखना)\\s+(.+)$");
        if(arg!=null)return "remember "+arg;

        arg=matchArg(s,
                "^(?iu)(?:research|research karo|रिसर्च|रिसर्च करो)\\s+(.+)$");
        if(arg!=null)return "research "+arg;

        arg=matchArg(s,
                "^(?iu)(?:scan app|app scan karo|scan karo|स्कैन करो|ऐप स्कैन करो)\\s+(.+)$");
        if(arg!=null)return "scan app "+arg;

        arg=matchArg(s,
                "^(?iu)(.+?)\\s+(?:ka scan karo|ko scan karo|स्कैन करो)$");
        if(arg!=null)return "scan app "+arg;

        arg=matchArg(s,
                "^(?iu)(?:tap|touch|dabao|click karo|टैप करो|टच करो|दबाओ)\\s+(.+)$");
        if(arg!=null)return "tap "+arg;

        arg=matchArg(s,
                "^(?iu)(?:type|likho|likh do|टाइप करो|लिखो|लिख दो)\\s+(.+)$");
        if(arg!=null)return "type "+arg;

        arg=matchArg(s,
                "^(?iu)(?:calculate|calc|hisab karo|hisaab karo|गणना करो|हिसाब करो)\\s+(.+)$");
        if(arg!=null)return "calculate "+normalizeMathWords(arg);

        arg=matchArg(s,
                "^(?iu)(?:open url|website kholo|site kholo|वेबसाइट खोलो|साइट खोलो)\\s+(.+)$");
        if(arg!=null)return "open url "+arg;

        arg=matchArg(s,
                "^(?iu)(?:prepare upgrade|upgrade ready karo|upgrade taiyar karo|अपग्रेड तैयार करो)\\s*(.*)$");
        if(arg!=null)return "prepare upgrade"+(arg.isEmpty()?"":" "+arg);

        // File save: "file X me Y save karo" / "save file X | Y".
        Matcher fm=Pattern.compile("(?iu)^file\\s+(.+?)\\s+(?:me|mein|में)\\s+(.+?)\\s+(?:save karo|save kar do|सेव करो)$").matcher(s);
        if(fm.matches())return "save file "+fm.group(1).trim()+" | "+fm.group(2).trim();

        // Keep canonical/unknown text untouched so future parsers/AI can see the original meaning.
        return s;
    }

    private static String normalizeMathWords(String s){
        return s.replaceAll("(?iu)\\s+(?:plus|jod|जोड़|जमा)\\s+"," + ")
                .replaceAll("(?iu)\\s+(?:minus|ghata|घटा|कम)\\s+"," - ")
                .replaceAll("(?iu)\\s+(?:times|guna|गुणा)\\s+"," * ")
                .replaceAll("(?iu)\\s+(?:divide by|bhaag|भाग)\\s+"," / ");
    }

    private static boolean any(String value,String... choices){
        for(String c:choices)if(value.equals(c))return true;
        return false;
    }

    private static boolean looksLikeSettings(String s){
        String l=s.toLowerCase(Locale.ROOT);
        return l.contains("setting")||l.contains("सेटिंग");
    }

    private static String matchArg(String s,String regex){
        Matcher m=Pattern.compile(regex).matcher(s);
        if(!m.matches())return null;
        return m.group(1)==null?"":m.group(1).trim();
    }
}
