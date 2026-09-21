package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.CodeDoctor;
import com.anamika.ai.developer.OfflineCodingBrain;

import java.io.File;

/** Coordinates owner-requested V13 source repair, feature creation, build and update staging. */
public final class UpgradeCoordinator {
    private static final String PREF="anamika13_upgrade";
    private static final String LAST_WS="last_workspace";
    private static final String LAST_CANDIDATE="last_candidate";

    private UpgradeCoordinator(){}

    public static String prepare(Context c,String request){
        try{
            UpgradeJournal.record(c,"SNAPSHOT","Preparing private source workspace.");
            File ws=SourceVault.createWorkspace(c,request);
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_WS,ws.getAbsolutePath())
                    .remove(LAST_CANDIDATE)
                    .apply();
            UpgradeJournal.record(c,"PLAN","Workspace ready: "+ws.getAbsolutePath());
            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            return "Self-upgrade workspace created:\n"+ws.getAbsolutePath()+
                    "\nCandidate versionCode automatically set above installed version."+
                    "\n\n"+cap.detail+
                    "\nNo candidate will be installed without APK verification and Android/owner confirmation.";
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
        if(!ComponentPackManager.brainInstalled(c))
            return "Offline brain runtime/model installed nahi hai.";
        UpgradeJournal.record(c,"OFFLINE_REPAIR_START",request==null?"":request);
        OfflineCodingBrain.Result r=OfflineCodingBrain.repair(c,ws,request);
        UpgradeJournal.record(c,r.ok?"OFFLINE_REPAIR_PASS":"OFFLINE_REPAIR_FAIL",r.message);
        if(!r.ok)return r.message;
        CodeDoctor.Report check=CandidateValidator.validateWorkspace(ws);
        UpgradeJournal.record(c,check.clean?"VALIDATE_PASS":"VALIDATE_FAIL",check.text());
        return r.message+"\n\n"+check.text();
    }

    /**
     * End-to-end feature creation attempt for an owner request.
     * It creates source changes automatically; installation still requires the verified
     * self-update screen and Android's confirmation.
     */
    public static String createOrUpgradeFunction(Context c,String request){
        String r=request==null?"":request.trim();
        if(r.isEmpty())return "Function request empty hai.";
        if(!ComponentPackManager.brainInstalled(c))
            return "Naya function create karne ke liye Offline Brain runtime + GGUF model install hona chahiye.";

        try{
            UpgradeJournal.record(c,"AUTO_FEATURE_START",r);
            File ws=SourceVault.createWorkspace(c,r);
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_WS,ws.getAbsolutePath())
                    .remove(LAST_CANDIDATE)
                    .apply();

            OfflineCodingBrain.Result brain=OfflineCodingBrain.repair(c,ws,
                    "Owner wants a new or changed Anamika 13 function. Implement the complete requested capability in the existing V13 architecture. "+
                    "Create any missing Java/XML/config files needed, connect the feature to the command/router/UI where appropriate, preserve package identity, "+
                    "and do not remove unrelated existing features. Owner request: "+r);
            UpgradeJournal.record(c,brain.ok?"AUTO_FEATURE_CODE_PASS":"AUTO_FEATURE_CODE_FAIL",brain.message);
            if(!brain.ok)return "Function source create nahi ho saka.\n"+brain.message;

            CodeDoctor.Report structural=CandidateValidator.validateWorkspace(ws);
            UpgradeJournal.record(c,structural.clean?"AUTO_FEATURE_VALIDATE_PASS":"AUTO_FEATURE_VALIDATE_FAIL",structural.text());
            if(!structural.clean)
                return "Brain ne source change kiya, lekin validation fail hui. Install/build block kiya gaya.\n"+structural.text();

            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            if(!cap.ready){
                return "Function ka source create + structural validation PASS hai.\nWorkspace: "+ws.getAbsolutePath()+
                        "\nAPK build abhi block hai: "+cap.detail+
                        "\nToolchain/signer ready hote hi 'local build' bolo.";
            }

            RollbackManager.checkpoint(c);
            LocalBuildEngine.BuildResult built=LocalBuildEngine.build(c,ws);
            UpgradeJournal.record(c,built.ok?"AUTO_FEATURE_BUILD_PASS":"AUTO_FEATURE_BUILD_FAIL",built.log);
            if(!built.ok)return "Function source ready tha, lekin real APK build fail hua.\n"+built.log;

            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_CANDIDATE,built.apk.getAbsolutePath()).apply();
            return "NEW FUNCTION BUILD READY\n"+built.log+
                    "\nCandidate: "+built.apk.getAbsolutePath()+
                    "\nAb 'self update' kholo. Installation owner/Android confirmation ke bina nahi hogi.";
        }catch(Exception e){
            UpgradeJournal.record(c,"AUTO_FEATURE_FAIL",safe(e));
            return "Automatic function upgrade failed: "+safe(e);
        }
    }

    public static String buildLatest(Context c){
        File ws=latestWorkspace(c);
        if(ws==null||!ws.isDirectory())return "Create an upgrade workspace first.";
        CodeDoctor.Report check=CandidateValidator.validateWorkspace(ws);
        if(!check.clean){
            UpgradeJournal.record(c,"BUILD_BLOCKED",check.text());
            return "Build blocked because structural validation failed.\n"+check.text();
        }
        LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
        if(!cap.ready){
            UpgradeJournal.record(c,"BUILD_BLOCKED",cap.detail);
            return "Local build blocked: "+cap.detail;
        }
        RollbackManager.checkpoint(c);
        UpgradeJournal.record(c,"LOCAL_BUILD_START",ws.getAbsolutePath());
        LocalBuildEngine.BuildResult r=LocalBuildEngine.build(c,ws);
        UpgradeJournal.record(c,r.ok?"LOCAL_BUILD_PASS":"LOCAL_BUILD_FAIL",r.log);
        if(r.ok){
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_CANDIDATE,r.apk.getAbsolutePath()).apply();
            return r.log+"\nCandidate: "+r.apk.getAbsolutePath();
        }
        return r.log;
    }

    public static File latestCandidate(Context c){
        String path=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(LAST_CANDIDATE,"");
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
                "\nBrain: "+(ComponentPackManager.brainInstalled(c)?"READY":"NOT READY")+
                "\nBuilder: "+(cap.ready?"READY":"NOT READY")+"\n"+cap.detail+
                "\nSigner: "+(SignerVault.ready(c)?"READY":"NOT READY")+
                "\nCandidate: "+(apk!=null&&apk.isFile()?apk.getAbsolutePath():"none");
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
