package com.anamika.ai;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.util.Arrays;

/**
 * Owner-only secure self-update installer.
 *
 * A candidate APK is accepted only when:
 *  - package name exactly matches Anamika,
 *  - signing certificate SHA-256 matches the currently installed Anamika,
 *  - candidate versionCode is greater than the installed version.
 *
 * Installation still uses Android PackageInstaller and normal OS confirmation.
 */
public final class SelfUpdateActivity extends Activity {
    private static final int REQ_PICK_APK=5201;
    private static final int REQ_UNKNOWN_SOURCES=5202;
    private static final String ACTION_RESULT="com.anamika.ai.SELF_UPDATE_RESULT";

    private TextView status;
    private Button installButton;
    private File staged;
    private String stagedPackage="";
    private long stagedVersion=-1L;

    @Override protected void onCreate(Bundle savedInstanceState){
        super.onCreate(savedInstanceState);
        if(!OwnerSession.isActive(this)){
            Toast.makeText(this,"Owner verification required.",Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        setContentView(R.layout.activity_self_update);
        status=findViewById(R.id.selfUpdateStatus);
        installButton=findViewById(R.id.installSelfUpdateButton);
        Button pick=findViewById(R.id.pickSelfUpdateButton);
        Button permission=findViewById(R.id.selfUpdatePermissionButton);
        installButton.setEnabled(false);

        File dir=new File(getFilesDir(),"self_update");
        staged=new File(dir,"owner_update.apk");

        pick.setOnClickListener(v->pickApk());
        permission.setOnClickListener(v->openInstallPermission());
        installButton.setOnClickListener(v->installVerifiedUpdate());

        handleResult(getIntent());
        refreshStatus();
    }

    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);
        setIntent(intent);
        handleResult(intent);
    }

    private void pickApk(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/vnd.android.package-archive");
        startActivityForResult(i,REQ_PICK_APK);
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(requestCode==REQ_PICK_APK && resultCode==RESULT_OK && data!=null && data.getData()!=null){
            stageAndVerify(data.getData());
        }else if(requestCode==REQ_UNKNOWN_SOURCES){
            refreshStatus();
        }
    }

    private void stageAndVerify(Uri source){
        installButton.setEnabled(false);
        File dir=staged.getParentFile();
        if(dir!=null && !dir.exists() && !dir.mkdirs()){
            status.setText("Cannot create self-update folder.");
            return;
        }
        File partial=new File(dir,"owner_update.apk.partial");
        try(InputStream in=getContentResolver().openInputStream(source);
            OutputStream out=new FileOutputStream(partial)){
            if(in==null) throw new IllegalStateException("Cannot open selected APK.");
            byte[] buf=new byte[256*1024];
            long total=0;
            int n;
            while((n=in.read(buf))>=0){
                if(n==0) continue;
                total+=n;
                if(total>4L*1024L*1024L*1024L) throw new IllegalStateException("APK exceeds 4 GB safety limit.");
                out.write(buf,0,n);
            }
            out.flush();
            if(total<1024) throw new IllegalStateException("APK is empty or invalid.");
        }catch(Exception e){
            partial.delete();
            status.setText("Copy failed: "+safe(e));
            return;
        }

        try{
            PackageManager pm=getPackageManager();
            PackageInfo current=getInstalledInfo(pm,getPackageName());
            PackageInfo candidate=getArchiveInfo(pm,partial.getAbsolutePath());
            if(candidate==null || candidate.packageName==null)
                throw new IllegalStateException("Selected file is not a valid Android APK.");

            if(!getPackageName().equals(candidate.packageName))
                throw new SecurityException("Rejected: package mismatch. Expected "+getPackageName()+" but APK is "+candidate.packageName+".");

            byte[] currentCert=certificateDigest(current);
            byte[] candidateCert=certificateDigest(candidate);
            if(currentCert==null || candidateCert==null || !Arrays.equals(currentCert,candidateCert))
                throw new SecurityException("Rejected: signing certificate does not match installed Anamika.");

            long currentVersion=versionCode(current);
            long candidateVersion=versionCode(candidate);
            if(candidateVersion<=currentVersion)
                throw new SecurityException("Rejected: update version must be newer. Installed="+currentVersion+", candidate="+candidateVersion+".");

            if(staged.exists() && !staged.delete())
                throw new IllegalStateException("Cannot replace previous staged update.");
            if(!partial.renameTo(staged))
                throw new IllegalStateException("Cannot finalize verified update.");

            stagedPackage=candidate.packageName;
            stagedVersion=candidateVersion;
            installButton.setEnabled(true);
            status.setText("VERIFIED OWNER UPDATE\nPackage: "+stagedPackage+
                    "\nVersion: "+candidateVersion+
                    "\nSigning certificate: MATCH"+
                    "\nAPK SHA-256: "+sha256(staged)+
                    "\nReady for owner-approved installation.");
        }catch(Exception e){
            partial.delete();
            stagedPackage="";
            stagedVersion=-1L;
            status.setText(safe(e));
        }
    }

    private void installVerifiedUpdate(){
        if(!OwnerSession.isActive(this)){
            status.setText("Owner session is not active.");
            return;
        }
        if(!staged.isFile() || staged.length()<1024 || stagedPackage.isEmpty() || stagedVersion<0){
            status.setText("No verified Anamika update is staged.");
            installButton.setEnabled(false);
            return;
        }
        if(!getPackageManager().canRequestPackageInstalls()){
            status.setText("Android install permission is required. Tap Install Permission first.");
            return;
        }

        PackageInstaller installer=getPackageManager().getPackageInstaller();
        PackageInstaller.Session session=null;
        try{
            PackageInstaller.SessionParams params=new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
            params.setAppPackageName(getPackageName());
            int id=installer.createSession(params);
            session=installer.openSession(id);
            try(InputStream in=new FileInputStream(staged);
                OutputStream out=session.openWrite("base.apk",0,staged.length())){
                byte[] buf=new byte[256*1024];
                int n;
                while((n=in.read(buf))>=0){
                    if(n==0) continue;
                    out.write(buf,0,n);
                }
                session.fsync(out);
            }
            Intent callback=new Intent(this,SelfUpdateActivity.class)
                    .setAction(ACTION_RESULT)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pending=PendingIntent.getActivity(this,id,callback,
                    PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_MUTABLE);
            session.commit(pending.getIntentSender());
            status.setText("Verified update handed to Android installer. Approve the system confirmation to update Anamika.");
        }catch(Exception e){
            status.setText("Self-update install request failed: "+safe(e));
            if(session!=null) try{session.abandon();}catch(Exception ignored){}
        }finally{
            if(session!=null) session.close();
        }
    }

    private void handleResult(Intent intent){
        if(intent==null || !ACTION_RESULT.equals(intent.getAction())) return;
        int state=intent.getIntExtra(PackageInstaller.EXTRA_STATUS,PackageInstaller.STATUS_FAILURE);
        String msg=intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
        if(state==PackageInstaller.STATUS_PENDING_USER_ACTION){
            Intent confirm=intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if(confirm!=null) startActivity(confirm);
            return;
        }
        if(state==PackageInstaller.STATUS_SUCCESS){
            status.setText("Anamika update installed successfully.");
            installButton.setEnabled(false);
        }else{
            status.setText("Update failed/cancelled. Status="+state+(msg==null?"":"\n"+msg));
        }
    }

    private void openInstallPermission(){
        try{
            Intent i=new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:"+getPackageName()));
            startActivityForResult(i,REQ_UNKNOWN_SOURCES);
        }catch(Exception e){
            startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS));
        }
    }

    private void refreshStatus(){
        boolean allowed=getPackageManager().canRequestPackageInstalls();
        status.setText("Secure Self-Update\nInstall permission: "+(allowed?"ready":"needs Android approval")+
                "\nSelect an owner-signed newer Anamika APK. Package and certificate must match.");
    }

    private static PackageInfo getInstalledInfo(PackageManager pm,String pkg)throws Exception{
        if(Build.VERSION.SDK_INT>=28) return pm.getPackageInfo(pkg,PackageManager.GET_SIGNING_CERTIFICATES);
        return pm.getPackageInfo(pkg,PackageManager.GET_SIGNATURES);
    }

    private static PackageInfo getArchiveInfo(PackageManager pm,String path){
        int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
        return pm.getPackageArchiveInfo(path,flags);
    }

    private static byte[] certificateDigest(PackageInfo info)throws Exception{
        Signature[] sigs;
        if(Build.VERSION.SDK_INT>=28 && info.signingInfo!=null){
            sigs=info.signingInfo.hasMultipleSigners()
                    ? info.signingInfo.getApkContentsSigners()
                    : info.signingInfo.getSigningCertificateHistory();
        }else{
            sigs=info.signatures;
        }
        if(sigs==null || sigs.length==0) return null;
        return MessageDigest.getInstance("SHA-256").digest(sigs[0].toByteArray());
    }

    private static long versionCode(PackageInfo info){
        return Build.VERSION.SDK_INT>=28?info.getLongVersionCode():info.versionCode;
    }

    private static String sha256(File f)throws Exception{
        MessageDigest md=MessageDigest.getInstance("SHA-256");
        try(InputStream in=new FileInputStream(f)){
            byte[] buf=new byte[256*1024];
            int n;
            while((n=in.read(buf))>0) md.update(buf,0,n);
        }
        byte[] d=md.digest();
        StringBuilder sb=new StringBuilder();
        for(byte b:d) sb.append(String.format(java.util.Locale.US,"%02x",b));
        return sb.toString();
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
