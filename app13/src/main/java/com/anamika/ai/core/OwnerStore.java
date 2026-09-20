package com.anamika.ai.core;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;

import java.security.SecureRandom;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Owner PIN storage for V13. Stores only a salted PBKDF2 hash, never the PIN. */
public final class OwnerStore {
    private static final String PREF="anamika13_owner";
    private static final String SALT="pin_salt";
    private static final String HASH="pin_hash";
    private static final String TRUSTED="trusted";
    private static final int ITERATIONS=120_000;
    private static final int BITS=256;

    private OwnerStore() {}

    public static boolean hasPin(Context c) {
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        return p.contains(SALT) && p.contains(HASH);
    }

    public static boolean isTrusted(Context c) {
        return hasPin(c) && c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getBoolean(TRUSTED,false);
    }

    public static void setPin(Context c,String pin) throws Exception {
        validatePin(pin);
        byte[] salt=new byte[16];
        new SecureRandom().nextBytes(salt);
        byte[] hash=derive(pin,salt);
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                .putString(SALT,Base64.encodeToString(salt,Base64.NO_WRAP))
                .putString(HASH,Base64.encodeToString(hash,Base64.NO_WRAP))
                .putBoolean(TRUSTED,true)
                .apply();
    }

    public static boolean verify(Context c,String pin) {
        try {
            validatePin(pin);
            SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
            byte[] salt=Base64.decode(p.getString(SALT,""),Base64.NO_WRAP);
            byte[] expected=Base64.decode(p.getString(HASH,""),Base64.NO_WRAP);
            byte[] actual=derive(pin,salt);
            boolean same=constantTimeEquals(expected,actual);
            if(same) p.edit().putBoolean(TRUSTED,true).apply();
            return same;
        } catch (Exception e) {
            return false;
        }
    }

    public static void forgetTrust(Context c) {
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().putBoolean(TRUSTED,false).apply();
    }

    private static void validatePin(String pin) {
        if(pin==null || !pin.matches("\\d{4,12}"))
            throw new IllegalArgumentException("Owner PIN must be 4-12 digits.");
    }

    private static byte[] derive(String pin,byte[] salt) throws Exception {
        PBEKeySpec spec=new PBEKeySpec(pin.toCharArray(),salt,ITERATIONS,BITS);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } finally {
            spec.clearPassword();
        }
    }

    private static boolean constantTimeEquals(byte[] a,byte[] b) {
        if(a==null||b==null) return false;
        int diff=a.length^b.length;
        int n=Math.min(a.length,b.length);
        for(int i=0;i<n;i++) diff|=a[i]^b[i];
        return diff==0;
    }
}
