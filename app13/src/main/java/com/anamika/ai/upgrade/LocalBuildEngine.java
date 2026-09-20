package com.anamika.ai.upgrade;

import android.content.Context;

import com.anamika.ai.core.HealthMonitor;

import java.io.File;

/**
 * Gatekeeper for phone-local APK builds.
 * V13 never claims build support until a complete ARM64 toolchain is physically present.
 */
public final class LocalBuildEngine {
    public static final class Capability {
        public final boolean ready;
        public final String detail;
        Capability(boolean ready,String detail){this.ready=ready;this.detail=detail;}
    }

    private LocalBuildEngine(){}

    public static Capability capability(Context c){
        File root=new File(c.getFilesDir(),"v13_toolchain");
        File aapt2=new File(root,"bin/aapt2");
        File d8=new File(root,"lib/d8.jar");
        File androidJar=new File(root,"platforms/android-36/android.jar");
        File signer=new File(root,"lib/apksig.jar");
        boolean files=aapt2.isFile()&&d8.isFile()&&androidJar.isFile()&&signer.isFile();
        boolean storage=HealthMonitor.enoughForLocalBuild(c,2L*1024L*1024L*1024L);
        if(!files) return new Capability(false,
                "Local build toolchain is not installed yet. Required: ARM64 aapt2, D8, android-36.jar and APK signer.");
        if(!aapt2.canExecute()) return new Capability(false,"Bundled aapt2 exists but is not executable.");
        if(!storage) return new Capability(false,"At least 2 GB free private storage is required for a safe local build.");
        return new Capability(true,"Phone-local Android build toolchain is ready.");
    }
}
