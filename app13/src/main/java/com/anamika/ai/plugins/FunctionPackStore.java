package com.anamika.ai.plugins;

import android.content.Context;

import com.anamika.ai.core.AndroidCompat;
import com.anamika.ai.language.LocalLanguageText;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Runtime-loaded declarative function packs.
 *
 * Packs cannot ship Java/Dex/native code. They may only compose a fixed set of
 * already-installed Anamika actions, which keeps hot updates small and prevents
 * packs from replacing or bypassing the core APK.
 */
public final class FunctionPackStore {
    public static final class Validation {
        public final boolean ok;
        public final String message;
        public final String packId;
        Validation(boolean ok,String message,String packId){
            this.ok=ok;this.message=message;this.packId=packId;
        }
    }

    public static final class Match {
        public final String packId;
        public final String functionId;
        public final String functionName;
        public final String reply;
        public final JSONArray actions;
        Match(String packId,String functionId,String functionName,String reply,JSONArray actions){
            this.packId=packId;this.functionId=functionId;this.functionName=functionName;
            this.reply=reply;this.actions=actions;
        }
    }

    private static final int MAX_PACKS=24;
    private static final int MAX_FUNCTIONS_PER_PACK=40;
    private static final int MAX_ACTIONS_PER_FUNCTION=8;
    private static final int MAX_TEXT=4000;

    // Hot packs intentionally exclude self-update/code-generation and raw accessibility
    // tap/type actions. Those remain core-owner workflows, not downloadable macros.
    private static final Set<String> ALLOWED_ACTIONS=new HashSet<>(Arrays.asList(
            "reply","open_app","search_web","open_url","open_settings","open_app_settings",
            "dial","calculate","remember","memory_status","save_file","vault_status",
            "open_plugins","open_components","component_status","autonomy_status","brain_status",
            "diagnostics","self_test","diagnostics_report",
            "scan_app","stop_scan","blueprint_status",
            "research","stop_research","research_status",
            "wake_on","wake_off","health","last_crash","watchdog",
            "upgrade_status","rollback_status","signer_status","device_info"
    ));

    private FunctionPackStore(){}

    public static File root(Context c){
        return new File(c.getFilesDir(),"v13_function_packs");
    }

    public static Validation validatePayload(File payload){
        try{
            File f=new File(payload,"functions.json");
            if(!f.isFile())return new Validation(false,"Function pack missing functions.json.","");
            JSONObject o=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
            if(!"anamika13-function-pack-v1".equals(o.optString("schema","")))
                return new Validation(false,"Unsupported function-pack schema.","");

            String packId=o.optString("pack_id","").trim().toLowerCase(Locale.ROOT);
            if(!validId(packId))return new Validation(false,"Invalid function pack_id.","");

            JSONArray functions=o.optJSONArray("functions");
            if(functions==null||functions.length()==0)
                return new Validation(false,"Function pack has no functions.",packId);
            if(functions.length()>MAX_FUNCTIONS_PER_PACK)
                return new Validation(false,"Function pack has too many functions.",packId);

            HashSet<String> ids=new HashSet<>();
            for(int i=0;i<functions.length();i++){
                JSONObject fn=functions.optJSONObject(i);
                if(fn==null)return new Validation(false,"Function entry "+i+" is invalid.",packId);
                String id=fn.optString("id","").trim().toLowerCase(Locale.ROOT);
                if(!validId(id)||!ids.add(id))
                    return new Validation(false,"Invalid or duplicate function id: "+id,packId);

                JSONArray aliases=fn.optJSONArray("aliases");
                JSONArray prefixes=fn.optJSONArray("prefix_aliases");
                if((aliases==null||aliases.length()==0)&&(prefixes==null||prefixes.length()==0))
                    return new Validation(false,"Function "+id+" needs aliases or prefix_aliases.",packId);
                String triggerError=validateTriggers(aliases,"alias",id);
                if(triggerError==null)triggerError=validateTriggers(prefixes,"prefix alias",id);
                if(triggerError!=null)return new Validation(false,triggerError,packId);

                JSONArray actions=fn.optJSONArray("actions");
                if(actions==null||actions.length()==0||actions.length()>MAX_ACTIONS_PER_FUNCTION)
                    return new Validation(false,"Function "+id+" must contain 1-"+MAX_ACTIONS_PER_FUNCTION+" actions.",packId);
                for(int j=0;j<actions.length();j++){
                    JSONObject action=actions.optJSONObject(j);
                    if(action==null)return new Validation(false,"Bad action in function "+id+".",packId);
                    String a=action.optString("action","").trim().toLowerCase(Locale.ROOT);
                    if(!ALLOWED_ACTIONS.contains(a))
                        return new Validation(false,"Function "+id+" uses blocked/unsupported action: "+a,packId);
                    if(tooLong(action.optString("arg1",""))||tooLong(action.optString("arg2",""))||
                            tooLong(action.optString("text","")))
                        return new Validation(false,"Function "+id+" action text is too long.",packId);
                }
            }
            return new Validation(true,"Function pack validation PASS.",packId);
        }catch(Exception e){
            return new Validation(false,"Function pack validation failed: "+safe(e),"");
        }
    }

    public static Match match(Context c,String raw){
        String input=raw==null?"":raw.trim();
        if(input.isEmpty())return null;
        String normalized=norm(input);
        ArrayList<JSONObject> functions=allFunctions(c);
        Match best=null;
        int bestScore=-1;

        for(JSONObject wrapper:functions){
            JSONObject fn=wrapper.optJSONObject("function");
            if(fn==null)continue;
            String packId=wrapper.optString("pack_id","");
            String fnId=fn.optString("id","");
            String fnName=fn.optString("name",fnId);

            JSONArray aliases=fn.optJSONArray("aliases");
            if(aliases!=null){
                for(int i=0;i<aliases.length();i++){
                    String alias=norm(aliases.optString(i,""));
                    if(!alias.isEmpty()&&normalized.equals(alias)){
                        Match m=buildMatch(packId,fn,fnName,input);
                        int score=10000+alias.length();
                        if(m!=null&&score>bestScore){best=m;bestScore=score;}
                    }
                }
            }

            JSONArray prefixes=fn.optJSONArray("prefix_aliases");
            if(prefixes!=null){
                for(int i=0;i<prefixes.length();i++){
                    String prefix=norm(prefixes.optString(i,""));
                    if(prefix.isEmpty())continue;
                    if(normalized.startsWith(prefix+" ")){
                        String tail=normalized.substring(prefix.length()).trim();
                        Match m=buildMatch(packId,fn,fnName,tail);
                        int score=5000+prefix.length();
                        if(m!=null&&score>bestScore){best=m;bestScore=score;}
                    }
                }
            }
        }
        return best;
    }

    public static Match byId(Context c,String id,String input){
        String wanted=id==null?"":id.trim().toLowerCase(Locale.ROOT);
        if(wanted.isEmpty())return null;
        for(JSONObject wrapper:allFunctions(c)){
            JSONObject fn=wrapper.optJSONObject("function");
            if(fn==null)continue;
            if(wanted.equals(fn.optString("id","").toLowerCase(Locale.ROOT))){
                String name=fn.optString("name",wanted);
                return buildMatch(wrapper.optString("pack_id",""),fn,name,input==null?"":input);
            }
        }
        return null;
    }

    public static String catalog(Context c){
        StringBuilder b=new StringBuilder();
        int count=0;
        for(JSONObject wrapper:allFunctions(c)){
            if(count++>=60)break;
            JSONObject fn=wrapper.optJSONObject("function");
            if(fn==null)continue;
            b.append(fn.optString("id",""))
                    .append(" | ").append(fn.optString("name",fn.optString("id","")));
            String d=fn.optString("description","").trim();
            if(!d.isEmpty())b.append(" | ").append(d);
            b.append("\n");
        }
        return b.length()==0?"(no function packs installed)":b.toString();
    }

    public static String status(Context c){
        File r=root(c);
        File[] packs=r.listFiles(File::isDirectory);
        int packCount=0,fnCount=0;
        if(packs!=null){
            for(File p:packs){
                if(!new File(p,"functions.json").isFile())continue;
                packCount++;
                try{
                    JSONObject o=new JSONObject(AndroidCompat.readText(new File(p,"functions.json"),StandardCharsets.UTF_8));
                    JSONArray f=o.optJSONArray("functions");
                    if(f!=null)fnCount+=f.length();
                }catch(Exception ignored){}
            }
        }
        return "Function packs: "+packCount+" pack(s), "+fnCount+" function(s)";
    }

    public static String packVersion(File packDir){
        File f=new File(packDir,"component.version");
        if(!f.isFile())return "installed";
        try{
            String s=AndroidCompat.readText(f,StandardCharsets.UTF_8).trim();
            return s.isEmpty()?"installed":s;
        }catch(Exception e){return "installed";}
    }

    private static Match buildMatch(String packId,JSONObject fn,String fnName,String input){
        JSONArray src=fn.optJSONArray("actions");
        if(src==null||src.length()==0)return null;
        JSONArray out=new JSONArray();
        for(int i=0;i<src.length();i++){
            JSONObject a=src.optJSONObject(i);
            if(a==null)continue;
            String action=a.optString("action","").trim().toLowerCase(Locale.ROOT);
            if(!ALLOWED_ACTIONS.contains(action))return null;
            JSONObject x=new JSONObject();
            try{
                x.put("action",action);
                x.put("arg1",subst(a.optString("arg1",""),input));
                x.put("arg2",subst(a.optString("arg2",""),input));
                x.put("text",subst(a.optString("text",""),input));
                out.put(x);
            }catch(Exception e){return null;}
        }
        String reply=subst(fn.optString("reply",""),input);
        return new Match(packId,fn.optString("id",""),fnName,reply,out);
    }

    private static ArrayList<JSONObject> allFunctions(Context c){
        ArrayList<JSONObject> out=new ArrayList<>();
        File r=root(c);
        File[] packs=r.listFiles(File::isDirectory);
        if(packs==null)return out;
        int pcount=0;
        for(File p:packs){
            if(pcount++>=MAX_PACKS)break;
            File f=new File(p,"functions.json");
            if(!f.isFile())continue;
            try{
                JSONObject root=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
                JSONArray functions=root.optJSONArray("functions");
                if(functions==null)continue;
                int count=Math.min(MAX_FUNCTIONS_PER_PACK,functions.length());
                for(int i=0;i<count;i++){
                    JSONObject fn=functions.optJSONObject(i);
                    if(fn==null)continue;
                    JSONObject w=new JSONObject();
                    w.put("pack_id",root.optString("pack_id",p.getName()));
                    w.put("function",fn);
                    out.add(w);
                }
            }catch(Exception ignored){}
        }
        return out;
    }

    private static String validateTriggers(JSONArray arr,String kind,String id){
        if(arr==null)return null;
        if(arr.length()>20)return "Function "+id+" has too many "+kind+" entries.";
        for(int i=0;i<arr.length();i++){
            String s=arr.optString(i,"").trim();
            if(s.length()<3||s.length()>120)return "Function "+id+" has invalid "+kind+".";
        }
        return null;
    }

    private static boolean validId(String s){
        return s!=null&&s.matches("[a-z0-9][a-z0-9._-]{0,63}");
    }

    private static String norm(String s){
        return LocalLanguageText.intentHint(s==null?"":s).toLowerCase(Locale.ROOT)
                .replaceAll("\\s+"," ").trim();
    }

    private static String subst(String template,String input){
        String t=template==null?"":template;
        String v=input==null?"":input;
        String out=t.replace("$input",v);
        return out.length()>MAX_TEXT?out.substring(0,MAX_TEXT):out;
    }

    private static boolean tooLong(String s){return s!=null&&s.length()>MAX_TEXT;}

    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
