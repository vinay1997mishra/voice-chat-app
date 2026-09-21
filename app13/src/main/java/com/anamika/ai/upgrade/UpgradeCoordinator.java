package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.developer.CodeDoctor;
import com.anamika.ai.developer.OfflineCodingBrain;

import java.io.File;

public final class UpgradeCoordinator {
    private static final String PREF="anamika13_upgrade";
    private static final String LAST_WS="last_workspace";

    private UpgradeCoordinator(){}

    public static String prepare(Context c,String request){
        try{
            UpgradeJournal.record(c,"SNAPSHOT","Preparing private source workspace.");
            File ws=SourceVault.createWorkspace(c,request);
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_WS,ws.getAbsolutePath()).apply();
            UpgradeJournal.record(c,"PLAN","Workspace ready: "+ws.getAbsolutePath());
            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            return "Self-upgrade workspace created:\n"+ws.getAbsolutePath()+"\n\n"+cap.detail+
                    "\nNo candidate will be installed without validation, matching signature and owner approval.";
        }catch(Exception e){
            UpgradeJournal.record(c,"REJECTED","Workspace preparation failed: "+safe(e));
            return "Could not prepare self-upgrade workspace: "+safe(e);
        }
    }

    public static String validateLatest(Context c){
        File ws=latestWorkspace(c);
        if(ws==null||!ws.isDirectory())return "Create an upgrade workspace first.";
        CodeDoctor.Report report=CandidateValidator.validateWorkspace(ws);
        UpgradeJournal.record(c,report.clean?"VALIDATE_PASS":"VALIDATE_FAIL",report.text());
        return report.text();
    }

    public static String repairLatestOffline(Context c,String request){
        File ws=latestWorkspace(c);
        if(ws==null||!ws.isDirectory())return "Create an upgrade workspace first.";
        UpgradeJournal.record(c,"OFFLINE_REPAIR_START",request==null?"":request);
        OfflineCodingBrain.Result r=OfflineCodingBrain.repair(c,ws,request);
        UpgradeJournal.record(c,r.ok?"OFFLINE_REPAIR_PASS":"OFFLINE_REPAIR_FAIL",r.message);
        if(!r.ok)return r.message;
        CodeDoctor.Report check=CandidateValidator.validateWorkspace(ws);
        UpgradeJournal.record(c,check.clean?"VALIDATE_PASS":"VALIDATE_FAIL",check.text());
        return r.message+"\n\n"+check.text();
    }

    public static String buildLatest(Context c){
        File ws=latestWorkspace(c);
        if(ws==null||!ws.isDirectory())return "Create an upgrade workspace first.";
        CodeDoctor.Report check=CandidateValidator.validateWorkspace(ws);
        if(!check.clean){
            UpgradeJournal.record(c,"BUILD_BLOCKED",check.text());
            return "Build blocked because structural validation failed.\n"+check.text();
        }
        RollbackManager.checkpoint(c);
        UpgradeJournal.record(c,"LOCAL_BUILD_START",ws.getAbsolutePath());
        LocalBuildEngine.BuildResult r=LocalBuildEngine.build(c,ws);
        UpgradeJournal.record(c,r.ok?"LOCAL_BUILD_PASS":"LOCAL_BUILD_FAIL",r.log);
        if(r.ok){
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString("last_candidate",r.apk.getAbsolutePath()).apply();
            return r.log+"\nCandidate: "+r.apk.getAbsolutePath();
        }
        return r.log;
    }

    public static File latestCandidate(Context c){
        String path=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString("last_candidate","");
        return path.isEmpty()?null:new File(path);
    }

    public static File latestWorkspace(Context c){
        String path=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(LAST_WS,"");
        return path.isEmpty()?null:new File(path);
    }

    public static String status(Context c){
        File ws=latestWorkspace(c);
        LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
        File apk=latestCandidate(c);
        return "Anamika 13 local self-upgrade\nWorkspace: "+
                (ws!=null&&ws.isDirectory()?ws.getAbsolutePath():"not created")+
                "\nBuilder: "+(cap.ready?"READY":"NOT READY")+"\n"+cap.detail+
                "\nCandidate: "+(apk!=null&&apk.isFile()?apk.getAbsolutePath():"none");
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
