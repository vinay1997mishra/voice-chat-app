package com.anamika.ai.media;

import android.content.Context;
import android.graphics.*;
import com.anamika.ai.files.AnamikaVault;

import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.*;

public final class PhotoEditEngine {
    public static final class Result {
        public final File file; public final int width,height; public final String mime;
        Result(File file,int width,int height,String mime){this.file=file;this.width=width;this.height=height;this.mime=mime;}
    }
    private PhotoEditEngine(){}

    public static Result edit(Context c,File source,String command)throws Exception{
        if(source==null||!source.isFile()) throw new FileNotFoundException("Photo file not found.");
        Bitmap original=BitmapFactory.decodeFile(source.getAbsolutePath());
        if(original==null) throw new IOException("Selected file is not a readable image.");
        Bitmap current=original;
        String lower=command==null?"":command.toLowerCase(Locale.ROOT);

        int[] size=parseSize(lower);
        if(size!=null){
            Bitmap next;
            if(containsAny(lower,"crop","square crop","center crop","क crop","क्रॉप")){
                next=centerCropAndScale(current,size[0],size[1]);
            }else{
                next=Bitmap.createScaledBitmap(current,size[0],size[1],true);
            }
            if(next!=current && current!=original) current.recycle();
            current=next;
        }

        int rotation=parseRotation(lower);
        if(rotation!=0){
            Matrix m=new Matrix();m.postRotate(rotation);
            Bitmap next=Bitmap.createBitmap(current,0,0,current.getWidth(),current.getHeight(),m,true);
            if(next!=current && current!=original) current.recycle();
            current=next;
        }

        if(containsAny(lower,"mirror","flip horizontal","ulta horizontal","मिरर")){
            Matrix m=new Matrix();m.preScale(-1f,1f);
            Bitmap next=Bitmap.createBitmap(current,0,0,current.getWidth(),current.getHeight(),m,true);
            if(next!=current && current!=original) current.recycle();
            current=next;
        }

        int quality=parseQuality(lower);
        boolean png=lower.contains("png");
        Bitmap.CompressFormat fmt=png?Bitmap.CompressFormat.PNG:Bitmap.CompressFormat.JPEG;
        String ext=png?".png":".jpg";
        String mime=png?"image/png":"image/jpeg";
        File out=new File(AnamikaVault.root(c),"Edited_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+ext);
        try(FileOutputStream fos=new FileOutputStream(out)){
            if(!current.compress(fmt,quality,fos)) throw new IOException("Photo encode failed.");
        }finally{
            if(current!=original) current.recycle();
            original.recycle();
        }
        AnamikaVault.registerGeneratedFile(c,out,mime);
        BitmapFactory.Options o=new BitmapFactory.Options();o.inJustDecodeBounds=true;BitmapFactory.decodeFile(out.getAbsolutePath(),o);
        return new Result(out,o.outWidth,o.outHeight,mime);
    }

    private static int[] parseSize(String s){
        Matcher m=Pattern.compile("(\\d{2,5})\\s*[x×]\\s*(\\d{2,5})").matcher(s);
        if(m.find()){
            int w=Integer.parseInt(m.group(1)),h=Integer.parseInt(m.group(2));
            if(w>0&&h>0&&w<=12000&&h<=12000)return new int[]{w,h};
        }
        if(s.contains("9:16")||s.contains("9 by 16")) return new int[]{1080,1920};
        if(s.contains("16:9")||s.contains("16 by 9")) return new int[]{1920,1080};
        if(s.contains("1:1")||s.contains("square")) return new int[]{1080,1080};
        if(s.contains("4:5")) return new int[]{1080,1350};
        return null;
    }

    private static int parseRotation(String s){
        Matcher m=Pattern.compile("(?:rotate|ghuma|घुमा)\\s*(90|180|270)").matcher(s);
        if(m.find()) return Integer.parseInt(m.group(1));
        if(s.contains("rotate right")) return 90;
        if(s.contains("rotate left")) return 270;
        return 0;
    }

    private static int parseQuality(String s){
        Matcher m=Pattern.compile("(?:quality|क्वालिटी)\\s*(\\d{1,3})").matcher(s);
        if(m.find()) return Math.max(1,Math.min(100,Integer.parseInt(m.group(1))));
        if(s.contains("compress")) return 82;
        return 95;
    }

    private static Bitmap centerCropAndScale(Bitmap src,int tw,int th){
        float srcRatio=src.getWidth()/(float)src.getHeight();
        float dstRatio=tw/(float)th;
        int x=0,y=0,w=src.getWidth(),h=src.getHeight();
        if(srcRatio>dstRatio){
            w=Math.round(src.getHeight()*dstRatio);
            x=(src.getWidth()-w)/2;
        }else{
            h=Math.round(src.getWidth()/dstRatio);
            y=(src.getHeight()-h)/2;
        }
        Bitmap cropped=Bitmap.createBitmap(src,x,y,w,h);
        Bitmap scaled=Bitmap.createScaledBitmap(cropped,tw,th,true);
        if(cropped!=src&&cropped!=scaled)cropped.recycle();
        return scaled;
    }
    private static boolean containsAny(String s,String... terms){for(String t:terms)if(s.contains(t))return true;return false;}
}
