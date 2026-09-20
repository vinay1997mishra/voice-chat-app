package com.anamika.ai.upgrade;

import android.content.Context;

import java.io.File;

public final class UpgradeCoordinator {
    private static final String PREF="anamika13_upgrade";
    private static final String LAST_WS="last_workspace";

    private UpgradeCoordinator(){}

    public static String prepare(Context c,String request){
        try{
            File ws=SourceVault.createWorkspace(c,request);
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().putString(LAST_WS,ws.getAbsolutePath()).apply();
            LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
            return "Self-upgrade workspace created:\n"+ws.getAbsolutePath()+"\n\n"+cap.detail+
                    "\nNo candidate will be installed without validation, matching signature and owner approval.";
        }catch(Exception e){
            return "Could not prepare self-upgrade workspace: "+safe(e);
        }
    }

    public static String status(Context c){
        String path=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(LAST_WS,"");
        File ws=path.isEmpty()?null:new File(path);
        LocalBuildEngine.Capability cap=LocalBuildEngine.capability(c);
        return "Anamika 13 local self-upgrade\nWorkspace: "+(ws!=null&&ws.isDirectory()?ws.getAbsolutePath():"not created")+
                "\nBuilder: "+(cap.ready?"READY":"NOT READY")+"\n"+cap.detail;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
