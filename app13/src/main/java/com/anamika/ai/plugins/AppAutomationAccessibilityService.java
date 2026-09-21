package com.anamika.ai.plugins;

import android.accessibilityservice.AccessibilityService;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.messaging.MessagingAutomationEngine;
import com.anamika.ai.research.ResearchStore;

import java.util.ArrayDeque;
import java.util.Deque;

/**
 * Owner-controlled Accessibility bridge for V13.
 * Automation works only on the active UI of packages explicitly enabled by the owner.
 */
public final class AppAutomationAccessibilityService extends AccessibilityService {
    private static volatile AppAutomationAccessibilityService instance;
    private final Handler automationHandler=new Handler(Looper.getMainLooper());
    private final Runnable messagingTick=()->processMessagingWindow();

    @Override protected void onServiceConnected(){instance=this;}

    @Override public void onAccessibilityEvent(AccessibilityEvent event){
        if(event==null)return;
        CharSequence p=event.getPackageName();
        String pkg=p==null?"":p.toString();
        if(pkg.isEmpty())return;
        AccessibilityNodeInfo root=getRootInActiveWindow();
        if(root!=null){
            try{
                BlueprintStore.recordWindow(this,pkg,root,String.valueOf(event.getEventType()));
                ResearchStore.recordWindow(this,pkg,root);
                MessagingAutomationEngine.onWindow(this,pkg,root);
            }finally{root.recycle();}
        }
        if(MessagingAutomationEngine.hasActiveSession(this)){
            automationHandler.removeCallbacks(messagingTick);
            automationHandler.postDelayed(messagingTick,650L);
        }
    }

    private void processMessagingWindow(){
        if(!MessagingAutomationEngine.hasActiveSession(this))return;
        AccessibilityNodeInfo root=getRootInActiveWindow();
        if(root==null)return;
        try{
            String pkg=root.getPackageName()==null?"":root.getPackageName().toString();
            MessagingAutomationEngine.onWindow(this,pkg,root);
        }finally{
            root.recycle();
        }
        if(MessagingAutomationEngine.hasActiveSession(this))
            automationHandler.postDelayed(messagingTick,650L);
    }

    public static boolean isConnected(){
        return instance!=null;
    }

    @Override public void onInterrupt(){}

    @Override public void onDestroy(){
        automationHandler.removeCallbacksAndMessages(null);
        if(instance==this)instance=null;
        super.onDestroy();
    }

    public static String clickVisibleText(String text){
        AppAutomationAccessibilityService s=instance;
        if(s==null)return "Accessibility service is not connected.";
        if(!OwnerStore.isTrusted(s))return "Owner verification required.";
        AccessibilityNodeInfo root=s.getRootInActiveWindow();
        if(root==null)return "No active app window.";
        try{
            String pkg=root.getPackageName()==null?"":root.getPackageName().toString();
            if(!AppPluginRegistry.isEnabled(s,pkg))
                return "Automation is disabled for "+pkg+". Enable it in Plugin Center first.";
            AccessibilityNodeInfo target=findText(root,text);
            if(target==null)return "Visible control not found: "+text;
            try{
                AccessibilityNodeInfo n=target;
                while(n!=null&&!n.isClickable()){
                    AccessibilityNodeInfo parent=n.getParent();
                    if(n!=target)n.recycle();
                    n=parent;
                }
                if(n==null)return "Control is visible but not clickable.";
                boolean ok=n.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                if(n!=target)n.recycle();
                return ok?"Tapped: "+text:"Android rejected the tap action.";
            }finally{target.recycle();}
        }finally{root.recycle();}
    }

    public static String typeIntoFocused(String text){
        AppAutomationAccessibilityService s=instance;
        if(s==null)return "Accessibility service is not connected.";
        if(!OwnerStore.isTrusted(s))return "Owner verification required.";
        AccessibilityNodeInfo root=s.getRootInActiveWindow();
        if(root==null)return "No active app window.";
        try{
            String pkg=root.getPackageName()==null?"":root.getPackageName().toString();
            if(!AppPluginRegistry.isEnabled(s,pkg))return "Automation is disabled for "+pkg+".";
            AccessibilityNodeInfo focus=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if(focus==null)return "No editable field is focused.";
            try{
                Bundle b=new Bundle();
                b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,text);
                return focus.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,b)
                        ?"Text entered.":"Android rejected text entry.";
            }finally{focus.recycle();}
        }finally{root.recycle();}
    }

    public static String back(){
        AppAutomationAccessibilityService s=instance;
        if(s==null)return "Accessibility service is not connected.";
        if(!OwnerStore.isTrusted(s))return "Owner verification required.";
        return s.performGlobalAction(GLOBAL_ACTION_BACK)?"Back performed.":"Android rejected Back.";
    }

    private static AccessibilityNodeInfo findText(AccessibilityNodeInfo root,String text){
        if(text==null||text.trim().isEmpty())return null;
        Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
        q.add(AccessibilityNodeInfo.obtain(root));
        String wanted=text.trim().toLowerCase(java.util.Locale.ROOT);
        while(!q.isEmpty()){
            AccessibilityNodeInfo n=q.removeFirst();
            CharSequence t=n.getText(),d=n.getContentDescription();
            String ts=t==null?"":t.toString().trim().toLowerCase(java.util.Locale.ROOT);
            String ds=d==null?"":d.toString().trim().toLowerCase(java.util.Locale.ROOT);
            if(ts.equals(wanted)||ds.equals(wanted)||ts.contains(wanted)||ds.contains(wanted)){
                while(!q.isEmpty())q.removeFirst().recycle();
                return n;
            }
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return null;
    }
}
