package com.anamika.ai.plugins;

import android.accessibilityservice.AccessibilityService;
import android.os.Bundle;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Button;
import android.view.View;
import android.os.Handler;
import android.os.Looper;
import android.os.Build;
import android.view.Display;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import com.anamika.ai.research.ResearchLearningStore;
import com.anamika.ai.OwnerSession;

/**
 * User-enabled UI assistant for explicitly enabled app plugins.
 * It only acts on the package selected by the owner in Plugin Center.
 */
public final class AppAutomationAccessibilityService extends AccessibilityService {
    private static final String PREFS = "anamika_automation";
    private static final String TARGET = "target_package";
    private static final String COMMAND = "pending_command";
    private static final String TOKEN = "pending_token";
    private static volatile AppAutomationAccessibilityService instance;
    private String lastToken = "";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private Button voiceBubble;


    @Override public void onServiceConnected() {
        super.onServiceConnected();
        instance=this;
        windowManager=(WindowManager)getSystemService(WINDOW_SERVICE);
        voiceBubble=new Button(this);
        voiceBubble.setText("A");
        voiceBubble.setTextSize(18f);
        voiceBubble.setVisibility(View.GONE);
        voiceBubble.setOnClickListener(v -> {
            Intent i=new Intent(this,VoiceCommandActivity.class);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_NO_ANIMATION);
            startActivity(i);
        });
        WindowManager.LayoutParams lp=new WindowManager.LayoutParams(
                dp(56),dp(56),WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        lp.gravity=Gravity.END|Gravity.CENTER_VERTICAL;
        lp.x=12;
        try{ windowManager.addView(voiceBubble,lp); }catch(Exception ignored){}
    }

    @Override public void onDestroy(){
        if(instance==this) instance=null;
        if(windowManager!=null && voiceBubble!=null){ try{windowManager.removeView(voiceBubble);}catch(Exception ignored){} }
        super.onDestroy();
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null || event.getPackageName() == null) return;
        String target = getSharedPreferences(PREFS, MODE_PRIVATE).getString(TARGET, "");
        String command = getSharedPreferences(PREFS, MODE_PRIVATE).getString(COMMAND, "");
        String token = getSharedPreferences(PREFS, MODE_PRIVATE).getString(TOKEN, "");
        String currentPkg = event.getPackageName().toString();
        ResearchLearningStore.capture(this, event);
        boolean currentEnabled = PluginRegistry.isEnabled(this,currentPkg);
        AccessibilityNodeInfo activeRoot = getRootInActiveWindow();
        if (AppBlueprintStore.isActive(this,currentPkg) && activeRoot != null) {
            AppBlueprintStore.record(this,event,activeRoot);
            if (Build.VERSION.SDK_INT >= 30 && !AppBlueprintStore.containsPasswordField(activeRoot) && AppBlueprintStore.shouldCaptureScreenshot(this)) {
                takeScreenshot(Display.DEFAULT_DISPLAY,getMainExecutor(),new TakeScreenshotCallback(){
                    @Override public void onSuccess(ScreenshotResult result){ AppBlueprintStore.saveScreenshot(AppAutomationAccessibilityService.this,result); }
                    @Override public void onFailure(int errorCode) { }
                });
            }
        }
        if (voiceBubble != null) voiceBubble.setVisibility(currentEnabled && OwnerSession.isActive(this) ? View.VISIBLE : View.GONE);
        if (currentEnabled && !currentPkg.equals(getPackageName())) {
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().putString(TARGET,currentPkg).apply();
            target=currentPkg;
        }
        if (target.isEmpty() || command.isEmpty() || token.isEmpty()) return;
        if (!OwnerSession.isActive(this)) { clearPending(token); return; }
        if (!target.equals(currentPkg) || token.equals(lastToken)) return;
        if (!PluginRegistry.isEnabled(this, target)) return;

        lastToken = token;
        handler.postDelayed(() -> {
            try { executeNaturalCommand(command); } finally { clearPending(token); }
        }, 250L);
    }

    @Override public void onInterrupt() { }

    private void executeNaturalCommand(String raw) {
        String normalized = raw.trim();
        if (normalized.isEmpty()) return;
        String target = getSharedPreferences(PREFS, MODE_PRIVATE).getString(TARGET, "");
        String lowerCommand = normalized.toLowerCase(Locale.ROOT);
        if (containsAny(lowerCommand,"saare functions check kar","sare functions check kar","check all functions","deep inspect app","app inspect karo")) {
            if (!target.isEmpty() && PluginRegistry.isEnabled(this,target)) {
                AppBlueprintStore.start(this,target);
                AccessibilityNodeInfo root=getRootInActiveWindow();
                if(root!=null){
                    AccessibilityEvent fake=AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
                    fake.setPackageName(target); fake.setClassName("OwnerRequestedDeepInspection");
                    AppBlueprintStore.record(this,fake,root); fake.recycle();
                }
            }
            return;
        }
        if (containsAny(lowerCommand,"inspection complete","inspection stop","function check complete","scan complete")) {
            AppBlueprintStore.stop(this); return;
        }
        if (!target.isEmpty()) AppBlueprintStore.recordUserAction(this,target,normalized);
        String[] steps = normalized.split("(?i)\\s+(?:then|and then|phir|fir|uske baad|फिर)\\s+");
        long delay = 0L;
        for (String step : steps) {
            final String action = step.trim();
            handler.postDelayed(() -> executeStep(action), delay);
            delay += 700L;
        }
    }

    private void executeStep(String raw) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return;
        String lower = raw.toLowerCase(Locale.ROOT).trim();

        if (containsAny(lower, "go back", "back", "wapas", "वापस")) {
            performGlobalAction(GLOBAL_ACTION_BACK); return;
        }
        if (containsAny(lower, "home screen", "go home", "होम")) {
            performGlobalAction(GLOBAL_ACTION_HOME); return;
        }
        if (containsAny(lower, "scroll down", "neeche scroll", "नीचे स्क्रॉल")) {
            if (!scroll(root, AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)) dispatchVerticalSwipe(true); return;
        }
        if (containsAny(lower, "scroll up", "upar scroll", "ऊपर स्क्रॉल")) {
            if (!scroll(root, AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)) dispatchVerticalSwipe(false); return;
        }

        String value = afterPrefix(raw, "type ", "write ", "likho ", "लिखो ", "enter ");
        if (value != null) { typeText(root, value); return; }

        String target = afterPrefix(raw, "tap ", "click ", "press ", "touch ", "dabao ", "दबाओ ");
        if (target != null) { clickText(root, target); return; }

        if (lower.startsWith("search ")) {
            if (clickText(root, "Search") || clickText(root, "खोजें")) {
                final String q = raw.substring(7).trim();
                handler.postDelayed(() -> {
                    AccessibilityNodeInfo fresh = getRootInActiveWindow();
                    if (fresh != null) typeText(fresh, q);
                }, 450L);
            }
            return;
        }

        // Natural fallback: try to click a visible element whose label resembles the command.
        clickText(root, raw);
    }

    private boolean clickText(AccessibilityNodeInfo root, String text) {
        List<AccessibilityNodeInfo> exact = root.findAccessibilityNodeInfosByText(text);
        for (AccessibilityNodeInfo n : exact) if (clickNodeOrParent(n)) return true;
        String needle = text.toLowerCase(Locale.ROOT);
        for (AccessibilityNodeInfo n : flatten(root)) {
            CharSequence label = n.getText() != null ? n.getText() : n.getContentDescription();
            if (label != null && label.toString().toLowerCase(Locale.ROOT).contains(needle)) {
                if (clickNodeOrParent(n)) return true;
            }
        }
        return false;
    }

    private boolean clickNodeOrParent(AccessibilityNodeInfo node) {
        AccessibilityNodeInfo n = node;
        for (int i=0;i<5 && n!=null;i++) {
            if (n.isClickable() && n.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true;
            n = n.getParent();
        }
        return false;
    }

    private boolean typeText(AccessibilityNodeInfo root, String text) {
        AccessibilityNodeInfo focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
        if (focused != null && focused.isEditable()) return setText(focused,text);
        for (AccessibilityNodeInfo n : flatten(root)) if (n.isEditable()) return setText(n,text);
        return false;
    }

    private boolean setText(AccessibilityNodeInfo node, String text) {
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        Bundle args = new Bundle();
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text);
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,args);
    }

    private boolean scroll(AccessibilityNodeInfo root, int action) {
        for (AccessibilityNodeInfo n : flatten(root)) if (n.isScrollable() && n.performAction(action)) return true;
        return false;
    }


    /** Delivers a normalized owner command immediately when the enabled target app is active; otherwise queues it for the next accessibility event. */
    public static void submitCommand(android.content.Context context,String target,String command){
        if(context==null||target==null||target.isEmpty()||command==null||command.trim().isEmpty()) return;
        if(!OwnerSession.isActive(context)) return;
        String token=java.util.UUID.randomUUID().toString();
        context.getSharedPreferences(PREFS,android.content.Context.MODE_PRIVATE).edit()
                .putString(TARGET,target).putString(COMMAND,command.trim()).putString(TOKEN,token).apply();
        AppAutomationAccessibilityService svc=instance;
        if(svc!=null && PluginRegistry.isEnabled(svc,target)){
            svc.handler.post(() -> {
                AccessibilityNodeInfo root=svc.getRootInActiveWindow();
                CharSequence pkg=root==null?null:root.getPackageName();
                if(pkg!=null && target.equals(pkg.toString())){
                    svc.lastToken=token;
                    try { svc.executeNaturalCommand(command.trim()); } finally { svc.clearPending(token); }
                }
            });
        }
    }

    private void clearPending(String token){
        String current=getSharedPreferences(PREFS,MODE_PRIVATE).getString(TOKEN,"");
        if(token!=null && token.equals(current)){
            getSharedPreferences(PREFS,MODE_PRIVATE).edit().remove(COMMAND).remove(TOKEN).apply();
        }
    }

    private void dispatchVerticalSwipe(boolean down){
        android.util.DisplayMetrics dm=getResources().getDisplayMetrics();
        float x=dm.widthPixels*0.5f;
        float high=dm.heightPixels*0.28f;
        float low=dm.heightPixels*0.78f;
        if(down) dispatchSwipe(x,low,x,high); else dispatchSwipe(x,high,x,low);
    }

    private void dispatchSwipe(float x1,float y1,float x2,float y2) {
        android.graphics.Path p = new android.graphics.Path(); p.moveTo(x1,y1); p.lineTo(x2,y2);
        android.accessibilityservice.GestureDescription.StrokeDescription stroke =
                new android.accessibilityservice.GestureDescription.StrokeDescription(p,0,350);
        dispatchGesture(new android.accessibilityservice.GestureDescription.Builder().addStroke(stroke).build(),null,null);
    }

    private List<AccessibilityNodeInfo> flatten(AccessibilityNodeInfo root) {
        List<AccessibilityNodeInfo> out = new ArrayList<>();
        walk(root,out,0); return out;
    }
    private void walk(AccessibilityNodeInfo n,List<AccessibilityNodeInfo> out,int depth) {
        if(n==null || depth>40 || out.size()>2500) return; out.add(n);
        for(int i=0;i<n.getChildCount();i++) walk(n.getChild(i),out,depth+1);
    }
    private int dp(int value){ return Math.round(value*getResources().getDisplayMetrics().density); }

    private static boolean containsAny(String text,String... terms){ for(String t:terms) if(text.equals(t)||text.contains(t)) return true; return false; }
    private static String afterPrefix(String raw,String... prefixes){
        String lower=raw.toLowerCase(Locale.ROOT);
        for(String p:prefixes) if(lower.startsWith(p)) return raw.substring(p.length()).trim();
        return null;
    }
}
