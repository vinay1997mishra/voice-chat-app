package com.anamika.ai.messaging;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Parses explicit owner message-send commands in English, Hinglish/Roman Hindi and Hindi. */
public final class MessageCommandParser {
    public static final class Request {
        public final String app;
        public final String recipient;
        public final String message;

        public Request(String app,String recipient,String message){
            this.app=clean(app);
            this.recipient=clean(recipient);
            this.message=clean(message);
        }

        public boolean valid(){
            return !app.isEmpty()&&!recipient.isEmpty()&&!message.isEmpty();
        }
    }

    private static final Pattern ENGLISH=Pattern.compile(
            "(?iu)^send(?:\\s+a)?\\s+(?:message|msg)\\s+(?:on|in|via)\\s+(.+?)\\s+to\\s+(.+?)(?:\\s*[:|,-]\\s*|\\s+saying\\s+)(.+)$");

    private static final Pattern HINGLISH=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:me|mein|par|pe)\\s+(.+?)\\s+ko\\s+(.+?)\\s+(?:bhejo|bhej do|send\\s*karo|send\\s*kar\\s*do|send\\s*karna)$");

    private static final Pattern HINGLISH_MESSAGE=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:me|mein|par|pe)\\s+(.+?)\\s+ko\\s+(?:message|msg)\\s+(?:bhejo|bhej do|send\\s*karo|send\\s*kar\\s*do)\\s*[:|,-]?\\s*(.+)$");

    private static final Pattern TELL=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:me|mein|par|pe)\\s+(.+?)\\s+ko\\s+(?:bol\\s*do|bata\\s*do|keh\\s*do)\\s+(.+)$");

    private static final Pattern HINDI=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:में|मे|पर)\\s+(.+?)\\s+को\\s+(.+?)\\s+(?:भेजो|भेज दो|सेंड करो|सेंड कर दो)$");

    private static final Pattern HINDI_MESSAGE=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:में|मे|पर)\\s+(.+?)\\s+को\\s+(?:मैसेज|मेसेज|संदेश)\\s+(?:भेजो|भेज दो|सेंड करो|सेंड कर दो)\\s*[:|,-]?\\s*(.+)$");

    private static final Pattern HINDI_TELL=Pattern.compile(
            "(?iu)^(.+?)\\s+(?:में|मे|पर)\\s+(.+?)\\s+को\\s+(?:बोल दो|बता दो|कह दो)\\s+(.+)$");

    private MessageCommandParser(){}

    public static Request parse(String raw){
        if(raw==null)return null;
        String s=raw.trim().replaceAll("\\s+"," ");
        if(s.isEmpty())return null;

        Matcher m=ENGLISH.matcher(s);
        if(m.matches())return request(m.group(1),m.group(2),m.group(3));

        m=HINGLISH_MESSAGE.matcher(s);
        if(m.matches())return request(m.group(1),m.group(2),m.group(3));

        m=TELL.matcher(s);
        if(m.matches())return request(m.group(1),m.group(2),m.group(3));

        m=HINGLISH.matcher(s);
        if(m.matches()){
            String body=m.group(3).trim()
                    .replaceFirst("(?iu)^(?:message|msg)\\s+","");
            return request(m.group(1),m.group(2),body);
        }

        m=HINDI_MESSAGE.matcher(s);
        if(m.matches())return request(m.group(1),m.group(2),m.group(3));

        m=HINDI_TELL.matcher(s);
        if(m.matches())return request(m.group(1),m.group(2),m.group(3));

        m=HINDI.matcher(s);
        if(m.matches()){
            String body=m.group(3).trim()
                    .replaceFirst("(?iu)^(?:मैसेज|मेसेज|संदेश)\\s+","");
            return request(m.group(1),m.group(2),body);
        }
        return null;
    }

    public static boolean looksLikeMessageCommand(String raw){
        if(raw==null)return false;
        String l=raw.toLowerCase(Locale.ROOT);
        return l.contains(" bhejo")||l.contains(" bhej do")||l.contains("send message")||
                l.contains("send karo")||l.contains("send kar do")||
                l.contains(" bol do")||l.contains(" bata do")||l.contains(" keh do")||
                l.contains(" भेजो")||l.contains(" भेज दो")||l.contains(" सेंड करो")||
                l.contains(" बोल दो")||l.contains(" बता दो")||l.contains(" कह दो");
    }

    private static Request request(String app,String recipient,String message){
        Request r=new Request(app,recipient,message);
        return r.valid()?r:null;
    }

    private static String clean(String s){
        if(s==null)return "";
        return s.trim().replaceAll("^[\\s:|,-]+|[\\s:|,-]+$","");
    }
}
