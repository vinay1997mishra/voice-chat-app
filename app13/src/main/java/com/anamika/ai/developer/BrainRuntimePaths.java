package com.anamika.ai.developer;

import android.content.Context;

import java.io.File;

/** Resolves native/runtime files without executing code from writable app storage. */
public final class BrainRuntimePaths {
    private BrainRuntimePaths(){}

    public static File root(Context c){
        return new File(c.getFilesDir(),"v13_brain");
    }

    public static File model(Context c){
        return new File(root(c),"model.gguf");
    }

    public static File schema(Context c){
        return new File(root(c),"edit-plan.schema.json");
    }

    public static File runtimeMarker(Context c){
        return new File(root(c),"runtime.ready");
    }

    public static File embeddedCli(Context c){
        String nativeDir=c.getApplicationInfo().nativeLibraryDir;
        return new File(nativeDir==null?"":nativeDir,"libanamika_llama_cli.so");
    }

    public static boolean cliReady(Context c){
        File cli=embeddedCli(c);
        if(!cli.isFile())return false;
        return cli.canExecute()||cli.setExecutable(true,true);
    }

    public static boolean runtimeReady(Context c){
        return runtimeMarker(c).isFile()&&schema(c).isFile()&&cliReady(c);
    }
}
