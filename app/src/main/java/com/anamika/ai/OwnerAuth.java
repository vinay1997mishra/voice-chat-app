package com.anamika.ai;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Local owner-PIN verifier. Stores only a salted PBKDF2 hash, never the raw PIN. */
public final class OwnerAuth {
    private static final String PREFS = "anamika_v7";
    private static final String LEGACY_PIN = "owner_pin";
    private static final String HASH = "owner_pin_hash";
    private static final String SALT = "owner_pin_salt";
    private static final int ITERATIONS = 120_000;
    private static final int KEY_BITS = 256;

    private OwnerAuth() { }

    public static boolean hasPin(Context context) {
        SharedPreferences p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        return p.contains(HASH) || p.contains(LEGACY_PIN);
    }

    /** Migrates a legacy plaintext PIN only after the owner successfully enters it. */
    public static boolean verifyOrSet(Context context, String pin) throws Exception {
        if (pin == null || !pin.matches("\\d{4,12}")) {
            throw new IllegalArgumentException("PIN must be 4 to 12 digits.");
        }
        SharedPreferences p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String hash = p.getString(HASH, null);
        String salt = p.getString(SALT, null);
        if ((hash == null) != (salt == null)) {
            throw new SecurityException("Owner credential store is incomplete; refusing to reset PIN automatically.");
        }
        if (hash == null) {
            String legacy = p.getString(LEGACY_PIN, null);
            if (legacy != null && !MessageDigest.isEqual(
                    legacy.getBytes(StandardCharsets.UTF_8), pin.getBytes(StandardCharsets.UTF_8))) {
                return false;
            }
            byte[] newSalt = new byte[16];
            new SecureRandom().nextBytes(newSalt);
            byte[] derived = derive(pin, newSalt);
            boolean stored=p.edit()
                    .putString(SALT, Base64.encodeToString(newSalt, Base64.NO_WRAP))
                    .putString(HASH, Base64.encodeToString(derived, Base64.NO_WRAP))
                    .remove(LEGACY_PIN)
                    .commit();
            if(!stored) throw new IllegalStateException("Could not persist owner credentials.");
            return true;
        }
        byte[] saltBytes = Base64.decode(salt, Base64.NO_WRAP);
        byte[] expected = Base64.decode(hash, Base64.NO_WRAP);
        byte[] actual = derive(pin, saltBytes);
        return MessageDigest.isEqual(expected, actual);
    }

    private static byte[] derive(String pin, byte[] salt) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(pin.toCharArray(), salt, ITERATIONS, KEY_BITS);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } finally {
            spec.clearPassword();
        }
    }
}
