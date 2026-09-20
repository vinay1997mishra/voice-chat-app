package com.anamika.ai.files;

import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.*;
import java.text.DecimalFormat;
import java.util.*;

public final class AnamikaVault {
    public static final class Entry {
        public final String id,name,mime,path;
        public final long size,addedAt;
        Entry(String id,String name,String mime,String path,long size,long addedAt){
            this.id=id;this.name=name;this.mime=mime;this.path=path;this.size=size;this.addedAt=addedAt;
        }
    }

    private static final String INDEX="vault_index.json";
    private AnamikaVault(){}

    public static File root(Context c){
        File d=new File(c.getFilesDir(),"anamika_vault");
        if(!d.exists()) d.mkdirs();
        return d;
    }

    public static synchronized Entry importUri(Context c,Uri uri) throws Exception{
        if(c==null||uri==null) throw new IllegalArgumentException("File missing.");
        String name=queryName(c,uri);
        String mime=c.getContentResolver().getType(uri);
        if(name==null||name.trim().isEmpty()) name="file_"+System.currentTimeMillis();
        name=safeName(name);
        String id=Long.toHexString(System.currentTimeMillis())+"_"+Integer.toHexString(uri.toString().hashCode());
        File out=uniqueFile(root(c),name);
        long total=0;
        try(InputStream in=c.getContentResolver().openInputStream(uri); OutputStream os=new BufferedOutputStream(new FileOutputStream(out))){
            if(in==null) throw new FileNotFoundException("Cannot open selected file.");
            byte[] b=new byte[256*1024]; int n;
            while((n=in.read(b))>0){
                total+=n;
                if(total>8L*1024L*1024L*1024L) throw new IOException("File exceeds 8 GB vault limit.");
                os.write(b,0,n);
            }
        }catch(Exception e){
            try{out.delete();}catch(Exception ignored){}
            throw e;
        }
        Entry entry=new Entry(id,out.getName(),mime==null?"application/octet-stream":mime,out.getAbsolutePath(),total,System.currentTimeMillis());
        List<Entry> all=load(c); all.add(entry); save(c,all);
        c.getSharedPreferences("anamika_v7",Context.MODE_PRIVATE).edit()
                .putString("last_vault_file",out.getAbsolutePath())
                .putString("last_vault_mime",entry.mime)
                .apply();
        return entry;
    }

    public static synchronized Entry registerGeneratedFile(Context c,File file,String mime){
        if(c==null||file==null||!file.isFile()) throw new IllegalArgumentException("Generated file missing.");
        String id=Long.toHexString(System.currentTimeMillis())+"_"+Integer.toHexString(file.getAbsolutePath().hashCode());
        Entry entry=new Entry(id,file.getName(),mime==null?"application/octet-stream":mime,
                file.getAbsolutePath(),file.length(),System.currentTimeMillis());
        List<Entry> all=load(c);
        all.add(entry);
        save(c,all);
        c.getSharedPreferences("anamika_v7",Context.MODE_PRIVATE).edit()
                .putString("last_vault_file",file.getAbsolutePath())
                .putString("last_vault_mime",entry.mime)
                .apply();
        return entry;
    }

    public static synchronized List<Entry> load(Context c){
        List<Entry> out=new ArrayList<>();
        File idx=new File(root(c),INDEX);
        if(!idx.isFile()) return out;
        try{
            String raw=readAll(idx);
            JSONArray a=new JSONArray(raw);
            for(int i=0;i<a.length();i++){
                JSONObject o=a.optJSONObject(i); if(o==null) continue;
                File f=new File(o.optString("path",""));
                if(!f.isFile()) continue;
                out.add(new Entry(o.optString("id",""),o.optString("name",f.getName()),
                        o.optString("mime","application/octet-stream"),f.getAbsolutePath(),f.length(),o.optLong("addedAt",0)));
            }
        }catch(Exception ignored){}
        return out;
    }

    public static synchronized List<Entry> search(Context c,String query){
        String q=query==null?"":query.trim().toLowerCase(Locale.ROOT);
        List<Entry> out=new ArrayList<>();
        for(Entry e:load(c)){
            if(q.isEmpty()||e.name.toLowerCase(Locale.ROOT).contains(q)||e.mime.toLowerCase(Locale.ROOT).contains(q)) out.add(e);
        }
        return out;
    }

    public static synchronized String summary(Context c){
        List<Entry> all=load(c); long bytes=0;
        int images=0,videos=0,audio=0,other=0;
        for(Entry e:all){
            bytes+=e.size;
            if(e.mime.startsWith("image/")) images++;
            else if(e.mime.startsWith("video/")) videos++;
            else if(e.mime.startsWith("audio/")) audio++;
            else other++;
        }
        return "Personal Space: "+all.size()+" files • "+human(bytes)+" total\n"+
                "Images "+images+" • Videos "+videos+" • Audio "+audio+" • Other "+other;
    }

    public static synchronized boolean moveToTrash(Context c,String nameOrId){
        if(nameOrId==null||nameOrId.trim().isEmpty()) return false;
        String q=nameOrId.trim().toLowerCase(Locale.ROOT);
        List<Entry> all=load(c);
        for(int i=0;i<all.size();i++){
            Entry e=all.get(i);
            if(e.id.equalsIgnoreCase(q)||e.name.toLowerCase(Locale.ROOT).contains(q)){
                File src=new File(e.path);
                File trash=new File(root(c),"trash"); if(!trash.exists()) trash.mkdirs();
                File dst=uniqueFile(trash,src.getName());
                boolean ok=src.renameTo(dst);
                if(!ok){
                    try{copy(src,dst); ok=src.delete();}catch(Exception ignored){}
                }
                if(ok){all.remove(i);save(c,all);return true;}
            }
        }
        return false;
    }

    public static String human(long bytes){
        if(bytes<1024) return bytes+" B";
        final String[] u={"KB","MB","GB","TB"};
        double v=bytes; int i=-1;
        do{v/=1024.0;i++;}while(v>=1024&&i<u.length-1);
        return new DecimalFormat(v>=100?"0":v>=10?"0.0":"0.00").format(v)+" "+u[i];
    }

    private static void save(Context c,List<Entry> all){
        JSONArray a=new JSONArray();
        for(Entry e:all){
            JSONObject o=new JSONObject();
            try{
                o.put("id",e.id);o.put("name",e.name);o.put("mime",e.mime);o.put("path",e.path);
                o.put("size",e.size);o.put("addedAt",e.addedAt);a.put(o);
            }catch(Exception ignored){}
        }
        File idx=new File(root(c),INDEX);
        try(FileOutputStream fos=new FileOutputStream(idx)){fos.write(a.toString(2).getBytes(java.nio.charset.StandardCharsets.UTF_8));}
        catch(Exception ignored){}
    }

    private static String queryName(Context c,Uri uri){
        Cursor cur=null;
        try{
            cur=c.getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME},null,null,null);
            if(cur!=null&&cur.moveToFirst()) return cur.getString(0);
        }catch(Exception ignored){}finally{if(cur!=null)cur.close();}
        String last=uri.getLastPathSegment();
        return last==null?"file":last;
    }

    private static String safeName(String n){return n.replaceAll("[\\\\/:*?\"<>|\\r\\n]","_");}
    private static File uniqueFile(File dir,String name){
        File f=new File(dir,name); if(!f.exists()) return f;
        int dot=name.lastIndexOf('.'); String b=dot>0?name.substring(0,dot):name; String e=dot>0?name.substring(dot):"";
        for(int i=2;i<10000;i++){f=new File(dir,b+"_"+i+e);if(!f.exists())return f;}
        return new File(dir,System.currentTimeMillis()+"_"+name);
    }
    private static String readAll(File f)throws Exception{
        try(InputStream in=new FileInputStream(f);ByteArrayOutputStream out=new ByteArrayOutputStream()){
            byte[] b=new byte[8192];int n;while((n=in.read(b))>0)out.write(b,0,n);
            return out.toString("UTF-8");
        }
    }
    private static void copy(File a,File b)throws Exception{
        try(InputStream in=new FileInputStream(a);OutputStream out=new FileOutputStream(b)){
            byte[] x=new byte[256*1024];int n;while((n=in.read(x))>0)out.write(x,0,n);
        }
    }
}
