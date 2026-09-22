package com.anamika.ai.upgrade;

import com.anamika.ai.developer.CodeDoctor;

import java.io.File;

/** Runs V13 structural validation over a private self-upgrade workspace. */
public final class CandidateValidator {
    private CandidateValidator(){}

    public static CodeDoctor.Report validateWorkspace(File workspace){
        if(workspace==null||!workspace.isDirectory()){
            java.util.List<String> p=new java.util.ArrayList<>();
            p.add("Workspace missing.");
            return new CodeDoctor.Report(false,0,p);
        }
        CodeDoctor.Report structural=CodeDoctor.inspect(workspace);
        UpgradeConsistencyGuard.Report consistency=UpgradeConsistencyGuard.inspect(workspace);
        if(consistency.clean)return structural;
        java.util.List<String> merged=new java.util.ArrayList<>();
        merged.addAll(structural.problems);
        merged.addAll(consistency.problems);
        return new CodeDoctor.Report(false,structural.filesChecked,merged);
    }
}
