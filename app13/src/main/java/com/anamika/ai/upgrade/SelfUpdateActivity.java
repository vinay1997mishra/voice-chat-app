package com.anamika.ai.upgrade;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.core.AndroidCompat;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/** Owner-only V13 update installer. Candidate must match package, version and signing certificate. */
public final class SelfUpdateActivity extends Activity {
    private static final int PICK=1301;
    private static final String RESULT_ACTION="com.anamika.ai.v13.UPDATE_RESULT";

    private TextView status;
    private File staged;
    private boolean verified;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        if(!OwnerStore.isTrusted(this)){finish();return;}
        staged=new File(new File(getFilesDir(),"v13_update"),"candidate.apk");
        buildUi();
        handleInstallResult(getIntent());
    }

    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);
        setIntent(intent);
        handleInstallResult(intent);
    }

    private void buildUi(){
        int pad=dp(16);
        LinearLayout box=new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(pad,pad,pad,pad);

        TextView title=new TextView(this);
        title.setText("Anamika 13 • Verified Self Update");
        title.setTextSize(22);
        box.addView(title,new LinearLayout.LayoutParams(-1,-2));

        status=new TextView(this);
        status.setText("Select a newer Anamika 13 APK. It will be accepted only if package name and signing certificate match.");
        status.setTextIsSelectable(true);
        LinearLayout.LayoutParams sp=new LinearLayout.LayoutParams(-1,0,1);
        sp.topMargin=dp(16);
        box.addView(status,sp);

        Button local=new Button(this); local.setText("Use Latest Local Build");
        Button pick=new Button(this); pick.setText("Select APK");
        Button permission=new Button(this); permission.setText("Install Permission");
        Button install=new Button(this); install.setText("Install Verified Update");
        install.setEnabled(false);
        box.addView(local);
        box.addView(pick);
        box.addView(permission);
        box.addView(install);

        local.setOnClickListener(v->stageLocalBuild());
        pick.setOnClickListener(v->pick());
        permission.setOnClickListener(v->openPermission());
        install.setOnClickListener(v->install());

        install.setTag(Boolean.FALSE);
        install.setOnClickListener(v->install());

        ScrollView scroll=new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);

        // Store button through content tree using fieldless lookup by listener closure.
        status.setTag(install);
    }

    private Button installButton(){return (Button)status.getTag();}


    private void stageLocalBuild(){
        File candidate=UpgradeCoordinator.latestCandidate(this);
        if(candidate==null||!candidate.isFile()){
            status.setText("No local build candidate found. Run local build first.");
            return;
        }
        verified=false;
        installButton().setEnabled(false);
        File dir=staged.getParentFile();
        if(dir!=null&&!dir.exists()&&!dir.mkdirs()){status.setText("Cannot create update folder.");return;}
        File partial=new File(dir,"candidate.partial");
        try(InputStream in=new FileInputStream(candidate); OutputStream out=new FileOutputStream(partial,false)){
            byte[] buf=new byte[128*1024];int n;long total=0;
            while((n=in.read(buf))>0){
                total+=n;
                if(total>2L*1024L*1024L*1024L)throw new IllegalStateException("APK exceeds 2 GB safety limit.");
                out.write(buf,0,n);
            }
            if(total<1024)throw new IllegalStateException("Local candidate is empty.");
        }catch(Exception e){
            partial.delete();
            status.setText("Local candidate copy failed: "+safe(e));
            return;
        }
        if(staged.exists()&&!staged.delete()){partial.delete();status.setText("Cannot replace previous candidate.");return;}
        if(!partial.renameTo(staged)){partial.delete();status.setText("Cannot finalize local candidate.");return;}
        ApkVerifier.Result r=ApkVerifier.verifySelfUpdate(this,staged);
        verified=r.ok;
        installButton().setEnabled(verified);
        status.setText(r.message+(verified?"\nReady for Android system confirmation.":"\nUpdate rejected."));
    }

    private void pick(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/vnd.android.package-archive");
        startActivityForResult(i,PICK);
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(requestCode==PICK&&resultCode==RESULT_OK&&data!=null&&data.getData()!=null) stage(data.getData());
    }

    private void stage(Uri uri){
        verified=false;
        installButton().setEnabled(false);
        File dir=staged.getParentFile();
        if(dir!=null&&!dir.exists()&&!dir.mkdirs()){status.setText("Cannot create update folder.");return;}
        File partial=new File(dir,"candidate.partial");
        try(InputStream in=getContentResolver().openInputStream(uri); OutputStream out=new FileOutputStream(partial)){
            if(in==null)throw new IllegalStateException("Cannot read selected file.");
            byte[] buf=new byte[128*1024]; int n; long total=0;
            while((n=in.read(buf))>0){
                total+=n;
                if(total>2L*1024L*1024L*1024L)throw new IllegalStateException("APK exceeds 2 GB safety limit.");
                out.write(buf,0,n);
            }
            if(total<1024)throw new IllegalStateException("Selected APK is empty.");
        }catch(Exception e){
            partial.delete();
            status.setText("Copy failed: "+safe(e));
            return;
        }
        if(staged.exists()&&!staged.delete()){partial.delete();status.setText("Cannot replace previous candidate.");return;}
        if(!partial.renameTo(staged)){partial.delete();status.setText("Cannot finalize candidate.");return;}

        ApkVerifier.Result r=ApkVerifier.verifySelfUpdate(this,staged);
        verified=r.ok;
        installButton().setEnabled(verified);
        status.setText(r.message+(verified?"\nReady for Android system confirmation.":"\nUpdate rejected."));
    }

    private void install(){
        if(!verified){status.setText("No verified candidate is ready.");return;}

        ApkVerifier.Result finalCheck=ApkVerifier.verifySelfUpdate(this,staged);
        if(!finalCheck.ok){
            verified=false;
            installButton().setEnabled(false);
            status.setText("Final APK verification failed. Install blocked.\n"+finalCheck.message);
            return;
        }

        String archive=VersionArchiveManager.beforeInstall(this,finalCheck.versionCode);
        if(!archive.startsWith("Old version ")){
            status.setText("Update blocked because current version could not be archived safely.\n"+archive);
            return;
        }

        if(!AndroidCompat.canRequestPackageInstalls(this)){
            status.setText(archive+"\n\nEnable “Install unknown apps” for Anamika first.");
            openPermission();
            return;
        }
        PackageInstaller installer=getPackageManager().getPackageInstaller();
        PackageInstaller.Session session=null;
        try{
            PackageInstaller.SessionParams params=new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
            params.setAppPackageName(getPackageName());
            int id=installer.createSession(params);
            session=installer.openSession(id);
            try(InputStream in=new FileInputStream(staged); OutputStream out=session.openWrite("base.apk",0,staged.length())){
                byte[] buf=new byte[128*1024]; int n;
                while((n=in.read(buf))>0)out.write(buf,0,n);
                session.fsync(out);
            }
            Intent callback=new Intent(this,SelfUpdateActivity.class)
                    .setAction(RESULT_ACTION)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pi=PendingIntent.getActivity(this,id,callback,
                    AndroidCompat.mutablePendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT));
            session.commit(pi.getIntentSender());
            status.setText(archive+"\n\nUpdate handed to Android. Complete the system confirmation. Old version archive automatic delete nahi hoga.");
        }catch(Exception e){
            status.setText("Install request failed: "+safe(e));
            if(session!=null)try{session.abandon();}catch(Exception ignored){}
        }finally{
            if(session!=null)session.close();
        }
    }

    private void handleInstallResult(Intent intent){
        if(intent==null||!RESULT_ACTION.equals(intent.getAction()))return;
        int result=intent.getIntExtra(PackageInstaller.EXTRA_STATUS,PackageInstaller.STATUS_FAILURE);
        if(result==PackageInstaller.STATUS_PENDING_USER_ACTION){
            Intent confirm=intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if(confirm!=null)startActivity(confirm);
        }else if(result==PackageInstaller.STATUS_SUCCESS){
            status.setText("Anamika update installed successfully. Next launches par post-update source/regression verification chalegi. Purana version owner command ke bina delete nahi hoga.");
        }else{
            status.setText("Update failed/cancelled. Status="+result+"\n"+intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE));
        }
    }

    private void openPermission(){
        try{
            startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+getPackageName())));
        }catch(Exception e){
            startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS));
        }
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private static String safe(Exception e){String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;}
}
