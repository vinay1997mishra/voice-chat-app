package com.anamika.ai.connector;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import com.anamika.ai.MainActivity;
import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.core.CrashJournal;
import com.anamika.ai.core.HealthMonitor;
import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.diagnostics.DiagnosticsController;
import com.anamika.ai.runtime.RuntimeWatchdog;
import com.anamika.ai.upgrade.UpgradeCoordinator;

import java.util.Locale;

import org.json.JSONObject;

public final class ChatGptConnectorService extends Service {
    private static final String CHANNEL="anamika13_chatgpt_connector";
    private static final int NOTIFICATION_ID=1314;
    private static final int PENDING_NOTIFICATION_ID=1315;
    public static final String ACTION_STOP="com.anamika.ai.v13.CONNECTOR_STOP";
    private volatile boolean stopping;
    private Thread worker;

    public static void start(Context c){
        ChatGptConnectorStore.setEnabled(c,true);
        Intent i=new Intent(c,ChatGptConnectorService.class);
        try{if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i); else c.startService(i);}catch(Throwable ignored){}
    }
    public static void stop(Context c){
        ChatGptConnectorStore.setEnabled(c,false);
        Intent i=new Intent(c,ChatGptConnectorService.class).setAction(ACTION_STOP);
        try{c.startService(i);}catch(Throwable e){c.stopService(new Intent(c,ChatGptConnectorService.class));}
    }

    @Override public void onCreate(){
        super.onCreate();
        createChannel();
        startForeground(NOTIFICATION_ID,notification("ChatGPT connector starting…"));
        startWorker();
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null&&ACTION_STOP.equals(intent.getAction())){
            stopping=true; ChatGptConnectorStore.setEnabled(this,false); stopSelf(); return START_NOT_STICKY;
        }
        if(!ChatGptConnectorStore.enabled(this)||!ChatGptConnectorStore.configured(this)){
            stopSelf(); return START_NOT_STICKY;
        }
        startWorker();
        return START_STICKY;
    }

    private synchronized void startWorker(){
        if(worker!=null&&worker.isAlive())return;
        stopping=false;
        worker=new Thread(this::loop,"anamika-chatgpt-connector");
        worker.start();
    }

    private void loop(){
        while(!stopping&&ChatGptConnectorStore.enabled(this)){
            try{
                JSONObject o=ChatGptConnectorClient.poll(this);
                JSONObject cmd=o.optJSONObject("command");
                if(cmd!=null){
                    String id=cmd.optString("id","");
                    String text=cmd.optString("text","");
                    if(!id.isEmpty()&&!text.trim().isEmpty()){
                        update("ChatGPT command received");
                        if(handleTrustedHeadlessCommand(id,text)){
                            Thread.sleep(300L);
                            continue;
                        }
                        // Android may block activity launches initiated from a background
                        // foreground-service process. Keep a durable owner-visible fallback
                        // notification carrying the exact queued command before trying the
                        // direct launch. MainActivity clears it only after consuming extras.
                        showPendingCommandNotification(id,text);
                        Intent open=new Intent(this,MainActivity.class)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                .putExtra("connector_command_id",id)
                                .putExtra("connector_command",text);
                        try{ startActivity(open); }
                        catch(Throwable ignored){ update("ChatGPT command waiting • tap notification"); }
                    }
                }else update("ChatGPT connector online");
                Thread.sleep(2500L);
            }catch(InterruptedException e){
                Thread.currentThread().interrupt(); break;
            }catch(Throwable e){
                update("Connector retrying…");
                try{Thread.sleep(5000L);}catch(InterruptedException x){Thread.currentThread().interrupt();break;}
            }
        }
    }

    /**
     * Executes only a deliberately small set of non-UI commands while the local
     * owner trust gate is still active. General phone/app actions continue through
     * MainActivity so Android permissions and visible owner controls remain in charge.
     *
     * Self-repair may edit only Anamika's disposable source workspace and can at most
     * produce a verified candidate APK. UpgradeCoordinator still requires the normal
     * Android/owner install confirmation before the installed app can change.
     */
    private boolean handleTrustedHeadlessCommand(String commandId,String raw){
        if(!OwnerStore.isTrusted(this))return false;
        String text=raw==null?"":raw.trim();
        String l=text.toLowerCase(Locale.ROOT).replaceAll("\\s+"," ").trim();

        boolean selfRepair=isSelfRepairCommand(l);
        boolean supported=selfRepair||
                l.equals("full diagnostics")||l.equals("run self test")||l.equals("self test")||
                l.equals("check all functions")||l.equals("diagnostics report")||
                l.equals("health")||l.equals("anamika health")||
                l.equals("last crash")||l.equals("crash report")||
                l.equals("watchdog")||l.equals("runtime status")||
                l.equals("upgrade status")||l.equals("self upgrade status");
        if(!supported)return false;

        if(!ChatGptConnectorClient.ackRunning(this,commandId)){
            update("Connector command ack failed • retrying later");
            return true;
        }

        String result;
        try{
            update(selfRepair?"Anamika self-repair running…":"Anamika diagnostics running…");
            if(selfRepair){
                result=UpgradeCoordinator.selfRepair(this,selfRepairProblem(text));
            }else if(l.equals("full diagnostics")||l.equals("run self test")||
                    l.equals("self test")||l.equals("check all functions")){
                result=DiagnosticsController.runAndSave(this);
            }else if(l.equals("diagnostics report")){
                result=DiagnosticsController.latest(this);
            }else if(l.equals("health")||l.equals("anamika health")){
                result=HealthMonitor.report(this);
            }else if(l.equals("last crash")||l.equals("crash report")){
                result=CrashJournal.read(this);
            }else if(l.equals("watchdog")||l.equals("runtime status")){
                result=RuntimeWatchdog.status(this);
            }else{
                result=UpgradeCoordinator.status(this);
            }
        }catch(Throwable e){
            String m=e.getMessage();
            result="Headless Anamika command failed: "+
                    (m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m);
        }

        ChatGptConnectorClient.postResult(this,commandId,result);
        update("ChatGPT command complete");
        return true;
    }

    private static boolean isSelfRepairCommand(String lower){
        return lower.equals("self repair")||lower.startsWith("self repair ")||
                lower.equals("fix yourself")||lower.startsWith("fix yourself ")||
                lower.equals("repair yourself")||lower.startsWith("repair yourself ")||
                lower.equals("khud ko thik karo")||lower.startsWith("khud ko thik karo ")||
                lower.equals("khud ko thik kr")||lower.startsWith("khud ko thik kr ")||
                lower.equals("apne aap ko thik karo")||lower.startsWith("apne aap ko thik karo ")||
                lower.equals("anamika khud ko thik karo")||lower.startsWith("anamika khud ko thik karo ")||
                lower.equals("apna code thik kr")||lower.startsWith("apna code thik kr ");
    }

    private static String selfRepairProblem(String original){
        String lower=original.toLowerCase(Locale.ROOT);
        String[] prefixes={
                "self repair","fix yourself","repair yourself",
                "khud ko thik karo","khud ko thik kr",
                "apne aap ko thik karo","anamika khud ko thik karo",
                "apna code thik kr"
        };
        for(String prefix:prefixes){
            if(lower.startsWith(prefix)){
                String body=original.substring(Math.min(prefix.length(),original.length()))
                        .replaceFirst("^[\\s:=-]+","").trim();
                return body.isEmpty()?original:body;
            }
        }
        return original;
    }

    private void createChannel(){
        if(Build.VERSION.SDK_INT>=26){
            NotificationManager nm=getSystemService(NotificationManager.class);
            if(nm!=null)nm.createNotificationChannel(new NotificationChannel(CHANNEL,"Anamika ChatGPT Connector",NotificationManager.IMPORTANCE_LOW));
        }
    }
    private Notification notification(String text){
        Intent open=new Intent(this,ChatGptConnectorActivity.class);
        PendingIntent pi=PendingIntent.getActivity(this,14,open,AndroidCompat.immutablePendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT));
        Notification.Builder b=Build.VERSION.SDK_INT>=26?new Notification.Builder(this,CHANNEL):new Notification.Builder(this);
        return b.setContentTitle("Anamika • ChatGPT Connector")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentIntent(pi)
                .setOngoing(true)
                .build();
    }
    private void update(String text){
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(nm!=null)nm.notify(NOTIFICATION_ID,notification(text));
    }

    private void showPendingCommandNotification(String commandId,String command){
        Intent open=new Intent(this,MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra("connector_command_id",commandId)
                .putExtra("connector_command",command);
        int requestCode=15000+(Math.abs(commandId.hashCode())%10000);
        PendingIntent pi=PendingIntent.getActivity(
                this,requestCode,open,
                AndroidCompat.immutablePendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT));
        Notification.Builder b=Build.VERSION.SDK_INT>=26
                ?new Notification.Builder(this,CHANNEL):new Notification.Builder(this);
        Notification n=b.setContentTitle("Anamika • ChatGPT command")
                .setContentText("Command received • tap only if Anamika did not open automatically")
                .setStyle(new Notification.BigTextStyle().bigText(
                        "ChatGPT command received. Android ne background app-open block kiya ho to yahan tap karke command continue karein."))
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build();
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(nm!=null)nm.notify(PENDING_NOTIFICATION_ID,n);
    }

    public static void clearPendingNotification(Context c){
        NotificationManager nm=(NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
        if(nm!=null)nm.cancel(PENDING_NOTIFICATION_ID);
    }

    @Override public void onDestroy(){
        stopping=true;
        if(worker!=null)worker.interrupt();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
}
