package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.components.ComponentPackManager;
import com.anamika.ai.developer.CodeDoctor;
import com.anamika.ai.developer.OfflineCodingBrain;

import java.io.File;

/**
 * Strict source -> validate -> repair -> real build -> APK verify gate.
 *
 * A candidate is never returned merely because a model said it was fixed.
 * Structural/consistency validation and a real signed Android build are mandatory.
 */
public final class UpgradeQualityGate {
    public static final class Result {
        public final boolean ok;
        public final File apk;
        public final String log;
        public final int repairPasses;
        Result(boolean ok,File apk,String log,int repairPasses){
            this.ok=ok;this.apk=apk;this.log=log;this.repairPasses=repairPasses;
        }
    }

    private static final int MAX_REPAIR_PASSES=2;

    private UpgradeQualityGate(){}

    public static Result run(Context c,File workspace,String ownerRequest){
        if(workspace==null||!workspace.isDirectory())
            return new Result(false,null,"Upgrade workspace missing.",0);

        String request=ownerRequest==null?"":ownerRequest.trim();
        int repairs=0;
        StringBuilder audit=new StringBuilder();

        for(int cycle=0;cycle<=MAX_REPAIR_PASSES;cycle++){
            CodeDoctor.Report validation=CandidateValidator.validateWorkspace(workspace);
            audit.append("\nVALIDATION ").append(cycle+1).append(":\n").append(validation.text()).append("\n");

            if(!validation.clean){
                if(cycle>=MAX_REPAIR_PASSES)
                    return new Result(false,null,
                            "Candidate validation still fails after automatic repair attempts. Install blocked.\n"+audit,
                            repairs);
                if(!ComponentPackManager.brainInstalled(c))
                    return new Result(false,null,
                            "Candidate validation failed and Offline Brain is not ready, so Anamika cannot repair it automatically. Install blocked.\n"+audit,
                            repairs);

                String repairPrompt=
                        "STRICT UPDATE REPAIR. The candidate source failed structural/consistency validation. "+
                        "Fix every reported problem before build. Update the existing implementation in place; do NOT create parallel V2/New/Copy/Updated versions of an existing function. "+
                        "Preserve all unrelated working features, package identity and owner controls. "+
                        "Do not delete old working functions unless the owner explicitly requested their removal. "+
                        "OWNER UPDATE REQUEST:\n"+request+
                        "\n\nVALIDATION FAILURES:\n"+validation.text();
                OfflineCodingBrain.Result repair=OfflineCodingBrain.repair(c,workspace,repairPrompt);
                repairs++;
                UpgradeJournal.record(c,repair.ok?"QUALITY_REPAIR_PASS":"QUALITY_REPAIR_FAIL",repair.message);
                audit.append("AUTO REPAIR ").append(repairs).append(": ").append(repair.message).append("\n");
                if(!repair.ok)
                    return new Result(false,null,"Automatic source repair failed. Install blocked.\n"+audit,repairs);
                continue;
            }

            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            if(!cap.ready)
                return new Result(false,null,
                        "Validation PASS, but real build is required and builder/signer is not ready.\n"+cap.detail+"\n"+audit,
                        repairs);

            UpgradeJournal.record(c,"QUALITY_BUILD_START","cycle="+(cycle+1)+" workspace="+workspace.getAbsolutePath());
            LocalBuildEngine.BuildResult built=LocalBuildEngine.build(c,workspace);
            audit.append("\nREAL BUILD ").append(cycle+1).append(":\n").append(built.log).append("\n");

            if(built.ok){
                UpgradeJournal.record(c,"QUALITY_GATE_PASS","repairs="+repairs+" apk="+built.apk.getAbsolutePath());
                return new Result(true,built.apk,
                        "STRICT UPDATE QUALITY GATE PASS\n"+
                        "Code/structure: PASS\nDuplicate-function guard: PASS\nReal signed APK build: PASS\nAPK identity/signature/version verification: PASS\n"+
                        "Automatic repair passes: "+repairs+"\n"+audit,
                        repairs);
            }

            if(cycle>=MAX_REPAIR_PASSES)
                return new Result(false,built.apk,
                        "Real build still fails after automatic repair attempts. Install blocked.\n"+audit,
                        repairs);
            if(!ComponentPackManager.brainInstalled(c))
                return new Result(false,built.apk,
                        "Real build failed and Offline Brain is unavailable for automatic repair. Install blocked.\n"+audit,
                        repairs);

            String buildRepairPrompt=
                    "STRICT BUILD-FAIL REPAIR. The candidate passed source validation but the real Android build failed. "+
                    "Use the build log to repair compile/resource/integration errors. Modify the existing implementation instead of creating duplicate replacement functions/classes. "+
                    "Preserve unrelated existing functions, package identity, signing/update architecture and owner controls. "+
                    "OWNER UPDATE REQUEST:\n"+request+
                    "\n\nREAL BUILD FAILURE:\n"+trim(built.log,12000);
            OfflineCodingBrain.Result repair=OfflineCodingBrain.repair(c,workspace,buildRepairPrompt);
            repairs++;
            UpgradeJournal.record(c,repair.ok?"QUALITY_BUILD_REPAIR_PASS":"QUALITY_BUILD_REPAIR_FAIL",repair.message);
            audit.append("BUILD REPAIR ").append(repairs).append(": ").append(repair.message).append("\n");
            if(!repair.ok)
                return new Result(false,built.apk,"Automatic build-error repair failed. Install blocked.\n"+audit,repairs);
        }

        return new Result(false,null,"Quality gate ended without a verified candidate.",repairs);
    }

    private static String trim(String s,int max){
        if(s==null)return "";
        return s.length()>max?s.substring(0,max):s;
    }
}
