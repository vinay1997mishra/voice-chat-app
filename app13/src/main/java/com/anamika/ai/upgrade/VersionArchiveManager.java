package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.os.Build;

import com.anamika.ai.core.CrashJournal;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/**
 * Keeps old installed versions until the owner explicitly deletes them.
 *
 * Before an update we archive both the currently installed APK and the exact
 * bundled source snapshot. After update, a version becomes "stable verified"
 * only after source/duplicate checks pass and three consecutive healthy launches
 * occur without a newer crash. No archive is ever deleted automatically.
 */
public final class VersionArchiveManager {
    private static final String PREF="anamika13_version_archive";
    private static final String EXPECTED_FROM="expected_from";
    private static final String EXPECTED_TO="expected_to";
    private static final String FIRST_SEEN="first_seen";
    private static final String HEALTHY="healthy_launches";
    private static final String STABLE="stable";
    private static final String REMINDER="reminder_shown";
    private static final String LAST_CRASH="last_crash_seen";
    private static final String VERIFY_STATUS="verify_status";
    private static volatile boolean countedThisProcess;

    private VersionArchiveManager(){}

    public static File root(Context c){
        return new File(c.getFilesDir(),"v13_version_archive");
    }

    public static String beforeInstall(Context c,long candidateVersion){
        try{
            long current=currentVersion(c);
            if(candidateVersion<=current)
                return "Archive preparation rejected: candidate version is not newer.";
            File archived=archiveCurrent(c,"before update to "+candidateVersion);
            SharedPreferences.Editor e=prefs(c).edit()
                    .putLong(EXPECTED_FROM,current)
                    .putLong(EXPECTED_TO,candidateVersion)
                    .putLong(FIRST_SEEN,0L)
                    .putInt(HEALTHY,0)
                    .putBoolean(STABLE,false)
                    .putBoolean(REMINDER,false)
                    .putLong(LAST_CRASH,0L)
                    .putString(VERIFY_STATUS,"waiting for version "+candidateVersion);
            e.apply();
            UpgradeJournal.record(c,"OLD_VERSION_ARCHIVED",
                    "v"+current+" -> "+archived.getAbsolutePath()+"; expecting v"+candidateVersion);
            return "Old version "+current+" archived safely. It will NOT be deleted automatically.";
        }catch(Exception e){
            return "Could not archive current version; install must stay blocked: "+safe(e);
        }
    }

    public static File archiveCurrent(Context c,String reason)throws Exception{
        PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        long code=Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
        File root=root(c);
        if(!root.exists()&&!root.mkdirs())throw new IllegalStateException("Cannot create version archive.");

        File dir=new File(root,"v"+code);
        if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create archive for v"+code);

        File apk=new File(dir,"base.apk");
        if(!apk.isFile()||apk.length()<1024){
            File installed=new File(c.getApplicationInfo().sourceDir);
            if(!installed.isFile())throw new IllegalStateException("Installed APK source is unavailable.");
            copy(installed,apk);
        }

        File source=new File(dir,"source");
        File marker=new File(source,".checkpoint_complete");
        if(!marker.isFile())SourceVault.snapshotBaseline(c,source);

        JSONObject meta=new JSONObject()
                .put("schema","anamika13-version-archive-v1")
                .put("version_code",code)
                .put("version_name",p.versionName==null?"":p.versionName)
                .put("apk_path",apk.getAbsolutePath())
                .put("source_path",source.getAbsolutePath())
                .put("reason",reason==null?"":reason)
                .put("archived_ms",System.currentTimeMillis())
                .put("automatic_deletion_allowed",false);
        write(new File(dir,"archive.json"),meta.toString(2));
        return dir;
    }

    /** Called on startup. Does not count a healthy launch yet. */
    public static String onLaunch(Context c){
        try{
            long expected=prefs(c).getLong(EXPECTED_TO,-1L);
            long current=currentVersion(c);
            if(expected<=0||current!=expected)return "";

            long first=prefs(c).getLong(FIRST_SEEN,0L);
            if(first<=0L){
                first=System.currentTimeMillis();
                prefs(c).edit().putLong(FIRST_SEEN,first).apply();
                UpgradeJournal.record(c,"POST_UPDATE_FIRST_LAUNCH","version="+current);
            }

            String verify=verifyCurrentSource(c);
            prefs(c).edit().putString(VERIFY_STATUS,verify).apply();
            return verify;
        }catch(Exception e){
            String msg="Post-update launch verification failed: "+safe(e);
            prefs(c).edit().putString(VERIFY_STATUS,msg).apply();
            return msg;
        }
    }

    /**
     * Call after the app has remained alive long enough to be considered a healthy launch.
     * Three consecutive healthy launches are required before the old-version reminder.
     */
    public static String recordHealthyLaunch(Context c){
        if(countedThisProcess)return "";
        countedThisProcess=true;
        try{
            long expected=prefs(c).getLong(EXPECTED_TO,-1L);
            long current=currentVersion(c);
            if(expected<=0||current!=expected)return "";

            long first=prefs(c).getLong(FIRST_SEEN,0L);
            if(first<=0L){
                first=System.currentTimeMillis();
                prefs(c).edit().putLong(FIRST_SEEN,first).apply();
            }

            String verify=verifyCurrentSource(c);
            if(!verify.startsWith("PASS")){
                prefs(c).edit().putInt(HEALTHY,0).putBoolean(STABLE,false)
                        .putString(VERIFY_STATUS,verify).apply();
                return verify;
            }

            File crash=CrashJournal.file(c);
            long crashMs=crash.isFile()?crash.lastModified():0L;
            long seenCrash=prefs(c).getLong(LAST_CRASH,0L);
            if(crashMs>first&&crashMs>seenCrash){
                prefs(c).edit()
                        .putLong(LAST_CRASH,crashMs)
                        .putInt(HEALTHY,0)
                        .putBoolean(STABLE,false)
                        .putString(VERIFY_STATUS,"New version had a recorded crash; healthy-launch count reset.")
                        .apply();
                UpgradeJournal.record(c,"POST_UPDATE_CRASH","version="+current+" crash_ms="+crashMs);
                return "New version had a recorded crash; stability count reset.";
            }

            int healthy=prefs(c).getInt(HEALTHY,0)+1;
            boolean stable=healthy>=3;
            prefs(c).edit()
                    .putInt(HEALTHY,healthy)
                    .putBoolean(STABLE,stable)
                    .putString(VERIFY_STATUS,"PASS • source/duplicate checks clean • healthy launches "+healthy+"/3")
                    .apply();
            UpgradeJournal.record(c,stable?"POST_UPDATE_STABLE":"POST_UPDATE_HEALTHY",
                    "version="+current+" healthy="+healthy);

            if(stable)
                return "New version "+current+" is stable-verified after source checks and 3 healthy launches.";
            return "Post-update healthy launch "+healthy+"/3.";
        }catch(Exception e){
            return "Post-update healthy check failed: "+safe(e);
        }
    }

    public static String consumeReminder(Context c){
        try{
            SharedPreferences p=prefs(c);
            if(!p.getBoolean(STABLE,false)||p.getBoolean(REMINDER,false))return "";
            long old=p.getLong(EXPECTED_FROM,-1L);
            long current=currentVersion(c);
            File oldDir=new File(root(c),"v"+old);
            if(old<=0||!oldDir.isDirectory())return "";
            p.edit().putBoolean(REMINDER,true).apply();
            return "New version "+current+" source/consistency checks aur 3 healthy launches PASS kar chuki hai. "+
                    "Old version "+old+" abhi bhi safe archive me hai. Agar aap chaho to 'delete old versions' bolo. "+
                    "Main aapke order ke bina old version delete nahi karungi.";
        }catch(Exception e){return "";}
    }

    public static String status(Context c){
        File[] dirs=root(c).listFiles(File::isDirectory);
        int count=0;long bytes=0;
        if(dirs!=null)for(File d:dirs){
            if(!d.getName().matches("v[0-9]+"))continue;
            count++;bytes+=size(d);
        }
        SharedPreferences p=prefs(c);
        return "Version archive: "+count+" old version(s), "+(bytes/1024/1024)+" MB"+
                "\nExpected update: "+p.getLong(EXPECTED_FROM,-1)+" -> "+p.getLong(EXPECTED_TO,-1)+
                "\nPost-update: "+p.getString(VERIFY_STATUS,"not pending")+
                "\nHealthy launches: "+p.getInt(HEALTHY,0)+"/3"+
                "\nStable verified: "+(p.getBoolean(STABLE,false)?"YES":"NO")+
                "\nAuto-delete old versions: NEVER";
    }

    /** Explicit owner action only. Deletes all archives older than the installed version. */
    public static String deleteOldVersions(Context c){
        try{
            long current=currentVersion(c);
            File[] dirs=root(c).listFiles(File::isDirectory);
            int removed=0;long freed=0;
            if(dirs!=null)for(File d:dirs){
                if(!d.getName().matches("v[0-9]+"))continue;
                long code;
                try{code=Long.parseLong(d.getName().substring(1));}catch(Exception e){continue;}
                if(code>=current)continue;
                long before=size(d);
                if(deleteTree(d)){removed++;freed+=before;}
            }
            UpgradeJournal.record(c,"OWNER_DELETED_OLD_VERSIONS",
                    "removed="+removed+" freed_bytes="+freed);
            return "Owner command complete: "+removed+" old archived version(s) deleted; "+
                    (freed/1024/1024)+" MB freed. Current version "+current+" untouched.";
        }catch(Exception e){
            return "Old-version delete failed: "+safe(e);
        }
    }

    private static String verifyCurrentSource(Context c)throws Exception{
        File base=SourceVault.ensureBaseline(c);
        com.anamika.ai.developer.CodeDoctor.Report report=CandidateValidator.validateWorkspace(base);
        if(!report.clean)return "FAIL • installed source validation: "+report.text();
        String[] core={
                "com.anamika.ai.MainActivity",
                "com.anamika.ai.CommandRouter",
                "com.anamika.ai.BrainCommandEngine",
                "com.anamika.ai.components.ComponentPackManager",
                "com.anamika.ai.upgrade.UpgradeCoordinator"
        };
        for(String cls:core)Class.forName(cls);
        return "PASS • installed source/duplicate/core-class checks clean";
    }

    private static long currentVersion(Context c)throws Exception{
        PackageInfo p=c.getPackageManager().getPackageInfo(c.getPackageName(),0);
        return Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
    }

    private static SharedPreferences prefs(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
    }

    private static void copy(File src,File dst)throws Exception{
        File parent=dst.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs())
            throw new IllegalStateException("Cannot create "+parent);
        try(FileInputStream in=new FileInputStream(src);FileOutputStream out=new FileOutputStream(dst,false)){
            byte[] b=new byte[128*1024];int n;
            while((n=in.read(b))>0)out.write(b,0,n);
            out.getFD().sync();
        }
    }

    private static void write(File f,String s)throws Exception{
        File p=f.getParentFile();
        if(p!=null&&!p.exists()&&!p.mkdirs())throw new IllegalStateException("Cannot create "+p);
        try(FileOutputStream out=new FileOutputStream(f,false)){
            out.write(s.getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        }
    }

    private static long size(File f){
        if(f==null||!f.exists())return 0;
        if(f.isFile())return f.length();
        long n=0;File[] kids=f.listFiles();
        if(kids!=null)for(File k:kids)n+=size(k);
        return n;
    }

    private static boolean deleteTree(File f){
        if(f==null||!f.exists())return true;
        boolean ok=true;
        if(f.isDirectory()){
            File[] kids=f.listFiles();
            if(kids!=null)for(File k:kids)ok&=deleteTree(k);
        }
        return (!f.exists()||f.delete())&&ok;
    }

    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
