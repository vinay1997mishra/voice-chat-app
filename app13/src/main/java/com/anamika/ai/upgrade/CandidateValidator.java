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
        return CodeDoctor.inspect(workspace);
    }
}
