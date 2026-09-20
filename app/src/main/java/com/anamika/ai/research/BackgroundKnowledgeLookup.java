package com.anamika.ai.research;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * Background public-knowledge lookup for words/short concepts.
 * Uses Wikimedia REST search APIs over HTTPS and caches successful results locally.
 */
public final class BackgroundKnowledgeLookup {
    public interface Callback { void onResult(Result result); }

    public static final class Result {
        public final boolean found;
        public final boolean fromCache;
        public final String title;
        public final String summary;
        public final String source;
        Result(boolean found,boolean fromCache,String title,String summary,String source){
            this.found=found; this.fromCache=fromCache; this.title=title; this.summary=summary; this.source=source;
        }
    }

    private static final String PREFS="anamika_web_learning";
    private BackgroundKnowledgeLookup(){}

    public static void lookup(Context context,String query,boolean preferHindi,Callback callback){
        final String q=query==null?"":query.trim();
        if(q.isEmpty()){ callback.onResult(new Result(false,false,"","","")); return; }

        Result cached=load(context,q);
        if(cached!=null){ callback.onResult(cached); return; }

        new Thread(() -> {
            Result r=null;
            if(preferHindi) r=fetchWikipedia("hi",q);
            if(r==null || !r.found) r=fetchWikipedia("en",q);
            if(r!=null && r.found) save(context,q,r);
            final Result out=r==null?new Result(false,false,"","",""):r;
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> callback.onResult(out));
        },"AnamikaKnowledgeLookup").start();
    }

    private static Result fetchWikipedia(String lang,String query){
        HttpURLConnection conn=null;
        try{
            String encoded=URLEncoder.encode(query,StandardCharsets.UTF_8.name());
            URL u=new URL("https://"+lang+".wikipedia.org/w/rest.php/v1/search/page?q="+encoded+"&limit=1");
            conn=(HttpURLConnection)u.openConnection();
            conn.setConnectTimeout(7000);
            conn.setReadTimeout(9000);
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Accept","application/json");
            conn.setRequestProperty("User-Agent","AnamikaAI/7.8.2 Android");
            int code=conn.getResponseCode();
            if(code<200 || code>=300) return null;
            BufferedReader br=new BufferedReader(new InputStreamReader(conn.getInputStream(),StandardCharsets.UTF_8));
            StringBuilder raw=new StringBuilder();
            String line;
            while((line=br.readLine())!=null){ raw.append(line); if(raw.length()>200000) break; }
            JSONObject root=new JSONObject(raw.toString());
            JSONArray pages=root.optJSONArray("pages");
            if(pages==null || pages.length()==0) return null;
            JSONObject p=pages.optJSONObject(0);
            if(p==null) return null;
            String title=p.optString("title",query);
            String desc=p.optString("description","");
            String excerpt=stripHtml(p.optString("excerpt",""));
            String summary=(desc+" "+excerpt).trim().replaceAll("\\s+"," ");
            if(summary.isEmpty()) return null;
            if(summary.length()>900) summary=summary.substring(0,900).trim();
            return new Result(true,false,title,summary,"Wikipedia "+lang.toUpperCase(Locale.ROOT));
        }catch(Throwable ignored){
            return null;
        }finally{
            if(conn!=null) conn.disconnect();
        }
    }

    private static String stripHtml(String s){
        if(s==null) return "";
        return s.replaceAll("<[^>]+>"," ")
                .replace("&quot;","\"")
                .replace("&amp;","&")
                .replace("&#39;","'")
                .replaceAll("\\s+"," ")
                .trim();
    }

    private static String key(String query){
        return "q_"+Integer.toHexString(query.trim().toLowerCase(Locale.ROOT).hashCode());
    }

    private static void save(Context c,String query,Result r){
        if(c==null || r==null || !r.found) return;
        String packed=r.title+"\n"+r.summary+"\n"+r.source;
        c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().putString(key(query),packed).apply();
    }

    private static Result load(Context c,String query){
        if(c==null) return null;
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        String packed=p.getString(key(query),"");
        if(packed.isEmpty()) return null;
        String[] x=packed.split("\\n",3);
        if(x.length<3) return null;
        return new Result(true,true,x[0],x[1],x[2]);
    }
}
