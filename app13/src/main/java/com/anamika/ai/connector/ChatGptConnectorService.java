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

import org.json.JSONObject;

public final class ChatGptConnectorService extends Service {
    private static final String CHANNEL="anamika13_chatgpt_connector";
    private static final int NOTIFICATION_ID=1314;
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
                        Intent open=new Intent(this,MainActivity.class)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                .putExtra("connector_command_id",id)
                                .putExtra("connector_command",text);
                        startActivity(open);
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
        return b.setContentTitle("Anamika AI 13 • ChatGPT Connector")
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

    @Override public void onDestroy(){
        stopping=true;
        if(worker!=null)worker.interrupt();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
}
