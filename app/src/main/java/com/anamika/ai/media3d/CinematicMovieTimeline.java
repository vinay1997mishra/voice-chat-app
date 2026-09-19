package com.anamika.ai.media3d;

/**
 * Deterministic multi-shot camera director for offline movie-style animation.
 * Produces establishing, tracking, chase, close-impact and hero-reveal shots.
 */
public final class CinematicMovieTimeline {
    public static final class Camera {
        public final float x,y,z;
        public final float tx,ty,tz;
        public final float fov;
        public final int shot;
        Camera(float x,float y,float z,float tx,float ty,float tz,float fov,int shot){
            this.x=x; this.y=y; this.z=z;
            this.tx=tx; this.ty=ty; this.tz=tz;
            this.fov=fov; this.shot=shot;
        }
    }

    private CinematicMovieTimeline(){}

    public static Camera sample(SceneSubject subject, DragonFlightPath.Pose pose,
                                float seconds,float duration,float intensity){
        float u=clamp(seconds/Math.max(1f,duration));
        float i=Math.max(0.6f,Math.min(1.8f,intensity));
        float cx,cy,cz,tx,ty,tz,fov;
        int shot;

        if(CinematicMotionPath.isGroundSubject(subject)){
            if(u<0.20f){
                float p=ease(u/0.20f);
                shot=1; fov=58f-8f*p;
                cx=-5.7f+2.4f*p; cy=1.55f+0.20f*p; cz=4.8f-0.4f*p;
            }else if(u<0.48f){
                float p=ease((u-0.20f)/0.28f);
                shot=2; fov=48f-5f*p;
                cx=pose.x*0.38f+2.8f*(1f-p); cy=1.18f+0.16f*(float)Math.sin(seconds*0.9f); cz=3.9f-0.65f*p;
            }else if(u<0.74f){
                float p=ease((u-0.48f)/0.26f);
                shot=3; fov=42f-8f*p;
                float a=(float)Math.PI*(0.18f+0.78f*p);
                cx=pose.x*0.22f+(float)Math.sin(a)*(2.4f-0.6f*p);
                cy=1.08f+0.42f*p;
                cz=pose.z+(float)Math.cos(a)*(2.8f-0.8f*p);
            }else if(u<0.90f){
                float p=ease((u-0.74f)/0.16f);
                shot=4; fov=34f-5f*p;
                cx=0.9f*(1f-p)+0.22f; cy=0.96f+0.34f*p; cz=2.5f-0.9f*p;
            }else{
                float p=ease((u-0.90f)/0.10f);
                shot=5; fov=31f+4f*p;
                float a=seconds*0.55f;
                cx=(float)Math.sin(a)*(1.45f+0.25f*p); cy=1.28f+0.20f*p; cz=1.8f+(float)Math.cos(a)*0.55f;
            }
            tx=pose.x*0.52f; ty=0.72f; tz=pose.z;
        }else{
            if(u<0.16f){
                float p=ease(u/0.16f);
                shot=1; fov=62f-10f*p;
                float a=-0.55f+p*0.60f;
                cx=(float)Math.sin(a)*5.8f; cy=3.7f-0.7f*p; cz=8.9f+(float)Math.cos(a)*0.8f;
            }else if(u<0.36f){
                float p=ease((u-0.16f)/0.20f);
                shot=2; fov=50f-6f*p;
                cx=pose.x*0.18f+2.9f*(1f-p); cy=pose.y*0.28f+1.55f; cz=7.1f-1.3f*p;
            }else if(u<0.58f){
                float p=ease((u-0.36f)/0.22f);
                shot=3; fov=43f-9f*p;
                cx=pose.x*0.50f+1.35f*(1f-p); cy=pose.y*0.44f+0.85f; cz=5.65f-1.15f*p;
            }else if(u<0.78f){
                float p=ease((u-0.58f)/0.20f);
                shot=4; fov=34f-4f*p;
                float a=(float)Math.PI*(0.15f+1.20f*p);
                cx=pose.x*0.25f+(float)Math.sin(a)*(1.95f-0.45f*p);
                cy=pose.y*0.36f+0.75f+0.32f*p;
                cz=pose.z+(float)Math.cos(a)*(2.15f-0.55f*p);
            }else if(u<0.91f){
                float p=ease((u-0.78f)/0.13f);
                shot=5; fov=30f-3f*p;
                cx=0.68f*(1f-p)+0.12f; cy=1.12f+0.42f*p; cz=3.05f-1.45f*p;
            }else{
                float p=ease((u-0.91f)/0.09f);
                shot=6; fov=29f+5f*p;
                float a=seconds*0.48f;
                cx=(float)Math.sin(a)*(1.22f+0.35f*p); cy=1.42f+0.24f*p; cz=1.75f+(float)Math.cos(a)*0.48f;
            }
            tx=pose.x*0.60f; ty=Math.max(0.72f,pose.y*0.62f); tz=pose.z;
        }

        float micro=0.018f*i;
        cx+=(float)Math.sin(seconds*11.3f)*micro;
        cy+=(float)Math.sin(seconds*9.7f+0.7f)*micro*0.7f;

        if(pose.landingImpact>0f){
            float shake=pose.landingImpact*0.12f*i;
            cx+=(float)Math.sin(seconds*83f)*shake;
            cy+=(float)Math.sin(seconds*71f+1.7f)*shake;
        }

        return new Camera(cx,cy,cz,tx,ty,tz,fov,shot);
    }

    private static float ease(float x){
        x=clamp(x);
        return x*x*(3f-2f*x);
    }

    private static float clamp(float x){
        return Math.max(0f,Math.min(1f,x));
    }
}
