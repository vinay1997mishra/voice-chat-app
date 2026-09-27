package com.anamika.ai.messaging;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.Toast;

import com.anamika.ai.core.OwnerStore;
import com.anamika.ai.phone.AppLauncher;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;

/**
 * Owner-authorized one-shot messaging automation.
 *
 * It uses only Android Accessibility UI metadata. If an app UI is unknown, it pauses
 * and asks the owner to tap the missing control once. That control selector is stored
 * per app and tried first on later runs.
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
    private static final String AWAIT_ROLE="await_role";
    private static final String MISS_COUNT="miss_count";
    private static final String CHAT_VERIFIED="chat_verified";

    private static final long SESSION_MS=60_000L;
    private static final long TEACHING_SESSION_MS=180_000L;
    private static final long ACTION_GAP_MS=450L;
    private static final int MISSES_BEFORE_ASK=4;

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
                .putString(AWAIT_ROLE,"")
                .putBoolean(CHAT_VERIFIED,false)
                .putInt(MISS_COUNT,0)
                .putLong(DEADLINE,now+SESSION_MS)
                .putLong(LAST_ACTION,0L)
                .apply();

        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_SINGLE_TOP);
        c.startActivity(launch);
        return "Messaging started: "+app.label+" → "+req.recipient+
                "\nMessage: "+req.message+
                "\nAgar koi control na mile to Anamika ruk kar aapse ek baar tap karne ko kahegi aur us control ko next time ke liye save karegi.";
    }

    public static String status(Context c){
        SharedPreferences p=prefs(c);
        String awaiting=p.getString(AWAIT_ROLE,"");
        if(!p.getBoolean(ACTIVE,false))
            return p.getString(STATUS,"No message automation is active.");
        return "Message automation: "+p.getString(STAGE,Stage.OPEN_APP.name())+
                "\nApp: "+p.getString(APP,"")+
                "\nRecipient: "+p.getString(RECIPIENT,"")+
                (awaiting.isEmpty()?"":"\nWaiting for owner help: "+awaiting)+
                "\nStatus: "+p.getString(STATUS,"");
    }

    public static String cancel(Context c){
        SharedPreferences p=prefs(c);
        boolean active=p.getBoolean(ACTIVE,false);
        p.edit()
                .putBoolean(ACTIVE,false)
                .putString(AWAIT_ROLE,"")
                .putString(STAGE,Stage.FAILED.name())
                .putString(STATUS,active?"Cancelled by owner.":"No active message automation.")
                .apply();
        return active?"Message automation cancelled.":"No message automation was active.";
    }

    public static boolean hasActiveSession(Context c){
        SharedPreferences p=prefs(c);
        return p.getBoolean(ACTIVE,false)&&System.currentTimeMillis()<=p.getLong(DEADLINE,0L);
    }

    /** Captures the owner's teaching tap/focus while an automation is paused for help. */
    public static void onOwnerInteraction(Context c,AccessibilityEvent event){
        if(event==null)return;
        SharedPreferences p=prefs(c);
        if(!p.getBoolean(ACTIVE,false))return;

        String role=p.getString(AWAIT_ROLE,"");
        if(role.isEmpty())return;

        CharSequence eventPkg=event.getPackageName();
        String pkg=eventPkg==null?"":eventPkg.toString();
        if(!pkg.equals(p.getString(PACKAGE,"")))return;

        int type=event.getEventType();
        if(type!=AccessibilityEvent.TYPE_VIEW_CLICKED&&type!=AccessibilityEvent.TYPE_VIEW_FOCUSED)return;

        AccessibilityNodeInfo source=event.getSource();
        if(source==null)return;
        try{
            String learned=MessagingLearningStore.learn(c,pkg,role,source);
            String recipient=p.getString(RECIPIENT,"");

            SharedPreferences.Editor e=p.edit()
                    .putString(AWAIT_ROLE,"")
                    .putInt(MISS_COUNT,0)
                    .putLong(DEADLINE,System.currentTimeMillis()+SESSION_MS)
                    .putLong(LAST_ACTION,System.currentTimeMillis());

            if("search".equals(role)){
                e.putString(STAGE,Stage.FIND_RECIPIENT.name())
                        .putString(STATUS,learned+" Ab "+recipient+" search kar rahi hu.");
                e.apply();
                toast(c,"Thik hai, Search control yaad rakh liya.");
            }else if("recipient_row".equals(role)){
                e.putBoolean(CHAT_VERIFIED,true)
                        .putString(STAGE,Stage.TYPE_MESSAGE.name())
                        .putString(STATUS,learned+" Chat owner ne select ki.");
                e.apply();
                toast(c,"Thik hai, chat selection yaad rakh li.");
            }else if("message_field".equals(role)){
                e.putString(STAGE,Stage.TYPE_MESSAGE.name())
                        .putString(STATUS,learned+" Message field learned.");
                e.apply();
                toast(c,"Message box yaad rakh liya.");
            }else if("send".equals(role)){
                e.apply();
                complete(c,learned+" Message sent; Send control next time ke liye saved.");
            }else{
                e.apply();
            }
        }finally{
            source.recycle();
        }
    }

    public static void onWindow(Context c,String pkg,AccessibilityNodeInfo root){
        if(root==null||pkg==null||pkg.isEmpty())return;
        SharedPreferences p=prefs(c);
        if(!p.getBoolean(ACTIVE,false))return;
        if(!OwnerStore.isTrusted(c)){fail(c,"Owner session is no longer trusted.");return;}
        if(System.currentTimeMillis()>p.getLong(DEADLINE,0L)){fail(c,"Timed out before the message could be sent.");return;}
        if(!pkg.equals(p.getString(PACKAGE,"")))return;
        if(!p.getString(AWAIT_ROLE,"").isEmpty())return;

        long now=System.currentTimeMillis();
        if(now-p.getLong(LAST_ACTION,0L)<ACTION_GAP_MS)return;

        Stage stage=readStage(p);
        String recipient=p.getString(RECIPIENT,"");
        String message=p.getString(MESSAGE,"");

        try{
            switch(stage){
                case OPEN_APP: {
                    if(hasMessageField(c,root,pkg)){
                        if(recipientVisible(root,recipient)){
                            prefs(c).edit().putBoolean(CHAT_VERIFIED,true).apply();
                            move(c,Stage.TYPE_MESSAGE,"Correct chat screen found.");
                            return;
                        }
                        if(c instanceof AccessibilityService){
                            boolean backed=((AccessibilityService)c)
                                    .performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK);
                            if(backed){
                                action(c,Stage.OPEN_APP,
                                        "Returning to the conversation list before selecting "+recipient+".");
                                return;
                            }
                        }
                        ask(c,"recipient_row",
                                "Sahi chat nahi mil rahi. "+recipient+" ki chat khol kar us chat/contact par ek baar tap karo; main yaad rakh lungi.");
                        return;
                    }

                    AccessibilityNodeInfo recipientNode=findByVisibleText(root,recipient);
                    if(recipientNode!=null){
                        try{
                            if(clickNode(recipientNode)){
                                prefs(c).edit().putBoolean(CHAT_VERIFIED,true).apply();
                                action(c,Stage.TYPE_MESSAGE,"Opened chat for "+recipient+".");
                                return;
                            }
                        }finally{recipientNode.recycle();}
                    }

                    AccessibilityNodeInfo search=findSearchControl(c,root,pkg);
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

                    miss(c,"Waiting for a searchable conversation list…","search",
                            "Search button nahi mil raha. Search button par ek baar tap karo; main ise next time ke liye save kar lungi.");
                    break;
                }

                case FIND_RECIPIENT: {
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
                    miss(c,"Looking for a search field…","recipient_row",
                            recipient+" ka result/chat nahi mil raha. Sahi contact/chat par ek baar tap karo; main is app ka selection pattern save kar lungi.");
                    break;
                }

                case OPEN_CHAT: {
                    if(hasMessageField(c,root,pkg)&&recipientVisible(root,recipient)){
                        prefs(c).edit().putBoolean(CHAT_VERIFIED,true).apply();
                        move(c,Stage.TYPE_MESSAGE,"Verified chat opened for "+recipient+".");
                        return;
                    }
                    AccessibilityNodeInfo result=findByVisibleText(root,recipient);
                    if(result!=null){
                        try{
                            if(clickNode(result)){
                                prefs(c).edit().putBoolean(CHAT_VERIFIED,true).apply();
                                action(c,Stage.TYPE_MESSAGE,"Opened chat for "+recipient+".");
                                return;
                            }
                        }finally{result.recycle();}
                    }
                    miss(c,"Waiting for recipient search result: "+recipient,"recipient_row",
                            recipient+" ki chat/result par ek baar tap karo. Main is app ka chat-selection control yaad rakh lungi.");
                    break;
                }

                case TYPE_MESSAGE: {
                    boolean verified=p.getBoolean(CHAT_VERIFIED,false)||recipientVisible(root,recipient);
                    if(!verified){
                        ask(c,"recipient_row",
                                "Recipient verify nahi ho raha. Agar ye "+recipient+" ki sahi chat hai to chat/contact area par ek baar tap karo.");
                        return;
                    }

                    AccessibilityNodeInfo box=findMessageField(c,root,pkg);
                    if(box==null){
                        miss(c,"Waiting for the message field…","message_field",
                                "Message box nahi mil raha. Message likhne wale box par ek baar tap karo; main ise save kar lungi.");
                        return;
                    }
                    try{
                        if(setText(box,message)){
                            action(c,Stage.SEND,"Message typed. Looking for Send.");
                            return;
                        }
                        ask(c,"message_field",
                                "Message box mil gaya lekin text enter nahi hua. Message box par ek baar tap karo; main control ko dubara learn kar lungi.");
                    }finally{box.recycle();}
                    break;
                }

                case SEND: {
                    boolean verified=p.getBoolean(CHAT_VERIFIED,false)||recipientVisible(root,recipient);
                    if(!verified){
                        fail(c,"Chat verification changed before Send. Message was not sent.");
                        return;
                    }
                    AccessibilityNodeInfo send=findSendControl(c,root,pkg);
                    if(send==null){
                        miss(c,"Message is typed, but Send control was not found.","send",
                                "Send button nahi mil raha. Send button par ek baar tap karo. Message abhi send ho jayega aur main button next time ke liye save kar lungi.");
                        return;
                    }
                    try{
                        if(clickNode(send)){
                            complete(c,"Message sent to "+recipient+".");
                            return;
                        }
                        ask(c,"send",
                                "Android ne Send tap reject kiya. Send button par ek baar manually tap karo; main ise learn kar lungi.");
                    }finally{send.recycle();}
                    break;
                }

                case COMPLETE:
                case FAILED:
                    break;
            }
        }catch(Throwable t){
            fail(c,"Messaging automation error: "+safe(t));
        }
    }

    private static void miss(Context c,String status,String role,String question){
        SharedPreferences p=prefs(c);
        int misses=p.getInt(MISS_COUNT,0)+1;
        p.edit().putInt(MISS_COUNT,misses).putString(STATUS,status).apply();
        if(misses>=MISSES_BEFORE_ASK)ask(c,role,question);
    }

    private static void ask(Context c,String role,String question){
        prefs(c).edit()
                .putString(AWAIT_ROLE,role)
                .putString(STATUS,question)
                .putInt(MISS_COUNT,0)
                .putLong(DEADLINE,System.currentTimeMillis()+TEACHING_SESSION_MS)
                .apply();
        toast(c,question);
    }

    private static boolean recipientVisible(AccessibilityNodeInfo root,String recipient){
        AccessibilityNodeInfo n=findByVisibleText(root,recipient);
        if(n==null)return false;
        n.recycle();
        return true;
    }

    private static boolean hasMessageField(Context c,AccessibilityNodeInfo root,String pkg){
        AccessibilityNodeInfo n=findMessageField(c,root,pkg);
        if(n==null)return false;
        n.recycle();
        return true;
    }

    private static AccessibilityNodeInfo findMessageField(Context c,AccessibilityNodeInfo root,String pkg){
        AccessibilityNodeInfo learned=MessagingLearningStore.find(c,root,pkg,"message_field");
        if(learned!=null&&learned.isEditable())return learned;
        if(learned!=null)learned.recycle();

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

    private static AccessibilityNodeInfo findSearchControl(Context c,AccessibilityNodeInfo root,String pkg){
        AccessibilityNodeInfo learned=MessagingLearningStore.find(c,root,pkg,"search");
        if(learned!=null)return learned;
        return findControl(root,new String[]{"search","find","new chat","new message","compose"},true);
    }

    private static AccessibilityNodeInfo findSendControl(Context c,AccessibilityNodeInfo root,String pkg){
        AccessibilityNodeInfo learned=MessagingLearningStore.find(c,root,pkg,"send");
        if(learned!=null)return learned;
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

    private static AccessibilityNodeInfo findByVisibleText(AccessibilityNodeInfo root,String wanted){
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
            if(contains==null&&(t.contains(w)||d.contains(w)))
                contains=AccessibilityNodeInfo.obtain(n);
            for(int i=0;i<n.getChildCount();i++){
                AccessibilityNodeInfo child=n.getChild(i);
                if(child!=null)q.addLast(child);
            }
            n.recycle();
        }
        return contains;
    }

    private static boolean setText(AccessibilityNodeInfo node,String value){
        if(node==null||!node.isEditable())return false;
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        Bundle b=new Bundle();
        b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,value);
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
                .putString(AWAIT_ROLE,"")
                .putInt(MISS_COUNT,0)
                .putLong(LAST_ACTION,System.currentTimeMillis())
                .apply();
    }

    private static void move(Context c,Stage next,String status){
        prefs(c).edit()
                .putString(STAGE,next.name())
                .putString(STATUS,status)
                .putString(AWAIT_ROLE,"")
                .putInt(MISS_COUNT,0)
                .apply();
    }

    private static void complete(Context c,String status){
        prefs(c).edit()
                .putBoolean(ACTIVE,false)
                .putString(AWAIT_ROLE,"")
                .putString(STAGE,Stage.COMPLETE.name())
                .putString(STATUS,status)
                .apply();
        toast(c,status);
    }

    private static void fail(Context c,String status){
        prefs(c).edit()
                .putBoolean(ACTIVE,false)
                .putString(AWAIT_ROLE,"")
                .putString(STAGE,Stage.FAILED.name())
                .putString(STATUS,status)
                .apply();
        toast(c,status);
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

    private static void toast(Context c,String message){
        new Handler(Looper.getMainLooper()).post(
                ()->Toast.makeText(c,message,Toast.LENGTH_LONG).show());
    }

    private static String safe(Throwable t){
        String m=t.getMessage();
        return m==null||m.trim().isEmpty()?t.getClass().getSimpleName():m;
    }
}
