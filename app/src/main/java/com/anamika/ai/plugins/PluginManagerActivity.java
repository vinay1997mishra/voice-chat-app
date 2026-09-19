package com.anamika.ai.plugins;

import android.app.Activity;
import android.content.Intent;
import android.content.ComponentName;
import android.text.TextUtils;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.anamika.ai.R;
import com.anamika.ai.OwnerSession;

import java.util.List;

public final class PluginManagerActivity extends Activity {
    private LinearLayout pluginList;
    private EditText commandInput;
    private TextView selectedView;
    private TextView inspectionStatus;
    private String selectedPackage = "";
    private String selectedLabel = "";

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_plugin_manager);
        if(!OwnerSession.isActive(this)){ toast("Owner session expired. Verify PIN in Anamika first."); finish(); return; }
        pluginList=findViewById(R.id.pluginList);
        commandInput=findViewById(R.id.pluginCommand);
        selectedView=findViewById(R.id.selectedPlugin);
        inspectionStatus=findViewById(R.id.inspectionStatus);
        Button accessibility=findViewById(R.id.accessibilityButton);
        CheckBox consent=findViewById(R.id.accessibilityConsent);
        Button run=findViewById(R.id.runPluginCommand);
        Button refresh=findViewById(R.id.refreshPlugins);
        Button startInspection=findViewById(R.id.startInspection);
        Button stopInspection=findViewById(R.id.stopInspection);
        accessibility.setOnClickListener(v -> {
            if(!consent.isChecked()){ toast("Please read and accept the App Control disclosure first"); return; }
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
        });
        refresh.setOnClickListener(v -> populate());
        startInspection.setOnClickListener(v -> startInspection());
        stopInspection.setOnClickListener(v -> stopInspection());
        run.setOnClickListener(v -> runSelected());
        populate();
        String last=AppBlueprintStore.latestPath(this);
        if(!last.isEmpty()) inspectionStatus.setText("Latest blueprint: "+last);
    }

    private void populate() {
        pluginList.removeAllViews();
        List<PluginRegistry.AppPlugin> apps=PluginRegistry.discover(this);
        for(PluginRegistry.AppPlugin app:apps) {
            LinearLayout row=new LinearLayout(this); row.setOrientation(LinearLayout.VERTICAL);
            row.setPadding(8,10,8,10);
            CheckBox enabled=new CheckBox(this);
            enabled.setText(app.label+"\n"+app.packageName);
            enabled.setChecked(app.enabled);
            enabled.setOnCheckedChangeListener((b,checked) -> PluginRegistry.setEnabled(this,app.packageName,checked));
            Button select=new Button(this); select.setText("Select "+app.label);
            select.setOnClickListener(v -> { selectedPackage=app.packageName; selectedLabel=app.label;
                selectedView.setText("Selected: "+app.label+" ("+app.packageName+")"); });
            row.addView(enabled); row.addView(select); pluginList.addView(row);
        }
        if(apps.isEmpty()) {
            TextView empty=new TextView(this); empty.setText("No launchable apps were visible. Refresh after installing apps."); pluginList.addView(empty);
        }
    }

    private void runSelected() {
        if(!OwnerSession.isActive(this)){ toast("Owner session expired. Verify PIN again."); finish(); return; }
        if(selectedPackage.isEmpty()) { toast("Select an app first"); return; }
        if(!PluginRegistry.isEnabled(this,selectedPackage)) { toast(selectedLabel+" is not owner-enabled. No control action was performed."); return; }
        if(!isAutomationServiceEnabled()){ toast("Anamika App Control service is off. No control action was performed."); return; }
        String result=AppPluginEngine.openAndRun(this,selectedPackage,commandInput.getText().toString().trim());
        toast(result);
    }

    private void startInspection(){
        if(!OwnerSession.isActive(this)){ toast("Owner session expired. Verify PIN again."); finish(); return; }
        if(selectedPackage.isEmpty()){ toast("Select an app first"); return; }
        if(!PluginRegistry.isEnabled(this,selectedPackage)){ toast(selectedLabel+" is not owner-enabled. Audit was not started."); return; }
        if(!isAutomationServiceEnabled()){ toast("Anamika App Control service is off. Audit was not started."); return; }
        String result=AppPluginEngine.openAndRun(this,selectedPackage,"check all functions");
        inspectionStatus.setText("Automatic audit requested for "+selectedLabel+
                ". Anamika will inspect visible screens and operate safe controls automatically. "+
                "Sensitive/destructive/financial/account actions are skipped and listed in the blueprint.\n"+result);
    }

    private void stopInspection(){
        java.io.File dir=AppBlueprintStore.stop(this);
        inspectionStatus.setText(dir==null?"Inspection stopped.":"Blueprint saved: "+dir.getAbsolutePath());
    }


    private boolean isAutomationServiceEnabled(){
        String enabled=Settings.Secure.getString(getContentResolver(),Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if(TextUtils.isEmpty(enabled)) return false;
        String expected=new ComponentName(this,AppAutomationAccessibilityService.class).flattenToString();
        TextUtils.SimpleStringSplitter splitter=new TextUtils.SimpleStringSplitter(':');
        splitter.setString(enabled);
        while(splitter.hasNext()) if(expected.equalsIgnoreCase(splitter.next())) return true;
        return false;
    }

    private void toast(String s){ Toast.makeText(this,s,Toast.LENGTH_LONG).show(); }
}
