package com.anamika.ai.developer;

import com.anamika.ai.core.AndroidCompat;

import android.util.Xml;

import org.json.JSONArray;
import org.json.JSONObject;
import org.xmlpull.v1.XmlPullParser;

import java.io.File;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Lightweight structural Code Doctor written for V13.
 * PASS means these structural checks passed, not that a full Android build passed.
 */
public final class CodeDoctor {
    public static final class Report {
        public final boolean clean;
        public final int filesChecked;
        public final List<String> problems;

        public Report(boolean clean,int filesChecked,List<String> problems){
            this.clean=clean;
            this.filesChecked=filesChecked;
            this.problems=problems;
        }

        public String text(){
            StringBuilder b=new StringBuilder();
            b.append(clean?"STRUCTURAL PASS":"STRUCTURAL FAIL")
                    .append("\nFiles checked: ").append(filesChecked);
            for(String p:problems)b.append("\n- ").append(p);
            if(clean)b.append("\nA real APK build is still required before installation.");
            return b.toString();
        }
    }

    private CodeDoctor(){}

    public static Report inspect(File root){
        List<String> problems=new ArrayList<>();
        int[] count={0};
        walk(root,root,count,problems);
        if(count[0]==0)problems.add("No source/config files were found.");
        return new Report(problems.isEmpty(),count[0],problems);
    }

    private static void walk(File root,File f,int[] count,List<String> problems){
        if(f==null||!f.exists())return;
        if(f.isDirectory()){
            File[] children=f.listFiles();
            if(children!=null)for(File c:children)walk(root,c,count,problems);
            return;
        }
        String n=f.getName().toLowerCase(Locale.ROOT);
        if(!(n.endsWith(".java")||n.endsWith(".kt")||n.endsWith(".xml")||
                n.endsWith(".json")||n.endsWith(".gradle")||n.endsWith(".properties")))return;
        count[0]++;
        try{
            String s=new String(AndroidCompat.readAllBytes(f),StandardCharsets.UTF_8);
            String rel=relative(root,f);
            if(n.endsWith(".json"))checkJson(rel,s,problems);
            else if(n.endsWith(".xml"))checkXml(rel,s,problems);
            else if(n.endsWith(".java")||n.endsWith(".kt")||n.endsWith(".gradle"))
                checkBrackets(rel,s,problems);
            if(s.indexOf('\0')>=0)problems.add(rel+": contains NUL characters.");
        }catch(Exception e){
            problems.add(f.getName()+": unreadable ("+safe(e)+")");
        }
    }

    private static void checkJson(String path,String s,List<String> problems){
        String t=s.trim();
        try{
            if(t.startsWith("{"))new JSONObject(t);
            else if(t.startsWith("["))new JSONArray(t);
            else problems.add(path+": JSON must start with { or [.");
        }catch(Exception e){problems.add(path+": invalid JSON ("+safe(e)+")");}
    }

    private static void checkXml(String path,String s,List<String> problems){
        try{
            XmlPullParser p=Xml.newPullParser();
            p.setInput(new StringReader(s));
            while(p.next()!=XmlPullParser.END_DOCUMENT){}
        }catch(Exception e){problems.add(path+": invalid XML ("+safe(e)+")");}
    }

    private static void checkBrackets(String path,String s,List<String> problems){
        int curly=0,round=0,square=0;
        boolean line=false,block=false,escape=false;
        char quote=0;
        for(int i=0;i<s.length();i++){
            char c=s.charAt(i),n=i+1<s.length()?s.charAt(i+1):'\0';
            if(line){if(c=='\n')line=false;continue;}
            if(block){if(c=='*'&&n=='/'){block=false;i++;}continue;}
            if(quote!=0){
                if(escape){escape=false;continue;}
                if(c=='\\'){escape=true;continue;}
                if(c==quote)quote=0;
                continue;
            }
            if(c=='/'&&n=='/'){line=true;i++;continue;}
            if(c=='/'&&n=='*'){block=true;i++;continue;}
            if(c=='\''||c=='"'){quote=c;continue;}
            if(c=='{')curly++; else if(c=='}')curly--;
            else if(c=='(')round++; else if(c==')')round--;
            else if(c=='[')square++; else if(c==']')square--;
            if(curly<0||round<0||square<0){problems.add(path+": closing bracket without opener.");return;}
        }
        if(block)problems.add(path+": unclosed block comment.");
        if(quote!=0)problems.add(path+": unclosed quoted string.");
        if(curly!=0||round!=0||square!=0)problems.add(path+": unbalanced brackets.");
    }

    private static String relative(File root,File f)throws Exception{
        String rp=root.getCanonicalPath();
        String fp=f.getCanonicalPath();
        if(fp.startsWith(rp+File.separator))return fp.substring(rp.length()+1).replace('\\','/');
        return f.getName();
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
