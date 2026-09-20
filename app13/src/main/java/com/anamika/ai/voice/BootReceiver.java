package com.anamika.ai.voice;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Best-effort wake restoration. New Android versions may require opening Anamika once after reboot. */
public final class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context,Intent intent){
        if(WakeService.isEnabled(context)) WakeService.enable(context);
    }
}
