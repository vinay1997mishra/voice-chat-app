package com.anamika.ai.messaging;

import android.content.Context;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONObject;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;

/**
 * Per-app learned UI selectors taught by the owner.
 * Stores only Accessibility metadata (view id/class/text/description), never app-private data.
 */
public final class MessagingLearningStore {
    private static final String PREF="anamika13_messaging_learning";

    private MessagingLearningStore(){}

    public static String learn(Context c,String pkg,String role,AccessibilityNodeInfo node){
        if(pkg==null||pkg.isEmpty()||role==null||role.isEmpty()||node==null)
            return "Learning data missing.";
        try{
            AccessibilityNodeInfo best=pickUsefulNode(node,role);
            if(best==null)return "I could not identify that control.";
            try{
                JSONObject o=new JSONObject()
                        .put("view_id",text(best.getViewIdResourceName()))
                        .put("class",text(best.getClassName()))
                        .put("text",text(best.getText()))
                        .put("desc",text(best.getContentDescription()))
                        .put("editable",best.isEditable())
                        .put("clickable",best.isClickable())
                        .put("learned_ms",System.currentTimeMillis());
                c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                        .putString(key(pkg,role),o.toString()).apply();
                return "Learned "+role+" for "+pkg+".";
            }finally{
                best.recycle();
            }
        }catch(Exception e){
            return "Could not save learned control: "+safe(e);
        }
    }

    public static AccessibilityNodeInfo find(Context c,AccessibilityNodeInfo root,String pkg,String role){
        if(root==null||pkg==null||role==null)return null;
        String raw=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(key(pkg,role),"");
        if(raw.isEmpty())return null;
        try{
            JSONObject o=new JSONObject(raw);
            Deque<AccessibilityNodeInfo> q=new ArrayDeque<>();
            q.add(AccessibilityNodeInfo.obtain(root));
            AccessibilityNodeInfo best=null;
            int bestScore=0;
            while(!q.isEmpty()){
                AccessibilityNodeInfo n=q.removeFirst();
                int score=score(n,o,role);
                if(score>bestScore){
                    if(best!=null)best.recycle();
                    best=AccessibilityNodeInfo.obtain(n);
                    bestScore=score;
                }
                for(int i=0;i<n.getChildCount();i++){
                    AccessibilityNodeInfo child=n.getChild(i);
                    if(child!=null)q.addLast(child);
                }
                n.recycle();
            }
            return bestScore>=5?best:recycleAndNull(best);
        }catch(Exception e){
            return null;
        }
    }

    public static boolean has(Context c,String pkg,String role){
        return c.getSharedPreferences(PREF,Context.MODE_PRIVATE).contains(key(pkg,role));
    }

    public static void clearPackage(Context c,String pkg){
        android.content.SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        android.content.SharedPreferences.Editor e=p.edit();
        for(String role:new String[]{"search","message_field","send","recipient_row"})
            e.remove(key(pkg,role));
        e.apply();
    }

    private static AccessibilityNodeInfo pickUsefulNode(AccessibilityNodeInfo source,String role){
        AccessibilityNodeInfo current=AccessibilityNodeInfo.obtain(source);
        if("message_field".equals(role)){
            for(int depth=0;depth<5&&current!=null;depth++){
                if(current.isEditable())return current;
                AccessibilityNodeInfo parent=current.getParent();
                current.recycle();
                current=parent;
            }
            return current;
        }
        for(int depth=0;depth<5&&current!=null;depth++){
            if(current.isClickable()||!text(current.getViewIdResourceName()).isEmpty())
                return current;
            AccessibilityNodeInfo parent=current.getParent();
            current.recycle();
            current=parent;
        }
        return current;
    }

    private static int score(AccessibilityNodeInfo n,JSONObject o,String role){
        String learnedId=o.optString("view_id","");
        String learnedClass=o.optString("class","");
        String learnedText=o.optString("text","");
        String learnedDesc=o.optString("desc","");
        int score=0;

        String id=text(n.getViewIdResourceName());
        String clazz=text(n.getClassName());
        String txt=text(n.getText());
        String desc=text(n.getContentDescription());

        if(!learnedId.isEmpty()&&learnedId.equals(id))score+=8;
        if(!learnedClass.isEmpty()&&learnedClass.equals(clazz))score+=2;
        if(!learnedText.isEmpty()&&learnedText.equalsIgnoreCase(txt))score+=4;
        if(!learnedDesc.isEmpty()&&learnedDesc.equalsIgnoreCase(desc))score+=4;
        if(o.optBoolean("editable",false)==n.isEditable())score+=1;
        if(o.optBoolean("clickable",false)==n.isClickable())score+=1;

        if("message_field".equals(role)&&!n.isEditable())score-=10;
        if(("search".equals(role)||"send".equals(role)||"recipient_row".equals(role))&&!n.isEnabled())score-=5;
        return score;
    }

    private static String key(String pkg,String role){
        return pkg+"::"+role.toLowerCase(Locale.ROOT);
    }

    private static AccessibilityNodeInfo recycleAndNull(AccessibilityNodeInfo n){
        if(n!=null)n.recycle();
        return null;
    }

    private static String text(CharSequence s){return s==null?"":s.toString();}
    private static String text(String s){return s==null?"":s;}
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
