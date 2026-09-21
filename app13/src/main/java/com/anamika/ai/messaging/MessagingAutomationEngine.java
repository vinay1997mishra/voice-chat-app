package com.anamika.ai.messaging;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.Toast;

import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.phone.AppLauncher;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;

/**
 * One-shot owner-authorized messaging automation.
 *
 * It never reads private app databases. It only uses UI nodes exposed by Android
 * Accessibility, and only for the package named in the explicit owner command.
 */
public final class MessagingAutomationEngine {
    private static final String PREF="anamika13_message_automation";
    private static final String ACTIVE="active";
    private static final String PACKAGE="package";
    private static final String APP="app";
    private static final String RECIPIENT="recipient";
    private static final String MESSAGE="message";
    private static final String STAGE="stage";
    private static final String STATUS="status";
    private static final String DEADLINE="deadline";
    private static final String LAST_ACTION="last_action";

    private static final long SESSION_MS=60_000L;
    private static final long ACTION_GAP_MS=450L;

    private enum Stage { OPEN_APP, FIND_RECIPIENT, OPEN_CHAT, TYPE_MESSAGE, SEND, COMPLETE, FAILED }

    private MessagingAutomationEngine(){}

    public static String start(Context c,MessageCommandParser.Request req){
        if(!OwnerStore.isTrusted(c))return "Owner verification required.";
        if(req==null||!req.valid())return "Message command could not be understood.";

        AppLauncher.AppRef app=AppLauncher.resolve(c,req.app);
        if(app==null)return "Installed app not found: "+req.app;

        PackageManager pm=c.getPackageManager();
        Intent launch=pm.getLaunchIntentForPackage(app.packageName);
        if(launch==null)return app.label+" cannot be launched.";

        long now=System.currentTimeMillis();
        prefs(c).edit()
                .putBoolean(ACTIVE,true)
                .putString(PACKAGE,app.packageName)
                .putString(APP,app.label)
                .putString(RECIPIENT,req.recipient)
                .putString(MESSAGE,req.message)
                .putString(STAGE,Stage.OPEN_APP.name())
                .putString(STATUS,"Opening "+app.label+"…")
                .putLong(DEADLINE,now+SESSION_MS)
                .putLong(LAST_ACTION,0L)
                .apply();

        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP);
        c.startActivity(launch);
        return "Messaging started: "+app.label+" → "+req.recipient+
                "\nMessage: "+req.message+
                "\nAccessibility must be enabled. Anamika will stop if the expected chat UI is not found.";
    }

    public static String status(Context c){
        SharedPreferences p=prefs(c);
        if(!p.getBoolean(ACTIVE,false)){
            return p.getString(STATUS,"No message automation is active.");
        }
        return "Message automation: "+p.getString(STAGE,Stage.OPEN_APP.name())+
                "\nApp: "+p.getString(APP,"")+
                "\nRecipient: "+p.getString(RECIPIENT,"")+
                "\nStatus: "+p.getString(STATUS,"");
    }

    public static String cancel(Context c){
        SharedPreferences p=prefs(c);
        boolean active=p.getBoolean(ACTIVE,false);
        p.edit()
                .putBoolean(ACTIVE,false)
                .putString(STAGE,Stage.FAILED.name())
                .putString(STATUS,active?"Cancelled by owner.":"No active message automation.")
                .apply();
        return active?"Message automation cancelled.":"No message automation was active.";
    }

    public static boolean hasActiveSession(Context c){
        SharedPreferences p=prefs(c);
        return p.getBoolean(ACTIVE,false)&&System.currentTimeMillis()<=p.getLong(DEADLINE,0L);
    }

    public static void onWindow(Context c,String pkg,AccessibilityNodeInfo root){
        if(root==null||pkg==null||pkg.isEmpty())return;
        SharedPreferences p=prefs(c);
        if(!p.getBoolean(ACTIVE,false))return;
        if(!OwnerStore.isTrusted(c)){fail(c,"Owner session is no longer trusted.");return;}
        if(System.currentTimeMillis()>p.getLong(DEADLINE,0L)){fail(c,"Timed out before the message could be sent.");return;}
        if(!pkg.equals(p.getString(PACKAGE,"")))return;

        long now=System.currentTimeMillis();
        if(now-p.getLong(LAST_ACTION,0L)<ACTION_GAP_MS)return;

        Stage stage=readStage(p);
        String recipient=p.getString(RECIPIENT,"");
        String message=p.getString(MESSAGE,"");

        try{
            switch(stage){
                case OPEN_APP:
                    if(hasMessageField(root)){
                        move(c,Stage.TYPE_MESSAGE,"Chat screen found.");
                        scheduleContinue(c,pkg,650);
                        return;
                    }
                    AccessibilityNodeInfo recipientNode=findByVisibleText(root,recipient,true);
                    if(recipientNode!=null){
                        try{
                            if(clickNode(recipientNode)){
                                action(c,Stage.TYPE_MESSAGE,"Opened chat for "+recipient+".");
                                return;
                            }
                        }finally{recipientNode.recycle();}
                    }
                    AccessibilityNodeInfo search=findSearchControl(root);
                    if(search!=null){
                        try{
                            if(clickNode(search)){
                                action(c,Stage.FIND_RECIPIENT,"Opened search.");
                                return;
                            }
                        }finally{search.recycle();}
                    }
                    AccessibilityNodeInfo editable=findBestEditable(root,false);
                    if(editable!=null){
                        try{
                            if(setText(editable,recipient)){
                                action(c,Stage.OPEN_CHAT,"Searching for "+recipient+".");
                                return;
                            }
                        }finally{editable.recycle();}
                    }
                    update(c,"Waiting for a searchable conversation list…");
                    break;

                case FIND_RECIPIENT:
                    AccessibilityNodeInfo searchBox=findBestEditable(root,false);
                    if(searchBox!=null){
                        try{
                            CharSequence current=searchBox.getText();
                            String cur=current==null?"":current.toString().trim();
                            if(!cur.equalsIgnoreCase(recipient)&&setText(searchBox,recipient)){
                                action(c,Stage.OPEN_CHAT,"Searching for "+recipient+".");
                                return;
                            }
                        }finally{searchBox.recycle();}
                    }
                    move(c,Stage.OPEN_CHAT,"Looking for "+recipient+" in results.");
                    scheduleContinue(c,pkg,500);
                    break;

                case OPEN_CHAT:
                    if(hasMessageField(root)){
                        move(c,Stage.TYPE_MESSAGE,"Chat opened.");
                        scheduleContinue(c,pkg,450);
                        return;
                    }
                    AccessibilityNodeInfo result=findByVisibleText(root,recipient,true);
                    if(result!=null){
                        try{
                            if(clickNode(result)){
                                action(c,Stage.TYPE_MESSAGE,"Opened chat for "+recipient+".");
                                return;
                            }
                        }finally{result.recycle();}
                    }
                    update(c,"Waiting for recipient search result: "+recipient);
                    break;

                case TYPE_MESSAGE:
                    AccessibilityNodeInfo box=findMessageField(root);
                    if(box==null){
                        update(c,"Waiting for the message field in "+recipient+"'s chat…");
                        return;
                    }
                    try{
                        if(setText(box,message)){
                            action(c,Stage.SEND,"Message typed. Looking for Send.");
                            return;
                        }
                        fail(c,"Android rejected text entry in the message field.");
                    }finally{box.recycle();}
                    break;

                case SEND:
                    AccessibilityNodeInfo send=findSendControl(root);
                    if(send==null){
                        update(c,"Message is typed, but a safe Send control was not found.");
                        return;
                    }
                    try{
                        if(clickNode(send)){
                            complete(c,"Message sent to "+recipient+".");
                            return;
                        }
                        fail(c,"Android rejected the Send tap.");
                    }finally{send.recycle();}
                    break;

                case COMPLETE:
                case FAILED:
                    break;
            }
        }catch(Throwable t){
            fail(c,"Messaging automation error: "+safe(t));
        }
    }

    private static void scheduleContinue(Context c,String pkg,long delay){
        new Handler(Looper.getMainLooper()).postDelayed(()->{
            // Accessibility events normally continue the state machine. This delayed
            // status touch prevents a rapid duplicate action if a vendor emits bursts.
            SharedPreferences p=prefs(c);
            if(p.getBoolean(ACTIVE,false)&&pkg.equals(p.getString(PACKAGE,"")))
                p.edit().putLong(LAST_ACTION,0L).apply();
        },delay);
    }

    private static boolean hasMessageField(AccessibilityNodeInfo root){
        AccessibilityNodeInfo n=findMessageField(root);
        if(n==null)return false;
        n.recycle();
        return true;
    }

    private static AccessibilityNodeInfo findMessageField(AccessibilityNodeInfo root){
        Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
        q.add(AccessibilityNodeInfo.obtain(root));
        AccessibilityNodeInfo best=null;
        int bestBottom=-1;
        while(!q.isEmpty()){
            AccessibilityNodeInfo n=q.removeFirst();
            if(n.isEditable()&&n.isEnabled()){
                String hint=text(n.getHintText());
                String desc=text(n.getContentDescription());
                String id=text(n.getViewIdResourceName());
                String joined=(hint+" "+desc+" "+id).toLowerCase(Locale.ROOT);
                Rect r=new Rect();n.getBoundsInScreen(r);
                boolean messageLike=containsAny(joined,
                        "message","compose","composer","entry","input","write","type a message","chat");
                if(messageLike||r.bottom>bestBottom){
                    if(best!=null)best.recycle();
                    best=AccessibilityNodeInfo.obtain(n);
                    bestBottom=r.bottom;
                }
            }
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return best;
    }

    private static AccessibilityNodeInfo findBestEditable(AccessibilityNodeInfo root,boolean bottomMost){
        Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
        q.add(AccessibilityNodeInfo.obtain(root));
        AccessibilityNodeInfo best=null;
        int score=Integer.MIN_VALUE;
        while(!q.isEmpty()){
            AccessibilityNodeInfo n=q.removeFirst();
            if(n.isEditable()&&n.isEnabled()){
                Rect r=new Rect();n.getBoundsInScreen(r);
                String joined=(text(n.getHintText())+" "+text(n.getContentDescription())+" "+
                        text(n.getViewIdResourceName())).toLowerCase(Locale.ROOT);
                int s=bottomMost?r.bottom:0;
                if(containsAny(joined,"search","find","recipient","people","contact"))s+=100000;
                if(best==null||s>score){
                    if(best!=null)best.recycle();
                    best=AccessibilityNodeInfo.obtain(n);
                    score=s;
                }
            }
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return best;
    }

    private static AccessibilityNodeInfo findSearchControl(AccessibilityNodeInfo root){
        return findControl(root,new String[]{"search","find","new chat","new message","compose"},true);
    }

    private static AccessibilityNodeInfo findSendControl(AccessibilityNodeInfo root){
        return findControl(root,new String[]{"send","send message","submit"},false);
    }

    private static AccessibilityNodeInfo findControl(AccessibilityNodeInfo root,String[] terms,boolean allowContains){
        Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
        q.add(AccessibilityNodeInfo.obtain(root));
        while(!q.isEmpty()){
            AccessibilityNodeInfo n=q.removeFirst();
            String value=(text(n.getText())+" "+text(n.getContentDescription())+" "+
                    text(n.getViewIdResourceName())).trim().toLowerCase(Locale.ROOT);
            boolean match=false;
            for(String term:terms){
                if(value.equals(term)||value.endsWith("/"+term)||value.endsWith("_"+term)||
                        (allowContains&&value.contains(term))){
                    match=true;break;
                }
            }
            if(match&&n.isEnabled()){
                AccessibilityNodeInfo result=AccessibilityNodeInfo.obtain(n);
                while(!q.isEmpty())q.removeFirst().recycle();
                n.recycle();
                return result;
            }
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return null;
    }

    private static AccessibilityNodeInfo findByVisibleText(AccessibilityNodeInfo root,String wanted,boolean exactFirst){
        String w=wanted==null?"":wanted.trim().toLowerCase(Locale.ROOT);
        if(w.isEmpty())return null;
        AccessibilityNodeInfo contains=null;
        Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
        q.add(AccessibilityNodeInfo.obtain(root));
        while(!q.isEmpty()){
            AccessibilityNodeInfo n=q.removeFirst();
            String t=text(n.getText()).trim().toLowerCase(Locale.ROOT);
            String d=text(n.getContentDescription()).trim().toLowerCase(Locale.ROOT);
            if(t.equals(w)||d.equals(w)){
                if(contains!=null)contains.recycle();
                while(!q.isEmpty())q.removeFirst().recycle();
                return n;
            }
            if(contains==null&&(t.contains(w)||d.contains(w)))contains=AccessibilityNodeInfo.obtain(n);
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return contains;
    }

    private static boolean setText(AccessibilityNodeInfo node,String text){
        if(node==null||!node.isEditable())return false;
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        Bundle b=new Bundle();
        b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,text);
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,b);
    }

    private static boolean clickNode(AccessibilityNodeInfo node){
        if(node==null)return false;
        AccessibilityNodeInfo current=AccessibilityNodeInfo.obtain(node);
        try{
            for(int depth=0;depth<6&&current!=null;depth++){
                if(current.isClickable()&&current.isEnabled())
                    return current.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                AccessibilityNodeInfo parent=current.getParent();
                current.recycle();
                current=parent;
            }
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK);
        }finally{
            if(current!=null)current.recycle();
        }
    }

    private static void action(Context c,Stage next,String status){
        prefs(c).edit()
                .putString(STAGE,next.name())
                .putString(STATUS,status)
                .putLong(LAST_ACTION,System.currentTimeMillis())
                .apply();
    }

    private static void move(Context c,Stage next,String status){
        prefs(c).edit().putString(STAGE,next.name()).putString(STATUS,status).apply();
    }

    private static void update(Context c,String status){
        prefs(c).edit().putString(STATUS,status).apply();
    }

    private static void complete(Context c,String status){
        prefs(c).edit()
                .putBoolean(ACTIVE,false)
                .putString(STAGE,Stage.COMPLETE.name())
                .putString(STATUS,status)
                .apply();
        Toast.makeText(c,status,Toast.LENGTH_LONG).show();
    }

    private static void fail(Context c,String status){
        prefs(c).edit()
                .putBoolean(ACTIVE,false)
                .putString(STAGE,Stage.FAILED.name())
                .putString(STATUS,status)
                .apply();
        Toast.makeText(c,status,Toast.LENGTH_LONG).show();
    }

    private static Stage readStage(SharedPreferences p){
        try{return Stage.valueOf(p.getString(STAGE,Stage.OPEN_APP.name()));}
        catch(Exception e){return Stage.OPEN_APP;}
    }

    private static SharedPreferences prefs(Context c){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
    }

    private static boolean containsAny(String value,String... terms){
        for(String t:terms)if(value.contains(t))return true;
        return false;
    }

    private static String text(CharSequence s){return s==null?"":s.toString();}
    private static String text(String s){return s==null?"":s;}

    private static String safe(Throwable t){
        String m=t.getMessage();
        return m==null||m.trim().isEmpty()?t.getClass().getSimpleName():m;
    }
}
