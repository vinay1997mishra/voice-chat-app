package com.anamika.toolchain;

import java.io.*;
import java.util.*;
import java.util.zip.*;

public final class ZipInjector {
    private static final int BUF=128*1024;

    public static void main(String[] args) throws Exception {
        if(args.length<3||args.length>5)
            throw new IllegalArgumentException("usage: ZipInjector <base.apk> <classes.dex> <output.apk> [assetsDir] [jniArm64Dir]");
        File base=new File(args[0]), dex=new File(args[1]), out=new File(args[2]);
        File assets=args.length>=4?new File(args[3]):null;
        File jni=args.length>=5?new File(args[4]):null;
        if(!base.isFile()||!dex.isFile())throw new FileNotFoundException("APK or classes.dex missing");
        File parent=out.getParentFile(); if(parent!=null)parent.mkdirs();

        byte[] buffer=new byte[BUF];
        Set<String> seen=new HashSet<>();
        try(ZipInputStream zin=new ZipInputStream(new BufferedInputStream(new FileInputStream(base)));
            ZipOutputStream zout=new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(out)))) {
            ZipEntry e;
            while((e=zin.getNextEntry())!=null){
                String name=e.getName();
                if("classes.dex".equals(name)){ zin.closeEntry(); continue; }
                if(!seen.add(name)){ zin.closeEntry(); continue; }
                ZipEntry n=new ZipEntry(name);
                n.setTime(e.getTime());
                zout.putNextEntry(n);
                int r; while((r=zin.read(buffer))>0)zout.write(buffer,0,r);
                zout.closeEntry(); zin.closeEntry();
            }

            addFile(zout,dex,"classes.dex",seen,buffer);
            if(assets!=null&&assets.isDirectory())addTree(zout,assets,"assets",seen,buffer);
            if(jni!=null&&jni.isDirectory())addTree(zout,jni,"lib/arm64-v8a",seen,buffer);
        }
    }

    private static void addTree(ZipOutputStream zout,File root,String prefix,Set<String> seen,byte[] buffer)throws Exception{
        File[] children=root.listFiles();
        if(children==null)return;
        Arrays.sort(children,new Comparator<File>(){public int compare(File a,File b){return a.getName().compareTo(b.getName());}});
        for(File child:children){
            String entry=prefix+"/"+child.getName();
            if(child.isDirectory())addTree(zout,child,entry,seen,buffer);
            else addFile(zout,child,entry,seen,buffer);
        }
    }

    private static void addFile(ZipOutputStream zout,File file,String entry,Set<String> seen,byte[] buffer)throws Exception{
        if(!seen.add(entry))return;
        ZipEntry e=new ZipEntry(entry);
        e.setTime(file.lastModified());
        zout.putNextEntry(e);
        try(InputStream in=new BufferedInputStream(new FileInputStream(file))){
            int r; while((r=in.read(buffer))>0)zout.write(buffer,0,r);
        }
        zout.closeEntry();
    }
}
