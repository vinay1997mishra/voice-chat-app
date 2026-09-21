package com.anamika.toolchain;

import java.io.*;
import java.util.*;
import java.util.zip.*;

public final class ZipInjector {
    private static final int BUF=128*1024;

    public static void main(String[] args) throws Exception {
        if(args.length!=3)throw new IllegalArgumentException("usage: ZipInjector <base.apk> <classes.dex> <output.apk>");
        File base=new File(args[0]), dex=new File(args[1]), out=new File(args[2]);
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
            ZipEntry d=new ZipEntry("classes.dex");
            d.setTime(System.currentTimeMillis());
            zout.putNextEntry(d);
            try(InputStream in=new BufferedInputStream(new FileInputStream(dex))){
                int r; while((r=in.read(buffer))>0)zout.write(buffer,0,r);
            }
            zout.closeEntry();
        }
    }
}
