package com.anamika.ai.creator;

import android.content.Context;
import android.media.MediaMetadataRetriever;
import android.os.Environment;

import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Provider-neutral online cinematic generator.
 * API keys are per-request only and are never persisted by this class.
 */
public final class InternetCinematicCreator {
    public interface Callback {
        void onProgress(String message);
        void onComplete(File video, Verification verification);
        void onError(String error);
    }

    public static final class Verification {
        public final int width;
        public final int height;
        public final long durationMs;
        public final boolean fullHdOrBetter;
        Verification(int width,int height,long durationMs){
            this.width=width; this.height=height; this.durationMs=durationMs;
            int longSide=Math.max(width,height), shortSide=Math.min(width,height);
            this.fullHdOrBetter=(longSide>=1920 && shortSide>=1080);
        }
    }

    private InternetCinematicCreator() {}

    public static void generate(Context context, String endpoint, String apiKey, String model,
                                String prompt, String referenceUrl, Callback callback) {
        new Thread(() -> {
            try {
                URL base=requireHttps(endpoint,"Creator endpoint");
                if (prompt == null || prompt.trim().isEmpty()) throw new IllegalArgumentException("Video prompt is empty.");
                callback.onProgress("Sending cinematic generation job…");
                JSONObject payload=new JSONObject();
                payload.put("prompt",prompt.trim());
                payload.put("model",model==null?"":model.trim());
                payload.put("reference_url",referenceUrl==null?"":referenceUrl.trim());
                payload.put("resolution","1920x1080");
                payload.put("style","premium cinematic 3D animation movie");
                payload.put("fps",30);
                payload.put("audio",true);

                JSONObject first=postJson(base,apiKey,payload);
                String video=first.optString("video_url","");
                String status=first.optString("status_url","");
                if(video.isEmpty() && status.isEmpty()) throw new IllegalStateException("Provider response has no video_url or status_url.");
                if(video.isEmpty()) {
                    URL statusUrl=requireHttps(status,"Provider status URL");
                    String statusKey=sameOrigin(base,statusUrl)?apiKey:""; // never leak the bearer token to another host/origin
                    for(int i=0;i<120;i++) {
                        Thread.sleep(3000L);
                        callback.onProgress("Rendering online… check "+(i+1));
                        JSONObject state=getJson(statusUrl,statusKey);
                        String stateName=state.optString("status","").toLowerCase(Locale.ROOT);
                        if(stateName.equals("failed")||stateName.equals("error")) throw new IllegalStateException(state.optString("error","Provider generation failed."));
                        video=state.optString("video_url","");
                        if(!video.isEmpty()) break;
                        if(stateName.equals("complete")||stateName.equals("succeeded")) {
                            throw new IllegalStateException("Provider marked job complete but returned no video_url.");
                        }
                    }
                }
                if(video.isEmpty()) throw new IllegalStateException("Provider did not return a completed video in time.");
                callback.onProgress("Downloading generated video…");
                File out=downloadVideo(context,requireHttps(video,"Generated video URL"));
                Verification v=verify(out);
                callback.onComplete(out,v);
            } catch(Exception e) {
                callback.onError(e.getMessage()==null?e.toString():e.getMessage());
            }
        },"anamika-internet-cinematic").start();
    }

    private static JSONObject postJson(URL endpoint,String apiKey,JSONObject payload) throws Exception {
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try {
            c.setConnectTimeout(20000); c.setReadTimeout(120000); c.setRequestMethod("POST"); c.setDoOutput(true);
            c.setInstanceFollowRedirects(false);
            c.setRequestProperty("Content-Type","application/json");
            if(apiKey!=null && !apiKey.isEmpty()) c.setRequestProperty("Authorization","Bearer "+apiKey);
            try(OutputStream out=c.getOutputStream()){ out.write(payload.toString().getBytes(StandardCharsets.UTF_8)); }
            return readJson(c);
        } finally { c.disconnect(); }
    }

    private static JSONObject getJson(URL endpoint,String apiKey) throws Exception {
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try {
            c.setConnectTimeout(20000); c.setReadTimeout(60000); c.setRequestMethod("GET");
            c.setInstanceFollowRedirects(false);
            if(apiKey!=null && !apiKey.isEmpty()) c.setRequestProperty("Authorization","Bearer "+apiKey);
            return readJson(c);
        } finally { c.disconnect(); }
    }

    private static JSONObject readJson(HttpURLConnection c) throws Exception {
        int code=c.getResponseCode();
        if(code>=300 && code<400) throw new IllegalStateException("HTTP redirect refused for authenticated creator request ("+code+"). Configure the final HTTPS endpoint directly.");
        InputStream in=(code>=200&&code<300)?c.getInputStream():c.getErrorStream();
        if(in==null) throw new IllegalStateException("HTTP "+code);
        StringBuilder sb=new StringBuilder();
        try(BufferedReader r=new BufferedReader(new InputStreamReader(in,StandardCharsets.UTF_8))){ String line; while((line=r.readLine())!=null && sb.length()<1_000_000) sb.append(line); }
        if(code<200||code>=300) throw new IllegalStateException("HTTP "+code+": "+sb);
        return new JSONObject(sb.toString());
    }

    private static File downloadVideo(Context context,URL url) throws Exception {
        File dir=context.getExternalFilesDir(Environment.DIRECTORY_MOVIES); if(dir==null) dir=context.getFilesDir();
        if(!dir.exists()&&!dir.mkdirs()) throw new IllegalStateException("Cannot create movie folder.");
        String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date());
        File out=new File(dir,"AnamikaOnlineCinematic_"+stamp+".mp4");
        HttpURLConnection c=(HttpURLConnection)url.openConnection();
        boolean ok=false;
        try {
            c.setConnectTimeout(20000); c.setReadTimeout(180000); c.setInstanceFollowRedirects(false);
            int code=c.getResponseCode();
            if(code<200||code>=300) throw new IllegalStateException("Video download HTTP "+code);
            long declared=c.getContentLengthLong();
            if(declared>4L*1024L*1024L*1024L) throw new IllegalStateException("Video exceeds 4 GB safety limit.");
            try(InputStream in=new BufferedInputStream(c.getInputStream()); FileOutputStream fos=new FileOutputStream(out)){
                byte[] buf=new byte[1024*256]; int n; long total=0;
                while((n=in.read(buf))>0){
                    total+=n;
                    if(total>4L*1024L*1024L*1024L) throw new IllegalStateException("Video exceeds 4 GB safety limit.");
                    fos.write(buf,0,n);
                }
                if(total<1024) throw new IllegalStateException("Downloaded video is unexpectedly small.");
            }
            ok=true;
            return out;
        } finally {
            c.disconnect();
            if(!ok && out.exists()) try{out.delete();}catch(Exception ignored){}
        }
    }

    private static Verification verify(File f) throws Exception {
        MediaMetadataRetriever r=new MediaMetadataRetriever();
        try {
            r.setDataSource(f.getAbsolutePath());
            int w=parseInt(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
            int h=parseInt(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
            long d=parseLong(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
            if(w<=0||h<=0||d<=0) throw new IllegalStateException("Downloaded file is not a valid video.");
            return new Verification(w,h,d);
        } finally { try{r.release();}catch(Exception ignored){} }
    }

    private static URL requireHttps(String raw,String label) throws Exception {
        if(raw==null||raw.trim().isEmpty()) throw new IllegalArgumentException(label+" is required.");
        URL u=new URL(raw.trim());
        if(!"https".equalsIgnoreCase(u.getProtocol())) throw new SecurityException(label+" must use HTTPS.");
        if(u.getHost()==null||u.getHost().trim().isEmpty()) throw new SecurityException(label+" has no valid host.");
        return u;
    }

    private static boolean sameOrigin(URL a,URL b){
        int ap=a.getPort()<0?a.getDefaultPort():a.getPort();
        int bp=b.getPort()<0?b.getDefaultPort():b.getPort();
        return a.getProtocol().equalsIgnoreCase(b.getProtocol()) && a.getHost().equalsIgnoreCase(b.getHost()) && ap==bp;
    }
    private static int parseInt(String s){ try{return Integer.parseInt(s);}catch(Exception e){return 0;} }
    private static long parseLong(String s){ try{return Long.parseLong(s);}catch(Exception e){return 0L;} }
}
