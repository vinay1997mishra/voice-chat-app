package com.anamika.ai.media;

import android.content.Context;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;

import com.anamika.ai.files.AnamikaVault;

import java.io.File;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.*;

public final class VideoEditEngine {
    public static final class Result{
        public final File file; public final double startSec,endSec; public final boolean muted;
        Result(File f,double s,double e,boolean m){file=f;startSec=s;endSec=e;muted=m;}
    }
    private VideoEditEngine(){}

    public static Result edit(Context c,File src,String command)throws Exception{
        if(src==null||!src.isFile()) throw new java.io.FileNotFoundException("Video file not found.");
        String lower=command==null?"":command.toLowerCase(Locale.ROOT);
        boolean mute=lower.contains("mute")||lower.contains("audio hata")||lower.contains("sound hata")||lower.contains("आवाज हट");
        double[] range=parseRange(lower);
        double start=range[0],end=range[1];

        MediaExtractor ex=new MediaExtractor();
        ex.setDataSource(src.getAbsolutePath());
        long durationUs=findDurationUs(ex);
        if(end<0) end=durationUs/1_000_000.0;
        start=Math.max(0,start);
        end=Math.min(end,durationUs/1_000_000.0);
        if(end<=start) throw new IllegalArgumentException("Video trim range valid nahi hai.");

        File out=new File(AnamikaVault.root(c),"EditedVideo_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".mp4");
        MediaMuxer mux=new MediaMuxer(out.getAbsolutePath(),MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        Map<Integer,Integer> tracks=new LinkedHashMap<>();
        int maxBuffer=1024*1024;
        for(int i=0;i<ex.getTrackCount();i++){
            MediaFormat f=ex.getTrackFormat(i);
            String mime=f.getString(MediaFormat.KEY_MIME);
            if(mime==null)continue;
            if(mute&&mime.startsWith("audio/"))continue;
            if(!mime.startsWith("video/")&&!mime.startsWith("audio/"))continue;
            int outTrack=mux.addTrack(f);
            tracks.put(i,outTrack);
            if(f.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) maxBuffer=Math.max(maxBuffer,f.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE));
        }
        if(tracks.isEmpty()){ex.release();mux.release();throw new IllegalStateException("No MP4 audio/video tracks found.");}
        for(Integer t:tracks.keySet()) ex.selectTrack(t);
        mux.start();

        long startUs=(long)(start*1_000_000L),endUs=(long)(end*1_000_000L);
        ex.seekTo(startUs,MediaExtractor.SEEK_TO_PREVIOUS_SYNC);
        ByteBuffer buffer=ByteBuffer.allocateDirect(Math.min(Math.max(maxBuffer,1024*1024),16*1024*1024));
        android.media.MediaCodec.BufferInfo info=new android.media.MediaCodec.BufferInfo();
        try{
            while(true){
                int inTrack=ex.getSampleTrackIndex();
                if(inTrack<0)break;
                long time=ex.getSampleTime();
                if(time<0||time>endUs)break;
                Integer outTrack=tracks.get(inTrack);
                if(outTrack==null){ex.advance();continue;}
                buffer.clear();
                int size=ex.readSampleData(buffer,0);
                if(size<0)break;
                if(time>=startUs){
                    info.offset=0;info.size=size;info.presentationTimeUs=Math.max(0,time-startUs);info.flags=ex.getSampleFlags();
                    mux.writeSampleData(outTrack,buffer,info);
                }
                if(!ex.advance())break;
            }
        }finally{
            try{mux.stop();}catch(Exception ignored){}
            mux.release();ex.release();
        }
        if(!out.isFile()||out.length()<1024){try{out.delete();}catch(Exception ignored){}throw new IllegalStateException("Edited video output invalid.");}
        AnamikaVault.registerGeneratedFile(c,out,"video/mp4");
        return new Result(out,start,end,mute);
    }

    private static long findDurationUs(MediaExtractor ex){
        long d=0;
        for(int i=0;i<ex.getTrackCount();i++){
            MediaFormat f=ex.getTrackFormat(i);
            if(f.containsKey(MediaFormat.KEY_DURATION)) d=Math.max(d,f.getLong(MediaFormat.KEY_DURATION));
        }
        return d;
    }

    private static double[] parseRange(String s){
        Matcher m=Pattern.compile("(?:trim|cut|from)?\\s*(\\d+(?:\\.\\d+)?)\\s*(?:sec|second|s)?\\s*(?:to|-|se)\\s*(\\d+(?:\\.\\d+)?)\\s*(?:sec|second|s)?").matcher(s);
        if(m.find()) return new double[]{Double.parseDouble(m.group(1)),Double.parseDouble(m.group(2))};
        m=Pattern.compile("(?:first|pehle|पहले)\\s*(\\d+(?:\\.\\d+)?)\\s*(?:sec|second|seconds|s)").matcher(s);
        if(m.find()) return new double[]{0,Double.parseDouble(m.group(1))};
        m=Pattern.compile("(?:trim|cut)\\s*(\\d+(?:\\.\\d+)?)\\s*(?:sec|second|seconds|s)").matcher(s);
        if(m.find()) return new double[]{0,Double.parseDouble(m.group(1))};
        return new double[]{0,-1};
    }
}
