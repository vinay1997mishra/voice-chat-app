package com.anamika.ai.media3d;

/** Subject-aware procedural choreography used by the offline cinematic renderer. */
public final class CinematicMotionPath {
    private CinematicMotionPath() { }

    public static DragonFlightPath.Pose sample(SceneSubject subject,float seconds,float duration) {
        if (subject == null || subject == SceneSubject.DRAGON || subject == SceneSubject.PHOENIX ||
                subject == SceneSubject.EAGLE || subject == SceneSubject.SPACESHIP) {
            return DragonFlightPath.sample(seconds,duration);
        }
        float u=clamp(seconds/Math.max(1f,duration));
        switch(subject) {
            case WOLF:
            case LION:
                return groundRun(seconds,u,subject==SceneSubject.LION?0.78f:0.68f,1.0f);
            case SUPERCAR:
                return groundRun(seconds,u,0.62f,1.55f);
            case ROBOT:
                return groundRun(seconds,u,0.82f,0.62f);
            case CRYSTAL:
            case CUSTOM_ASSET:
            default:
                return heroFloat(seconds,u);
        }
    }

    public static boolean isGroundSubject(SceneSubject subject){
        return subject==SceneSubject.WOLF||subject==SceneSubject.LION||subject==SceneSubject.SUPERCAR||subject==SceneSubject.ROBOT;
    }

    private static DragonFlightPath.Pose groundRun(float seconds,float u,float y,float speed){
        float enter=1f-smooth(Math.min(1f,u/0.68f));
        float x=-4.6f*enter*speed + 0.18f*(float)Math.sin(seconds*1.6f)*(1f-u);
        float z=-0.55f + 0.22f*(float)Math.sin(seconds*0.55f);
        float bob=0.035f*(float)Math.sin(seconds*(speed>1.2f?8.5f:5.3f));
        float yaw=-86f + 8f*(float)Math.sin(seconds*0.45f)*(1f-u);
        float impact=pulse(u,0.70f,0.79f)*0.42f;
        return new DragonFlightPath.Pose(x,y+bob,z,yaw,0f,0f,(float)Math.sin(seconds*6.2f),0f,impact);
    }

    private static DragonFlightPath.Pose heroFloat(float seconds,float u){
        float p=smooth(Math.min(1f,u/0.65f));
        float x=(1f-p)*2.6f*(float)Math.sin(seconds*0.8f);
        float y=1.25f+0.28f*(float)Math.sin(seconds*0.9f)*(1f-0.45f*p);
        float z=-1.2f+0.65f*p;
        float yaw=seconds*18f;
        float impact=pulse(u,0.72f,0.82f)*0.32f;
        return new DragonFlightPath.Pose(x,y,z,yaw,-4f,4f*(float)Math.sin(seconds),0f,0f,impact);
    }

    private static float pulse(float x,float a,float b){
        if(x<=a||x>=b)return 0f;
        return (float)Math.sin(((x-a)/(b-a))*Math.PI);
    }
    private static float smooth(float x){x=clamp(x);return x*x*(3f-2f*x);}
    private static float clamp(float x){return Math.max(0f,Math.min(1f,x));}
}
