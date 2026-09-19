package com.anamika.ai;

import android.app.KeyguardManager;
import android.content.Context;

/**
 * Short-lived owner authorization shared with sensitive background surfaces such as App Control.
 * A valid PIN unlock grants a session; commands are rejected after expiry or while the device is locked.
 */
public final class OwnerSession {
    private static final String PREFS = "anamika_owner_session";
    private static final String VALID_UNTIL = "valid_until";
    private static final long SESSION_MS = 10L * 60L * 1000L;

    private OwnerSession() { }

    public static void grant(Context context) {
        if (context == null) return;
        long until = System.currentTimeMillis() + SESSION_MS;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(VALID_UNTIL, until).commit();
    }

    public static void revoke(Context context) {
        if (context == null) return;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(VALID_UNTIL).commit();
    }

    public static boolean isActive(Context context) {
        if (context == null) return false;
        try {
            KeyguardManager km = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null && km.isDeviceLocked()) return false;
        } catch (Throwable ignored) { }
        long until = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(VALID_UNTIL, 0L);
        if (until <= System.currentTimeMillis()) {
            if (until != 0L) revoke(context);
            return false;
        }
        return true;
    }

    public static long remainingMs(Context context) {
        if (!isActive(context)) return 0L;
        long until = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(VALID_UNTIL, 0L);
        return Math.max(0L, until - System.currentTimeMillis());
    }
}
