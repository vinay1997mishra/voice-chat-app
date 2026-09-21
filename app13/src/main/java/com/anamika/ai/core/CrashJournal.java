package com.anamika.ai.core;

import com.anamika.ai.core.AndroidCompat;

import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Writes the last uncaught Java crash to private storage before delegating to Android. */
public final class CrashJournal {
    private CrashJournal() {}

    public static void install(Context c) {
        final Context app=c.getApplicationContext();
        final Thread.UncaughtExceptionHandler previous=Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((thread,error)->{
            try { write(app,thread,error); } catch(Throwable ignored) {}
            if(previous!=null) previous.uncaughtException(thread,error);
        });
    }

    public static File file(Context c) {
        return new File(new File(c.getFilesDir(),"runtime"),"last_crash.txt");
    }

    public static String read(Context c) {
        try {
            File f=file(c);
            if(!f.isFile()) return "No recorded Java crash.";
            return new String(AndroidCompat.readAllBytes(f),StandardCharsets.UTF_8);
        } catch(Exception e) {
            return "Crash journal unavailable: "+e.getClass().getSimpleName();
        }
    }

    private static void write(Context c,Thread thread,Throwable error) throws Exception {
        File f=file(c);
        File parent=f.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs()) return;
        StringBuilder b=new StringBuilder();
        b.append(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS",Locale.US).format(new Date())).append('\n');
        b.append("Thread: ").append(thread==null?"unknown":thread.getName()).append('\n');
        for(Throwable t=error;t!=null;t=t.getCause()){
            b.append(t).append('\n');
            for(StackTraceElement s:t.getStackTrace()) b.append("  at ").append(s).append('\n');
            b.append("Caused by:\n");
        }
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(b.toString().getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }
    }
}
