package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.CodeDoctor;
import com.anamika.ai.developer.OfflineCodingBrain;
import com.anamika.ai.diagnostics.DiagnosticsReportStore;

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
     * Lets Anamika repair her own V13 implementation from inside the app.
     * The owner describes the problem in normal language. Anamika combines it with the
     * latest local diagnostics, edits only a disposable self-source workspace, validates
     * the result, and builds a signed self-update candidate when possible.
     */
    public static String selfRepair(Context c,String ownerProblem){
        String problem=ownerProblem==null?"":ownerProblem.trim();
        if(problem.isEmpty())
            problem="Inspect the latest local diagnostics and repair the current Anamika 13 implementation without removing unrelated features.";
        if(!ComponentPackManager.brainInstalled(c))
            return "Self repair ke liye Offline Brain runtime + GGUF model READY hona chahiye.";

        try{
            UpgradeJournal.record(c,"SELF_REPAIR_START",problem);
            File ws=SourceVault.createWorkspace(c,"self repair: "+problem);
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_WS,ws.getAbsolutePath())
                    .remove(LAST_CANDIDATE)
                    .apply();

            String diagnostics=DiagnosticsReportStore.readLatest(c);
            if(diagnostics.length()>12000)diagnostics=diagnostics.substring(0,12000);

            String request=
                    "You are repairing Anamika AI 13 from inside Anamika herself. "+
                    "Use the owner problem statement plus latest local diagnostics to identify the concrete defect. "+
                    "Repair the existing V13 source in this workspace, preserve unrelated functions and package identity, "+
                    "connect the repaired behavior to the existing UI/router/runtime where needed, and do not claim success unless the edit plan is valid. "+
                    "OWNER PROBLEM:\n"+problem+
                    "\n\nLATEST LOCAL DIAGNOSTICS:\n"+diagnostics;

            OfflineCodingBrain.Result brain=OfflineCodingBrain.repair(c,ws,request);
            UpgradeJournal.record(c,brain.ok?"SELF_REPAIR_CODE_PASS":"SELF_REPAIR_CODE_FAIL",brain.message);
            if(!brain.ok)return "Self repair source create nahi ho saka.\n"+brain.message;

            CodeDoctor.Report structural=CandidateValidator.validateWorkspace(ws);
            UpgradeJournal.record(c,structural.clean?"SELF_REPAIR_VALIDATE_PASS":"SELF_REPAIR_VALIDATE_FAIL",structural.text());
            if(!structural.clean)
                return "Self repair edit apply hua, lekin Code Doctor validation fail hui. Build/install block kiya gaya.\n"+structural.text();

            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            if(!cap.ready){
                return "SELF REPAIR SOURCE READY + VALIDATION PASS\nWorkspace: "+ws.getAbsolutePath()+
                        "\nAPK build abhi block hai: "+cap.detail+
                        "\nBuilder/signer ready hote hi 'local build' bolo.";
            }

            RollbackManager.checkpoint(c);
            LocalBuildEngine.BuildResult built=LocalBuildEngine.build(c,ws);
            UpgradeJournal.record(c,built.ok?"SELF_REPAIR_BUILD_PASS":"SELF_REPAIR_BUILD_FAIL",built.log);
            if(!built.ok)return "Self repair validation PASS tha, lekin real local APK build fail hua.\n"+built.log;

            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_CANDIDATE,built.apk.getAbsolutePath()).apply();

            return "SELF REPAIR BUILD READY\n"+
                    "Anamika ne apna source repair + validate + local sign/build kiya.\n"+
                    built.log+
                    "\nCandidate: "+built.apk.getAbsolutePath()+
                    "\nAb 'self update' kholo. Final install Android/owner confirmation ke baad hoga.";
        }catch(Exception e){
            UpgradeJournal.record(c,"SELF_REPAIR_FAIL",safe(e));
            return "Self repair failed: "+safe(e);
        }
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

    /**
     * Accepts owner-supplied source/code text, asks the offline coding brain to inspect it
     * against the current V13 workspace, repair it when needed, integrate it, validate it,
     * and produce a signed local APK candidate when the builder/signer are ready.
     */
    public static String applyOwnerCode(Context c,String suppliedCode){
        String code=suppliedCode==null?"":suppliedCode.trim();
        if(code.isEmpty())return "Direct code empty hai. 'apply code' ke baad code paste karo.";
        if(code.length()>48000)
            return "Direct code bahut bada hai. Ek baar me 48,000 characters tak paste karo ya code ko parts me do.";
        if(!ComponentPackManager.brainInstalled(c))
            return "Direct code check/repair ke liye Offline Brain runtime + GGUF model install hona chahiye.";

        try{
            UpgradeJournal.record(c,"DIRECT_CODE_START","Owner supplied "+code.length()+" chars.");
            File ws=SourceVault.createWorkspace(c,"owner supplied direct code");
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_WS,ws.getAbsolutePath())
                    .remove(LAST_CANDIDATE)
                    .apply();

            String request=
                    "The owner supplied code directly for Anamika 13. Inspect it against the current V13 source. "+
                    "Determine what function/change the code is intended to provide. Validate syntax, imports, APIs, package names, logic and integration. "+
                    "If the supplied code is wrong or incomplete, repair it before integrating. Preserve unrelated existing features and package identity. "+
                    "Create or modify only the files needed, connect the change to command/router/UI when appropriate, and return a valid edit plan. "+
                    "OWNER-SUPPLIED CODE START\n"+code+"\nOWNER-SUPPLIED CODE END";

            OfflineCodingBrain.Result brain=OfflineCodingBrain.repair(c,ws,request);
            UpgradeJournal.record(c,brain.ok?"DIRECT_CODE_REPAIR_PASS":"DIRECT_CODE_REPAIR_FAIL",brain.message);
            if(!brain.ok)
                return "Direct code integrate/repair nahi ho saka.\n"+brain.message;

            CodeDoctor.Report structural=CandidateValidator.validateWorkspace(ws);
            UpgradeJournal.record(c,structural.clean?"DIRECT_CODE_VALIDATE_PASS":"DIRECT_CODE_VALIDATE_FAIL",structural.text());
            if(!structural.clean)
                return "Code apply hua, lekin Code Doctor validation fail hui. Build/install block kiya gaya.\n"+structural.text();

            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            if(!cap.ready){
                return "DIRECT CODE VALIDATION PASS\nWorkspace: "+ws.getAbsolutePath()+
                        "\nAPK build abhi block hai: "+cap.detail+
                        "\nToolchain/signer ready hone ke baad 'local build' bolo.";
            }

            RollbackManager.checkpoint(c);
            LocalBuildEngine.BuildResult built=LocalBuildEngine.build(c,ws);
            UpgradeJournal.record(c,built.ok?"DIRECT_CODE_BUILD_PASS":"DIRECT_CODE_BUILD_FAIL",built.log);
            if(!built.ok)
                return "Code Doctor PASS tha, lekin real local APK build fail hua.\n"+built.log;

            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(LAST_CANDIDATE,built.apk.getAbsolutePath()).apply();

            return "DIRECT CODE BUILD READY\n"+
                    "Code checked + repaired/integrated + validated + signed candidate ready.\n"+
                    built.log+
                    "\nCandidate: "+built.apk.getAbsolutePath()+
                    "\nAb 'self update' kholo. Final install Android/owner confirmation ke baad hoga.";
        }catch(Exception e){
            UpgradeJournal.record(c,"DIRECT_CODE_FAIL",safe(e));
            return "Direct code workflow failed: "+safe(e);
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
