package com.anamika.ai.language;

import java.util.Locale;

/**
 * Compact owner-conversation guide distilled from the recent working style.
 *
 * This is not model fine-tuning. It gives the offline model deterministic
 * semantic guidance so short Hindi/Hinglish follow-ups can be resolved from
 * the existing recent-chat memory instead of being treated as isolated text.
 */
public final class OwnerConversationProfile {
    private OwnerConversationProfile(){}

    public static String promptGuide(){
        return "RECENT OWNER CONVERSATION STYLE: "+
                "Short follow-ups like 'ho gaya?', 'kar diya?', 'kitna hua?', 'kya hua?', 'ab?', 'aur?' normally refer to the most recent active task. "+
                "Words like 'ye', 'isme', 'usme', 'upar wala', 'pehle wala', 'last wala', 'abhi wala' must be resolved from recent chat before asking what they mean. "+
                "In Anamika work, 'new update' usually means preserve existing functions/data and update the installed app; do not interpret it as remove/rebuild everything unless explicitly asked. "+
                "'add kar', 'thik kar', 'recheck kar', 'sab kuch check kar' continue the current target. "+
                "Recognize mixed mobile/dev terms such as APK, GitHub, build, CI, signer, key, P12, AAPT2, toolchain, plugin, blueprint, wake, voice, offline brain and self-upgrade as normal Hinglish. "+
                "For calculations, phrases like 'iska 40%', 'upar wale me add kar', 'ab kitna' reuse the immediately relevant numbers from chat. "+
                "Reply in concise Hindi/Hinglish matching the owner, preserve exact names/numbers, and never claim a build/action is complete unless it really completed.";
    }

    public static String semanticHint(String raw){
        if(raw==null)return "";
        String s=LocalLanguageText.intentHint(raw).trim();
        if(s.isEmpty())return "";
        String l=s.toLowerCase(Locale.ROOT);

        if(l.matches("^(?:ho gaya|ho gya|hogya|kar diya|done|ready|kitna hua|kya hua|ab|aur|fir|phir|kab tak)\\??$"))
            return "Treat this as a follow-up about the most recent active task in recent chat.";

        if(l.matches(".*\\b(?:ye|isme|usme|upar wala|upar wali|pehle wala|pehle wali|last wala|last wali|abhi wala|abhi wali)\\b.*"))
            return "Resolve pronouns/references from the most recent relevant chat turn before asking for clarification.";

        if(l.contains("new update")||l.contains("naya update")||l.contains("update ready")||
                l.contains("pura app")||l.contains("dubara install"))
            return "In Anamika context, prefer an in-place signed update that preserves existing functions and app data unless the owner explicitly asks to remove something.";

        if(l.matches(".*\\b(?:add karo|add kar|thik karo|thik kar|theek karo|theek kar|recheck karo|recheck kar|check karo|check kar)\\b.*"))
            return "Continue modifying/checking the current subject from recent chat; do not silently switch to an unrelated target.";

        if(l.matches(".*\\b(?:iska|uska|upar wale|upar wali|ab kitna|kitne percent|kitna percent)\\b.*"))
            return "For numeric follow-ups, reuse the immediately relevant amount/rate from recent chat and keep units consistent.";

        if(l.contains("reply bhi")||l.contains("jaldi")||l.contains("kitna sochega"))
            return "Respond concisely with the current result/status; do not echo frustration.";

        return "";
    }
}
