package com.anamika.ai;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Restarts Anamika's foreground wake service after an unexpected process/task stop. */
public final class WakeRecoveryReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context,Intent intent){
        if(context==null) return;
        if(!OwnerSession.isTrusted(context)) return;
        if(!context.getSharedPreferences("anamika_v7",Context.MODE_PRIVATE)
                .getBoolean("wake_enabled",false)) return;
        try{
            Intent svc=new Intent(context,BackgroundWakeService.class)
                    .setAction(BackgroundWakeService.ACTION_START);
            if(Build.VERSION.SDK_INT>=26) context.startForegroundService(svc);
            else context.startService(svc);
        }catch(Throwable ignored){}
    }
}
