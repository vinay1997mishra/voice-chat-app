package com.anamika.ai.plugins;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.ColorSpace;
import android.graphics.Rect;
import android.hardware.HardwareBuffer;
import android.os.Build;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedWriter;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Records owner-authorized, observable UI structure for later original reimplementation. */
public final class AppBlueprintStore {
    private static final String PREFS="anamika_blueprints";
    private static final String ACTIVE="active";
    private static final String TARGET="target";
    private static final String SESSION="session";
    private static final String LAST="last_blueprint";
    private static final String LAST_SHOT="last_shot_ms";

    private AppBlueprintStore() {}

    public static File start(Context c,String packageName){
        String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date());
        File base=c.getExternalFilesDir(null);
        if(base==null) base=c.getFilesDir();
        File root=new File(base,"blueprints/"+safeName(packageName)+"_"+stamp);
        if(!root.exists() && !root.mkdirs()) throw new IllegalStateException("Cannot create blueprint folder");
        c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit()
                .putBoolean(ACTIVE,true).putString(TARGET,packageName).putString(SESSION,root.getAbsolutePath()).apply();
        writeText(new File(root,"session.json"),"{\"package\":"+quote(packageName)+",\"started\":"+System.currentTimeMillis()+"}");
        return root;
    }

    public static File stop(Context c){
        android.content.SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        String path=p.getString(SESSION,"");
        p.edit().putBoolean(ACTIVE,false).putString(LAST,path).remove(SESSION).apply();
        if(path.isEmpty()) return null;
        File root=new File(path);
        writeText(new File(root,"completed.txt"),"Inspection completed at "+new Date()+"\nObservable UI only; passwords/private source/server logic are not captured.\n");
        return root;
    }

    public static boolean isActive(Context c,String pkg){
        android.content.SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        return p.getBoolean(ACTIVE,false)&&pkg!=null&&pkg.equals(p.getString(TARGET,""));
    }

    public static String currentTarget(Context c){ return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(TARGET,""); }
    public static String latestPath(Context c){ return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(LAST,""); }

    public static void record(Context c, AccessibilityEvent event, AccessibilityNodeInfo root){
        if(root==null||event==null||event.getPackageName()==null) return;
        String pkg=event.getPackageName().toString(); if(!isActive(c,pkg)) return;
        String dir=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(SESSION,""); if(dir.isEmpty()) return;
        try{
            JSONObject screen=new JSONObject();
            screen.put("time",System.currentTimeMillis());
            screen.put("package",pkg);
            screen.put("event_type",AccessibilityEvent.eventTypeToString(event.getEventType()));
            screen.put("class",String.valueOf(event.getClassName()));
            screen.put("source_text",event.isPassword()?new JSONArray().put("<password-redacted>"):
                    (event.getText()==null?new JSONArray():new JSONArray(event.getText())));
            JSONArray nodes=new JSONArray(); flatten(root,nodes,0); screen.put("nodes",nodes);
            appendLine(new File(dir,"screens.jsonl"),screen.toString());
        }catch(Exception ignored){}
    }

    public static void recordUserAction(Context c,String pkg,String command){
        if(!isActive(c,pkg)) return;
        String dir=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(SESSION,""); if(dir.isEmpty()) return;
        try{
            JSONObject o=new JSONObject();
            o.put("time",System.currentTimeMillis());
            o.put("command",redactTypedValue(command));
            o.put("package",pkg);
            appendLine(new File(dir,"actions.jsonl"),o.toString());
        }catch(Exception ignored){}
    }

    /** Records decisions/results made by the owner-authorized automatic UI audit. */
    public static void recordAuditResult(Context c,String pkg,String state,String label,String detail){
        if(!isActive(c,pkg)) return;
        String dir=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(SESSION,""); if(dir.isEmpty()) return;
        try{
            JSONObject o=new JSONObject();
            o.put("time",System.currentTimeMillis());
            o.put("package",pkg==null?"":pkg);
            o.put("state",state==null?"":state);
            o.put("label",label==null?"":label);
            o.put("detail",detail==null?"":detail);
            appendLine(new File(dir,"auto_audit.jsonl"),o.toString());
        }catch(Exception ignored){}
    }

    /** Seals the blueprint and writes a human-readable automatic audit summary. */
    public static File completeAutoAudit(Context c,int tested,int skipped,int screens,String reason){
        android.content.SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        String path=p.getString(SESSION,"");
        if(!path.isEmpty()){
            String text="Anamika Automatic App Audit\n"+
                    "Completed: "+new Date()+"\n"+
                    "Safe controls/touch zones tested: "+tested+"\n"+
                    "Sensitive/destructive/unknown controls skipped: "+skipped+"\n"+
                    "Observable screens sampled: "+screens+"\n"+
                    "Reason: "+(reason==null?"completed":reason)+"\n"+
                    "Note: passwords, payment, messaging, account changes, destructive actions and OS permission grants are not auto-executed.\n";
            writeText(new File(path,"AUTO_AUDIT_REPORT.txt"),text);
            writeFunctionBlueprint(new File(path));
        }
        return stop(c);
    }

    private static void writeFunctionBlueprint(File root){
        File audit=new File(root,"auto_audit.jsonl");
        if(!audit.isFile()) return;
        StringBuilder out=new StringBuilder();
        out.append("ANAMIKA APP BLUEPRINT — FUNCTION BY FUNCTION\n");
        out.append("Generated from owner-authorized observable UI audit.\n");
        out.append("This explains observed controls/screens; private server logic or hidden source code cannot be inferred.\n\n");
        int n=0;
        try(BufferedReader r=new BufferedReader(new FileReader(audit))){
            String line;
            while((line=r.readLine())!=null){
                try{
                    JSONObject o=new JSONObject(line);
                    String state=o.optString("state","");
                    String label=o.optString("label","");
                    String detail=o.optString("detail","");
                    if("TRY_TAP".equals(state) || "TRY_TOUCH".equals(state)){
                        n++;
                        out.append("FUNCTION ").append(n).append(": ")
                                .append(label.isEmpty()?"<unlabelled>":label).append("\n");
                        out.append("  Test: ").append("TRY_TOUCH".equals(state)
                                ?"Anamika used a direct gesture touch on this safe touch zone.\n"
                                :"Anamika tapped this visible safe accessibility control.\n");
                    } else if("RESULT".equals(state)){
                        out.append("  Observed result: ").append(detail).append("\n\n");
                    } else if("SCROLL".equals(state)){
                        out.append("NAVIGATION: Scroll ").append(label).append(" — ").append(detail).append("\n");
                    } else if("BACK".equals(state)){
                        out.append("NAVIGATION: Back — ").append(detail).append("\n");
                    } else if("SKIPPED".equals(state) || "SKIP_EXTERNAL".equals(state)){
                        out.append("SKIPPED CONTROL: ").append(label.isEmpty()?"<unknown>":label)
                                .append(" — ").append(detail).append("\n");
                    } else if("FAILED_TAP".equals(state) || "FAILED_TOUCH".equals(state)){
                        out.append("FAILED CONTROL: ").append(label).append(" — ").append(detail).append("\n");
                    } else if("SUMMARY".equals(state)){
                        out.append("AUDIT SUMMARY: ").append(label).append(" — ").append(detail).append("\n");
                    }
                }catch(Exception ignored){}
            }
        }catch(Exception ignored){ return; }
        out.append("\nTotal safe functions attempted: ").append(n).append("\n");
        writeText(new File(root,"BLUEPRINT_FUNCTIONS.txt"),out.toString());
    }

    public static boolean shouldCaptureScreenshot(Context c){
        long now=System.currentTimeMillis(); android.content.SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        long last=p.getLong(LAST_SHOT,0L); if(now-last<1500L) return false; p.edit().putLong(LAST_SHOT,now).apply(); return true;
    }

    public static boolean containsPasswordField(AccessibilityNodeInfo root){
        return containsPasswordField(root,0);
    }

    private static boolean containsPasswordField(AccessibilityNodeInfo n,int depth){
        if(n==null||depth>35) return false;
        if(n.isPassword()) return true;
        for(int i=0;i<n.getChildCount();i++) if(containsPasswordField(n.getChild(i),depth+1)) return true;
        return false;
    }

    public static void saveScreenshot(Context c, android.accessibilityservice.AccessibilityService.ScreenshotResult result){
        String dir=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(SESSION,""); if(dir.isEmpty()||result==null) return;
        if(Build.VERSION.SDK_INT<30) return;
        HardwareBuffer hb=result.getHardwareBuffer(); ColorSpace cs=result.getColorSpace();
        if(hb==null||cs==null) return;
        Bitmap hw=null,copy=null;
        try{
            hw=Bitmap.wrapHardwareBuffer(hb,cs); if(hw==null) return;
            copy=hw.copy(Bitmap.Config.ARGB_8888,false);
            File shots=new File(dir,"screenshots"); if(!shots.exists() && !shots.mkdirs()) return;
            File out=new File(shots,"screen_"+System.currentTimeMillis()+".png");
            try(FileOutputStream fos=new FileOutputStream(out)){ copy.compress(Bitmap.CompressFormat.PNG,100,fos); }
        }catch(Exception ignored){} finally{
            if(copy!=null) copy.recycle(); if(hw!=null) hw.recycle(); try{hb.close();}catch(Exception ignored){}
        }
    }

    public static String latestSummary(Context c,int maxChars){
        String path=latestPath(c); if(path.isEmpty()||maxChars<=0) return "";
        String screens=tail(new File(path,"screens.jsonl"),Math.max(1,(maxChars*3)/4));
        String actions=tail(new File(path,"actions.jsonl"),Math.max(1,maxChars/5));
        String audit=tail(new File(path,"auto_audit.jsonl"),Math.max(1,maxChars/5));
        if(screens.isEmpty()&&actions.isEmpty()&&audit.isEmpty()) return "";
        String result="LATEST APP BLUEPRINT (observable UI/actions; passwords redacted):\nSCREENS:\n"+screens+"\nACTIONS:\n"+actions+"\nAUTO AUDIT:\n"+audit;
        if(result.length()>maxChars) result=result.substring(result.length()-maxChars);
        return result;
    }

    private static void flatten(AccessibilityNodeInfo n,JSONArray out,int depth)throws Exception{
        if(n==null||depth>35||out.length()>1800) return;
        JSONObject o=new JSONObject(); Rect b=new Rect(); n.getBoundsInScreen(b);
        boolean password=n.isPassword();
        o.put("class",safe(n.getClassName()));
        o.put("text",password?"<password-redacted>":safe(n.getText()));
        o.put("description",password?"":safe(n.getContentDescription()));
        o.put("hint",password?"":safe(n.getHintText()));
        o.put("password",password);
        o.put("view_id",safe(n.getViewIdResourceName())); o.put("clickable",n.isClickable()); o.put("editable",n.isEditable());
        o.put("scrollable",n.isScrollable()); o.put("enabled",n.isEnabled()); o.put("checked",n.isChecked()); o.put("selected",n.isSelected());
        o.put("bounds",b.flattenToString()); o.put("child_count",n.getChildCount());
        JSONArray acts=new JSONArray(); for(AccessibilityNodeInfo.AccessibilityAction a:n.getActionList()) acts.put(a.getId()); o.put("actions",acts);
        out.put(o); for(int i=0;i<n.getChildCount();i++) flatten(n.getChild(i),out,depth+1);
    }

    private static String redactTypedValue(String command){
        if(command==null) return "";
        String lower=command.trim().toLowerCase(Locale.ROOT);
        String[] prefixes={"type ","write ","likho ","लिखो ","enter "};
        for(String p:prefixes) if(lower.startsWith(p)) return command.substring(0,Math.min(command.length(),p.length()))+"<typed-text-redacted>";
        return command;
    }

    private static String tail(File f,int maxChars){
        if(!f.isFile()) return "";
        try{
            byte[] data=java.nio.file.Files.readAllBytes(f.toPath()); String s=new String(data,StandardCharsets.UTF_8);
            return s.length()>maxChars?s.substring(s.length()-maxChars):s;
        }catch(Exception e){return "";}
    }
    private static String safeName(String s){return (s==null?"app":s).replaceAll("[^A-Za-z0-9._-]","_");}
    private static String safe(CharSequence s){return s==null?"":s.toString();}
    private static String safe(String s){return s==null?"":s;}
    private static String quote(String s){return JSONObject.quote(s==null?"":s);}
    private static void appendLine(File f,String line)throws Exception{ File p=f.getParentFile(); if(p!=null&&!p.exists()&&!p.mkdirs())throw new IllegalStateException("Cannot create blueprint folder"); try(BufferedWriter w=new BufferedWriter(new FileWriter(f,true))){w.write(line);w.newLine();} }
    private static void writeText(File f,String text){try{File p=f.getParentFile();if(p!=null&&!p.exists()&&!p.mkdirs())return;try(FileOutputStream o=new FileOutputStream(f)){o.write(text.getBytes(StandardCharsets.UTF_8));}}catch(Exception ignored){}}
}
