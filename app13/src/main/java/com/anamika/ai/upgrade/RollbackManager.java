package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.os.Build;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/**
 * Forward-recovery checkpoint system.
 *
 * Android normally rejects version downgrades, so V13 rollback is implemented as a
 * recovery build based on the last-known-good source but with a versionCode greater
 * than the currently installed build.
 */
public final class RollbackManager {
    private static final String DIR="v13_recovery";
    private static final String CHECKPOINT="checkpoint.json";

    private RollbackManager(){}

    public static String checkpoint(Context c){
        try{
            File baseline=SourceVault.ensureBaseline(c);
            PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
            long code=Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
            JSONObject json=new JSONObject()
                    .put("schema","anamika13-recovery-v1")
                    .put("version_name",p.versionName)
                    .put("version_code",code)
                    .put("source_baseline",baseline.getAbsolutePath())
                    .put("created_ms",System.currentTimeMillis());

            File dir=new File(c.getFilesDir(),DIR);
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create recovery directory.");
            File f=new File(dir,CHECKPOINT);
            try(FileOutputStream out=new FileOutputStream(f,false)){
                out.write(json.toString(2).getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            UpgradeJournal.record(c,"RECOVERY_CHECKPOINT","Last-known-good version "+code);
            return "Recovery checkpoint READY for version "+code+".";
        }catch(Exception e){
            return "Recovery checkpoint failed: "+safe(e);
        }
    }

    public static String status(Context c){
        try{
            File f=new File(new File(c.getFilesDir(),DIR),CHECKPOINT);
            if(!f.isFile())return "Rollback pipeline: no recovery checkpoint yet.";
            JSONObject o=new JSONObject(new String(java.nio.file.Files.readAllBytes(f.toPath()),StandardCharsets.UTF_8));
            return "Rollback pipeline: CHECKPOINT READY"+
                    "\nLast-known-good version: "+o.optLong("version_code",-1)+
                    "\nSource: "+o.optString("source_baseline","unknown")+
                    "\nRecovery uses a newer versionCode because Android blocks normal downgrade installs.";
        }catch(Exception e){
            return "Rollback pipeline: checkpoint unreadable ("+safe(e)+")";
        }
    }

    public static File prepareRecoveryWorkspace(Context c,String reason) throws Exception {
        File checkpoint=new File(new File(c.getFilesDir(),DIR),CHECKPOINT);
        if(!checkpoint.isFile())throw new IllegalStateException("Create a recovery checkpoint first.");

        JSONObject o=new JSONObject(new String(java.nio.file.Files.readAllBytes(checkpoint.toPath()),StandardCharsets.UTF_8));
        PackageInfo cur=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        long current=Build.VERSION.SDK_INT>=28?cur.getLongVersionCode():cur.versionCode;
        File ws=SourceVault.createWorkspace(c,"RECOVERY: "+(reason==null?"":reason));

        JSONObject plan=new JSONObject()
                .put("schema","anamika13-recovery-plan-v1")
                .put("last_good_version_code",o.optLong("version_code",-1))
                .put("minimum_recovery_version_code",current+1)
                .put("reason",reason==null?"":reason)
                .put("created_ms",System.currentTimeMillis());

        File planFile=new File(ws,"RECOVERY_PLAN.json");
        try(FileOutputStream out=new FileOutputStream(planFile,false)){
            out.write(plan.toString(2).getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }
        UpgradeJournal.record(c,"RECOVERY_PLAN","Workspace "+ws.getAbsolutePath());
        return ws;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
