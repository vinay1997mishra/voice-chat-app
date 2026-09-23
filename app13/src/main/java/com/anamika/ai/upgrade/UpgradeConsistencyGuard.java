package com.anamika.ai.upgrade;

import com.anamika.ai.core.AndroidCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Prevents accidental parallel copies of an existing implementation.
 *
 * This is intentionally conservative: real Java/Kotlin compilation remains the
 * final authority, but obvious duplicate FQCNs, shadow-copy filenames and
 * duplicate Function Pack identities are rejected before a candidate build.
 */
public final class UpgradeConsistencyGuard {
    public static final class Report {
        public final boolean clean;
        public final List<String> problems;
        Report(boolean clean,List<String> problems){
            this.clean=clean;this.problems=problems;
        }
    }

    private static final Pattern PACKAGE=Pattern.compile("(?m)^\\s*package\\s+([A-Za-z0-9_.]+)\\s*;");
    private static final Pattern JAVA_TYPE=Pattern.compile(
            "(?m)\\b(?:public\\s+|protected\\s+|private\\s+)?(?:final\\s+|abstract\\s+)?(?:class|interface|enum|record)\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\b");
    private static final Pattern KOTLIN_PACKAGE=Pattern.compile("(?m)^\\s*package\\s+([A-Za-z0-9_.]+)\\s*$");
    private static final Pattern KOTLIN_TYPE=Pattern.compile(
            "(?m)\\b(?:class|interface|object|enum\\s+class|data\\s+class|sealed\\s+class)\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\b");

    private UpgradeConsistencyGuard(){}

    public static Report inspect(File root){
        List<String> problems=new ArrayList<>();
        if(root==null||!root.isDirectory()){
            problems.add("Workspace missing.");
            return new Report(false,problems);
        }

        Map<String,String> fqcnToPath=new HashMap<>();
        Map<String,Set<String>> packageFiles=new HashMap<>();
        Map<String,String> functionOwner=new HashMap<>();
        walk(root,root,fqcnToPath,packageFiles,functionOwner,problems);
        detectShadowCopies(packageFiles,problems);
        checkCriticalFiles(root,problems);
        return new Report(problems.isEmpty(),problems);
    }

    private static void walk(
            File root,File f,Map<String,String> fqcnToPath,Map<String,Set<String>> packageFiles,
            Map<String,String> functionOwner,List<String> problems){
        if(f==null||!f.exists())return;
        if(f.getName().startsWith(".anamika_"))return;
        if(f.isDirectory()){
            File[] kids=f.listFiles();
            if(kids!=null)for(File k:kids)walk(root,k,fqcnToPath,packageFiles,functionOwner,problems);
            return;
        }

        String n=f.getName().toLowerCase(Locale.ROOT);
        try{
            String rel=relative(root,f);
            if(n.endsWith(".java")||n.endsWith(".kt")){
                String s=AndroidCompat.readText(f,StandardCharsets.UTF_8);
                Pattern pp=n.endsWith(".java")?PACKAGE:KOTLIN_PACKAGE;
                Pattern tp=n.endsWith(".java")?JAVA_TYPE:KOTLIN_TYPE;
                Matcher pm=pp.matcher(s);
                String pkg=pm.find()?pm.group(1):"";
                Matcher tm=tp.matcher(s);
                if(tm.find()){
                    String type=tm.group(1);
                    String fqcn=pkg.isEmpty()?type:pkg+"."+type;
                    String prior=fqcnToPath.put(fqcn,rel);
                    if(prior!=null&&!prior.equals(rel))
                        problems.add("Duplicate type "+fqcn+" in "+prior+" and "+rel+".");
                    String key=pkg;
                    Set<String> files=packageFiles.get(key);
                    if(files==null){files=new HashSet<>();packageFiles.put(key,files);}
                    files.add(type);
                }
            }else if(n.equals("functions.json")){
                inspectFunctionPack(f,rel,functionOwner,problems);
            }
        }catch(Exception e){
            problems.add(f.getName()+": consistency check failed ("+safe(e)+")");
        }
    }

    private static void inspectFunctionPack(
            File f,String rel,Map<String,String> functionOwner,List<String> problems)throws Exception{
        JSONObject root=new JSONObject(AndroidCompat.readText(f,StandardCharsets.UTF_8));
        if(!"anamika13-function-pack-v1".equals(root.optString("schema","")))return;
        String pack=root.optString("pack_id",rel).trim().toLowerCase(Locale.ROOT);
        JSONArray functions=root.optJSONArray("functions");
        if(functions==null)return;
        Set<String> local=new HashSet<>();
        for(int i=0;i<functions.length();i++){
            JSONObject fn=functions.optJSONObject(i);
            if(fn==null)continue;
            String id=fn.optString("id","").trim().toLowerCase(Locale.ROOT);
            if(id.isEmpty())continue;
            if(!local.add(id))problems.add("Duplicate function id "+id+" inside pack "+pack+".");
            String identity=pack+"/"+id;
            String prior=functionOwner.put(identity,rel);
            if(prior!=null&&!prior.equals(rel))
                problems.add("Duplicate Function Pack identity "+identity+" in "+prior+" and "+rel+".");
        }
    }

    private static void detectShadowCopies(Map<String,Set<String>> packageFiles,List<String> problems){
        String[] suffixes={"V2","V3","New","Copy","Updated","Fixed","Latest","Backup"};
        for(Map.Entry<String,Set<String>> e:packageFiles.entrySet()){
            Set<String> types=e.getValue();
            for(String t:types){
                for(String suffix:suffixes){
                    if(t.endsWith(suffix)&&t.length()>suffix.length()){
                        String base=t.substring(0,t.length()-suffix.length());
                        if(types.contains(base))
                            problems.add("Possible duplicate implementation: "+base+" and "+t+
                                    " exist in package "+e.getKey()+". Update the existing implementation instead of copying it.");
                    }
                }
            }
        }
    }

    private static void checkCriticalFiles(File root,List<String> problems){
        String[] required={
                "app13/build.gradle",
                "app13/src/main/AndroidManifest.xml",
                "app13/src/main/java/com/anamika/ai/MainActivity.java",
                "app13/src/main/java/com/anamika/ai/CommandRouter.java",
                "app13/src/main/java/com/anamika/ai/BrainCommandEngine.java",
                "app13/src/main/java/com/anamika/ai/components/ComponentPackManager.java",
                "app13/src/main/java/com/anamika/ai/upgrade/UpgradeCoordinator.java"
        };
        for(String rel:required)if(!new File(root,rel).isFile())
            problems.add("Critical existing function file is missing: "+rel);
    }

    private static String relative(File root,File f)throws Exception{
        String rp=root.getCanonicalPath(),fp=f.getCanonicalPath();
        if(fp.startsWith(rp+File.separator))
            return fp.substring(rp.length()+1).replace('\\','/');
        return f.getName();
    }

    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
