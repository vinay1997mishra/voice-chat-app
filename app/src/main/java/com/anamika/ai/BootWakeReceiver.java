package com.anamika.ai;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Best-effort always-on wake-service resume after reboot/app update for a remembered owner. */
public final class BootWakeReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if(context==null) return;
        if(!OwnerSession.isTrusted(context)) return;
        context.getSharedPreferences("anamika_v7",Context.MODE_PRIVATE)
                .edit().putBoolean("wake_enabled",true).apply();
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
