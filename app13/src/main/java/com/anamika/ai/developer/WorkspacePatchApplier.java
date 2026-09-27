package com.anamika.ai.developer;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/**
 * Applies a local coding model's JSON edit plan only inside the prepared upgrade workspace.
 * Supported operations: write, delete.
 */
public final class WorkspacePatchApplier {
    public static final class Result{
        public final boolean ok;
        public final int applied;
        public final String message;
        Result(boolean ok,int applied,String message){this.ok=ok;this.applied=applied;this.message=message;}
    }

    private WorkspacePatchApplier(){}

    public static Result apply(File workspace,String json){
        try{
            JSONObject root=new JSONObject(json);
            if(!"anamika13-edit-plan-v1".equals(root.optString("schema","")))
                return new Result(false,0,"Offline brain returned unsupported edit-plan schema.");
            JSONArray edits=root.optJSONArray("edits");
            if(edits==null||edits.length()==0)return new Result(false,0,"Offline brain returned no edits.");

            int applied=0;
            for(int i=0;i<edits.length();i++){
                JSONObject e=edits.getJSONObject(i);
                String op=e.optString("op","");
                String path=e.optString("path","");
                File target=safeChild(workspace,path);
                if("write".equals(op)){
                    String content=e.optString("content","");
                    File parent=target.getParentFile();
                    if(parent!=null&&!parent.exists()&&!parent.mkdirs())
                        return new Result(false,applied,"Cannot create "+parent);
                    try(FileOutputStream out=new FileOutputStream(target,false)){
                        out.write(content.getBytes(StandardCharsets.UTF_8));
                        out.getFD().sync();
                    }
                    applied++;
                }else if("delete".equals(op)){
                    if(target.exists()&&!deleteTree(target))
                        return new Result(false,applied,"Cannot delete "+path);
                    applied++;
                }else{
                    return new Result(false,applied,"Unsupported edit operation: "+op);
                }
            }
            return new Result(true,applied,"Applied "+applied+" offline code edit(s).");
        }catch(Exception e){
            return new Result(false,0,"Edit plan apply failed: "+safe(e));
        }
    }

    private static File safeChild(File root,String rel)throws Exception{
        if(rel==null||rel.trim().isEmpty()||rel.startsWith("/")||rel.contains("../")||rel.contains("..\\"))
            throw new IllegalArgumentException("Unsafe workspace path.");
        File f=new File(root,rel);
        String rp=root.getCanonicalPath();
        String fp=f.getCanonicalPath();
        if(!fp.startsWith(rp+File.separator))
            throw new IllegalArgumentException("Edit escaped workspace.");
        return f;
    }

    private static boolean deleteTree(File f){
        boolean ok=true;
        if(f.isDirectory()){
            File[] children=f.listFiles();
            if(children!=null)for(File c:children)ok&=deleteTree(c);
        }
        return !f.exists()||f.delete()&&ok;
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
