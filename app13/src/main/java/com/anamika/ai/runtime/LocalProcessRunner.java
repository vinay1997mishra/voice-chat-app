package com.anamika.ai.runtime;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/** Small bounded process runner for owner-installed private component runtimes. */
public final class LocalProcessRunner {
    public static final class Result {
        public final boolean started;
        public final boolean timedOut;
        public final int exitCode;
        public final String stdout;
        public final String stderr;

        Result(boolean started,boolean timedOut,int exitCode,String stdout,String stderr){
            this.started=started;this.timedOut=timedOut;this.exitCode=exitCode;
            this.stdout=stdout;this.stderr=stderr;
        }

        public boolean ok(){return started&&!timedOut&&exitCode==0;}
    }

    private LocalProcessRunner(){}

    public static Result run(List<String> command,File cwd,Map<String,String> env,long timeoutMs){
        Process p=null;
        StreamCollector out=null,err=null;
        try{
            ProcessBuilder b=new ProcessBuilder(command);
            if(cwd!=null)b.directory(cwd);
            if(env!=null)b.environment().putAll(env);
            b.redirectErrorStream(false);
            p=b.start();
            out=new StreamCollector(p.getInputStream(),2*1024*1024);
            err=new StreamCollector(p.getErrorStream(),2*1024*1024);
            Thread ot=new Thread(out,"anamika-proc-out");
            Thread et=new Thread(err,"anamika-proc-err");
            ot.start();et.start();

            boolean finished=p.waitFor(Math.max(1000L,timeoutMs),TimeUnit.MILLISECONDS);
            if(!finished){
                p.destroy();
                if(!p.waitFor(800,TimeUnit.MILLISECONDS))p.destroyForcibly();
            }
            ot.join(1000);et.join(1000);
            return new Result(true,!finished,finished?p.exitValue():-1,out.text(),err.text());
        }catch(Exception e){
            return new Result(false,false,-1,"",safe(e));
        }finally{
            if(p!=null)try{p.destroy();}catch(Exception ignored){}
        }
    }

    private static final class StreamCollector implements Runnable{
        private final InputStream in;
        private final int limit;
        private final ByteArrayOutputStream data=new ByteArrayOutputStream();
        StreamCollector(InputStream in,int limit){this.in=in;this.limit=limit;}
        @Override public void run(){
            try{
                byte[] b=new byte[8192];int n,total=0;
                while((n=in.read(b))>0){
                    int keep=Math.min(n,Math.max(0,limit-total));
                    if(keep>0){data.write(b,0,keep);total+=keep;}
                    if(total>=limit)break;
                }
            }catch(Exception ignored){}
        }
        String text(){return new String(data.toByteArray(),StandardCharsets.UTF_8);}
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
