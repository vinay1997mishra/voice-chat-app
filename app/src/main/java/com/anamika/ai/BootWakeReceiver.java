package com.anamika.ai;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Best-effort wake-service resume after reboot. Newer Android may require the owner to reopen Anamika. */
public final class BootWakeReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if(context==null) return;
        boolean enabled=context.getSharedPreferences("anamika_v7",Context.MODE_PRIVATE)
                .getBoolean("wake_enabled",false);
        if(!enabled || !OwnerSession.isTrusted(context)) return;
        try{
            Intent svc=new Intent(context,BackgroundWakeService.class)
                    .setAction(BackgroundWakeService.ACTION_START);
            if(Build.VERSION.SDK_INT>=26) context.startForegroundService(svc);
            else context.startService(svc);
        }catch(Throwable ignored){
            // Android may block microphone foreground-service start from BOOT_COMPLETED.
        }
    }
}
