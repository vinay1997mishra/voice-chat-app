package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.SharedPreferences;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.CodeIntakeAnalyzer;
import com.anamika.ai.language.LanguageCommandInterpreter;
import com.anamika.ai.phone.CalculatorEngine;

import java.io.File;

/**
 * Lightweight old-vs-new update scorecard.
 *
 * Percentages are evidence scores from deterministic probes + post-update stability.
 * They are not a claim that every live phone/OEM/app interaction has been proven.
 */
public final class UpdateScorecard {
    private static final String PREF="anamika13_update_scorecard";
    private static final String BASELINE="baseline_probe";
    private static final String CURRENT="current_probe";
    private static final String QUALITY="quality";
    private static final String PROBLEM="problem";
    private static final String DELTA="delta";
    private static final String TARGETS="targets";
    private static final String BENEFIT="benefit";
    private static final String LAST_DETAIL="last_detail";
    private static final String PENDING="pending";

    private UpdateScorecard(){}

    public static void recordPlannedCode(Context c,CodeIntakeAnalyzer.Analysis a){
        if(a==null)return;
        prefs(c).edit()
                .putString(TARGETS,a.targets)
                .putInt(BENEFIT,a.estimatedBenefitPercent)
                .apply();
    }

    public static String captureBaseline(Context c){
        Probe p=probe(c);
        prefs(c).edit()
                .putInt(BASELINE,p.percent)
                .putInt(CURRENT,p.percent)
                .putInt(QUALITY,p.percent)
                .putInt(PROBLEM,100-p.percent)
                .putInt(DELTA,0)
                .putString(LAST_DETAIL,p.detail)
                .putBoolean(PENDING,true)
                .apply();
        return "Old-version baseline probe: "+p.percent+"% ("+p.passed+"/"+p.total+" checks PASS).";
    }

    public static String refresh(Context c,int healthyLaunches,boolean stable,boolean crashDetected,boolean sourceVerified){
        Probe p=probe(c);
        int baseline=prefs(c).getInt(BASELINE,p.percent);
        int stability=Math.max(0,Math.min(3,healthyLaunches))*10; // 0..30
        int quality=(int)Math.round(p.percent*0.70d)+stability;
        if(!sourceVerified)quality=Math.min(quality,45);
        if(crashDetected)quality=Math.max(0,quality-25);
        if(stable&&sourceVerified&&!crashDetected)quality=Math.max(quality,95);
        if(quality>100)quality=100;
        int problem=100-quality;
        int delta=p.percent-baseline;

        String detail="Automated probe "+p.percent+"% ("+p.passed+"/"+p.total+" PASS)"+
                " • healthy launches "+healthyLaunches+"/3"+
                " • source "+(sourceVerified?"PASS":"FAIL")+
                " • new crash "+(crashDetected?"YES":"NO");

        prefs(c).edit()
                .putInt(CURRENT,p.percent)
                .putInt(QUALITY,quality)
                .putInt(PROBLEM,problem)
                .putInt(DELTA,delta)
                .putString(LAST_DETAIL,detail)
                .putBoolean(PENDING,!stable)
                .apply();
        return status(c);
    }

    public static String status(Context c){
        SharedPreferences p=prefs(c);
        int quality=p.getInt(QUALITY,-1);
        if(quality<0)return "Update scorecard: no update baseline captured yet.";
        int problem=p.getInt(PROBLEM,100-quality);
        int delta=p.getInt(DELTA,0);
        int benefit=p.getInt(BENEFIT,-1);
        String targets=p.getString(TARGETS,"not specified");
        StringBuilder b=new StringBuilder();
        b.append("UPDATE SCORECARD")
                .append("\nUpdate Quality: ").append(quality).append("%")
                .append("\nProblem/Regression score: ").append(problem).append("%")
                .append("\nCore probe change vs old version: ")
                .append(delta>=0?"+":"").append(delta).append(" percentage point(s)")
                .append("\nUpdated/target functions: ").append(targets);
        if(benefit>=0)b.append("\nPre-install estimated benefit potential: ").append(benefit).append("%");
        b.append("\n").append(p.getString(LAST_DETAIL,""))
                .append("\nPercentages automated checks/stability evidence par based hain; live voice/OEM/third-party-app behavior ko real use se verify karna hota hai.");
        return b.toString();
    }

    private static Probe probe(Context c){
        int pass=0,total=0;
        StringBuilder detail=new StringBuilder();

        total++; if("com.anamika.ai13".equals(c.getPackageName()))pass++; else detail.append("package;");

        total++;
        try{
            File base=SourceVault.ensureBaseline(c);
            if(CandidateValidator.validateWorkspace(base).clean)pass++; else detail.append("source;");
        }catch(Exception e){detail.append("source;");}

        String[] classes={
                "com.anamika.ai.MainActivity",
                "com.anamika.ai.CommandRouter",
                "com.anamika.ai.BrainCommandEngine",
                "com.anamika.ai.components.ComponentPackManager",
                "com.anamika.ai.plugins.FunctionPackStore",
                "com.anamika.ai.language.UnderstandingPackStore",
                "com.anamika.ai.upgrade.UpgradeCoordinator"
        };
        for(String cls:classes){
            total++;
            try{Class.forName(cls);pass++;}catch(Throwable e){detail.append(cls.substring(cls.lastIndexOf('.')+1)).append(";");}
        }

        total++;
        try{
            String n=LanguageCommandInterpreter.normalize("WhatsApp kholo").toLowerCase();
            if(n.startsWith("open "))pass++;else detail.append("language;");
        }catch(Exception e){detail.append("language;");}

        total++;
        try{
            if(Math.abs(CalculatorEngine.evaluate("2+3*4")-14d)<0.000001d)pass++;
            else detail.append("calculator;");
        }catch(Exception e){detail.append("calculator;");}

        total++;
        try{
            String status=ComponentPackManager.status(c);
            if(status!=null&&!status.trim().isEmpty())pass++;else detail.append("components;");
        }catch(Exception e){detail.append("components;");}

        int percent=total==0?0:(int)Math.round(pass*100.0d/total);
        return new Probe(pass,total,percent,detail.length()==0?"all quick probes passed":"failed: "+detail);
    }

    private static SharedPreferences prefs(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
    }

    private static final class Probe{
        final int passed,total,percent;
        final String detail;
        Probe(int passed,int total,int percent,String detail){
            this.passed=passed;this.total=total;this.percent=percent;this.detail=detail;
        }
    }
}
