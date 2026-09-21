package com.anamika.ai.voice;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Best-effort wake restoration. New Android versions may require opening Anamika once after reboot. */
public final class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context,Intent intent){
        if(!WakeService.isEnabled(context))return;
        // Android 14+ does not allow a microphone foreground service to be created
        // from BOOT_COMPLETED / package-replaced background delivery. Keep the
        // preference enabled and restart once MainActivity is visible.
        if(Build.VERSION.SDK_INT>=34)return;
        WakeService.enable(context);
    }
}
