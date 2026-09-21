package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import android.util.Base64;

import com.anamika.ai.core.AndroidCompat;

import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.util.Arrays;
import java.util.Calendar;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import javax.security.auth.x500.X500Principal;

/**
 * Secure local signing vault for Android 5.0+.
 *
 * Android 6+ uses an AndroidKeyStore AES key. Android 5.x uses an
 * AndroidKeyStore RSA keypair to wrap a random AES key kept only as ciphertext
 * in Anamika private storage.
 */
public final class SignerVault {
    private static final String ANDROID_KEYSTORE="AndroidKeyStore";
    private static final String KEY_ALIAS="anamika13_signer_wrap_v1";
    private static final String LEGACY_RSA_ALIAS="anamika13_signer_wrap_rsa_v1";
    private static final String DIR="v13_signer";
    private static final String FILE="vault.json";
    private static final String LEGACY_WRAPPED_AES="legacy_wrapped_aes.bin";
    // Permanent Anamika 13 release identity. Public fingerprint only; private key is never stored in Git.
    public static final String EXPECTED_RELEASE_CERT_SHA256="508f4a20c4d5daa8c314796608e8c5e6988dad37adf9f5f5a6022442d155f520";

    public static final class SigningMaterial {
        public final PrivateKey privateKey;
        public final Certificate[] chain;
        SigningMaterial(PrivateKey privateKey,Certificate[] chain){
            this.privateKey=privateKey;this.chain=chain;
        }
    }

    public static final class TemporaryPkcs12 implements AutoCloseable {
        public final File file;
        public final char[] password;
        TemporaryPkcs12(File file,char[] password){this.file=file;this.password=password;}
        @Override public void close(){
            Arrays.fill(password,'\0');
            if(file!=null&&file.exists()){
                try{
                    java.io.RandomAccessFile raf=new java.io.RandomAccessFile(file,"rw");
                    byte[] zero=new byte[8192];
                    long left=raf.length();
                    raf.seek(0);
                    while(left>0){int n=(int)Math.min(zero.length,left);raf.write(zero,0,n);left-=n;}
                    raf.close();
                }catch(Exception ignored){}
                try{file.delete();}catch(Exception ignored){}
            }
        }
    }

    private SignerVault(){}

    public static String status(Context c){
        File f=vaultFile(c);
        if(!f.isFile())return "Signer vault: NOT PROVISIONED. Import the same release PKCS#12 that signed the installed Anamika.";
        try{
            JSONObject o=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
            String cert=o.optString("cert_sha256","");
            String installed=installedCertSha256(c);
            boolean match=!cert.isEmpty()&&cert.equalsIgnoreCase(installed)
                    &&cert.equalsIgnoreCase(EXPECTED_RELEASE_CERT_SHA256);
            return "Signer vault: "+(match?"READY":"CERTIFICATE MISMATCH")+
                    "\nCertificate SHA-256: "+(cert.isEmpty()?"unknown":cert)+
                    "\nKeystore mode: "+(Build.VERSION.SDK_INT>=23?"AES":"RSA-wrapped AES");
        }catch(Throwable e){
            return "Signer vault: unreadable ("+safe(e)+")";
        }
    }

    public static boolean ready(Context c){
        File f=vaultFile(c);
        if(!f.isFile())return false;
        try{
            JSONObject o=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
            String cert=o.optString("cert_sha256","");
            return cert.equalsIgnoreCase(installedCertSha256(c))
                    &&cert.equalsIgnoreCase(EXPECTED_RELEASE_CERT_SHA256);
        }catch(Throwable e){return false;}
    }

    public static String importPkcs12(Context c,byte[] pkcs12,char[] password){
        if(pkcs12==null||pkcs12.length<256)return "Signing file is empty or invalid.";
        if(password==null)password=new char[0];
        try{
            KeyStore p12=KeyStore.getInstance("PKCS12");
            p12.load(new ByteArrayInputStream(pkcs12),password);
            String alias=firstPrivateKeyAlias(p12);
            if(alias==null)return "No private signing key found in PKCS#12.";
            Key key=p12.getKey(alias,password);
            if(!(key instanceof PrivateKey))return "PKCS#12 does not contain a usable private key.";
            Certificate cert=p12.getCertificate(alias);
            if(cert==null)return "Signing certificate missing.";

            String candidate=sha256(cert.getEncoded());
            String installed=installedCertSha256(c);
            if(!candidate.equalsIgnoreCase(EXPECTED_RELEASE_CERT_SHA256))
                return "Signer rejected: this is not the pinned Anamika 13 permanent release key.";
            if(!candidate.equalsIgnoreCase(installed))
                return "Signer rejected: certificate does not match installed Anamika.";

            SecretKey wrap=wrappingKey(c);
            Enc keyBlob=encrypt(wrap,pkcs12);
            Enc passBlob=encrypt(wrap,new String(password).getBytes(StandardCharsets.UTF_8));

            JSONObject json=new JSONObject()
                    .put("schema","anamika13-signer-v1")
                    .put("cert_sha256",candidate)
                    .put("key_iv",b64(keyBlob.iv))
                    .put("key_ct",b64(keyBlob.ciphertext))
                    .put("pass_iv",b64(passBlob.iv))
                    .put("pass_ct",b64(passBlob.ciphertext));

            File dir=vaultFile(c).getParentFile();
            if(dir!=null&&!dir.exists()&&!dir.mkdirs())return "Cannot create signer vault.";
            File partial=new File(dir,FILE+".partial");
            try(FileOutputStream out=new FileOutputStream(partial,false)){
                out.write(json.toString().getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            File target=vaultFile(c);
            if(target.exists()&&!target.delete()){partial.delete();return "Cannot replace signer vault.";}
            if(!partial.renameTo(target)){partial.delete();return "Cannot finalize signer vault.";}
            Arrays.fill(password,'\0');
            return "Signer vault READY. Matching release certificate stored encrypted.";
        }catch(Throwable e){
            Arrays.fill(password,'\0');
            return "Signer import failed: "+safe(e);
        }
    }

    public static SigningMaterial load(Context c) throws Exception {
        if(!ready(c))throw new IllegalStateException("Signer vault is not ready.");
        JSONObject o=new JSONObject(AndroidCompat.readText(vaultFile(c),StandardCharsets.UTF_8));
        SecretKey wrap=wrappingKey(c);
        byte[] p12Bytes=decrypt(wrap,b64d(o.getString("key_iv")),b64d(o.getString("key_ct")));
        byte[] passBytes=decrypt(wrap,b64d(o.getString("pass_iv")),b64d(o.getString("pass_ct")));
        char[] password=new String(passBytes,StandardCharsets.UTF_8).toCharArray();
        Arrays.fill(passBytes,(byte)0);
        try{
            KeyStore p12=KeyStore.getInstance("PKCS12");
            p12.load(new ByteArrayInputStream(p12Bytes),password);
            String alias=firstPrivateKeyAlias(p12);
            if(alias==null)throw new IllegalStateException("Signing key missing.");
            Key key=p12.getKey(alias,password);
            Certificate[] chain=p12.getCertificateChain(alias);
            if(!(key instanceof PrivateKey)||chain==null||chain.length==0)
                throw new IllegalStateException("Signing material incomplete.");
            return new SigningMaterial((PrivateKey)key,chain);
        }finally{
            Arrays.fill(password,'\0');Arrays.fill(p12Bytes,(byte)0);
        }
    }

    public static TemporaryPkcs12 materializeTemporary(Context c,File dir) throws Exception {
        if(!ready(c))throw new IllegalStateException("Signer vault is not ready.");
        if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create signer temp directory.");
        JSONObject o=new JSONObject(AndroidCompat.readText(vaultFile(c),StandardCharsets.UTF_8));
        SecretKey wrap=wrappingKey(c);
        byte[] p12Bytes=decrypt(wrap,b64d(o.getString("key_iv")),b64d(o.getString("key_ct")));
        byte[] passBytes=decrypt(wrap,b64d(o.getString("pass_iv")),b64d(o.getString("pass_ct")));
        char[] password=new String(passBytes,StandardCharsets.UTF_8).toCharArray();
        Arrays.fill(passBytes,(byte)0);
        File f=new File(dir,"signer-"+System.currentTimeMillis()+".p12");
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(p12Bytes);out.getFD().sync();
        }finally{Arrays.fill(p12Bytes,(byte)0);}
        return new TemporaryPkcs12(f,password);
    }

    private static SecretKey wrappingKey(Context c) throws Exception {
        if(Build.VERSION.SDK_INT>=23)return Api23Wrap.get();
        return LegacyWrap.get(c);
    }

    private static final class Api23Wrap {
        static SecretKey get() throws Exception {
            KeyStore ks=KeyStore.getInstance(ANDROID_KEYSTORE);
            ks.load(null);
            Key existing=ks.getKey(KEY_ALIAS,null);
            if(existing instanceof SecretKey)return (SecretKey)existing;

            KeyGenerator kg=KeyGenerator.getInstance(
                    android.security.keystore.KeyProperties.KEY_ALGORITHM_AES,ANDROID_KEYSTORE);
            kg.init(new android.security.keystore.KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    android.security.keystore.KeyProperties.PURPOSE_ENCRYPT|
                            android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build());
            return kg.generateKey();
        }
    }

    @SuppressWarnings("deprecation")
    private static final class LegacyWrap {
        static SecretKey get(Context c) throws Exception {
            KeyStore ks=KeyStore.getInstance(ANDROID_KEYSTORE);
            ks.load(null);
            if(!ks.containsAlias(LEGACY_RSA_ALIAS)){
                Calendar start=Calendar.getInstance();
                Calendar end=Calendar.getInstance();end.add(Calendar.YEAR,30);
                android.security.KeyPairGeneratorSpec spec=
                        new android.security.KeyPairGeneratorSpec.Builder(c)
                                .setAlias(LEGACY_RSA_ALIAS)
                                .setSubject(new X500Principal("CN=Anamika13SignerWrap"))
                                .setSerialNumber(BigInteger.ONE)
                                .setStartDate(start.getTime())
                                .setEndDate(end.getTime())
                                .build();
                KeyPairGenerator gen=KeyPairGenerator.getInstance("RSA",ANDROID_KEYSTORE);
                gen.initialize(spec);gen.generateKeyPair();
                ks.load(null);
            }

            File dir=new File(c.getFilesDir(),DIR);
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create signer key directory.");
            File wrapped=new File(dir,LEGACY_WRAPPED_AES);
            Certificate cert=ks.getCertificate(LEGACY_RSA_ALIAS);
            Key privateKey=ks.getKey(LEGACY_RSA_ALIAS,null);
            if(cert==null||!(privateKey instanceof PrivateKey))
                throw new IllegalStateException("Android 5 keystore RSA key unavailable.");

            Cipher rsa=Cipher.getInstance("RSA/ECB/PKCS1Padding");
            if(wrapped.isFile()){
                rsa.init(Cipher.DECRYPT_MODE,(PrivateKey)privateKey);
                byte[] raw=rsa.doFinal(AndroidCompat.readAllBytes(wrapped));
                try{return new SecretKeySpec(raw,"AES");}
                finally{Arrays.fill(raw,(byte)0);}
            }

            byte[] raw=new byte[16];
            new SecureRandom().nextBytes(raw);
            SecretKey key=new SecretKeySpec(raw,"AES");
            rsa.init(Cipher.ENCRYPT_MODE,cert.getPublicKey());
            byte[] enc=rsa.doFinal(raw);
            Arrays.fill(raw,(byte)0);
            try(FileOutputStream out=new FileOutputStream(wrapped,false)){
                out.write(enc);out.getFD().sync();
            }
            return key;
        }
    }

    private static Enc encrypt(SecretKey key,byte[] data) throws Exception {
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE,key);
        return new Enc(cipher.getIV(),cipher.doFinal(data));
    }

    private static byte[] decrypt(SecretKey key,byte[] iv,byte[] data) throws Exception {
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE,key,new GCMParameterSpec(128,iv));
        return cipher.doFinal(data);
    }

    private static String firstPrivateKeyAlias(KeyStore ks) throws Exception {
        java.util.Enumeration<String> aliases=ks.aliases();
        while(aliases.hasMoreElements()){String a=aliases.nextElement();if(ks.isKeyEntry(a))return a;}
        return null;
    }

    private static String installedCertSha256(Context c) throws Exception {
        PackageManager pm=c.getPackageManager();
        Signature sig;
        if(Build.VERSION.SDK_INT>=28){
            sig=Api28Signatures.first(pm,c.getPackageName());
        }else{
            PackageInfo p=pm.getPackageInfo(c.getPackageName(),PackageManager.GET_SIGNATURES);
            sig=p.signatures!=null&&p.signatures.length>0?p.signatures[0]:null;
        }
        if(sig==null)throw new IllegalStateException("Installed signing certificate unavailable.");
        return sha256(sig.toByteArray());
    }

    private static final class Api28Signatures {
        static Signature first(PackageManager pm,String pkg) throws Exception {
            PackageInfo p=pm.getPackageInfo(pkg,PackageManager.GET_SIGNING_CERTIFICATES);
            android.content.pm.SigningInfo info=p.signingInfo;
            if(info==null)return null;
            Signature[] s=info.hasMultipleSigners()?info.getApkContentsSigners():info.getSigningCertificateHistory();
            return s!=null&&s.length>0?s[0]:null;
        }
    }

    private static String sha256(byte[] data) throws Exception {
        byte[] digest=MessageDigest.getInstance("SHA-256").digest(data);
        StringBuilder b=new StringBuilder();
        for(byte x:digest)b.append(String.format("%02x",x));
        return b.toString();
    }

    private static File vaultFile(Context c){return new File(new File(c.getFilesDir(),DIR),FILE);}
    private static String b64(byte[] b){return Base64.encodeToString(b,Base64.NO_WRAP);}
    private static byte[] b64d(String s){return Base64.decode(s,Base64.NO_WRAP);}
    private static final class Enc {
        final byte[] iv;final byte[] ciphertext;
        Enc(byte[] iv,byte[] ciphertext){this.iv=iv;this.ciphertext=ciphertext;}
    }
    private static String safe(Throwable e){
        String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
