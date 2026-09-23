package com.anamika.ai.language;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Local/private adaptive owner-language learner.
 *
 * Learns recurring phrasing and explicit word meanings from owner chat without
 * modifying the GGUF model. It feeds a compact runtime guide to both natural chat
 * and command planning. No cloud upload is performed here.
 */
public final class AdaptiveLanguageLearner {
    private static final String PREF="anamika_adaptive_language";
    private static final String KEY_ENABLED="enabled";
    private static final String KEY_COUNTS="phrase_counts";
    private static final String KEY_RECENT="recent_phrases";
    private static final String KEY_ALIASES="aliases";
    private static final String KEY_OBS="observations";
    private static final int MAX_PHRASES=80;
    private static final int MAX_RECENT=24;
    private static final int MAX_ALIASES=40;

    private static final Pattern MEANS_HINGLISH=Pattern.compile(
            "(?iu)^\\s*([\\p{L}][\\p{L}0-9_ -]{0,23})\\s+ka\\s+matlab\\s+([\\p{L}][\\p{L}0-9_ -]{0,31})\\s*$");
    private static final Pattern MEANS_ENGLISH=Pattern.compile(
            "(?iu)^\\s*([\\p{L}][\\p{L}0-9_ -]{0,23})\\s+means\\s+([\\p{L}][\\p{L}0-9_ -]{0,31})\\s*$");

    private AdaptiveLanguageLearner(){}

    public static boolean enabled(Context c){
        return prefs(c).getBoolean(KEY_ENABLED,true);
    }

    public static String setEnabled(Context c,boolean enabled){
        prefs(c).edit().putBoolean(KEY_ENABLED,enabled).apply();
        return enabled
                ?"Adaptive language learning ON. Anamika owner ke recurring Hinglish/language patterns local device par seekhegi."
                :"Adaptive language learning OFF. Existing learned profile safe rahega.";
    }

    public static void observeOwner(Context c,String raw){
        if(c==null||!enabled(c)||raw==null)return;
        String s=sanitize(raw);
        if(s.isEmpty())return;

        SharedPreferences p=prefs(c);
        try{
            JSONObject counts=jsonObject(p.getString(KEY_COUNTS,"{}"));
            int n=counts.optInt(s,0)+1;
            counts.put(s,Math.min(n,9999));
            pruneCounts(counts,MAX_PHRASES);

            JSONArray recent=jsonArray(p.getString(KEY_RECENT,"[]"));
            JSONArray next=new JSONArray();
            next.put(s);
            for(int i=0;i<recent.length()&&next.length()<MAX_RECENT;i++){
                String x=recent.optString(i,"").trim();
                if(x.isEmpty()||x.equalsIgnoreCase(s))continue;
                next.put(x);
            }

            JSONObject aliases=jsonObject(p.getString(KEY_ALIASES,"{}"));
            learnExplicitMeaning(raw,aliases);
            pruneAliases(aliases,MAX_ALIASES);

            p.edit()
                    .putString(KEY_COUNTS,counts.toString())
                    .putString(KEY_RECENT,next.toString())
                    .putString(KEY_ALIASES,aliases.toString())
                    .putLong(KEY_OBS,p.getLong(KEY_OBS,0L)+1L)
                    .apply();
        }catch(Exception ignored){}
    }

    public static String promptGuide(Context c){
        if(c==null||!enabled(c))return "";
        SharedPreferences p=prefs(c);
        try{
            JSONObject counts=jsonObject(p.getString(KEY_COUNTS,"{}"));
            JSONObject aliases=jsonObject(p.getString(KEY_ALIASES,"{}"));
            JSONArray recent=jsonArray(p.getString(KEY_RECENT,"[]"));
            if(counts.length()==0&&aliases.length()==0)return "";

            StringBuilder b=new StringBuilder();
            b.append("ADAPTIVE OWNER LANGUAGE PROFILE (local/private):\n");
            b.append("- The owner often communicates by short Hinglish continuations; resolve meaning from recent context before asking again.\n");

            List<PhraseCount> common=topCounts(counts,10);
            if(!common.isEmpty()){
                b.append("- Recurring owner phrasing: ");
                for(int i=0;i<common.size();i++){
                    if(i>0)b.append(" | ");
                    b.append(common.get(i).phrase);
                    if(common.get(i).count>1)b.append(" (x").append(common.get(i).count).append(")");
                }
                b.append("\n");
            }

            if(aliases.length()>0){
                b.append("- Explicitly learned owner vocabulary: ");
                Iterator<String> keys=aliases.keys();int i=0;
                while(keys.hasNext()&&i<10){
                    String k=keys.next();
                    if(i++>0)b.append(" | ");
                    b.append(k).append(" = ").append(aliases.optString(k,""));
                }
                b.append("\n");
            }

            if(recent.length()>0){
                b.append("- Recent owner-style examples: ");
                int limit=Math.min(6,recent.length());
                for(int i=0;i<limit;i++){
                    if(i>0)b.append(" | ");
                    b.append(recent.optString(i,""));
                }
                b.append("\n");
            }
            b.append("- Learned examples describe language style, not permission to invent facts/actions. Exact current names, code, numbers and URLs remain authoritative.");
            return b.toString();
        }catch(Exception e){return "";}
    }

    public static String semanticHint(Context c,String raw){
        if(c==null||raw==null||raw.trim().isEmpty()||!enabled(c))return "";
        try{
            JSONObject aliases=jsonObject(prefs(c).getString(KEY_ALIASES,"{}"));
            String l=raw.toLowerCase(Locale.ROOT);
            Iterator<String> keys=aliases.keys();
            while(keys.hasNext()){
                String k=keys.next();
                if(containsWordish(l,k.toLowerCase(Locale.ROOT)))
                    return "Learned owner vocabulary: '"+k+"' means '"+aliases.optString(k,"")+"'.";
            }
        }catch(Exception ignored){}
        return "";
    }

    public static String status(Context c){
        SharedPreferences p=prefs(c);
        try{
            JSONObject counts=jsonObject(p.getString(KEY_COUNTS,"{}"));
            JSONObject aliases=jsonObject(p.getString(KEY_ALIASES,"{}"));
            return "Adaptive language learning: "+(enabled(c)?"ON":"OFF")+
                    "\nOwner messages observed: "+p.getLong(KEY_OBS,0L)+
                    "\nRecurring phrase memory: "+counts.length()+"/"+MAX_PHRASES+
                    "\nExplicit vocabulary: "+aliases.length()+"/"+MAX_ALIASES+
                    "\nStorage: local/private app data"+
                    "\nMethod: runtime context learning (not GGUF weight fine-tuning).";
        }catch(Exception e){return "Adaptive language learning status unavailable.";}
    }

    public static String reset(Context c){
        boolean on=enabled(c);
        prefs(c).edit().clear().putBoolean(KEY_ENABLED,on).apply();
        return "Adaptive language profile reset. Learning "+(on?"ON":"OFF")+".";
    }

    private static String sanitize(String raw){
        String s=raw.trim().replaceAll("\\s+"," ");
        if(s.length()<2||s.length()>180)return "";
        String l=s.toLowerCase(Locale.ROOT);
        if(l.contains("password")||l.contains("passcode")||l.contains("otp")||
                l.contains("owner pin")||l.contains("keystore")||l.contains("private key"))
            return "";
        if(s.matches("(?s).*(https?://|www\\.|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}).*"))
            return "";
        if(s.matches(".*\\d{7,}.*"))return "";
        if(looksLikeCode(s))return "";
        return s.toLowerCase(Locale.ROOT).replaceAll("\\b\\d+(?:[.,]\\d+)?\\b","<num>");
    }

    private static boolean looksLikeCode(String s){
        String l=s.toLowerCase(Locale.ROOT);
        int score=0;
        if(l.contains("package ")&&s.contains(";"))score+=3;
        if(l.contains("import ")&&s.contains(";"))score+=2;
        if(l.contains(" class ")||l.startsWith("class ")||l.contains(" fun "))score+=2;
        if(s.contains("{")&&s.contains("}")&&s.contains("(")&&s.contains(")"))score+=2;
        if(l.contains("<?xml")||l.contains("<manifest")||l.contains("<script"))score+=3;
        return score>=3;
    }

    private static void learnExplicitMeaning(String raw,JSONObject aliases){
        Matcher m=MEANS_HINGLISH.matcher(raw.trim());
        if(!m.matches())m=MEANS_ENGLISH.matcher(raw.trim());
        if(!m.matches())return;
        String from=cleanAlias(m.group(1)),to=cleanAlias(m.group(2));
        if(from.isEmpty()||to.isEmpty()||from.equalsIgnoreCase(to))return;
        try{aliases.put(from,to);}catch(Exception ignored){}
    }

    private static String cleanAlias(String s){
        if(s==null)return "";
        s=s.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+"," ");
        if(s.length()<1||s.length()>32)return "";
        return s;
    }

    private static void pruneCounts(JSONObject o,int max)throws Exception{
        if(o.length()<=max)return;
        List<PhraseCount> all=topCounts(o,o.length());
        JSONObject n=new JSONObject();
        for(int i=0;i<all.size()&&i<max;i++)n.put(all.get(i).phrase,all.get(i).count);
        List<String> remove=new ArrayList<>();
        Iterator<String> it=o.keys();while(it.hasNext())remove.add(it.next());
        for(String k:remove)o.remove(k);
        Iterator<String> ni=n.keys();while(ni.hasNext()){String k=ni.next();o.put(k,n.optInt(k,1));}
    }

    private static void pruneAliases(JSONObject o,int max){
        if(o.length()<=max)return;
        ArrayList<String> keys=new ArrayList<>();
        Iterator<String> it=o.keys();while(it.hasNext())keys.add(it.next());
        for(int i=max;i<keys.size();i++)o.remove(keys.get(i));
    }

    private static List<PhraseCount> topCounts(JSONObject o,int max){
        ArrayList<PhraseCount> all=new ArrayList<>();
        Iterator<String> it=o.keys();
        while(it.hasNext()){
            String k=it.next();
            all.add(new PhraseCount(k,o.optInt(k,1)));
        }
        Collections.sort(all,new Comparator<PhraseCount>(){
            @Override public int compare(PhraseCount a,PhraseCount b){
                int c=Integer.compare(b.count,a.count);
                return c!=0?c:a.phrase.compareTo(b.phrase);
            }
        });
        return all.size()<=max?all:new ArrayList<>(all.subList(0,max));
    }

    private static boolean containsWordish(String hay,String needle){
        if(needle.isEmpty())return false;
        int p=hay.indexOf(needle);
        while(p>=0){
            int e=p+needle.length();
            boolean left=p==0||!Character.isLetterOrDigit(hay.charAt(p-1));
            boolean right=e>=hay.length()||!Character.isLetterOrDigit(hay.charAt(e));
            if(left&&right)return true;
            p=hay.indexOf(needle,p+1);
        }
        return false;
    }

    private static JSONObject jsonObject(String s){
        try{return new JSONObject(s==null||s.trim().isEmpty()?"{}":s);}catch(Exception e){return new JSONObject();}
    }
    private static JSONArray jsonArray(String s){
        try{return new JSONArray(s==null||s.trim().isEmpty()?"[]":s);}catch(Exception e){return new JSONArray();}
    }
    private static SharedPreferences prefs(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
    }

    private static final class PhraseCount{
        final String phrase;final int count;
        PhraseCount(String phrase,int count){this.phrase=phrase;this.count=count;}
    }
}
