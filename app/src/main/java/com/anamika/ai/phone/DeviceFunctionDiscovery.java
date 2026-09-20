package com.anamika.ai.phone;

import android.content.Context;
import android.content.Intent;
import android.os.Build;

import com.anamika.ai.LocalModelBridge;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class DeviceFunctionDiscovery {
    public interface Callback { void onResult(Result r); }
    public static final class Result {
        public final boolean found;
        public final boolean verified;
        public final String explanation;
        public final String action;
        public final boolean fromMemory;
        Result(boolean f,boolean v,String e,String a,boolean m){
            found=f;verified=v;explanation=e;action=a;fromMemory=m;
        }
    }

    private DeviceFunctionDiscovery(){}

    public static void discover(Context c,String phrase,Callback cb){
        VerifiedFunctionMemory.Entry remembered=VerifiedFunctionMemory.find(c,phrase);
        if(remembered!=null && !remembered.action.isEmpty() && new Intent(remembered.action).resolveActivity(c.getPackageManager())!=null){
            cb.onResult(new Result(true,true,remembered.label,remembered.action,true));
            return;
        }

        new Thread(() -> {
            String deviceContext=DeviceProfileStore.searchContext(c);
            String query=(phrase==null?"":phrase.trim())+" "+deviceContext+" setting";
            String web=searchWeb(query);
            String candidate=VerifiedFunctionMemory.knownActionForKeyword(
                    (phrase==null?"":phrase)
            );
            boolean verified=false;
            if(!candidate.isEmpty()){
                verified=new Intent(candidate).resolveActivity(c.getPackageManager())!=null;
            }
            String explanation=buildExplanation(c,phrase,web,candidate);
            Result out=new Result(!web.isEmpty()||!candidate.isEmpty(),verified,explanation,candidate,false);
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> cb.onResult(out));
        },"AnamikaFunctionDiscovery").start();
    }

    private static String buildExplanation(Context c,String phrase,String web,String action){
        if(web==null) web="";
        try{
            if(LocalModelBridge.getStatus(c).ready && !web.isEmpty()){
                String prompt="You are Anamika. The owner asked about a phone function/settings control. "+
                        "Explain in concise Indian Hinglish what the function likely is and where it is, using only the web snippet below. "+
                        "Do not claim it is verified unless Android local verification confirms it. "+
                        "Owner phrase: "+phrase+"\nWeb snippets:\n"+web+"\nCandidate Android action: "+action;
                String out=LocalModelBridge.generate(c,prompt);
                if(out!=null&&!out.trim().isEmpty()) return out.trim();
            }
        }catch(Throwable ignored){}
        if(!action.isEmpty()) return "Android setting route mila hai aur local device par verify kiya ja sakta hai.";
        return web.isEmpty()?"Function ka reliable route nahi mila.":"Web se possible location mili, lekin local verification pending hai.";
    }

    private static String searchWeb(String query){
        HttpURLConnection conn=null;
        try{
            String q=URLEncoder.encode(query,StandardCharsets.UTF_8.name());
            URL u=new URL("https://html.duckduckgo.com/html/?q="+q);
            conn=(HttpURLConnection)u.openConnection();
            conn.setConnectTimeout(7000);
            conn.setReadTimeout(9000);
            conn.setInstanceFollowRedirects(true);
            conn.setRequestProperty("User-Agent","Mozilla/5.0 AnamikaAI/7.8.2");
            int code=conn.getResponseCode();
            if(code<200||code>=300) return "";
            StringBuilder html=new StringBuilder();
            try(BufferedReader br=new BufferedReader(new InputStreamReader(conn.getInputStream(),StandardCharsets.UTF_8))){
                String line; while((line=br.readLine())!=null && html.length()<350000) html.append(line).append('\n');
            }
            Pattern p=Pattern.compile("(?s)<a[^>]*class=\\\"result__snippet[^>]*>(.*?)</a>|<div[^>]*class=\\\"result__snippet[^>]*>(.*?)</div>");
            Matcher m=p.matcher(html.toString());
            StringBuilder out=new StringBuilder();
            while(m.find() && out.length()<5000){
                String raw=m.group(1)!=null?m.group(1):m.group(2);
                String clean=raw.replaceAll("<[^>]+>"," ")
                        .replace("&amp;","&").replace("&quot;","\"").replace("&#x27;","'")
                        .replaceAll("\\s+"," ").trim();
                if(!clean.isEmpty()) out.append(clean).append('\n');
            }
            return out.toString().trim();
        }catch(Throwable ignored){
            return "";
        }finally{ if(conn!=null) conn.disconnect(); }
    }

    public static boolean openVerified(Context c,String phrase){
        VerifiedFunctionMemory.Entry e=VerifiedFunctionMemory.find(c,phrase);
        if(e==null||e.action.isEmpty()) return false;
        try{
            Intent i=new Intent(e.action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if(i.resolveActivity(c.getPackageManager())==null) return false;
            c.startActivity(i);
            return true;
        }catch(Throwable t){return false;}
    }
}
