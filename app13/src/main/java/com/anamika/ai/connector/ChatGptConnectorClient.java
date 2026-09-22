package com.anamika.ai.connector;

import android.content.Context;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public final class ChatGptConnectorClient {
    private ChatGptConnectorClient(){}

    public static final class PairResult{
        public final boolean ok; public final String message; public final String deviceId; public final String token;
        PairResult(boolean ok,String message,String deviceId,String token){this.ok=ok;this.message=message;this.deviceId=deviceId;this.token=token;}
    }

    public static PairResult pair(String baseUrl,String pairingCode,String deviceName){
        HttpURLConnection con=null;
        try{
            String base=ChatGptConnectorStore.normalizeUrl(baseUrl);
            con=(HttpURLConnection)new URL(base+"/device/pair").openConnection();
            con.setConnectTimeout(15000); con.setReadTimeout(20000);
            con.setRequestMethod("POST"); con.setDoOutput(true);
            con.setRequestProperty("Content-Type","application/json; charset=utf-8");
            JSONObject body=new JSONObject()
                    .put("pairing_code",pairingCode==null?"":pairingCode)
                    .put("device_name",deviceName==null?"Anamika Android":deviceName);
            byte[] data=body.toString().getBytes(StandardCharsets.UTF_8);
            try(OutputStream out=con.getOutputStream()){out.write(data);}
            int code=con.getResponseCode();
            String raw=read(code>=200&&code<300?con.getInputStream():con.getErrorStream());
            if(code<200||code>=300)return new PairResult(false,"Pairing HTTP "+code+": "+raw,"","");
            JSONObject o=new JSONObject(raw);
            String id=o.optString("device_id",""); String token=o.optString("device_token","");
            if(id.isEmpty()||token.isEmpty())return new PairResult(false,"Pairing response incomplete.","","");
            return new PairResult(true,"ChatGPT connector paired.",id,token);
        }catch(Exception e){return new PairResult(false,"Pairing failed: "+safe(e),"","");}
        finally{if(con!=null)con.disconnect();}
    }

    public static JSONObject poll(Context c)throws Exception{
        String base=ChatGptConnectorStore.serverUrl(c), token=ChatGptConnectorStore.token(c), id=ChatGptConnectorStore.deviceId(c);
        if(base.isEmpty()||token.isEmpty()||id.isEmpty())throw new IllegalStateException("Connector not paired.");
        HttpURLConnection con=(HttpURLConnection)new URL(base+"/device/commands/next").openConnection();
        try{
            con.setConnectTimeout(12000); con.setReadTimeout(15000);
            con.setRequestMethod("GET");
            con.setRequestProperty("Authorization","Bearer "+token);
            con.setRequestProperty("X-Anamika-Device",id);
            int code=con.getResponseCode();
            String raw=read(code>=200&&code<300?con.getInputStream():con.getErrorStream());
            if(code<200||code>=300)throw new IllegalStateException("Poll HTTP "+code+": "+raw);
            return new JSONObject(raw);
        }finally{con.disconnect();}
    }

    public static void postResult(Context c,String commandId,String result){
        if(commandId==null||commandId.trim().isEmpty())return;
        final Context app=c.getApplicationContext();
        new Thread(()->postResultBlocking(app,commandId,result),"anamika-connector-result").start();
    }

    private static void postResultBlocking(Context c,String commandId,String result){
        HttpURLConnection con=null;
        try{
            String base=ChatGptConnectorStore.serverUrl(c), token=ChatGptConnectorStore.token(c), id=ChatGptConnectorStore.deviceId(c);
            if(base.isEmpty()||token.isEmpty()||id.isEmpty())return;
            con=(HttpURLConnection)new URL(base+"/device/results").openConnection();
            con.setConnectTimeout(12000); con.setReadTimeout(15000);
            con.setRequestMethod("POST"); con.setDoOutput(true);
            con.setRequestProperty("Authorization","Bearer "+token);
            con.setRequestProperty("X-Anamika-Device",id);
            con.setRequestProperty("Content-Type","application/json; charset=utf-8");
            JSONObject body=new JSONObject().put("command_id",commandId).put("result",result==null?"":result);
            try(OutputStream out=con.getOutputStream()){out.write(body.toString().getBytes(StandardCharsets.UTF_8));}
            try{read(con.getResponseCode()>=400?con.getErrorStream():con.getInputStream());}catch(Exception ignored){}
        }catch(Exception ignored){}finally{if(con!=null)con.disconnect();}
    }

    private static String read(InputStream in)throws Exception{
        if(in==null)return "";
        StringBuilder b=new StringBuilder();
        try(BufferedReader r=new BufferedReader(new InputStreamReader(in,StandardCharsets.UTF_8))){
            String line; while((line=r.readLine())!=null){if(b.length()>0)b.append("\n");b.append(line);}
        }
        return b.toString();
    }
    private static String safe(Throwable e){String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;}
}
