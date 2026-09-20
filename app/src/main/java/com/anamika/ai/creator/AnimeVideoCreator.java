package com.anamika.ai.creator;

import android.content.Context;
import android.media.MediaMetadataRetriever;
import com.anamika.ai.files.AnamikaVault;

import org.json.JSONObject;
import org.json.JSONArray;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * Provider-neutral anime video pipeline.
 *
 * Supported workflows:
 * - video_to_anime: transforms an owner-selected source video.
 * - story_to_anime: generates scenes, dialogue and multi-character audio from a story.
 *
 * Voice instructions request generic human-like character voices. This class never
 * requests or performs cloning of an identifiable person's voice.
 */
public final class AnimeVideoCreator {
    public interface Callback {
        void onProgress(String message);
        void onComplete(File video, Verification verification);
        void onError(String error);
    }

    public static final class Verification {
        public final int width,height;
        public final long durationMs;
        public final boolean valid;
        Verification(int w,int h,long d){
            width=w;height=h;durationMs=d;valid=w>0&&h>0&&d>0;
        }
    }

    private AnimeVideoCreator(){}

    public static void transformVideo(Context context,String endpoint,String apiKey,String model,
                                      File source,String prompt,int width,int height,Callback cb){
        new Thread(() -> {
            try{
                if(source==null||!source.isFile()) throw new FileNotFoundException("Source video missing.");
                if(source.length()>3L*1024L*1024L*1024L) throw new IllegalArgumentException("Source video exceeds 3 GB.");
                URL base=requireHttps(endpoint,"Anime creator endpoint");
                cb.onProgress("Uploading source video for anime transformation…");
                JSONObject first=postMultipart(base,apiKey,source,commonFields(
                        "video_to_anime",model,prompt,width,height));
                File out=waitAndDownload(context,base,apiKey,first,cb);
                Verification v=verify(out);
                if(!v.valid) throw new IllegalStateException("Provider output is not a valid video.");
                AnamikaVault.registerGeneratedFile(context,out,"video/mp4");
                cb.onComplete(out,v);
            }catch(Exception e){
                cb.onError(e.getMessage()==null?e.toString():e.getMessage());
            }
        },"anamika-video-to-anime").start();
    }

    public static void storyToAnime(Context context,String endpoint,String apiKey,String model,
                                    String story,int width,int height,Callback cb){
        new Thread(() -> {
            try{
                if(story==null||story.trim().isEmpty()) throw new IllegalArgumentException("Story is empty.");
                URL base=requireHttps(endpoint,"Anime creator endpoint");
                cb.onProgress("Planning anime scenes, dialogue and character voices…");
                JSONObject payload=commonFields("story_to_anime",model,story,width,height);
                payload.put("story",story.trim());
                payload.put("auto_storyboard",true);
                payload.put("auto_dialogue",true);
                payload.put("auto_character_cast",true);
                payload.put("character_age_detection",true);
                payload.put("character_gender_presentation_detection",true);
                payload.put("character_personality_detection",true);
                payload.put("multi_character_voices",true);
                payload.put("voice_assignment","one distinct generic voice per character; keep the same assigned voice for that character across every scene");
                payload.put("voice_cast_profiles",defaultVoiceCastProfiles());
                payload.put("voice_cast_rules",
                        "Assign by story/visual character description: adult man -> adult_male; adult woman -> adult_female; "+
                        "boy -> child_boy; girl -> child_girl; old man -> elderly_male; old woman -> elderly_female; "+
                        "narration -> narrator. If age/gender is unclear, choose a neutral generic voice and keep it consistent.");
                payload.put("voice_personality_matching",true);
                payload.put("voice_emotion_matching",true);
                payload.put("voice_consistency_across_scenes",true);
                payload.put("speaker_separation",true);
                payload.put("dialogue_lip_sync_per_character",true);
                JSONObject first=postJson(base,apiKey,payload);
                File out=waitAndDownload(context,base,apiKey,first,cb);
                Verification v=verify(out);
                if(!v.valid) throw new IllegalStateException("Provider output is not a valid video.");
                AnamikaVault.registerGeneratedFile(context,out,"video/mp4");
                cb.onComplete(out,v);
            }catch(Exception e){
                cb.onError(e.getMessage()==null?e.toString():e.getMessage());
            }
        },"anamika-story-to-anime").start();
    }

    private static JSONArray defaultVoiceCastProfiles()throws Exception{
        JSONArray a=new JSONArray();
        a.put(voiceProfile("adult_male","adult male","natural, warm, confident; optional deep/soft/serious/energetic variants",0.92,0.82));
        a.put(voiceProfile("adult_female","adult female","natural, expressive, clear; optional soft/calm/energetic/serious variants",1.08,0.92));
        a.put(voiceProfile("child_boy","young boy","child-like, bright, playful, believable; never robotic",1.22,1.02));
        a.put(voiceProfile("child_girl","young girl","child-like, bright, expressive, believable; never robotic",1.28,1.03));
        a.put(voiceProfile("elderly_male","elderly male","older, textured, slower, natural breath and age character",0.80,0.76));
        a.put(voiceProfile("elderly_female","elderly female","older, warm/textured, slower, natural age character",0.94,0.78));
        a.put(voiceProfile("narrator","narrator","cinematic, clear, emotionally controlled, natural human delivery",0.98,0.88));
        a.put(voiceProfile("neutral","gender-neutral adult","natural neutral character voice",1.00,0.90));
        return a;
    }

    private static JSONObject voiceProfile(String id,String ageGender,String style,double pitchHint,double rateHint)throws Exception{
        JSONObject o=new JSONObject();
        o.put("id",id);
        o.put("age_gender",ageGender);
        o.put("style",style);
        o.put("pitch_hint",pitchHint);
        o.put("rate_hint",rateHint);
        o.put("human_realism","high");
        o.put("anime_performance","natural character acting");
        o.put("avoid_robotic_tts",true);
        o.put("clone_real_person",false);
        return o;
    }

    private static JSONObject commonFields(String workflow,String model,String prompt,int width,int height)throws Exception{
        JSONObject p=new JSONObject();
        int w=Math.max(256,Math.min(4096,width<=0?1920:width));
        int h=Math.max(256,Math.min(4096,height<=0?1080:height));
        p.put("workflow",workflow);
        p.put("model",model==null?"":model.trim());
        p.put("prompt",prompt==null?"":prompt.trim());
        p.put("width",w);
        p.put("height",h);
        p.put("resolution",w+"x"+h);
        p.put("fps",30);
        p.put("style","high-quality original anime look; temporal consistency; stable faces; clean line art; cinematic lighting");
        p.put("preserve_motion",true);
        p.put("preserve_scene_timing",true);
        p.put("lip_sync",true);
        p.put("audio",true);
        p.put("voice_style","natural human-like anime character performance");
        p.put("voice_realism","high");
        p.put("avoid_robotic_tts",true);
        p.put("voice_clone",false);
        p.put("voice_identity_policy","generic non-identifiable character voices only");
        p.put("dialogue_language","auto-detect from story/source");
        return p;
    }

    private static JSONObject postMultipart(URL endpoint,String apiKey,File source,JSONObject fields)throws Exception{
        String boundary="----AnamikaAnime"+Long.toHexString(System.currentTimeMillis());
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try{
            c.setConnectTimeout(30000);
            c.setReadTimeout(180000);
            c.setRequestMethod("POST");
            c.setDoOutput(true);
            c.setChunkedStreamingMode(1024*1024);
            c.setInstanceFollowRedirects(false);
            c.setRequestProperty("Content-Type","multipart/form-data; boundary="+boundary);
            if(apiKey!=null&&!apiKey.isEmpty()) c.setRequestProperty("Authorization","Bearer "+apiKey);

            try(OutputStream raw=new BufferedOutputStream(c.getOutputStream())){
                for(Iterator<String> it=fields.keys();it.hasNext();){
                    String key=it.next();
                    writeTextPart(raw,boundary,key,String.valueOf(fields.opt(key)));
                }
                raw.write(("--"+boundary+"\r\n").getBytes(StandardCharsets.UTF_8));
                raw.write(("Content-Disposition: form-data; name=\"source_video\"; filename=\""+
                        safeFilename(source.getName())+"\"\r\n").getBytes(StandardCharsets.UTF_8));
                raw.write("Content-Type: video/mp4\r\n\r\n".getBytes(StandardCharsets.UTF_8));
                try(InputStream in=new BufferedInputStream(new FileInputStream(source))){
                    byte[] b=new byte[256*1024];int n;
                    while((n=in.read(b))>0) raw.write(b,0,n);
                }
                raw.write("\r\n".getBytes(StandardCharsets.UTF_8));
                raw.write(("--"+boundary+"--\r\n").getBytes(StandardCharsets.UTF_8));
            }
            return readJson(c);
        }finally{c.disconnect();}
    }

    private static void writeTextPart(OutputStream out,String boundary,String name,String value)throws Exception{
        out.write(("--"+boundary+"\r\n").getBytes(StandardCharsets.UTF_8));
        out.write(("Content-Disposition: form-data; name=\""+name+"\"\r\n\r\n").getBytes(StandardCharsets.UTF_8));
        out.write((value==null?"":value).getBytes(StandardCharsets.UTF_8));
        out.write("\r\n".getBytes(StandardCharsets.UTF_8));
    }

    private static JSONObject postJson(URL endpoint,String apiKey,JSONObject payload)throws Exception{
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try{
            c.setConnectTimeout(30000);c.setReadTimeout(180000);c.setRequestMethod("POST");c.setDoOutput(true);
            c.setInstanceFollowRedirects(false);c.setRequestProperty("Content-Type","application/json");
            if(apiKey!=null&&!apiKey.isEmpty())c.setRequestProperty("Authorization","Bearer "+apiKey);
            try(OutputStream out=c.getOutputStream()){out.write(payload.toString().getBytes(StandardCharsets.UTF_8));}
            return readJson(c);
        }finally{c.disconnect();}
    }

    private static File waitAndDownload(Context context,URL base,String apiKey,JSONObject first,Callback cb)throws Exception{
        String video=first.optString("video_url","");
        String status=first.optString("status_url","");
        if(video.isEmpty()&&status.isEmpty()) throw new IllegalStateException("Provider response has no video_url or status_url.");
        if(video.isEmpty()){
            URL statusUrl=requireHttps(status,"Anime provider status URL");
            String statusKey=sameOrigin(base,statusUrl)?apiKey:"";
            for(int i=0;i<180;i++){
                Thread.sleep(3000L);
                cb.onProgress("Anime rendering + voice processing… "+(i+1));
                JSONObject state=getJson(statusUrl,statusKey);
                String st=state.optString("status","").toLowerCase(Locale.ROOT);
                if(st.equals("failed")||st.equals("error")) throw new IllegalStateException(state.optString("error","Anime generation failed."));
                video=state.optString("video_url","");
                if(!video.isEmpty())break;
            }
        }
        if(video.isEmpty()) throw new IllegalStateException("Provider did not return a completed anime video in time.");
        cb.onProgress("Downloading and verifying anime video…");
        return download(context,requireHttps(video,"Generated anime video URL"));
    }

    private static JSONObject getJson(URL endpoint,String apiKey)throws Exception{
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try{
            c.setConnectTimeout(20000);c.setReadTimeout(60000);c.setRequestMethod("GET");c.setInstanceFollowRedirects(false);
            if(apiKey!=null&&!apiKey.isEmpty())c.setRequestProperty("Authorization","Bearer "+apiKey);
            return readJson(c);
        }finally{c.disconnect();}
    }

    private static JSONObject readJson(HttpURLConnection c)throws Exception{
        int code=c.getResponseCode();
        if(code>=300&&code<400) throw new IllegalStateException("HTTP redirect refused ("+code+"). Use final HTTPS endpoint.");
        InputStream in=(code>=200&&code<300)?c.getInputStream():c.getErrorStream();
        if(in==null)throw new IOException("HTTP "+code);
        StringBuilder sb=new StringBuilder();
        try(BufferedReader r=new BufferedReader(new InputStreamReader(in,StandardCharsets.UTF_8))){
            String line;while((line=r.readLine())!=null&&sb.length()<1_000_000)sb.append(line);
        }
        if(code<200||code>=300)throw new IOException("HTTP "+code+": "+sb);
        return new JSONObject(sb.toString());
    }

    private static File download(Context c,URL u)throws Exception{
        File dir=AnamikaVault.root(c);
        File out=new File(dir,"AnimeVideo_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".mp4");
        HttpURLConnection h=(HttpURLConnection)u.openConnection();
        boolean ok=false;
        try{
            h.setConnectTimeout(20000);h.setReadTimeout(240000);h.setInstanceFollowRedirects(false);
            int code=h.getResponseCode();
            if(code<200||code>=300)throw new IOException("Anime video download HTTP "+code);
            try(InputStream in=new BufferedInputStream(h.getInputStream());OutputStream os=new BufferedOutputStream(new FileOutputStream(out))){
                byte[] b=new byte[256*1024];int n;long total=0;
                while((n=in.read(b))>0){
                    total+=n;
                    if(total>4L*1024L*1024L*1024L)throw new IOException("Output exceeds 4 GB.");
                    os.write(b,0,n);
                }
                if(total<1024)throw new IOException("Anime output is unexpectedly small.");
            }
            ok=true;return out;
        }finally{h.disconnect();if(!ok)try{out.delete();}catch(Exception ignored){}}
    }

    private static Verification verify(File f)throws Exception{
        MediaMetadataRetriever r=new MediaMetadataRetriever();
        try{
            r.setDataSource(f.getAbsolutePath());
            int w=parseInt(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
            int h=parseInt(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
            long d=parseLong(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
            return new Verification(w,h,d);
        }finally{try{r.release();}catch(Exception ignored){}}
    }

    private static URL requireHttps(String raw,String label)throws Exception{
        if(raw==null||raw.trim().isEmpty())throw new IllegalArgumentException(label+" is required.");
        URL u=new URL(raw.trim());
        if(!"https".equalsIgnoreCase(u.getProtocol()))throw new SecurityException(label+" must use HTTPS.");
        if(u.getHost()==null||u.getHost().trim().isEmpty())throw new SecurityException(label+" has no valid host.");
        return u;
    }

    private static boolean sameOrigin(URL a,URL b){
        int ap=a.getPort()<0?a.getDefaultPort():a.getPort();
        int bp=b.getPort()<0?b.getDefaultPort():b.getPort();
        return a.getProtocol().equalsIgnoreCase(b.getProtocol())&&a.getHost().equalsIgnoreCase(b.getHost())&&ap==bp;
    }

    private static String safeFilename(String s){return s==null?"source.mp4":s.replaceAll("[^A-Za-z0-9._-]","_");}
    private static int parseInt(String s){try{return Integer.parseInt(s);}catch(Exception e){return 0;}}
    private static long parseLong(String s){try{return Long.parseLong(s);}catch(Exception e){return 0L;}}
}
