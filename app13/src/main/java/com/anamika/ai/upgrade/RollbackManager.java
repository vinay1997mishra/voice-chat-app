package com.anamika.ai.upgrade;

import com.anamika.ai.core.AndroidCompat;

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
 * A checkpoint now contains an immutable copy of the exact last-known-good source.
 * Android normally rejects version downgrades, so recovery uses that exact source
 * with a versionCode higher than the currently installed build.
 */
public final class RollbackManager {
    private static final String DIR="v13_recovery";
    private static final String CHECKPOINT="checkpoint.json";

    private RollbackManager(){}

    public static String checkpoint(Context c){
        try{
            PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
            long code=Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;

            File dir=new File(c.getFilesDir(),DIR);
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create recovery directory.");

            File snapshot=new File(new File(dir,"snapshots"),"v"+code);
            SourceVault.snapshotBaseline(c,snapshot);

            JSONObject json=new JSONObject()
                    .put("schema","anamika13-recovery-v2")
                    .put("version_name",p.versionName)
                    .put("version_code",code)
                    .put("source_snapshot",snapshot.getAbsolutePath())
                    .put("created_ms",System.currentTimeMillis());

            File f=new File(dir,CHECKPOINT);
            try(FileOutputStream out=new FileOutputStream(f,false)){
                out.write(json.toString(2).getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            UpgradeJournal.record(c,"RECOVERY_CHECKPOINT","Immutable last-known-good version "+code);
            return "Recovery checkpoint READY for version "+code+".";
        }catch(Exception e){
            return "Recovery checkpoint failed: "+safe(e);
        }
    }

    public static String status(Context c){
        try{
            File f=new File(new File(c.getFilesDir(),DIR),CHECKPOINT);
            if(!f.isFile())return "Rollback pipeline: no recovery checkpoint yet.";
            JSONObject o=new JSONObject(new String(AndroidCompat.readAllBytes(f),StandardCharsets.UTF_8));
            File snapshot=new File(o.optString("source_snapshot",""));
            boolean ready=snapshot.isDirectory()&&new File(snapshot,".checkpoint_complete").isFile();
            return "Rollback pipeline: "+(ready?"CHECKPOINT READY":"CHECKPOINT INCOMPLETE")+
                    "\nLast-known-good version: "+o.optLong("version_code",-1)+
                    "\nImmutable source: "+(snapshot.getPath().isEmpty()?"unknown":snapshot.getAbsolutePath())+
                    "\nRecovery uses a newer versionCode because Android blocks normal downgrade installs.";
        }catch(Exception e){
            return "Rollback pipeline: checkpoint unreadable ("+safe(e)+")";
        }
    }

    public static boolean checkpointReady(Context c){
        try{
            File f=new File(new File(c.getFilesDir(),DIR),CHECKPOINT);
            if(!f.isFile())return false;
            JSONObject o=new JSONObject(new String(AndroidCompat.readAllBytes(f),StandardCharsets.UTF_8));
            File snapshot=new File(o.optString("source_snapshot",""));
            return snapshot.isDirectory()&&new File(snapshot,".checkpoint_complete").isFile();
        }catch(Exception e){return false;}
    }

    public static File prepareRecoveryWorkspace(Context c,String reason) throws Exception {
        File checkpoint=new File(new File(c.getFilesDir(),DIR),CHECKPOINT);
        if(!checkpoint.isFile())throw new IllegalStateException("Create a recovery checkpoint first.");

        JSONObject o=new JSONObject(new String(AndroidCompat.readAllBytes(checkpoint),StandardCharsets.UTF_8));
        File snapshot=new File(o.optString("source_snapshot",""));
        if(!snapshot.isDirectory()||!new File(snapshot,".checkpoint_complete").isFile())
            throw new IllegalStateException("Immutable checkpoint source is missing.");

        long current=SourceVault.currentVersionCode(c);
        File ws=SourceVault.createWorkspaceFromSnapshot(
                c,snapshot,"RECOVERY: "+(reason==null?"":reason),false);
        SourceVault.prepareVersionForUpdate(ws,current+1L);

        JSONObject plan=new JSONObject()
                .put("schema","anamika13-recovery-plan-v2")
                .put("last_good_version_code",o.optLong("version_code",-1))
                .put("minimum_recovery_version_code",current+1)
                .put("source_snapshot",snapshot.getAbsolutePath())
                .put("reason",reason==null?"":reason)
                .put("created_ms",System.currentTimeMillis());

        File planFile=new File(ws,"RECOVERY_PLAN.json");
        try(FileOutputStream out=new FileOutputStream(planFile,false)){
            out.write(plan.toString(2).getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }
        UpgradeJournal.record(c,"RECOVERY_PLAN","Exact checkpoint workspace "+ws.getAbsolutePath());
        return ws;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
