package com.anamika.ai.developer;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Lightweight direct-code detector/analyzer used before the offline coding model.
 * It never claims semantic correctness; the real source integration is still gated
 * by Code Doctor, duplicate checks, a real Android build and APK verification.
 */
public final class CodeIntakeAnalyzer {
    public static final class Analysis {
        public final boolean looksLikeCode;
        public final String language;
        public final String targets;
        public final int estimatedBenefitPercent;
        public final String summary;

        Analysis(boolean looksLikeCode,String language,String targets,int benefit,String summary){
            this.looksLikeCode=looksLikeCode;
            this.language=language;
            this.targets=targets;
            this.estimatedBenefitPercent=benefit;
            this.summary=summary;
        }

        public String ownerReport(){
            return "DIRECT CODE DETECTED"+
                    "\nLanguage: "+language+
                    "\nLikely target function/class: "+targets+
                    "\nEstimated benefit potential: "+estimatedBenefitPercent+"%"+
                    "\nNote: benefit estimate code scope/integration signals par based hai; actual quality update install ke baad tests se score hogi.";
        }
    }

    private static final Pattern JAVA_TYPE=Pattern.compile(
            "\\b(?:class|interface|enum|record)\\s+([A-Za-z_$][A-Za-z0-9_$]*)");
    private static final Pattern KOTLIN_FUN=Pattern.compile(
            "\\bfun\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\(");
    private static final Pattern JAVA_METHOD=Pattern.compile(
            "(?m)(?:public|protected|private|static|final|synchronized|native|abstract|\\s)+[A-Za-z0-9_$<>\\[\\].?]+\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\(");

    private CodeIntakeAnalyzer(){}

    public static boolean looksLikeCode(String raw){
        if(raw==null)return false;
        String s=raw.trim();
        if(s.length()<35)return false;
        String l=s.toLowerCase(Locale.ROOT);
        int score=0;
        if(l.contains("package ")&&s.contains(";"))score+=3;
        if(l.contains("import ")&&s.contains(";"))score+=2;
        if(l.matches("(?s).*\\b(class|interface|enum|record)\\s+[a-zA-Z_$][a-zA-Z0-9_$]*.*"))score+=3;
        if(l.matches("(?s).*\\b(public|private|protected)\\s+(static\\s+)?[a-zA-Z0-9_<>\\[\\].?]+\\s+[a-zA-Z_$][a-zA-Z0-9_$]*\\s*\\(.*"))score+=2;
        if(l.contains(" fun ")||l.startsWith("fun ")||l.contains("override fun "))score+=3;
        if(l.contains("<?xml")||l.contains("<manifest")||l.contains("<linearlayout")||l.contains("<resources"))score+=4;
        if(l.contains("<html")||l.contains("<script")||l.contains("function(")||l.contains("=>"))score+=2;
        if(l.contains("gradle")||l.contains("dependencies {")||l.contains("android {"))score+=2;
        if(s.contains("{")&&s.contains("}")&&s.contains("(")&&s.contains(")"))score+=1;
        if(s.split("\n").length>=4)score+=1;
        return score>=3;
    }

    public static Analysis analyze(String raw){
        String s=raw==null?"":raw.trim();
        boolean code=looksLikeCode(s);
        String language=detectLanguage(s);
        LinkedHashSet<String> targets=new LinkedHashSet<>();
        collect(JAVA_TYPE,s,targets,5);
        collect(KOTLIN_FUN,s,targets,5);
        collect(JAVA_METHOD,s,targets,5);
        inferAreas(s,targets);

        if(targets.isEmpty())targets.add("existing Anamika function determined from source integration");
        String targetText=join(targets,8);

        int benefit=45;
        String l=s.toLowerCase(Locale.ROOT);
        if(!targets.isEmpty())benefit+=8;
        if(l.contains("try")&&l.contains("catch"))benefit+=4;
        if(l.contains("validate")||l.contains("verify")||l.contains("check"))benefit+=5;
        if(l.contains("fallback")||l.contains("rollback")||l.contains("recovery"))benefit+=6;
        if(l.contains("timeout")||l.contains("retry"))benefit+=4;
        if(l.contains("memory")||l.contains("context")||l.contains("language"))benefit+=5;
        if(l.contains("wake")||l.contains("voice")||l.contains("speech"))benefit+=5;
        if(l.contains("upgrade")||l.contains("build")||l.contains("function pack"))benefit+=6;
        if(s.length()>1500)benefit+=3;
        if(benefit>92)benefit=92;
        if(!code)benefit=25;

        return new Analysis(code,language,targetText,benefit,
                "Detected "+language+" code targeting "+targetText+".");
    }

    private static String detectLanguage(String s){
        String l=s.toLowerCase(Locale.ROOT);
        if(l.contains("<?xml")||l.contains("<manifest")||l.contains("<resources"))return "Android XML";
        if(l.contains("<html")||l.contains("<script"))return "HTML/JavaScript";
        if(l.contains("plugins {")||l.contains("android {")||l.contains("dependencies {"))return "Gradle";
        if(l.matches("(?s).*\\bfun\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(.*")||l.contains("val ")||l.contains("var "))return "Kotlin";
        if(l.contains("package ")||l.contains("public class")||l.contains("private static")||l.contains("public static"))return "Java";
        if(l.contains("def ")||l.contains("import os")||l.contains("if __name__"))return "Python";
        if(l.contains("const ")||l.contains("let ")||l.contains("function "))return "JavaScript";
        if(l.trim().startsWith("{")&&l.trim().endsWith("}"))return "JSON/config";
        return "source/config code";
    }

    private static void collect(Pattern p,String s,Set<String> out,int max){
        Matcher m=p.matcher(s);
        while(m.find()&&out.size()<max){
            String n=m.group(1);
            if(n==null||n.length()<2)continue;
            if("if".equals(n)||"for".equals(n)||"while".equals(n)||"catch".equals(n)||"switch".equals(n))continue;
            out.add(n);
        }
    }

    private static void inferAreas(String s,Set<String> out){
        String l=s.toLowerCase(Locale.ROOT);
        if(l.contains("wake")||l.contains("speechrecognizer")||l.contains("voice"))out.add("Voice/Wake");
        if(l.contains("upgrade")||l.contains("apk")||l.contains("signer")||l.contains("build"))out.add("Self-Upgrade");
        if(l.contains("functionpack")||l.contains("function pack"))out.add("Function Pack");
        if(l.contains("language")||l.contains("hinglish")||l.contains("context"))out.add("Language/Context");
        if(l.contains("message")||l.contains("whatsapp"))out.add("Messaging");
        if(l.contains("accessibility")||l.contains("plugin"))out.add("Plugin/Automation");
        if(l.contains("memory")||l.contains("remember"))out.add("Memory");
        if(l.contains("diagnostic")||l.contains("health")||l.contains("crash"))out.add("Diagnostics/Health");
    }

    private static String join(Set<String> set,int max){
        List<String> x=new ArrayList<>(set);
        StringBuilder b=new StringBuilder();
        for(int i=0;i<x.size()&&i<max;i++){
            if(i>0)b.append(", ");
            b.append(x.get(i));
        }
        return b.toString();
    }
}
