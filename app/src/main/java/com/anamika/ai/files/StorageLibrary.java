package com.anamika.ai.files;

import android.content.Context;
import android.net.Uri;
import android.os.Environment;
import androidx.documentfile.provider.DocumentFile;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class StorageLibrary {
    private static final String PREFS="anamika_storage";
    private static final String TREE="tree_uri";
    private static final int MAX_SCAN=50000;

    public static final class Item {
        public final String name,mime,location;
        public final long size;
        public final Uri uri;
        Item(String name,String mime,long size,String location,Uri uri){
            this.name=name;this.mime=mime;this.size=size;this.location=location;this.uri=uri;
        }
        public String line(){
            return name+" • "+AnamikaVault.human(size)+" • "+(mime==null?"file":mime);
        }
    }

    private StorageLibrary(){}

    public static void saveTree(Context c,Uri uri){
        if(c==null||uri==null)return;
        c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().putString(TREE,uri.toString()).apply();
    }

    public static Uri getTree(Context c){
        String raw=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(TREE,"");
        try{return raw.isEmpty()?null:Uri.parse(raw);}catch(Exception e){return null;}
    }

    public static boolean hasPersistentTree(Context c){
        Uri wanted=getTree(c); if(wanted==null)return false;
        for(android.content.UriPermission p:c.getContentResolver().getPersistedUriPermissions()){
            if(p.isReadPermission() && wanted.equals(p.getUri())) return true;
        }
        return false;
    }

    public static boolean hasAllFilesAccess(){
        return android.os.Build.VERSION.SDK_INT<30 || Environment.isExternalStorageManager();
    }

    public static List<Item> search(Context c,String query,int limit){
        int cap=Math.max(1,Math.min(limit,500));
        String q=query==null?"":query.trim().toLowerCase(Locale.ROOT);
        List<Item> out=new ArrayList<>();
        Counter counter=new Counter();
        if(hasAllFilesAccess()){
            File root=Environment.getExternalStorageDirectory();
            scanFile(root,q,out,cap,counter);
        }else{
            Uri tree=getTree(c);
            if(tree!=null){
                DocumentFile root=DocumentFile.fromTreeUri(c,tree);
                if(root!=null) scanDoc(root,q,out,cap,counter);
            }
        }
        return out;
    }

    public static String summary(Context c){
        Counter counter=new Counter();
        if(hasAllFilesAccess()){
            scanCount(Environment.getExternalStorageDirectory(),counter);
            return "Storage access: All-files mode\nIndexed "+counter.files+" files • "+AnamikaVault.human(counter.bytes)+
                    (counter.capped?" • scan capped at "+MAX_SCAN:"");
        }
        Uri tree=getTree(c);
        if(tree==null) return "Storage access: no persistent folder selected.";
        DocumentFile root=DocumentFile.fromTreeUri(c,tree);
        if(root==null) return "Storage access: saved folder is unavailable.";
        scanDocCount(root,counter);
        return "Storage access: persistent folder\nIndexed "+counter.files+" files • "+AnamikaVault.human(counter.bytes)+
                (counter.capped?" • scan capped at "+MAX_SCAN:"");
    }

    private static void scanFile(File f,String q,List<Item> out,int limit,Counter count){
        if(f==null||out.size()>=limit||count.files>=MAX_SCAN)return;
        if(f.isFile()){
            count.files++;count.bytes+=Math.max(0,f.length());
            if(q.isEmpty()||f.getName().toLowerCase(Locale.ROOT).contains(q)){
                out.add(new Item(f.getName(),guessMime(f.getName()),f.length(),f.getAbsolutePath(),Uri.fromFile(f)));
            }
            return;
        }
        File[] list;
        try{list=f.listFiles();}catch(Throwable t){return;}
        if(list==null)return;
        for(File x:list){
            if(out.size()>=limit||count.files>=MAX_SCAN){count.capped=true;return;}
            // Android blocks some private app sandboxes even with broad storage access.
            String p=x.getAbsolutePath();
            if(p.contains("/Android/data/")||p.contains("/Android/obb/")) continue;
            scanFile(x,q,out,limit,count);
        }
    }

    private static void scanDoc(DocumentFile f,String q,List<Item> out,int limit,Counter count){
        if(f==null||out.size()>=limit||count.files>=MAX_SCAN)return;
        if(f.isFile()){
            count.files++;count.bytes+=Math.max(0,f.length());
            String n=f.getName()==null?"file":f.getName();
            if(q.isEmpty()||n.toLowerCase(Locale.ROOT).contains(q)){
                out.add(new Item(n,f.getType(),f.length(),f.getUri().toString(),f.getUri()));
            }
            return;
        }
        DocumentFile[] list;
        try{list=f.listFiles();}catch(Throwable t){return;}
        for(DocumentFile x:list){
            if(out.size()>=limit||count.files>=MAX_SCAN){count.capped=true;return;}
            scanDoc(x,q,out,limit,count);
        }
    }

    private static void scanCount(File f,Counter c){
        if(f==null||c.files>=MAX_SCAN)return;
        if(f.isFile()){c.files++;c.bytes+=Math.max(0,f.length());return;}
        File[] list;try{list=f.listFiles();}catch(Throwable t){return;}if(list==null)return;
        for(File x:list){
            if(c.files>=MAX_SCAN){c.capped=true;return;}
            String p=x.getAbsolutePath();
            if(p.contains("/Android/data/")||p.contains("/Android/obb/"))continue;
            scanCount(x,c);
        }
    }

    private static void scanDocCount(DocumentFile f,Counter c){
        if(f==null||c.files>=MAX_SCAN)return;
        if(f.isFile()){c.files++;c.bytes+=Math.max(0,f.length());return;}
        DocumentFile[] list;try{list=f.listFiles();}catch(Throwable t){return;}
        for(DocumentFile x:list){if(c.files>=MAX_SCAN){c.capped=true;return;}scanDocCount(x,c);}
    }

    private static String guessMime(String n){
        String x=n.toLowerCase(Locale.ROOT);
        if(x.matches(".*\\.(jpg|jpeg|png|webp|gif|heic)$"))return "image/*";
        if(x.matches(".*\\.(mp4|mkv|mov|webm|avi|3gp)$"))return "video/*";
        if(x.matches(".*\\.(mp3|wav|m4a|aac|ogg|flac)$"))return "audio/*";
        if(x.endsWith(".pdf"))return "application/pdf";
        if(x.matches(".*\\.(txt|md|json|xml|csv|log|java|kt|py|js|ts|html|css)$"))return "text/*";
        return "application/octet-stream";
    }

    private static final class Counter{long files=0,bytes=0;boolean capped=false;}
}
