package com.anamika.ai;

import android.content.Context;
import android.content.SharedPreferences;

/** Owner-selectable local inference effort for the offline command brain. */
public final class BrainEffortStore {
    public enum Mode {
        INSTANT("Instant",4096,700,45_000L,"0.05"),
        MEDIUM("Medium",8192,1400,90_000L,"0.10"),
        HARD("Hard",12288,2200,180_000L,"0.12");

        public final String label;
        public final int contextTokens;
        public final int maxTokens;
        public final long timeoutMs;
        public final String temperature;

        Mode(String label,int contextTokens,int maxTokens,long timeoutMs,String temperature){
            this.label=label;
            this.contextTokens=contextTokens;
            this.maxTokens=maxTokens;
            this.timeoutMs=timeoutMs;
            this.temperature=temperature;
        }
    }

    private static final String PREF="anamika13_brain_effort";
    private static final String KEY="mode";

    private BrainEffortStore(){}

    public static Mode get(Context c){
        String value=c.getSharedPreferences(PREF,Context.MODE_PRIVATE)
                .getString(KEY,Mode.INSTANT.name());
        try{return Mode.valueOf(value);}
        catch(Exception ignored){return Mode.INSTANT;}
    }

    public static void set(Context c,Mode mode){
        if(mode==null)mode=Mode.INSTANT;
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE)
                .edit().putString(KEY,mode.name()).apply();
    }

    public static String describe(Context c){
        Mode m=get(c);
        if(m==Mode.INSTANT)return "Instant • fastest replies";
        if(m==Mode.MEDIUM)return "Medium • more reasoning time";
        return "Hard • longest local reasoning";
    }
}
