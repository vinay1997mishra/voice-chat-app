package com.anamika.ai.media3d;

import android.graphics.Bitmap;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.media.MediaMuxer;
import android.view.Surface;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;

/** Hardware-accelerated offline H.264 cinematic MP4 exporter. */
public final class Premium3DVideoExporter {
    private static final String MIME="video/avc";
    private static final int TIMEOUT_US=10_000;

    public interface Callback {
        void onProgress(int percent);
        void onComplete(File file);
        void onError(Throwable error);
    }

    private Premium3DVideoExporter() { }

    public static void exportAsync(File file, CinematicSceneConfig scene, int width, int height,
                                   int fps, Callback callback) {
        new Thread(() -> {
            try {
                export(file,scene,width,height,fps,callback);
                verifyAnimatedOutput(file,scene.durationSeconds);
                callback.onComplete(file);
            } catch(Throwable t) {
                if(file!=null && file.exists()) try{file.delete();}catch(Exception ignored){}
                callback.onError(t);
            }
        },"anamika-cinematic-export").start();
    }

    private static void export(File file,CinematicSceneConfig scene,int width,int height,
                               int fps,Callback callback) throws IOException {
        if(file==null||scene==null||callback==null) throw new IllegalArgumentException("file, scene and callback are required");
        if(width<320||height<240||fps<1||fps>120) throw new IllegalArgumentException("Invalid export dimensions/fps");
        if((width&1)!=0 || (height&1)!=0) throw new IllegalArgumentException("H.264 export width/height must be even");
        if(file.getParentFile()!=null && !file.getParentFile().exists() && !file.getParentFile().mkdirs()) throw new IOException("Cannot create output folder");
        if(file.exists()&&!file.delete()) throw new IOException("Cannot replace output file");

        int pixels=width*height;
        int bitRate;
        if(pixels>=3840*2160) bitRate=35_000_000;
        else if(pixels>=2560*1440) bitRate=20_000_000;
        else if(pixels>=1920*1080) bitRate=12_000_000;
        else bitRate=7_000_000;
        if(fps>=60) bitRate=(int)(bitRate*1.45f);

        MediaFormat format=MediaFormat.createVideoFormat(MIME,width,height);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT,MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
        format.setInteger(MediaFormat.KEY_BIT_RATE,bitRate);
        format.setInteger(MediaFormat.KEY_FRAME_RATE,fps);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL,1);

        MediaCodec encoder=null;
        MediaMuxer muxer=null;
        CodecEglSurface egl=null;
        boolean muxerStarted=false;
        int trackIndex=-1;

        try {
            encoder=MediaCodec.createEncoderByType(MIME);
            encoder.configure(format,null,null,MediaCodec.CONFIGURE_FLAG_ENCODE);
            Surface input=encoder.createInputSurface();
            encoder.start();
            muxer=new MediaMuxer(file.getAbsolutePath(),MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            egl=new CodecEglSurface(input);
            egl.makeCurrent();

            Premium3DRenderer renderer=new Premium3DRenderer();
            renderer.setScene(scene);
            renderer.onSurfaceCreated(null,null);
            renderer.onSurfaceChanged(null,width,height);

            MediaCodec.BufferInfo info=new MediaCodec.BufferInfo();
            int totalFrames=Math.max(1,fps*scene.durationSeconds);
            for(int i=0;i<totalFrames;i++) {
                float seconds=i/(float)fps;
                renderer.renderAtTime(seconds);
                egl.setPresentationTime(i*1_000_000_000L/fps);
                if(!egl.swapBuffers()) throw new IllegalStateException("EGL swap failed");
                DrainResult d=drainEncoder(encoder,muxer,info,false,muxerStarted,trackIndex);
                muxerStarted=d.muxerStarted;
                trackIndex=d.trackIndex;
                if(i%Math.max(1,fps/3)==0) callback.onProgress((i*100)/totalFrames);
            }

            encoder.signalEndOfInputStream();
            boolean eos=false;
            while(!eos) {
                DrainResult d=drainEncoder(encoder,muxer,info,true,muxerStarted,trackIndex);
                muxerStarted=d.muxerStarted;
                trackIndex=d.trackIndex;
                eos=d.endOfStream;
            }
            callback.onProgress(100);
        } finally {
            if(egl!=null) egl.release();
            if(encoder!=null) {
                try { encoder.stop(); } catch(Exception ignored) { }
                encoder.release();
            }
            if(muxer!=null) {
                if(muxerStarted) try { muxer.stop(); } catch(Exception ignored) { }
                muxer.release();
            }
        }
    }

    private static void verifyAnimatedOutput(File file,int expectedSeconds) throws IOException {
        if(file==null || !file.isFile() || file.length()<64L*1024L)
            throw new IOException("Exported MP4 is missing or unexpectedly small.");

        MediaMetadataRetriever r=new MediaMetadataRetriever();
        try {
            r.setDataSource(file.getAbsolutePath());
            long duration=parseLong(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
            long minExpected=Math.max(1500L,expectedSeconds*1000L*7L/10L);
            if(duration<minExpected)
                throw new IOException("Exported MP4 duration is incomplete: "+duration+" ms.");

            long dUs=duration*1000L;
            long t1=Math.max(100_000L,(long)(dUs*0.16));
            long t2=Math.max(t1+100_000L,(long)(dUs*0.50));
            long t3=Math.max(t2+100_000L,(long)(dUs*0.84));

            Bitmap a=null,b=null,c=null;
            try {
                a=r.getFrameAtTime(t1,MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
                b=r.getFrameAtTime(t2,MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
                if(a==null||b==null) throw new IOException("Could not decode exported animation frames.");
                double diff12=frameDifference(a,b);
                a.recycle(); a=null;
                if(diff12<2.0){
                    c=r.getFrameAtTime(t3,MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
                    if(c==null) throw new IOException("Could not decode final animation frame.");
                    double diff23=frameDifference(b,c);
                    if(diff23<2.0)
                        throw new IOException("Exported MP4 appears static/frozen; animation verification failed.");
                }
            } finally {
                if(a!=null&&!a.isRecycled()) a.recycle();
                if(b!=null&&!b.isRecycled()) b.recycle();
                if(c!=null&&!c.isRecycled()) c.recycle();
            }
        } catch(IOException e) {
            throw e;
        } catch(Exception e) {
            throw new IOException("Video verification failed: "+e.getMessage(),e);
        } finally {
            try { r.release(); } catch(Exception ignored) { }
        }
    }

    private static double frameDifference(Bitmap a,Bitmap b) {
        int w=Math.min(a.getWidth(),b.getWidth());
        int h=Math.min(a.getHeight(),b.getHeight());
        if(w<=0||h<=0) return 0.0;
        int cols=12, rows=12;
        long total=0; int count=0;
        for(int iy=1;iy<=rows;iy++){
            int y=Math.min(h-1,(iy*h)/(rows+1));
            for(int ix=1;ix<=cols;ix++){
                int x=Math.min(w-1,(ix*w)/(cols+1));
                int p=a.getPixel(x,y), q=b.getPixel(x,y);
                total+=Math.abs(((p>>16)&255)-((q>>16)&255));
                total+=Math.abs(((p>>8)&255)-((q>>8)&255));
                total+=Math.abs((p&255)-(q&255));
                count+=3;
            }
        }
        return count==0?0.0:(double)total/count;
    }

    private static long parseLong(String s) {
        try { return Long.parseLong(s); } catch(Exception e) { return 0L; }
    }

    private static DrainResult drainEncoder(MediaCodec encoder,MediaMuxer muxer,
                                            MediaCodec.BufferInfo info,boolean waitForEos,
                                            boolean muxerStarted,int trackIndex) {
        boolean eos=false;
        int idle=0;
        while(true) {
            int status=encoder.dequeueOutputBuffer(info,waitForEos?TIMEOUT_US:0);
            if(status==MediaCodec.INFO_TRY_AGAIN_LATER) {
                if(!waitForEos) break;
                if(++idle>120) throw new IllegalStateException("Encoder EOS timed out; export aborted instead of hanging.");
            } else if(status==MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if(muxerStarted) throw new IllegalStateException("Encoder format changed twice");
                trackIndex=muxer.addTrack(encoder.getOutputFormat());
                muxer.start();
                muxerStarted=true;
            } else if(status>=0) {
                ByteBuffer data=encoder.getOutputBuffer(status);
                if(data==null) throw new IllegalStateException("Encoder output buffer is null");
                if((info.flags&MediaCodec.BUFFER_FLAG_CODEC_CONFIG)!=0) info.size=0;
                if(info.size>0) {
                    if(!muxerStarted) throw new IllegalStateException("Muxer has not started");
                    data.position(info.offset);
                    data.limit(info.offset+info.size);
                    muxer.writeSampleData(trackIndex,data,info);
                }
                eos=(info.flags&MediaCodec.BUFFER_FLAG_END_OF_STREAM)!=0;
                encoder.releaseOutputBuffer(status,false);
                if(eos) break;
            }
        }
        return new DrainResult(muxerStarted,trackIndex,eos);
    }

    private static final class DrainResult {
        final boolean muxerStarted;
        final int trackIndex;
        final boolean endOfStream;
        DrainResult(boolean muxerStarted,int trackIndex,boolean endOfStream) {
            this.muxerStarted=muxerStarted;
            this.trackIndex=trackIndex;
            this.endOfStream=endOfStream;
        }
    }
}
