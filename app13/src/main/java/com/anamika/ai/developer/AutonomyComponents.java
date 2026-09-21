package com.anamika.ai.developer;

import android.content.Context;

import com.anamika.ai.upgrade.LocalBuildEngine;
import com.anamika.ai.upgrade.RollbackManager;
import com.anamika.ai.upgrade.SignerVault;

import java.io.File;

/** Readiness view for V13 phone-local autonomous repair/update components. */
public final class AutonomyComponents {
    private AutonomyComponents(){}

    public static String status(Context c){
        LocalBuildEngine.Capability build=LocalBuildEngine.capability(c);
        File model=BrainRuntimePaths.model(c);

        boolean modelReady=model.isFile()&&model.length()>16L*1024L*1024L;
        boolean runtimeReady=BrainRuntimePaths.runtimeReady(c);

        return "Anamika 13 autonomy components"+
                "\nLocal builder: "+(build.ready?"READY":"NOT READY")+
                "\n"+build.detail+
                "\nSigner: "+(SignerVault.ready(c)?"READY":"NOT READY")+
                "\nOffline coding model: "+(modelReady?"MODEL PRESENT":"MODEL MISSING")+
                "\nOffline inference runtime: "+(runtimeReady?"READY":"NOT READY")+
                "\n"+RollbackManager.status(c);
    }

    public static String brainStatus(Context c){
        return OfflineCodingBrain.status(c)+
                "\nNo separate app is required; model/schema stay private and native inference runtime is embedded in the signed APK.";
    }
}
