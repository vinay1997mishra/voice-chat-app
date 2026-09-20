package com.anamika.ai.plugins;

import android.accessibilityservice.AccessibilityService;
import android.os.Bundle;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;
import android.widget.LinearLayout;
import android.view.View;
import android.os.Handler;
import android.os.Looper;
import android.os.Build;
import android.view.Display;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
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
    private static final String ONE_SHOT = "one_shot_owner_command";
    private static volatile AppAutomationAccessibilityService instance;
    private String lastToken = "";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private Button voiceBubble;
    private LinearLayout auditOverlay;
    private TextView auditOverlayText;
    private Button auditAllowOnce;
    private Button auditSkipRisk;
    private boolean waitingRiskConfirmation = false;
    private String pendingRiskLabel = "";
    private String pendingRiskFingerprint = "";
    private String pendingRiskSourceScreenSig = "";
    private final android.graphics.Rect pendingRiskBounds = new android.graphics.Rect();

    // Owner-commanded automatic app audit state. Bounded and intentionally skips risky actions.
    private boolean autoAuditActive = false;
    private String autoAuditTarget = "";
    private long autoAuditStartedMs = 0L;
    private int autoAuditTested = 0;
    private int autoAuditSkipped = 0;
    private int autoAuditScreens = 0;
    private int autoAuditDepth = 0;
    private static final int AUTO_AUDIT_MAX_ACTIONS = 2000;
    private static final int AUTO_AUDIT_MAX_DEPTH = 60;
    private static final long AUTO_AUDIT_MAX_MS = 1_800_000L;
    private final Set<String> autoAuditNodes = new HashSet<>();
    private final Set<String> autoAuditScreensSeen = new HashSet<>();
    private final Set<String> autoAuditScrolled = new HashSet<>();
    private final Set<String> autoAuditTouchZones = new HashSet<>();
    private int autoAuditGestureTaps = 0;
    private String lastAuditActionLabel = "";
    private String lastAuditSourceScreenSig = "";


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
        createAuditOverlay();
    }

    @Override public void onDestroy(){
        if(instance==this) instance=null;
        handler.removeCallbacksAndMessages(null);
        autoAuditActive=false;
        if(windowManager!=null && voiceBubble!=null){ try{windowManager.removeView(voiceBubble);}catch(Exception ignored){} }
        if(windowManager!=null && auditOverlay!=null){ try{windowManager.removeView(auditOverlay);}catch(Exception ignored){} }
        super.onDestroy();
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null || event.getPackageName() == null) return;
        String target = getSharedPreferences(PREFS, MODE_PRIVATE).getString(TARGET, "");
        String command = getSharedPreferences(PREFS, MODE_PRIVATE).getString(COMMAND, "");
        String token = getSharedPreferences(PREFS, MODE_PRIVATE).getString(TOKEN, "");
        boolean oneShot = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(ONE_SHOT,false);
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
        if (!oneShot && !PluginRegistry.isEnabled(this,target)) return;

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
        if(normalized.startsWith("whatsapp-message|")){
            String[] parts=normalized.split("\\|",3);
            if(parts.length==3) performWhatsAppMessage(parts[1],parts[2]);
            return;
        }
        if (containsAny(lowerCommand,
                "saare functions check kar","sare functions check kar","check all functions",
                "is app ke saare functions check kar","is app ke sare functions check kar",
                "deep inspect app","app inspect karo","auto audit app","poora app check karo")) {
            if (!target.isEmpty() && PluginRegistry.isEnabled(this,target)) startAutoAudit(target);
            return;
        }
        if (containsAny(lowerCommand,"inspection complete","inspection stop","function check complete","scan complete","audit stop")) {
            if(autoAuditActive) finishAutoAudit("Owner stopped the automatic audit.");
            else AppBlueprintStore.stop(this);
            return;
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

    private void startAutoAudit(String target) {
        if (target == null || target.trim().isEmpty() || !PluginRegistry.isEnabled(this,target)) return;
        autoAuditActive = false;
        autoAuditNodes.clear();
        autoAuditScreensSeen.clear();
        autoAuditScrolled.clear();
        autoAuditTouchZones.clear();
        autoAuditGestureTaps = 0;
        autoAuditTarget = target;
        autoAuditStartedMs = System.currentTimeMillis();
        autoAuditTested = 0;
        autoAuditSkipped = 0;
        autoAuditScreens = 0;
        autoAuditDepth = 0;
        lastAuditSourceScreenSig = "";
        java.io.File dir = AppBlueprintStore.start(this,target);
        boolean learnedAlready = PluginRegistry.isDeepAuditTrusted(this,target);
        PluginRegistry.setDeepAuditTrusted(this,target,true);
        AppBlueprintStore.recordAuditResult(this,target,"START","",
                "Owner requested automatic deep function audit. Persistent safe-touch trust="+
                        (learnedAlready?"reused":"granted")+". Blueprint: "+dir.getAbsolutePath());
        autoAuditActive = true;
        waitingRiskConfirmation=false;
        showAuditStatus("Starting deep audit", "Opening app map and learning safe paths…");
        android.widget.Toast.makeText(this,
                learnedAlready
                        ? "Anamika Deep Audit started with learned safe-touch permission."
                        : "Anamika Deep Audit started. Safe-touch permission will be remembered for this enabled app.",
                android.widget.Toast.LENGTH_LONG).show();
        handler.postDelayed(this::auditNext,500L);
    }

    private void auditNext() {
        if (!autoAuditActive) return;
        if (waitingRiskConfirmation) return;
        if (!OwnerSession.isActive(this)) { finishAutoAudit("Owner session expired."); return; }
        if (!PluginRegistry.isEnabled(this,autoAuditTarget)) { finishAutoAudit("Plugin was disabled."); return; }
        if (System.currentTimeMillis()-autoAuditStartedMs > AUTO_AUDIT_MAX_MS) {
            finishAutoAudit("Time limit reached."); return;
        }
        if (autoAuditTested >= AUTO_AUDIT_MAX_ACTIONS) {
            finishAutoAudit("Safe-action limit reached."); return;
        }

        AccessibilityNodeInfo root=getRootInActiveWindow();
        if(root==null){ handler.postDelayed(this::auditNext,500L); return; }
        CharSequence pkgCs=root.getPackageName();
        String currentPkg=pkgCs==null?"":pkgCs.toString();

        if(!autoAuditTarget.equals(currentPkg)){
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"SKIP_EXTERNAL","",currentPkg);
            autoAuditSkipped++;
            performGlobalAction(GLOBAL_ACTION_BACK);
            if(autoAuditDepth>0) autoAuditDepth--;
            handler.postDelayed(this::auditNext,800L);
            return;
        }

        String screenSig=screenSignature(root);
        showAuditStatus("Scanning screen "+(autoAuditScreens+1),
                "Tested "+autoAuditTested+" • skipped "+autoAuditSkipped+" • depth "+autoAuditDepth);
        if(autoAuditScreensSeen.add(screenSig)) {
            autoAuditScreens++;
            AccessibilityEvent fake=AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
            fake.setPackageName(autoAuditTarget);
            fake.setClassName("AnamikaAutoAudit");
            AppBlueprintStore.record(this,fake,root);
            fake.recycle();
        }
        if(!lastAuditActionLabel.isEmpty()){
            boolean navigated=!lastAuditSourceScreenSig.isEmpty() && !lastAuditSourceScreenSig.equals(screenSig);
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"RESULT",lastAuditActionLabel,
                    "screen="+screenSig+" navigated="+navigated+" class="+String.valueOf(root.getClassName())+
                            " visible="+screenSummary(root));
            if(!navigated && autoAuditDepth>0) autoAuditDepth--;
            lastAuditActionLabel="";
            lastAuditSourceScreenSig="";
        }

        List<AccessibilityNodeInfo> nodes=flatten(root);
        String currentScreenSummary=screenSummary(root);
        for(AccessibilityNodeInfo n:nodes){
            if(n==null || !n.isVisibleToUser() || !n.isEnabled()) continue;
            String label=nodeLabel(n);
            String sig=screenSig+"|"+nodeSignature(n,label);
            if(autoAuditNodes.contains(sig)) continue;

            boolean semanticClick = n.isClickable() || supportsAction(n,AccessibilityNodeInfo.ACTION_CLICK);
            boolean touchOnly = !semanticClick && isSafeTouchOnlyCandidate(n,currentScreenSummary);
            if(!semanticClick && !touchOnly) continue;
            autoAuditNodes.add(sig);

            if(n.isPassword() || n.isEditable()){
                autoAuditSkipped++;
                String reason=n.isPassword()?"password field":"editable/input field";
                AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"SKIPPED",label,reason);
                AuditLearningStore.learnRisk(this,autoAuditTarget,sig,label);
                showAuditStatus("Protected field skipped", reason);
                continue;
            }

            String auditLabel=label.trim().isEmpty()?touchZoneLabel(n):label;
            if(!label.trim().isEmpty() && isRiskyAuditAction(label)){
                AuditLearningStore.learnRisk(this,autoAuditTarget,sig,auditLabel);
                requestRiskConfirmation(n,auditLabel,sig,screenSig);
                return;
            }
            boolean learnedSafe=AuditLearningStore.knownSafe(this,autoAuditTarget,sig);
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,touchOnly?"TRY_TOUCH":"TRY_TAP",auditLabel,
                    "class="+String.valueOf(n.getClassName())+" viewId="+String.valueOf(n.getViewIdResourceName())+
                            (touchOnly?" mode=gesture-center":" mode=accessibility-click")+
                            " learned="+learnedSafe);
            showAuditStatus(touchOnly?"Touch-zone check":"Control check", auditLabel);

            boolean acted = semanticClick ? clickNodeOrParent(n) : gestureTapNode(n);
            if(acted){
                autoAuditTested++;
                if(touchOnly) autoAuditGestureTaps++;
                AuditLearningStore.learnSafe(this,autoAuditTarget,sig,auditLabel);
                lastAuditSourceScreenSig=screenSig;
                lastAuditActionLabel=auditLabel;
                if(autoAuditDepth < AUTO_AUDIT_MAX_DEPTH) autoAuditDepth++;
                handler.postDelayed(this::auditNext,touchOnly?1100L:900L);
                return;
            } else {
                autoAuditSkipped++;
                AuditLearningStore.learnFailed(this,autoAuditTarget,sig,auditLabel);
                AppBlueprintStore.recordAuditResult(this,autoAuditTarget,
                        touchOnly?"FAILED_TOUCH":"FAILED_TAP",auditLabel,
                        touchOnly?"gesture dispatch was rejected":"control did not accept ACTION_CLICK");
            }
        }

        // Some custom Canvas/Surface/Texture/Compose UIs expose one large view rather than
        // individual clickable Accessibility nodes. Probe a bounded, reversible grid only
        // on non-sensitive screens, and record every coordinate in the blueprint.
        if(!containsRiskyScreenText(currentScreenSummary) && probeCustomSurface(root,screenSig)){
            handler.postDelayed(this::auditNext,1200L);
            return;
        }

        if(!autoAuditScrolled.contains(screenSig) && scroll(root,AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)){
            autoAuditScrolled.add(screenSig);
            autoAuditTested++;
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"SCROLL","down","discover more visible controls");
            showAuditStatus("Scrolling", "Looking for more controls below");
            handler.postDelayed(this::auditNext,800L);
            return;
        }

        if(autoAuditDepth>0){
            autoAuditDepth--;
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"BACK","",
                    "No new safe controls on current screen; returning to previous screen.");
            showAuditStatus("Going back", "Current branch exhausted; checking next path");
            performGlobalAction(GLOBAL_ACTION_BACK);
            handler.postDelayed(this::auditNext,800L);
            return;
        }

        finishAutoAudit("No more untested safe visible controls.");
    }

    private void finishAutoAudit(String reason){
        if(!autoAuditActive) return;
        autoAuditActive=false;
        waitingRiskConfirmation=false;
        AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"SUMMARY","gesture_touch_zones",
                "Direct gesture touch tests="+autoAuditGestureTaps);
        AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"SUMMARY","learned_profile",
                AuditLearningStore.summary(this,autoAuditTarget));
        showAuditStatus("Audit complete",
                "Screens "+autoAuditScreens+" • tested "+autoAuditTested+" • skipped "+autoAuditSkipped);
        java.io.File dir=AppBlueprintStore.completeAutoAudit(
                this,autoAuditTested,autoAuditSkipped,autoAuditScreens,reason);
        String path=dir==null?"":dir.getAbsolutePath();
        android.widget.Toast.makeText(this,
                "Anamika Auto Audit complete. Blueprint ready."+ (path.isEmpty()?"":" "+path),
                android.widget.Toast.LENGTH_LONG).show();
        handler.postDelayed(this::hideAuditOverlay,3500L);
    }

    private void createAuditOverlay(){
        if(windowManager==null || auditOverlay!=null) return;
        auditOverlay=new LinearLayout(this);
        auditOverlay.setOrientation(LinearLayout.VERTICAL);
        auditOverlay.setPadding(dp(12),dp(8),dp(12),dp(8));
        auditOverlay.setBackgroundColor(0xDD111111);

        auditOverlayText=new TextView(this);
        auditOverlayText.setTextColor(0xFFFFFFFF);
        auditOverlayText.setTextSize(13f);
        auditOverlay.addView(auditOverlayText,new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout buttons=new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        auditAllowOnce=new Button(this);
        auditAllowOnce.setText("Allow once");
        auditSkipRisk=new Button(this);
        auditSkipRisk.setText("Skip");
        buttons.addView(auditAllowOnce,new LinearLayout.LayoutParams(0,LinearLayout.LayoutParams.WRAP_CONTENT,1f));
        buttons.addView(auditSkipRisk,new LinearLayout.LayoutParams(0,LinearLayout.LayoutParams.WRAP_CONTENT,1f));
        auditOverlay.addView(buttons);
        auditAllowOnce.setVisibility(View.GONE);
        auditSkipRisk.setVisibility(View.GONE);
        auditOverlay.setVisibility(View.GONE);

        auditAllowOnce.setOnClickListener(v -> allowPendingRiskOnce());
        auditSkipRisk.setOnClickListener(v -> skipPendingRisk());

        WindowManager.LayoutParams p=new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN|WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT);
        p.gravity=Gravity.TOP;
        p.y=dp(8);
        try{ windowManager.addView(auditOverlay,p); }catch(Exception ignored){}
    }

    private void showAuditStatus(String title,String detail){
        if(auditOverlay==null || auditOverlayText==null) return;
        auditOverlay.setVisibility(View.VISIBLE);
        auditOverlayText.setText("Anamika Deep Audit\n"+title+"\n"+detail);
        if(!waitingRiskConfirmation){
            auditAllowOnce.setVisibility(View.GONE);
            auditSkipRisk.setVisibility(View.GONE);
        }
    }

    private void hideAuditOverlay(){
        if(auditOverlay!=null) auditOverlay.setVisibility(View.GONE);
    }

    private void requestRiskConfirmation(AccessibilityNodeInfo node,String label,String fingerprint,String sourceScreenSig){
        if(node==null || waitingRiskConfirmation) return;
        node.getBoundsInScreen(pendingRiskBounds);
        pendingRiskLabel=label==null?"<risky control>":label;
        pendingRiskFingerprint=fingerprint==null?"":fingerprint;
        pendingRiskSourceScreenSig=sourceScreenSig==null?"":sourceScreenSig;
        waitingRiskConfirmation=true;
        AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"RISK_CONFIRM",pendingRiskLabel,
                "Owner confirmation required before this action.");
        showAuditStatus("Risk confirmation required",
                pendingRiskLabel+"\nThis audit is paused until you choose.");
        if(auditAllowOnce!=null) auditAllowOnce.setVisibility(View.VISIBLE);
        if(auditSkipRisk!=null) auditSkipRisk.setVisibility(View.VISIBLE);
    }

    private void allowPendingRiskOnce(){
        if(!waitingRiskConfirmation) return;
        waitingRiskConfirmation=false;
        if(auditAllowOnce!=null) auditAllowOnce.setVisibility(View.GONE);
        if(auditSkipRisk!=null) auditSkipRisk.setVisibility(View.GONE);
        String label=pendingRiskLabel;
        android.graphics.Rect bounds=new android.graphics.Rect(pendingRiskBounds);
        AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"RISK_ALLOWED_ONCE",label,
                "Owner approved this risky action once.");
        showAuditStatus("Owner approved once",label);
        boolean dispatched=!bounds.isEmpty() && dispatchTap(bounds.exactCenterX(),bounds.exactCenterY());
        if(dispatched){
            autoAuditTested++;
            lastAuditSourceScreenSig=pendingRiskSourceScreenSig;
            lastAuditActionLabel=label;
            if(autoAuditDepth<AUTO_AUDIT_MAX_DEPTH) autoAuditDepth++;
        }else{
            autoAuditSkipped++;
            AuditLearningStore.learnFailed(this,autoAuditTarget,pendingRiskFingerprint,label);
            AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"FAILED_TOUCH",label,
                    "Owner approved, but gesture dispatch failed.");
        }
        clearPendingRisk();
        handler.postDelayed(this::auditNext,1100L);
    }

    private void skipPendingRisk(){
        if(!waitingRiskConfirmation) return;
        waitingRiskConfirmation=false;
        String label=pendingRiskLabel;
        autoAuditSkipped++;
        AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"RISK_SKIPPED",label,
                "Owner chose Skip for this audit.");
        showAuditStatus("Risk skipped",label);
        clearPendingRisk();
        handler.postDelayed(this::auditNext,350L);
    }

    private void clearPendingRisk(){
        pendingRiskLabel="";
        pendingRiskFingerprint="";
        pendingRiskSourceScreenSig="";
        pendingRiskBounds.setEmpty();
        if(auditAllowOnce!=null) auditAllowOnce.setVisibility(View.GONE);
        if(auditSkipRisk!=null) auditSkipRisk.setVisibility(View.GONE);
    }

    private String screenSignature(AccessibilityNodeInfo root){
        StringBuilder b=new StringBuilder();
        b.append(String.valueOf(root.getClassName())).append('|');
        int added=0;
        for(AccessibilityNodeInfo n:flatten(root)){
            if(added>=30) break;
            String label=nodeLabel(n);
            if(!label.isEmpty()){ b.append(label).append(';'); added++; }
        }
        return Integer.toHexString(b.toString().hashCode());
    }

    private String screenSummary(AccessibilityNodeInfo root){
        StringBuilder b=new StringBuilder();
        int count=0;
        for(AccessibilityNodeInfo n:flatten(root)){
            String label=nodeLabel(n);
            if(label.isEmpty()) continue;
            if(count++>0) b.append(" | ");
            b.append(label.replace("\n"," "));
            if(count>=12) break;
        }
        String s=b.toString();
        return s.length()>700?s.substring(0,700):s;
    }

    private String nodeSignature(AccessibilityNodeInfo n,String label){
        android.graphics.Rect r=new android.graphics.Rect();
        n.getBoundsInScreen(r);
        return String.valueOf(n.getClassName())+"|"+
                String.valueOf(n.getViewIdResourceName())+"|"+label+"|"+r.flattenToString();
    }

    private String nodeLabel(AccessibilityNodeInfo n){
        CharSequence v=n.getText();
        if(v==null || v.length()==0) v=n.getContentDescription();
        if((v==null || v.length()==0) && n.getHintText()!=null) v=n.getHintText();
        if((v==null || v.length()==0) && n.getViewIdResourceName()!=null) v=n.getViewIdResourceName();
        return v==null?"":v.toString().trim();
    }

    private boolean isRiskyAuditAction(String raw){
        String s=raw==null?"":raw.toLowerCase(Locale.ROOT);
        String[] risky={
                "delete","remove","uninstall","erase","clear data","factory reset",
                "buy","purchase","pay","payment","checkout","order","recharge","withdraw","transfer","send money",
                "send","message","sms","post","publish","upload","share","call","dial",
                "logout","log out","sign out","login","log in","sign in","otp","password","pin",
                "subscribe","unsubscribe","follow","unfollow","like","dislike","block","report",
                "install","update app","allow","permission","grant","camera","microphone","location",
                "confirm","submit","save changes","book","reserve",
                "हटाएं","डिलीट","भुगतान","पेमेंट","भेजें","कॉल","लॉगआउट","लॉगिन","पासवर्ड","ओटीपी",
                "अनुमति","खरीद","रिचार्ज","निकासी","ट्रांसफर"
        };
        for(String k:risky) if(s.contains(k)) return true;
        return false;
    }

    private void performWhatsAppMessage(String recipient,String message){
        if(recipient==null||message==null||recipient.trim().isEmpty()||message.trim().isEmpty()) return;
        final String who=recipient.trim();
        final String body=message.trim();
        final String target=getSharedPreferences(PREFS,MODE_PRIVATE).getString(TARGET,"");
        boolean oneShot=getSharedPreferences(PREFS,MODE_PRIVATE).getBoolean(ONE_SHOT,false);
        if(!"com.whatsapp".equals(target) || (!oneShot && !PluginRegistry.isEnabled(this,target))) return;
        if(!OwnerSession.isActive(this)) return;

        AccessibilityNodeInfo root=getRootInActiveWindow();
        if(root==null) return;
        AppBlueprintStore.recordUserAction(this,target,"Explicit owner WhatsApp message to "+who);

        boolean searchOpened=clickText(root,"Search") || clickText(root,"Search…") || clickText(root,"खोजें");
        handler.postDelayed(() -> {
            AccessibilityNodeInfo r1=getRootInActiveWindow();
            if(r1==null) return;
            if(!typeText(r1,who)){
                android.widget.Toast.makeText(this,"WhatsApp search field nahi mila.",android.widget.Toast.LENGTH_LONG).show();
                return;
            }
            handler.postDelayed(() -> {
                AccessibilityNodeInfo r2=getRootInActiveWindow();
                if(r2==null) return;
                if(!clickExactText(r2,who)){
                    android.widget.Toast.makeText(this,"Exact contact “"+who+"” nahi mila; message send nahi kiya.",android.widget.Toast.LENGTH_LONG).show();
                    return;
                }
                handler.postDelayed(() -> {
                    AccessibilityNodeInfo r3=getRootInActiveWindow();
                    if(r3==null) return;
                    if(!typeText(r3,body)){
                        android.widget.Toast.makeText(this,"WhatsApp message box nahi mila.",android.widget.Toast.LENGTH_LONG).show();
                        return;
                    }
                    handler.postDelayed(() -> {
                        AccessibilityNodeInfo r4=getRootInActiveWindow();
                        if(r4==null) return;
                        boolean sent=clickText(r4,"Send") || clickText(r4,"भेजें");
                        android.widget.Toast.makeText(this,
                                sent?"Message sent to "+who:"Message type hua, lekin Send button nahi mila; draft chhoda gaya.",
                                android.widget.Toast.LENGTH_LONG).show();
                    },650L);
                },800L);
            },900L);
        },searchOpened?600L:250L);
    }

    private boolean clickExactText(AccessibilityNodeInfo root,String text){
        if(root==null||text==null) return false;
        String needle=text.trim();
        for(AccessibilityNodeInfo n:flatten(root)){
            CharSequence t=n.getText();
            CharSequence d=n.getContentDescription();
            if((t!=null && needle.equalsIgnoreCase(t.toString().trim())) ||
                    (d!=null && needle.equalsIgnoreCase(d.toString().trim()))){
                if(clickNodeOrParent(n)) return true;
            }
        }
        return false;
    }

    public static String readVisibleScreenText(){
        AppAutomationAccessibilityService svc=instance;
        if(svc==null) return "";
        AccessibilityNodeInfo root=svc.getRootInActiveWindow();
        if(root==null) return "";
        java.util.LinkedHashSet<String> lines=new java.util.LinkedHashSet<>();
        for(AccessibilityNodeInfo n:svc.flatten(root)){
            if(n==null || !n.isVisibleToUser()) continue;
            if(n.isPassword()){
                lines.add("<password hidden>");
                continue;
            }
            String label=svc.nodeLabel(n);
            if(label==null || label.trim().isEmpty()) continue;
            String low=label.toLowerCase(Locale.ROOT);
            if(low.matches(".*\\b(otp|pin|cvv|password|passcode)\\b.*")) {
                lines.add("<sensitive field hidden>");
                continue;
            }
            String clean=label.replace("\n"," ").trim();
            if(clean.length()>240) clean=clean.substring(0,240);
            lines.add(clean);
            if(lines.size()>=180) break;
        }
        StringBuilder out=new StringBuilder();
        for(String line:lines){
            if(out.length()>0) out.append("\n");
            out.append(line);
            if(out.length()>10000) break;
        }
        return out.toString();
    }

    public static boolean queueVisibleAction(String raw,long delayMs){
        AppAutomationAccessibilityService svc=instance;
        if(svc==null || raw==null || raw.trim().isEmpty()) return false;
        svc.handler.postDelayed(() -> svc.executeStep(raw),Math.max(0L,delayMs));
        return true;
    }

    public static boolean queueSettingsSearch(String query,long delayMs){
        AppAutomationAccessibilityService svc=instance;
        if(svc==null || query==null || query.trim().isEmpty()) return false;
        final String q=query.trim();
        svc.handler.postDelayed(() -> {
            AccessibilityNodeInfo root=svc.getRootInActiveWindow();
            if(root==null) return;
            boolean opened=svc.clickText(root,"Search settings") || svc.clickText(root,"Search") ||
                    svc.clickText(root,"खोजें") || svc.clickText(root,"सेटिंग खोजें");
            svc.handler.postDelayed(() -> {
                AccessibilityNodeInfo fresh=svc.getRootInActiveWindow();
                if(fresh!=null) svc.typeText(fresh,q);
            },opened?550L:200L);
        },Math.max(0L,delayMs));
        return true;
    }

    public static boolean queueFirstSeekBarPercent(int percent,long delayMs){
        AppAutomationAccessibilityService svc=instance;
        if(svc==null) return false;
        final int p=Math.max(0,Math.min(100,percent));
        svc.handler.postDelayed(() -> {
            AccessibilityNodeInfo root=svc.getRootInActiveWindow();
            if(root==null) return;
            for(AccessibilityNodeInfo n:svc.flatten(root)){
                if(n==null || !n.isVisibleToUser() || !n.isEnabled()) continue;
                String cls=String.valueOf(n.getClassName()).toLowerCase(Locale.ROOT);
                if(cls.contains("seekbar") || supportsSetProgress(n)){
                    android.os.Bundle b=new android.os.Bundle();
                    b.putFloat(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE,p);
                    if(n.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.getId(),b)) return;
                }
            }
        },Math.max(0L,delayMs));
        return true;
    }

    private static boolean supportsSetProgress(AccessibilityNodeInfo node){
        if(node==null) return false;
        for(AccessibilityNodeInfo.AccessibilityAction a:node.getActionList()){
            if(a!=null && a.getId()==AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.getId()) return true;
        }
        return false;
    }

    /** Common phone-level owner commands that do not depend on any plugin. */
    public static boolean performOwnerPhoneCommand(android.content.Context context,String command){
        if(context==null || command==null || !OwnerSession.isActive(context)) return false;
        AppAutomationAccessibilityService svc=instance;
        if(svc==null) return false;
        String lower=command.toLowerCase(Locale.ROOT).trim();
        svc.handler.post(() -> {
            if(containsAny(lower,"home","home screen","go home","होम")){
                svc.performGlobalAction(GLOBAL_ACTION_HOME);
            } else if(containsAny(lower,"back","go back","wapas","वापस")){
                svc.performGlobalAction(GLOBAL_ACTION_BACK);
            } else if(containsAny(lower,"recent apps","recents","recent kholo","हाल के ऐप")){
                svc.performGlobalAction(GLOBAL_ACTION_RECENTS);
            } else if(containsAny(lower,"notifications","notification kholo","नोटिफिकेशन")){
                svc.performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS);
            } else if(containsAny(lower,"quick settings","quick setting","control center")){
                svc.performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS);
            }
        });
        return containsAny(lower,"home","home screen","go home","होम",
                "back","go back","wapas","वापस",
                "recent apps","recents","recent kholo","हाल के ऐप",
                "notifications","notification kholo","नोटिफिकेशन",
                "quick settings","quick setting","control center");
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

        java.util.regex.Matcher postfixTap=java.util.regex.Pattern.compile(
                "(?i)^(.+?)\\s+(?:par\\s+)?(?:tap|click|press|touch|dabao|दबाओ)\\s*(?:karo|kar|do)?$"
        ).matcher(raw.trim());
        if(postfixTap.find()){ clickText(root,postfixTap.group(1).trim()); return; }

        java.util.regex.Matcher postfixOpen=java.util.regex.Pattern.compile(
                "(?i)^(.+?)\\s+(?:open|khol|kholo|खोलो)\\s*(?:karo|kar|do)?$"
        ).matcher(raw.trim());
        if(postfixOpen.find()){ clickText(root,postfixOpen.group(1).trim()); return; }

        java.util.regex.Matcher postfixType=java.util.regex.Pattern.compile(
                "(?i)^(.+?)\\s+(?:type|write|likho|लिखो)\\s*(?:karo|kar|do)?$"
        ).matcher(raw.trim());
        if(postfixType.find()){ typeText(root,postfixType.group(1).trim()); return; }

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

    private boolean supportsAction(AccessibilityNodeInfo node,int actionId){
        if(node==null) return false;
        for(AccessibilityNodeInfo.AccessibilityAction a:node.getActionList()){
            if(a!=null && a.getId()==actionId) return true;
        }
        return false;
    }

    private boolean gestureTapNode(AccessibilityNodeInfo node){
        if(node==null || Build.VERSION.SDK_INT<24) return false;
        android.graphics.Rect b=new android.graphics.Rect();
        node.getBoundsInScreen(b);
        if(b.isEmpty()) return false;
        float x=b.exactCenterX(), y=b.exactCenterY();
        return dispatchTap(x,y);
    }

    private boolean dispatchTap(float x,float y){
        if(Build.VERSION.SDK_INT<24) return false;
        android.util.DisplayMetrics dm=getResources().getDisplayMetrics();
        if(x<1 || y<1 || x>=dm.widthPixels-1 || y>=dm.heightPixels-1) return false;
        android.graphics.Path p=new android.graphics.Path();
        p.moveTo(x,y);
        android.accessibilityservice.GestureDescription.StrokeDescription stroke=
                new android.accessibilityservice.GestureDescription.StrokeDescription(p,0,90);
        return dispatchGesture(new android.accessibilityservice.GestureDescription.Builder()
                .addStroke(stroke).build(),null,null);
    }

    private boolean isSafeTouchOnlyCandidate(AccessibilityNodeInfo n,String screenText){
        if(n==null || n.isPassword() || n.isEditable() || n.isScrollable()) return false;
        if(containsRiskyScreenText(screenText)) return false;
        android.graphics.Rect b=new android.graphics.Rect();
        n.getBoundsInScreen(b);
        if(b.isEmpty() || b.width()<dp(20) || b.height()<dp(20)) return false;
        android.util.DisplayMetrics dm=getResources().getDisplayMetrics();
        float area=(float)b.width()*(float)b.height();
        float screenArea=(float)dm.widthPixels*(float)dm.heightPixels;
        if(area>screenArea*0.60f) return false;
        float cy=b.exactCenterY();
        if(cy<dm.heightPixels*0.06f || cy>dm.heightPixels*0.94f) return false;

        String label=nodeLabel(n);
        if(!label.isEmpty()) return !isRiskyAuditAction(label);

        String cls=String.valueOf(n.getClassName()).toLowerCase(Locale.ROOT);
        boolean custom=cls.contains("image") || cls.contains("canvas") || cls.contains("surface") ||
                cls.contains("texture") || cls.contains("compose") || cls.endsWith(".view");
        return custom && n.getChildCount()==0;
    }

    private String touchZoneLabel(AccessibilityNodeInfo n){
        android.graphics.Rect b=new android.graphics.Rect();
        n.getBoundsInScreen(b);
        String cls=String.valueOf(n.getClassName());
        return "<touch-zone "+cls+" "+b.flattenToString()+">";
    }

    private boolean containsRiskyScreenText(String raw){
        if(raw==null || raw.trim().isEmpty()) return false;
        String s=raw.toLowerCase(Locale.ROOT);
        String[] riskyScreen={
                "payment","pay","purchase","checkout","order","recharge","withdraw","transfer",
                "send money","delete","remove account","factory reset","password","otp","pin",
                "login","sign in","permission","allow","camera","microphone","location",
                "भुगतान","पेमेंट","रिचार्ज","निकासी","ट्रांसफर","पासवर्ड","ओटीपी","लॉगिन","अनुमति"
        };
        for(String k:riskyScreen) if(s.contains(k)) return true;
        return false;
    }

    private boolean probeCustomSurface(AccessibilityNodeInfo root,String screenSig){
        if(Build.VERSION.SDK_INT<24 || root==null) return false;
        android.util.DisplayMetrics dm=getResources().getDisplayMetrics();
        for(AccessibilityNodeInfo n:flatten(root)){
            if(n==null || !n.isVisibleToUser() || !n.isEnabled() || n.isPassword() || n.isEditable()) continue;
            String cls=String.valueOf(n.getClassName()).toLowerCase(Locale.ROOT);
            boolean surface=cls.contains("surfaceview") || cls.contains("textureview") ||
                    cls.contains("canvas") || cls.contains("composeview");
            if(!surface) continue;

            android.graphics.Rect b=new android.graphics.Rect();
            n.getBoundsInScreen(b);
            if(b.isEmpty() || b.width()<dm.widthPixels*0.35f || b.height()<dm.heightPixels*0.20f) continue;

            // 3x3 interior grid: enough to discover common unlabeled touch zones without
            // blindly tapping system edges. Every tested point is de-duplicated per screen.
            float[] fractions={0.25f,0.50f,0.75f};
            for(float fy:fractions){
                for(float fx:fractions){
                    float x=b.left+b.width()*fx;
                    float y=b.top+b.height()*fy;
                    if(y<dm.heightPixels*0.08f || y>dm.heightPixels*0.92f) continue;
                    String zone=screenSig+"|grid|"+Math.round(x)+"|"+Math.round(y);
                    if(!autoAuditTouchZones.add(zone)) continue;
                    String label="<custom-touch "+Math.round(x)+","+Math.round(y)+">";
                    AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"TRY_TOUCH",label,
                            "class="+String.valueOf(n.getClassName())+" mode=custom-surface-grid");
                    if(dispatchTap(x,y)){
                        autoAuditTested++;
                        autoAuditGestureTaps++;
                        lastAuditActionLabel=label;
                        if(autoAuditDepth<AUTO_AUDIT_MAX_DEPTH) autoAuditDepth++;
                        return true;
                    }
                    autoAuditSkipped++;
                    AppBlueprintStore.recordAuditResult(this,autoAuditTarget,"FAILED_TOUCH",label,
                            "gesture dispatch was rejected");
                }
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
            getSharedPreferences(PREFS,MODE_PRIVATE).edit()
                    .remove(COMMAND).remove(TOKEN).remove(ONE_SHOT).apply();
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
