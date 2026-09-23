package com.anamika.ai.language;

import android.content.Context;

import com.anamika.ai.core.AndroidCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * Runtime-loaded conversation/understanding layer.
 *
 * Core Java stays stable while owner-approved understanding packs can update
 * prompt guidance and semantic follow-up rules without replacing the APK.
 */
public final class UnderstandingPackStore {
    private static final int MAX_PROFILE_CHARS=12000;
    private static final int MAX_RULES=120;

    private UnderstandingPackStore(){}

    public static File root(Context c){
        return new File(c.getFilesDir(),"v13_understanding");
    }

    public static boolean installed(Context c){
        File r=root(c);
        return new File(r,"owner_context_profile.txt").isFile()
                &&new File(r,"semantic_rules.json").isFile();
    }

    public static String version(Context c){
        File f=new File(root(c),"component.version");
        if(!f.isFile())return installed(c)?"installed":"not installed";
        try{
            String s=AndroidCompat.readText(f,StandardCharsets.UTF_8).trim();
            return s.isEmpty()?"installed":s;
        }catch(Exception e){return installed(c)?"installed":"not installed";}
    }

    public static String promptGuide(Context c){
        return promptGuide(c,6000);
    }

    /**
     * Returns an effort-sized understanding guide. The installed owner profile can be
     * much larger than a small local-model context window, so callers must budget it.
     */
    public static String promptGuide(Context c,int maxChars){
        int budget=Math.max(600,Math.min(MAX_PROFILE_CHARS,maxChars));
        String base="";
        File f=new File(root(c),"owner_context_profile.txt");
        if(f.isFile()){
            try{
                String s=AndroidCompat.readText(f,StandardCharsets.UTF_8).trim();
                if(!s.isEmpty())base=s.length()>MAX_PROFILE_CHARS?s.substring(0,MAX_PROFILE_CHARS):s;
            }catch(Exception ignored){}
        }
        if(base.isEmpty())base=OwnerConversationProfile.promptGuide();

        String adaptive=AdaptiveLanguageLearner.promptGuide(c);
        int adaptiveBudget=adaptive.isEmpty()?0:Math.min(1400,Math.max(350,budget/3));
        int baseBudget=Math.max(250,budget-adaptiveBudget-(adaptiveBudget>0?2:0));

        String b=clip(base,baseBudget);
        if(adaptiveBudget<=0)return b;
        String a=clip(adaptive,adaptiveBudget);
        return a.isEmpty()?b:b+"\n\n"+a;
    }

    public static String semanticHint(Context c,String raw){
        String learned=AdaptiveLanguageLearner.semanticHint(c,raw);
        String dynamic=dynamicHint(c,raw);
        if(!learned.isEmpty()&&!dynamic.isEmpty())return learned+" "+dynamic;
        if(!learned.isEmpty())return learned;
        if(!dynamic.isEmpty())return dynamic;
        return OwnerConversationProfile.semanticHint(raw);
    }

    private static String dynamicHint(Context c,String raw){
        if(raw==null||raw.trim().isEmpty())return "";
        File f=new File(root(c),"semantic_rules.json");
        if(!f.isFile())return "";
        try{
            String text=LocalLanguageText.intentHint(raw);
            String lower=text.toLowerCase(Locale.ROOT);
            JSONObject root=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
            JSONArray rules=root.optJSONArray("rules");
            if(rules==null)return "";
            int count=Math.min(MAX_RULES,rules.length());
            for(int i=0;i<count;i++){
                JSONObject rule=rules.optJSONObject(i);
                if(rule==null)continue;
                String hint=rule.optString("hint","").trim();
                if(hint.isEmpty())continue;

                String regex=rule.optString("regex","").trim();
                if(!regex.isEmpty()){
                    try{
                        if(lower.matches(regex))return hint;
                    }catch(Exception ignored){}
                }

                JSONArray any=rule.optJSONArray("contains_any");
                if(any!=null){
                    for(int j=0;j<any.length();j++){
                        String needle=any.optString(j,"").toLowerCase(Locale.ROOT).trim();
                        if(!needle.isEmpty()&&lower.contains(needle))return hint;
                    }
                }
            }
        }catch(Exception ignored){}
        return "";
    }

    private static String clip(String s,int max){
        if(s==null)return "";
        String x=s.trim();
        if(x.length()<=max)return x;
        int cut=Math.max(0,max-24);
        return x.substring(0,cut)+"\n[profile clipped]";
    }

    public static String status(Context c){
        String base=installed(c)
                ?"Understanding pack: READY ("+version(c)+")"
                :"Understanding pack: built-in fallback only";
        return base+"\n"+AdaptiveLanguageLearner.status(c);
    }
}
