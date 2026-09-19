package com.anamika.ai;

import android.app.KeyguardManager;
import android.content.Context;

/**
 * Persistent owner trust for the current device.
 *
 * After a successful Owner PIN verification, this device is remembered until the
 * owner explicitly logs out/forgets it, app data is cleared, or the app is reinstalled.
 * Sensitive phone-control actions still fail closed while Android reports the device locked.
 */
public final class OwnerSession {
    private static final String PREFS = "anamika_owner_session";
    private static final String TRUSTED = "trusted_owner_device";
    private static final String VALID_UNTIL = "valid_until"; // legacy migration support
    private static final long LEGACY_SESSION_MS = 10L * 60L * 1000L;

    private OwnerSession() { }

    /** Successful owner verification permanently remembers this app install/device. */
    public static void grant(Context context) {
        if (context == null) return;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(TRUSTED, true)
                .remove(VALID_UNTIL)
                .commit();
    }

    /** Explicit logout / forget-this-device. */
    public static void revoke(Context context) {
        if (context == null) return;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(TRUSTED)
                .remove(VALID_UNTIL)
                .commit();
    }

    public static boolean isTrusted(Context context) {
        if (context == null) return false;
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(TRUSTED, false);
    }

    public static boolean isActive(Context context) {
        if (context == null) return false;
        try {
            KeyguardManager km = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null && km.isDeviceLocked()) return false;
        } catch (Throwable ignored) { }

        if (isTrusted(context)) return true;

        // Legacy migration path: if an older timed session is still valid, convert it
        // to persistent trust so existing owners are not forced to log in repeatedly.
        long until = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getLong(VALID_UNTIL, 0L);
        if (until > System.currentTimeMillis()) {
            grant(context);
            return true;
        }
        if (until != 0L) revoke(context);
        return false;
    }

    /** Long.MAX_VALUE means remembered owner login on this device. */
    public static long remainingMs(Context context) {
        if (isTrusted(context)) return Long.MAX_VALUE;
        if (!isActive(context)) return 0L;
        long until = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getLong(VALID_UNTIL, 0L);
        return Math.max(0L, until - System.currentTimeMillis());
    }
}
