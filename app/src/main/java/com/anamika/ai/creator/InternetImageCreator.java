package com.anamika.ai.creator;

import android.content.Context;
import android.graphics.BitmapFactory;

import com.anamika.ai.files.AnamikaVault;

import org.json.JSONObject;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;

public final class InternetImageCreator {
    public interface Callback {
        void onProgress(String message);
        void onComplete(File image,int width,int height);
        void onError(String error);
    }
    private InternetImageCreator(){}

    public static void generate(Context context,String endpoint,String apiKey,String model,
                                String prompt,String referenceUrl,int width,int height,Callback cb){
        new Thread(() -> {
            try{
                URL base=requireHttps(endpoint,"Creator endpoint");
                if(prompt==null||prompt.trim().isEmpty()) throw new IllegalArgumentException("Image prompt is empty.");
                int w=clamp(width,256,4096),h=clamp(height,256,4096);
                cb.onProgress("Sending image generation job…");
                JSONObject payload=new JSONObject();
                payload.put("media_type","image");
                payload.put("prompt",prompt.trim());
                payload.put("model",model==null?"":model.trim());
                payload.put("reference_url",referenceUrl==null?"":referenceUrl.trim());
                payload.put("width",w);payload.put("height",h);
                payload.put("resolution",w+"x"+h);

                JSONObject first=postJson(base,apiKey,payload);
                String image=first.optString("image_url","");
                String status=first.optString("status_url","");
                if(image.isEmpty()&&status.isEmpty()) throw new IllegalStateException("Provider response has no image_url or status_url.");
                if(image.isEmpty()){
                    URL statusUrl=requireHttps(status,"Provider status URL");
                    String statusKey=sameOrigin(base,statusUrl)?apiKey:"";
                    for(int i=0;i<120;i++){
                        Thread.sleep(2000L);
                        cb.onProgress("Rendering image… check "+(i+1));
                        JSONObject state=getJson(statusUrl,statusKey);
                        String st=state.optString("status","").toLowerCase(Locale.ROOT);
                        if(st.equals("failed")||st.equals("error")) throw new IllegalStateException(state.optString("error","Provider image generation failed."));
                        image=state.optString("image_url","");
                        if(!image.isEmpty())break;
                    }
                }
                if(image.isEmpty()) throw new IllegalStateException("Provider did not return image_url in time.");
                cb.onProgress("Downloading generated image…");
                File out=download(context,requireHttps(image,"Generated image URL"));
                BitmapFactory.Options o=new BitmapFactory.Options();
                o.inJustDecodeBounds=true;BitmapFactory.decodeFile(out.getAbsolutePath(),o);
                if(o.outWidth<=0||o.outHeight<=0) throw new IllegalStateException("Downloaded file is not a valid image.");
                AnamikaVault.registerGeneratedFile(context,out,guessMime(out.getName()));
                cb.onComplete(out,o.outWidth,o.outHeight);
            }catch(Exception e){
                cb.onError(e.getMessage()==null?e.toString():e.getMessage());
            }
        },"anamika-image-creator").start();
    }

    private static File download(Context c,URL u)throws Exception{
        File dir=AnamikaVault.root(c);
        String name="AnamikaGenerated_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".jpg";
        File out=new File(dir,name);
        HttpURLConnection h=(HttpURLConnection)u.openConnection();
        boolean ok=false;
        try{
            h.setConnectTimeout(20000);h.setReadTimeout(120000);h.setInstanceFollowRedirects(false);
            int code=h.getResponseCode();if(code<200||code>=300)throw new IOException("Image download HTTP "+code);
            try(InputStream in=new BufferedInputStream(h.getInputStream());OutputStream os=new FileOutputStream(out)){
                byte[] b=new byte[128*1024];int n;long total=0;
                while((n=in.read(b))>0){
                    total+=n;if(total>200L*1024L*1024L)throw new IOException("Image exceeds 200 MB.");
                    os.write(b,0,n);
                }
                if(total<512)throw new IOException("Generated image is unexpectedly small.");
            }
            ok=true;return out;
        }finally{h.disconnect();if(!ok)try{out.delete();}catch(Exception ignored){}}
    }

    private static JSONObject postJson(URL endpoint,String key,JSONObject payload)throws Exception{
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try{
            c.setConnectTimeout(20000);c.setReadTimeout(120000);c.setRequestMethod("POST");c.setDoOutput(true);
            c.setInstanceFollowRedirects(false);c.setRequestProperty("Content-Type","application/json");
            if(key!=null&&!key.isEmpty())c.setRequestProperty("Authorization","Bearer "+key);
            try(OutputStream out=c.getOutputStream()){out.write(payload.toString().getBytes(StandardCharsets.UTF_8));}
            return readJson(c);
        }finally{c.disconnect();}
    }
    private static JSONObject getJson(URL endpoint,String key)throws Exception{
        HttpURLConnection c=(HttpURLConnection)endpoint.openConnection();
        try{
            c.setConnectTimeout(20000);c.setReadTimeout(60000);c.setRequestMethod("GET");c.setInstanceFollowRedirects(false);
            if(key!=null&&!key.isEmpty())c.setRequestProperty("Authorization","Bearer "+key);
            return readJson(c);
        }finally{c.disconnect();}
    }
    private static JSONObject readJson(HttpURLConnection c)throws Exception{
        int code=c.getResponseCode();InputStream in=(code>=200&&code<300)?c.getInputStream():c.getErrorStream();
        if(in==null)throw new IOException("HTTP "+code);
        StringBuilder sb=new StringBuilder();try(BufferedReader r=new BufferedReader(new InputStreamReader(in,StandardCharsets.UTF_8))){
            String line;while((line=r.readLine())!=null&&sb.length()<1_000_000)sb.append(line);
        }
        if(code<200||code>=300)throw new IOException("HTTP "+code+": "+sb);
        return new JSONObject(sb.toString());
    }
    private static URL requireHttps(String raw,String label)throws Exception{
        if(raw==null||raw.trim().isEmpty())throw new IllegalArgumentException(label+" is required.");
        URL u=new URL(raw.trim());if(!"https".equalsIgnoreCase(u.getProtocol()))throw new SecurityException(label+" must use HTTPS.");
        return u;
    }
    private static boolean sameOrigin(URL a,URL b){
        int ap=a.getPort()<0?a.getDefaultPort():a.getPort(),bp=b.getPort()<0?b.getDefaultPort():b.getPort();
        return a.getProtocol().equalsIgnoreCase(b.getProtocol())&&a.getHost().equalsIgnoreCase(b.getHost())&&ap==bp;
    }
    private static int clamp(int v,int lo,int hi){return Math.max(lo,Math.min(hi,v<=0?1024:v));}
    private static String guessMime(String n){String s=n.toLowerCase(Locale.ROOT);return s.endsWith(".png")?"image/png":s.endsWith(".webp")?"image/webp":"image/jpeg";}
}
