package com.anamika.ai.plugins;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.core.OwnerStore;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Simple owner-controlled package allow-list. */
public final class PluginManagerActivity extends Activity {
    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        if(!OwnerStore.isTrusted(this)){finish();return;}
        build();
    }

    private void build(){
        LinearLayout box=new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(14),dp(14),dp(14),dp(14));

        TextView title=new TextView(this);title.setText("Anamika 13 • Plugin Center");title.setTextSize(22);box.addView(title);
        TextView note=new TextView(this);note.setText("Only apps you enable here may receive Accessibility automation commands.");box.addView(note);
        Button access=new Button(this);access.setText("Open Accessibility Settings");box.addView(access);
        access.setOnClickListener(v->startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));

        PackageManager pm=getPackageManager();
        List<ApplicationInfo> apps;
        if(Build.VERSION.SDK_INT>=33)apps=pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0));
        else apps=pm.getInstalledApplications(0);
        List<ApplicationInfo> launchable=new ArrayList<>();
        for(ApplicationInfo a:apps)if(pm.getLaunchIntentForPackage(a.packageName)!=null && !a.packageName.equals(getPackageName()))launchable.add(a);
        launchable.sort(Comparator.comparing(a->String.valueOf(pm.getApplicationLabel(a)),String.CASE_INSENSITIVE_ORDER));

        for(ApplicationInfo a:launchable){
            CheckBox cb=new CheckBox(this);
            cb.setText(pm.getApplicationLabel(a)+"\n"+a.packageName);
            cb.setChecked(AppPluginRegistry.isEnabled(this,a.packageName));
            cb.setOnCheckedChangeListener((v,on)->AppPluginRegistry.setEnabled(this,a.packageName,on));
            box.addView(cb);
        }
        ScrollView scroll=new ScrollView(this);scroll.addView(box);setContentView(scroll);
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
}
