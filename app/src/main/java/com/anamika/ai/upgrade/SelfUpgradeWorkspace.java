package com.anamika.ai.upgrade;

import android.content.Context;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;
import com.anamika.ai.OfflineCodeValidator;
import com.anamika.ai.CompilerPackManager;
import java.util.Date;
import java.util.Locale;

/**
 * Extracts the immutable build-time source snapshot shipped with Anamika into a
 * versioned private workspace. Existing workspaces are retained for review/rollback.
 */
public final class SelfUpgradeWorkspace {
    private SelfUpgradeWorkspace(){ }

    public static File prepare(Context c,String request)throws Exception{
        File base=new File(c.getFilesDir(),"self_upgrade");
        if(!base.exists()&&!base.mkdirs()) throw new IllegalStateException("Cannot create self-upgrade storage");
        String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(new Date());
        File root=new File(base,"workspace_"+stamp);
        if(!root.mkdirs()) throw new IllegalStateException("Cannot create self-upgrade workspace");
        boolean ok=false;
        try{
            copyAssetTree(c.getAssets(),"self_source",root);
            write(new File(root,"OWNER_UPGRADE_REQUEST.txt"),request==null?"":request);
            write(new File(root,"WORKSPACE_INFO.txt"),
                    "Created: "+new Date()+"\n"+
                    "Source: immutable snapshot bundled in the currently installed Anamika APK.\n"+
                    "Rule: generated changes require validation + owner approval + a separately built/signed APK before installation.\n");
            write(new File(base,"LATEST_WORKSPACE.txt"),root.getAbsolutePath()+"\n");
            pruneOldWorkspaces(base,8,root);
            ok=true;
            return root;
        } finally {
            if(!ok) delete(root);
        }
    }

    public static String sourceContext(File workspace,int maxChars)throws Exception{
        if(workspace==null||!workspace.isDirectory()) return "";
        int cap=Math.max(8000,Math.min(maxChars,120000));
        List<File> all=new ArrayList<>();
        collectTextFiles(workspace,all);
        all.sort((a,b)->Integer.compare(priority(a.getName()),priority(b.getName())));
        StringBuilder out=new StringBuilder();
        for(File f:all){
            if(out.length()>=cap) break;
            String rel=relative(workspace,f);
            if(rel.startsWith("candidate_source/")) continue;
            String text=readText(f,Math.min(20000,cap-out.length()));
            if(text.isEmpty()) continue;
            out.append("\n<<<CURRENT_FILE:").append(rel).append(">>>\n")
                    .append(text).append("\n<<<END CURRENT FILE>>>\n");
        }
        if(out.length()>cap) out.setLength(cap);
        return out.toString();
    }

    public static File saveVerifiedCandidate(Context c,File workspace,String generatedText)throws Exception{
        if(workspace==null||!workspace.isDirectory()) throw new IllegalArgumentException("Self-upgrade workspace missing.");
        OfflineCodeValidator.Report vr=OfflineCodeValidator.validateGeneratedText(generatedText);
        if(!vr.isClean()) throw new IllegalStateException("Candidate structural validation failed. "+vr.details());
        CompilerPackManager.Report cr=CompilerPackManager.verifyGeneratedText(c,generatedText);
        if(!cr.isFullyVerified()) throw new IllegalStateException("Candidate compiler verification incomplete. "+cr.details());
        Map<String,String> files=OfflineCodeValidator.parse(generatedText);
        if(files.isEmpty()) throw new IllegalStateException("No generated file blocks found.");

        File dest=new File(workspace,"candidate_source");
        if(dest.exists()) delete(dest);
        if(!dest.mkdirs()) throw new IllegalStateException("Cannot create candidate_source.");

        String root=dest.getCanonicalPath()+File.separator;
        for(Map.Entry<String,String> e:files.entrySet()){
            String safe=safeRelative(e.getKey());
            File out=new File(dest,safe);
            String canon=out.getCanonicalPath();
            if(!canon.startsWith(root)) throw new SecurityException("Candidate path escaped workspace.");
            File parent=out.getParentFile();
            if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create candidate folder.");
            write(out,e.getValue()==null?"":e.getValue());
        }
        write(new File(workspace,"CANDIDATE_VERIFICATION.txt"),
                "STRUCTURAL\n"+vr.details()+"\n\nCOMPILER\n"+cr.details()+"\n");
        write(new File(workspace,"CANDIDATE_GENERATION.txt"),generatedText==null?"":generatedText);
        return dest;
    }

    private static void collectTextFiles(File f,List<File> out){
        if(f==null||!f.exists()) return;
        if(f.isFile()){
            String n=f.getName().toLowerCase(Locale.ROOT);
            if(n.endsWith(".java")||n.endsWith(".kt")||n.endsWith(".xml")||n.endsWith(".gradle")||
                    n.endsWith(".json")||n.endsWith(".txt")||n.endsWith(".properties")||
                    n.endsWith(".py")||n.endsWith(".md")) out.add(f);
            return;
        }
        File[] children=f.listFiles();
        if(children!=null) for(File x:children) collectTextFiles(x,out);
    }

    private static int priority(String n){
        String s=n==null?"":n.toLowerCase(Locale.ROOT);
        if(s.equals("mainactivity.java")) return 0;
        if(s.contains("universallanguagerouter")) return 1;
        if(s.contains("selfupgradeworkspace")) return 2;
        if(s.contains("standalonedeveloperengine")) return 3;
        if(s.equals("androidmanifest.xml")) return 4;
        if(s.endsWith(".gradle")) return 5;
        return 20;
    }

    private static String relative(File root,File f)throws Exception{
        String rp=root.getCanonicalPath();
        String fp=f.getCanonicalPath();
        if(fp.startsWith(rp+File.separator)) return fp.substring(rp.length()+1).replace('\\','/');
        return f.getName();
    }

    private static String readText(File f,int cap)throws Exception{
        byte[] data=java.nio.file.Files.readAllBytes(f.toPath());
        String s=new String(data,StandardCharsets.UTF_8);
        return s.length()>cap?s.substring(0,cap):s;
    }

    private static String safeRelative(String raw){
        String p=raw==null?"":raw.trim().replace('\\','/');
        if(p.isEmpty()||p.startsWith("/")||p.contains("\u0000")) throw new SecurityException("Unsafe candidate path.");
        StringBuilder b=new StringBuilder();
        for(String part:p.split("/")){
            if(part.isEmpty()||".".equals(part)) continue;
            if("..".equals(part)) throw new SecurityException("Parent traversal not allowed.");
            if(b.length()>0)b.append('/');
            b.append(part);
        }
        if(b.length()==0) throw new SecurityException("Unsafe candidate path.");
        return b.toString();
    }

    private static void copyAssetTree(AssetManager a,String path,File dest)throws Exception{
        String[] children=a.list(path);
        if(children!=null&&children.length>0){
            if(!dest.exists()&&!dest.mkdirs()) throw new IllegalStateException("Cannot create workspace folder");
            for(String ch:children) copyAssetTree(a,path+"/"+ch,new File(dest,ch));
            return;
        }
        File parent=dest.getParentFile(); if(parent!=null&&!parent.exists()&&!parent.mkdirs()) throw new IllegalStateException("Cannot create workspace folder");
        try(InputStream in=a.open(path); FileOutputStream out=new FileOutputStream(dest)){
            byte[] buf=new byte[65536]; int n; while((n=in.read(buf))>0) out.write(buf,0,n);
        }
    }

    private static void pruneOldWorkspaces(File base,int keep,File current){
        File[] all=base.listFiles(f->f.isDirectory()&&f.getName().startsWith("workspace_")&&!f.equals(current));
        if(all==null||all.length<=keep-1)return;
        java.util.Arrays.sort(all,(a,b)->Long.compare(b.lastModified(),a.lastModified()));
        for(int i=Math.max(0,keep-1);i<all.length;i++) delete(all[i]);
    }

    private static void write(File file,String text)throws Exception{
        try(FileOutputStream o=new FileOutputStream(file)){o.write(text.getBytes(StandardCharsets.UTF_8));}
    }
    private static void delete(File f){ if(f==null||!f.exists())return; if(f.isDirectory()){File[] a=f.listFiles();if(a!=null)for(File x:a)delete(x);} try{f.delete();}catch(Exception ignored){} }
}
