package com.anamika.ai.connector;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

public final class ChatGptConnectorStore {
    private static final String PREF="anamika13_chatgpt_connector";
    private static final String URL="server_url";
    private static final String DEVICE_ID="device_id";
    private static final String TOKEN="device_token";
    private static final String ENABLED="enabled";
    private static final String KEY_ALIAS="anamika13_connector_aes";

    private ChatGptConnectorStore(){}

    public static String serverUrl(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(URL,"");
    }
    public static String deviceId(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(DEVICE_ID,"");
    }
    public static boolean enabled(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getBoolean(ENABLED,false);
    }
    public static boolean configured(Context c){
        return !serverUrl(c).isEmpty()&&!deviceId(c).isEmpty()&&!token(c).isEmpty();
    }
    public static void setEnabled(Context c,boolean on){
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().putBoolean(ENABLED,on).apply();
    }
    public static void savePairing(Context c,String url,String deviceId,String token)throws Exception{
        String normalized=normalizeUrl(url);
        String stored=protect(c,token);
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                .putString(URL,normalized)
                .putString(DEVICE_ID,deviceId==null?"":deviceId.trim())
                .putString(TOKEN,stored)
                .putBoolean(ENABLED,true)
                .apply();
    }
    public static void clear(Context c){
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().clear().apply();
    }
    public static String token(Context c){
        String stored=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(TOKEN,"");
        if(stored.isEmpty())return "";
        try{return unprotect(c,stored);}catch(Exception e){return "";}
    }
    public static String status(Context c){
        return "ChatGPT Connector\nServer: "+(serverUrl(c).isEmpty()?"not configured":serverUrl(c))+
                "\nDevice ID: "+(deviceId(c).isEmpty()?"not paired":deviceId(c))+
                "\nToken: "+(token(c).isEmpty()?"missing":"stored")+
                "\nBridge: "+(enabled(c)?"ON":"OFF");
    }
    public static String normalizeUrl(String raw){
        String s=raw==null?"":raw.trim();
        while(s.endsWith("/"))s=s.substring(0,s.length()-1);
        if(!s.startsWith("https://"))throw new IllegalArgumentException("Connector URL https:// se start hona chahiye.");
        return s;
    }

    private static String protect(Context c,String plain)throws Exception{
        if(Build.VERSION.SDK_INT<23)return "plain:"+Base64.encodeToString(plain.getBytes(StandardCharsets.UTF_8),Base64.NO_WRAP);
        SecretKey key=getOrCreateKey();
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE,key);
        byte[] iv=cipher.getIV();
        byte[] enc=cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
        return "gcm:"+Base64.encodeToString(iv,Base64.NO_WRAP)+":"+Base64.encodeToString(enc,Base64.NO_WRAP);
    }
    private static String unprotect(Context c,String stored)throws Exception{
        if(stored.startsWith("plain:")){
            return new String(Base64.decode(stored.substring(6),Base64.DEFAULT),StandardCharsets.UTF_8);
        }
        if(!stored.startsWith("gcm:"))return "";
        String[] p=stored.split(":",3);
        if(p.length!=3)return "";
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        SecretKey key=(SecretKey)ks.getKey(KEY_ALIAS,null);
        if(key==null)return "";
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE,key,new GCMParameterSpec(128,Base64.decode(p[1],Base64.DEFAULT)));
        return new String(cipher.doFinal(Base64.decode(p[2],Base64.DEFAULT)),StandardCharsets.UTF_8);
    }
    private static SecretKey getOrCreateKey()throws Exception{
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        java.security.Key k=ks.getKey(KEY_ALIAS,null);
        if(k instanceof SecretKey)return (SecretKey)k;
        KeyGenerator kg=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        kg.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build());
        return kg.generateKey();
    }
}
