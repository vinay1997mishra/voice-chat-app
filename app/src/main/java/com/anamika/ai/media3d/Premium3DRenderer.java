package com.anamika.ai.media3d;

import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

/**
 * Offline cinematic OpenGL ES renderer.
 * Includes a procedural articulated dragon fallback so the scene works without network assets.
 * A production rigged GLB can later replace the fallback while retaining the same choreography.
 */
public final class Premium3DRenderer implements GLSurfaceView.Renderer {
    private static final int SPHERE_STACKS = 14;
    private static final int SPHERE_SLICES = 20;
    private static final int CLOUD_COUNT = 190;
    private static final int FIRE_COUNT = 90;

    private final FloatBuffer sphereBuffer;
    private final int sphereVertexCount;
    private final FloatBuffer wingBuffer;
    private final FloatBuffer cloudBuffer;
    private final FloatBuffer fireBuffer;

    private final float[] projection = new float[16];
    private final float[] view = new float[16];
    private final float[] pv = new float[16];
    private final float[] model = new float[16];
    private final float[] temp = new float[16];
    private final float[] temp2 = new float[16];
    private final float[] mvp = new float[16];

    private int meshProgram;
    private int simpleProgram;
    private long startNanos;
    private int width = 1;
    private int height = 1;
    private volatile CinematicSceneConfig scene = CinematicSceneConfig.defaultDragon();

    public Premium3DRenderer() {
        float[] sphere = buildSphere(SPHERE_STACKS, SPHERE_SLICES);
        sphereVertexCount = sphere.length / 6;
        sphereBuffer = allocate(sphere);
        wingBuffer = allocate(buildWing());
        cloudBuffer = allocate(buildClouds());
        fireBuffer = ByteBuffer.allocateDirect(FIRE_COUNT * 3 * 4)
                .order(ByteOrder.nativeOrder()).asFloatBuffer();
    }

    private static FloatBuffer allocate(float[] values) {
        FloatBuffer b = ByteBuffer.allocateDirect(values.length * 4)
                .order(ByteOrder.nativeOrder()).asFloatBuffer();
        b.put(values).position(0);
        return b;
    }

    public void setPreset(ScenePreset preset) {
        CinematicSceneConfig old = scene;
        scene = new CinematicSceneConfig(preset, old.subject, old.fireBreath,
                old.cinematicFog, old.impactShake, old.intensity, old.durationSeconds, old.brief);
    }

    public void setScene(CinematicSceneConfig config) {
        if (config != null) scene = config;
    }

    public CinematicSceneConfig getScene() { return scene; }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig config) {
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glEnable(GLES20.GL_CULL_FACE);
        GLES20.glCullFace(GLES20.GL_BACK);
        meshProgram = createProgram(MESH_VERTEX, MESH_FRAGMENT);
        simpleProgram = createProgram(SIMPLE_VERTEX, SIMPLE_FRAGMENT);
        startNanos = System.nanoTime();
    }

    @Override public void onSurfaceChanged(GL10 gl, int width, int height) {
        this.width = Math.max(1, width);
        this.height = Math.max(1, height);
        GLES20.glViewport(0, 0, this.width, this.height);
        float ratio = (float)this.width / this.height;
        Matrix.perspectiveM(projection, 0, 50f, ratio, 0.08f, 80f);
    }

    @Override public void onDrawFrame(GL10 gl) {
        float seconds = (System.nanoTime() - startNanos) / 1_000_000_000f;
        CinematicSceneConfig s = scene;
        renderAtTime(seconds % s.durationSeconds);
    }

    public void renderAtTime(float seconds) {
        CinematicSceneConfig cfg = scene;
        ScenePreset s = cfg.preset;
        DragonFlightPath.Pose pose = CinematicMotionPath.sample(cfg.subject, seconds, cfg.durationSeconds);
        float u = clamp(seconds / cfg.durationSeconds);

        GLES20.glViewport(0, 0, width, height);
        GLES20.glClearColor(s.background[0], s.background[1], s.background[2], 1f);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT | GLES20.GL_DEPTH_BUFFER_BIT);

        configureCamera(seconds, u, pose, cfg);
        Matrix.multiplyMM(pv, 0, projection, 0, view, 0);

        drawSkyClouds(seconds, s, cfg);
        drawGround(s, pose, cfg);

        if (cfg.subject != null) {
            // Faint temporal echoes create a motion-trail impression during fast descent.
            if (u > 0.34f && u < 0.77f) {
                GLES20.glDepthMask(false);
                drawSubject(CinematicMotionPath.sample(cfg.subject, Math.max(0f, seconds - 0.07f), cfg.durationSeconds), seconds - 0.07f, s, cfg, 0.13f);
                drawSubject(CinematicMotionPath.sample(cfg.subject, Math.max(0f, seconds - 0.035f), cfg.durationSeconds), seconds - 0.035f, s, cfg, 0.22f);
                GLES20.glDepthMask(true);
            }
            drawSubject(pose, seconds, s, cfg, 1f);
            if (cfg.fireBreath && pose.fire > 0.01f) drawFire(pose, seconds, s, cfg);
        }

        if (cfg.cinematicFog) drawForegroundFog(seconds, s, cfg);
    }

    private void configureCamera(float seconds, float u, DragonFlightPath.Pose pose, CinematicSceneConfig cfg) {
        CinematicMovieTimeline.Camera camera=CinematicMovieTimeline.sample(
                cfg.subject,pose,seconds,cfg.durationSeconds,cfg.intensity);
        float ratio=(float)Math.max(1,width)/Math.max(1,height);
        Matrix.perspectiveM(projection,0,camera.fov,ratio,0.06f,100f);
        Matrix.setLookAtM(view,0,
                camera.x,camera.y,camera.z,
                camera.tx,camera.ty,camera.tz,
                0f,1f,0f);
    }


    private void drawSubject(DragonFlightPath.Pose pose, float t, ScenePreset s,
                             CinematicSceneConfig cfg, float alpha) {
        switch (cfg.subject) {
            case PHOENIX:
            case EAGLE:
                drawBird(pose, t, s, cfg, alpha, cfg.subject == SceneSubject.PHOENIX);
                break;
            case WOLF:
            case LION:
                drawQuadruped(pose, t, s, cfg, alpha, cfg.subject == SceneSubject.LION);
                break;
            case SUPERCAR:
                drawSupercar(pose, t, s, cfg, alpha);
                break;
            case SPACESHIP:
                drawSpaceship(pose, t, s, cfg, alpha);
                break;
            case ROBOT:
                drawRobot(pose, t, s, cfg, alpha);
                break;
            case CRYSTAL:
            case CUSTOM_ASSET:
                drawCrystalHero(pose, t, s, cfg, alpha);
                break;
            case DRAGON:
            default:
                drawDragon(pose, t, s, cfg, alpha);
                break;
        }
    }

    private float[] subjectRoot(DragonFlightPath.Pose pose, CinematicSceneConfig cfg, boolean grounded) {
        float[] root = new float[16];
        Matrix.setIdentityM(root, 0);
        float y = grounded ? 0.62f + Math.max(0f, pose.y - 0.6f) * 0.08f : pose.y;
        Matrix.translateM(root, 0, pose.x, y, pose.z);
        Matrix.rotateM(root, 0, pose.yaw, 0f, 1f, 0f);
        Matrix.rotateM(root, 0, grounded ? 0f : pose.pitch, 1f, 0f, 0f);
        Matrix.rotateM(root, 0, grounded ? pose.roll * 0.15f : pose.roll, 0f, 0f, 1f);
        float scale = 0.72f * cfg.intensity;
        Matrix.scaleM(root, 0, scale, scale, scale);
        return root;
    }

    private void drawBird(DragonFlightPath.Pose pose, float t, ScenePreset s,
                          CinematicSceneConfig cfg, float alpha, boolean phoenix) {
        float[] root = subjectRoot(pose, cfg, false);
        float flap = pose.wing * (phoenix ? 35f : 27f);
        part(root, 0f,0f,0f, 0f,0f,0f, 0.48f,0.34f,1.05f, s,alpha,0.38f);
        part(root, 0f,0.18f,-0.85f, -10f,0f,0f, 0.28f,0.24f,0.38f, s,alpha,0.48f);
        part(root, 0f,0.12f,-1.18f, 4f,0f,0f, 0.12f,0.10f,0.28f, s,alpha,0.72f);
        drawWing(root,true,flap,s,alpha); drawWing(root,false,-flap,s,alpha);
        for(int i=0;i<(phoenix?7:4);i++) {
            float side=(i-(phoenix?3:1.5f))*0.13f;
            part(root,side,-0.05f,0.88f+i*0.18f, 18f,0f,side*22f,
                    0.07f,0.08f,0.40f+i*0.045f,s,alpha,phoenix?0.7f:0.32f);
        }
    }

    private void drawQuadruped(DragonFlightPath.Pose pose, float t, ScenePreset s,
                               CinematicSceneConfig cfg, float alpha, boolean lion) {
        float[] root = subjectRoot(pose,cfg,true);
        float stride=(float)Math.sin(t*5.2f)*18f;
        part(root,0f,0f,0f,0f,0f,0f,0.65f,0.42f,1.25f,s,alpha,0.30f);
        part(root,0f,0.30f,-1.0f,-8f,0f,0f,0.42f,0.38f,0.52f,s,alpha,lion?0.55f:0.34f);
        if(lion) part(root,0f,0.31f,-0.84f,0f,0f,0f,0.57f,0.55f,0.36f,s,alpha,0.20f);
        limb(root,-0.42f,-0.25f,-0.62f,stride,0.14f,0.15f,0.62f,s,alpha);
        limb(root,0.42f,-0.25f,-0.62f,-stride,0.14f,0.15f,0.62f,s,alpha);
        limb(root,-0.42f,-0.25f,0.62f,-stride,0.15f,0.16f,0.66f,s,alpha);
        limb(root,0.42f,-0.25f,0.62f,stride,0.15f,0.16f,0.66f,s,alpha);
        for(int i=0;i<6;i++) {
            float wave=(float)Math.sin(t*2.5f-i*.5f)*0.22f;
            part(root,wave,0.12f,1.0f+i*0.28f,0f,0f,wave*10f,
                    0.16f*(1-i*.10f),0.14f*(1-i*.10f),0.34f,s,alpha,0.25f);
        }
    }

    private void drawSupercar(DragonFlightPath.Pose pose, float t, ScenePreset s,
                              CinematicSceneConfig cfg, float alpha) {
        float[] root=subjectRoot(pose,cfg,true);
        Matrix.rotateM(root,0,90f,0f,1f,0f);
        part(root,0f,0f,0f,0f,0f,0f,0.78f,0.22f,1.65f,s,alpha,0.92f);
        part(root,0f,0.26f,-0.12f,0f,0f,0f,0.58f,0.24f,0.70f,s,alpha,0.78f);
        for(int side=-1;side<=1;side+=2) for(int z=-1;z<=1;z+=2)
            part(root,side*0.68f,-0.25f,z*1.05f,90f,0f,0f,0.24f,0.13f,0.24f,s,alpha,0.16f);
        part(root,0f,0.06f,-1.58f,0f,0f,0f,0.74f,0.07f,0.10f,s,alpha,0.95f);
    }

    private void drawSpaceship(DragonFlightPath.Pose pose, float t, ScenePreset s,
                               CinematicSceneConfig cfg, float alpha) {
        float[] root=subjectRoot(pose,cfg,false);
        part(root,0f,0f,0f,0f,0f,0f,0.46f,0.34f,1.75f,s,alpha,0.95f);
        part(root,-0.95f,-0.08f,0.10f,0f,0f,-10f,1.15f,0.08f,0.55f,s,alpha,0.84f);
        part(root,0.95f,-0.08f,0.10f,0f,0f,10f,1.15f,0.08f,0.55f,s,alpha,0.84f);
        part(root,0f,0.16f,-1.52f,0f,0f,0f,0.18f,0.18f,0.30f,s,alpha,0.95f);
    }

    private void drawRobot(DragonFlightPath.Pose pose, float t, ScenePreset s,
                           CinematicSceneConfig cfg, float alpha) {
        float[] root=subjectRoot(pose,cfg,true);
        float arm=(float)Math.sin(t*2.6f)*24f;
        part(root,0f,0.55f,0f,0f,0f,0f,0.52f,0.68f,0.34f,s,alpha,0.92f);
        part(root,0f,1.32f,-0.05f,0f,0f,0f,0.34f,0.34f,0.32f,s,alpha,0.88f);
        limb(root,-0.62f,0.62f,0f,arm,0.15f,0.16f,0.68f,s,alpha);
        limb(root,0.62f,0.62f,0f,-arm,0.15f,0.16f,0.68f,s,alpha);
        limb(root,-0.28f,-0.52f,0f,-arm,0.18f,0.18f,0.78f,s,alpha);
        limb(root,0.28f,-0.52f,0f,arm,0.18f,0.18f,0.78f,s,alpha);
    }

    private void drawCrystalHero(DragonFlightPath.Pose pose, float t, ScenePreset s,
                                 CinematicSceneConfig cfg, float alpha) {
        float[] root=subjectRoot(pose,cfg,false);
        Matrix.rotateM(root,0,t*24f,0f,1f,0f);
        for(int i=0;i<7;i++) {
            float a=(float)(i*Math.PI*2/7.0);
            part(root,(float)Math.sin(a)*0.38f,(i==0?0.35f:-0.05f),(float)Math.cos(a)*0.38f,
                    -18f,0f,(float)Math.toDegrees(a),0.20f,0.68f,0.20f,s,alpha,0.96f);
        }
        part(root,0f,0f,0f,0f,0f,0f,0.46f,0.85f,0.46f,s,alpha,1f);
    }

    private void drawDragon(DragonFlightPath.Pose pose, float t, ScenePreset s,
                            CinematicSceneConfig cfg, float alpha) {
        float[] root = new float[16];
        Matrix.setIdentityM(root, 0);
        Matrix.translateM(root, 0, pose.x, pose.y, pose.z);
        Matrix.rotateM(root, 0, pose.yaw, 0f, 1f, 0f);
        Matrix.rotateM(root, 0, pose.pitch, 1f, 0f, 0f);
        Matrix.rotateM(root, 0, pose.roll, 0f, 0f, 1f);
        float scale = 0.72f * cfg.intensity;
        Matrix.scaleM(root, 0, scale, scale, scale);

        float flap = pose.wing * 28f;
        float breathe = 1f + 0.025f * (float)Math.sin(t * 3.2f);

        // Body and chest.
        part(root, 0f, 0f, 0f, 0f,0f,0f, 0.82f*breathe,0.48f,1.38f, s, alpha, 0.48f);
        part(root, 0f, 0.18f,-0.72f, -12f,0f,0f, 0.63f,0.50f,0.72f, s, alpha, 0.54f);

        // Neck chain gives an organic curved silhouette.
        for (int i = 0; i < 5; i++) {
            float p = i / 4f;
            part(root, 0f, 0.30f + p*0.50f, -1.0f - p*0.72f,
                    -18f + p*12f, 0f, 0f,
                    0.37f - p*0.055f, 0.34f - p*0.045f, 0.50f, s, alpha, 0.44f);
        }

        // Head, muzzle, horn bases.
        part(root, 0f,0.86f,-1.92f, -4f,0f,0f, 0.46f,0.35f,0.62f, s, alpha, 0.62f);
        part(root, 0f,0.76f,-2.43f, 5f,0f,0f, 0.34f,0.25f,0.52f, s, alpha, 0.58f);
        part(root,-0.22f,1.12f,-2.00f, -35f,0f,-12f, 0.08f,0.08f,0.47f, s, alpha, 0.72f);
        part(root, 0.22f,1.12f,-2.00f, -35f,0f, 12f, 0.08f,0.08f,0.47f, s, alpha, 0.72f);

        // Rear legs and forelegs.
        limb(root, -0.48f,-0.22f,0.45f, 18f, 0.18f,0.22f,0.72f, s, alpha);
        limb(root,  0.48f,-0.22f,0.45f,-18f, 0.18f,0.22f,0.72f, s, alpha);
        limb(root, -0.42f, 0.05f,-0.72f, 12f, 0.13f,0.17f,0.58f, s, alpha);
        limb(root,  0.42f, 0.05f,-0.72f,-12f, 0.13f,0.17f,0.58f, s, alpha);

        // Tail: articulated chain with wave lag.
        for (int i = 0; i < 9; i++) {
            float p = i / 8f;
            float wave = (float)Math.sin(t * 2.1f - i * 0.58f) * (0.18f + p*0.24f);
            part(root, wave, 0.06f + 0.08f*(float)Math.sin(i*0.7f), 1.12f + i*0.40f,
                    3f*(float)Math.sin(t+i), 0f, wave*8f,
                    0.34f*(1f-p*0.72f), 0.27f*(1f-p*0.72f), 0.48f, s, alpha, 0.40f);
        }

        drawWing(root, true, flap, s, alpha);
        drawWing(root, false, -flap, s, alpha);

        // Dorsal spikes.
        for (int i = 0; i < 6; i++) {
            float z = -0.9f + i*0.42f;
            part(root, 0f,0.52f,z, -65f,0f,0f, 0.07f,0.28f,0.16f, s, alpha, 0.75f);
        }
    }

    private void limb(float[] root, float x, float y, float z, float rz,
                      float sx, float sy, float sz, ScenePreset s, float alpha) {
        part(root, x,y,z, 24f,0f,rz, sx,sy,sz, s,alpha,0.42f);
        part(root, x*1.08f,y-0.46f,z-0.20f, -16f,0f,rz, sx*0.72f,sy*0.72f,sz*0.75f, s,alpha,0.50f);
    }

    private void drawWing(float[] root, boolean left, float flap, ScenePreset s, float alpha) {
        GLES20.glUseProgram(meshProgram);
        System.arraycopy(root, 0, model, 0, 16);
        float side = left ? -1f : 1f;
        Matrix.translateM(model, 0, side*0.58f,0.26f,-0.15f);
        Matrix.rotateM(model, 0, side*(20f + flap), 0f,0f,1f);
        Matrix.rotateM(model, 0, side*8f, 0f,1f,0f);
        Matrix.scaleM(model, 0, side, 1f, 1f);
        Matrix.multiplyMM(mvp, 0, pv, 0, model, 0);
        bindMeshUniforms(s, alpha, 0.32f);
        int aPos = GLES20.glGetAttribLocation(meshProgram, "aPos");
        int aNormal = GLES20.glGetAttribLocation(meshProgram, "aNormal");
        wingBuffer.position(0);
        GLES20.glEnableVertexAttribArray(aPos);
        GLES20.glVertexAttribPointer(aPos, 3, GLES20.GL_FLOAT, false, 24, wingBuffer);
        wingBuffer.position(3);
        GLES20.glEnableVertexAttribArray(aNormal);
        GLES20.glVertexAttribPointer(aNormal, 3, GLES20.GL_FLOAT, false, 24, wingBuffer);
        GLES20.glDisable(GLES20.GL_CULL_FACE);
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, 12);
        GLES20.glEnable(GLES20.GL_CULL_FACE);
        GLES20.glDisableVertexAttribArray(aPos);
        GLES20.glDisableVertexAttribArray(aNormal);
    }

    private void part(float[] root, float x,float y,float z,
                      float rx,float ry,float rz, float sx,float sy,float sz,
                      ScenePreset s,float alpha,float metallic) {
        System.arraycopy(root, 0, model, 0, 16);
        Matrix.translateM(model, 0, x,y,z);
        Matrix.rotateM(model, 0, rx,1f,0f,0f);
        Matrix.rotateM(model, 0, ry,0f,1f,0f);
        Matrix.rotateM(model, 0, rz,0f,0f,1f);
        Matrix.scaleM(model, 0, sx,sy,sz);
        drawSphereModel(s, alpha, metallic);
    }

    private void drawSphereModel(ScenePreset s, float alpha, float metallic) {
        GLES20.glUseProgram(meshProgram);
        Matrix.multiplyMM(mvp, 0, pv, 0, model, 0);
        bindMeshUniforms(s, alpha, metallic);
        int aPos = GLES20.glGetAttribLocation(meshProgram, "aPos");
        int aNormal = GLES20.glGetAttribLocation(meshProgram, "aNormal");
        sphereBuffer.position(0);
        GLES20.glEnableVertexAttribArray(aPos);
        GLES20.glVertexAttribPointer(aPos, 3, GLES20.GL_FLOAT, false, 24, sphereBuffer);
        sphereBuffer.position(3);
        GLES20.glEnableVertexAttribArray(aNormal);
        GLES20.glVertexAttribPointer(aNormal, 3, GLES20.GL_FLOAT, false, 24, sphereBuffer);
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, sphereVertexCount);
        GLES20.glDisableVertexAttribArray(aPos);
        GLES20.glDisableVertexAttribArray(aNormal);
    }

    private void bindMeshUniforms(ScenePreset s, float alpha, float metallic) {
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(meshProgram,"uMvp"),1,false,mvp,0);
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(meshProgram,"uModel"),1,false,model,0);
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(meshProgram,"uPrimary"),1,s.primary,0);
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(meshProgram,"uAccent"),1,s.accent,0);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(meshProgram,"uAlpha"),alpha);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(meshProgram,"uMetallic"),metallic);
    }

    private void drawSkyClouds(float t, ScenePreset s, CinematicSceneConfig cfg) {
        GLES20.glUseProgram(simpleProgram);
        Matrix.setIdentityM(model,0);
        Matrix.rotateM(model,0,t*0.8f,0f,1f,0f);
        Matrix.multiplyMM(mvp,0,pv,0,model,0);
        simplePoints(cloudBuffer, CLOUD_COUNT,
                new float[]{0.50f,0.62f,0.75f, cfg.cinematicFog ? 0.18f : 0.08f},
                22f);
    }

    private void drawForegroundFog(float t, ScenePreset s, CinematicSceneConfig cfg) {
        GLES20.glDepthMask(false);
        GLES20.glUseProgram(simpleProgram);
        Matrix.setIdentityM(model,0);
        Matrix.translateM(model,0,0f,-0.35f + 0.12f*(float)Math.sin(t*0.35f),2.3f);
        Matrix.scaleM(model,0,0.58f,0.36f,0.42f);
        Matrix.multiplyMM(mvp,0,pv,0,model,0);
        simplePoints(cloudBuffer, CLOUD_COUNT,
                new float[]{s.primary[0]*0.45f+0.2f,s.primary[1]*0.45f+0.2f,s.primary[2]*0.45f+0.2f,0.10f},
                34f);
        GLES20.glDepthMask(true);
    }

    private void drawFire(DragonFlightPath.Pose pose, float t, ScenePreset s, CinematicSceneConfig cfg) {
        fireBuffer.position(0);
        float yaw = (float)Math.toRadians(pose.yaw);
        float fx = -(float)Math.sin(yaw);
        float fz = -(float)Math.cos(yaw);
        float baseX = pose.x + fx * 1.65f * cfg.intensity;
        float baseY = pose.y + 0.58f * cfg.intensity;
        float baseZ = pose.z + fz * 1.65f * cfg.intensity;
        for (int i=0;i<FIRE_COUNT;i++) {
            float p = i/(float)(FIRE_COUNT-1);
            float seed = hash(i*13+7);
            float seed2 = hash(i*29+3);
            float spread = 0.10f + p*0.42f;
            float life = (p + (t*0.62f + seed) % 1f) % 1f;
            float dist = life * 3.0f * pose.fire * cfg.intensity;
            fireBuffer.put(baseX + fx*dist + (seed-0.5f)*spread);
            fireBuffer.put(baseY + (seed2-0.5f)*spread + 0.20f*(float)Math.sin(life*Math.PI));
            fireBuffer.put(baseZ + fz*dist + (seed2-0.5f)*spread);
        }
        fireBuffer.position(0);
        GLES20.glDepthMask(false);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA,GLES20.GL_ONE);
        GLES20.glUseProgram(simpleProgram);
        Matrix.setIdentityM(model,0);
        Matrix.multiplyMM(mvp,0,pv,0,model,0);
        simplePoints(fireBuffer,FIRE_COUNT,new float[]{1f,0.22f+0.45f*(1f-pose.fire),0.02f,0.78f},13f+18f*pose.fire);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA,GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glDepthMask(true);
    }

    private void drawGround(ScenePreset s, DragonFlightPath.Pose pose, CinematicSceneConfig cfg) {
        Matrix.setIdentityM(model,0);
        Matrix.translateM(model,0,0f,-0.02f,0f);
        Matrix.scaleM(model,0,7.5f,0.05f,7.5f);
        drawSphereModel(s,1f,0.18f);

        // Impact glow at landing.
        if (pose.landingImpact > 0.02f) {
            GLES20.glDepthMask(false);
            GLES20.glUseProgram(simpleProgram);
            float[] ring = buildImpactRing(pose.landingImpact * 3.2f + 0.6f);
            FloatBuffer rb = allocate(ring);
            Matrix.setIdentityM(model,0);
            Matrix.translateM(model,0,0f,0.06f,-0.5f);
            Matrix.rotateM(model,0,90f,1f,0f,0f);
            Matrix.multiplyMM(mvp,0,pv,0,model,0);
            simpleLine(rb,ring.length/3,new float[]{s.accent[0],s.accent[1],s.accent[2],0.65f*pose.landingImpact},4f);
            GLES20.glDepthMask(true);
        }
    }

    private void simplePoints(FloatBuffer buffer, int count, float[] color, float pointSize) {
        int aPos = GLES20.glGetAttribLocation(simpleProgram,"aPos");
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(simpleProgram,"uMvp"),1,false,mvp,0);
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(simpleProgram,"uColor"),1,color,0);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(simpleProgram,"uPointSize"),pointSize);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(simpleProgram,"uRoundPoint"),1f);
        buffer.position(0);
        GLES20.glEnableVertexAttribArray(aPos);
        GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,12,buffer);
        GLES20.glDrawArrays(GLES20.GL_POINTS,0,count);
        GLES20.glDisableVertexAttribArray(aPos);
    }

    private void simpleLine(FloatBuffer buffer,int count,float[] color,float width) {
        int aPos=GLES20.glGetAttribLocation(simpleProgram,"aPos");
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(simpleProgram,"uMvp"),1,false,mvp,0);
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(simpleProgram,"uColor"),1,color,0);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(simpleProgram,"uPointSize"),2f);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(simpleProgram,"uRoundPoint"),0f);
        buffer.position(0);
        GLES20.glEnableVertexAttribArray(aPos);
        GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,12,buffer);
        GLES20.glLineWidth(width);
        GLES20.glDrawArrays(GLES20.GL_LINE_STRIP,0,count);
        GLES20.glDisableVertexAttribArray(aPos);
    }

    private static float[] buildSphere(int stacks, int slices) {
        float[] out = new float[stacks*slices*6*6];
        int o=0;
        for (int i=0;i<stacks;i++) {
            float v0=i/(float)stacks, v1=(i+1)/(float)stacks;
            float p0=(v0-0.5f)*(float)Math.PI, p1=(v1-0.5f)*(float)Math.PI;
            for (int j=0;j<slices;j++) {
                float u0=j/(float)slices, u1=(j+1)/(float)slices;
                float a0=u0*(float)Math.PI*2f, a1=u1*(float)Math.PI*2f;
                float[] A=point(p0,a0), B=point(p0,a1), C=point(p1,a1), D=point(p1,a0);
                o=put(out,o,A); o=put(out,o,B); o=put(out,o,C);
                o=put(out,o,A); o=put(out,o,C); o=put(out,o,D);
            }
        }
        return out;
    }

    private static float[] point(float p,float a) {
        float cp=(float)Math.cos(p);
        return new float[]{cp*(float)Math.sin(a),(float)Math.sin(p),cp*(float)Math.cos(a)};
    }

    private static int put(float[] out,int o,float[] p) {
        out[o++]=p[0]; out[o++]=p[1]; out[o++]=p[2];
        out[o++]=p[0]; out[o++]=p[1]; out[o++]=p[2];
        return o;
    }

    private static float[] buildWing() {
        // position + approximate normal. Four triangles form a swept leathery wing.
        return new float[]{
            0,0,0, 0,0.55f,0.83f,   -1.15f,0.15f,-0.10f, 0,0.55f,0.83f,   -2.75f,-0.28f,0.42f, 0,0.55f,0.83f,
            0,0,0, 0,0.55f,0.83f,   -2.75f,-0.28f,0.42f, 0,0.55f,0.83f,   -1.58f,-0.66f,1.18f, 0,0.55f,0.83f,
            -1.15f,0.15f,-0.10f, 0,0.55f,0.83f,  -3.15f,0.06f,1.28f, 0,0.55f,0.83f, -2.75f,-0.28f,0.42f, 0,0.55f,0.83f,
            -2.75f,-0.28f,0.42f, 0,0.55f,0.83f, -3.15f,0.06f,1.28f, 0,0.55f,0.83f, -1.58f,-0.66f,1.18f, 0,0.55f,0.83f
        };
    }

    private static float[] buildClouds() {
        float[] data=new float[CLOUD_COUNT*3];
        for(int i=0;i<CLOUD_COUNT;i++) {
            float r=4.5f+hash(i*17)*12f;
            float a=hash(i*31+4)*(float)Math.PI*2f;
            data[i*3]=(float)Math.sin(a)*r;
            data[i*3+1]=-0.5f+hash(i*47+9)*7.5f;
            data[i*3+2]=-9f+(float)Math.cos(a)*r;
        }
        return data;
    }

    private static float[] buildImpactRing(float radius) {
        int n=72; float[] d=new float[(n+1)*3];
        for(int i=0;i<=n;i++) {
            float a=i/(float)n*(float)Math.PI*2f;
            d[i*3]=(float)Math.cos(a)*radius;
            d[i*3+1]=(float)Math.sin(a)*radius;
            d[i*3+2]=0f;
        }
        return d;
    }

    private static float hash(int x) {
        int n=x*374761393 + 668265263;
        n=(n^(n>>>13))*1274126177;
        n=n^(n>>>16);
        return (n & 0x7fffffff)/(float)0x7fffffff;
    }

    private static int createProgram(String vs,String fs) {
        int vertex=loadShader(GLES20.GL_VERTEX_SHADER,vs);
        int fragment=loadShader(GLES20.GL_FRAGMENT_SHADER,fs);
        int program=GLES20.glCreateProgram();
        GLES20.glAttachShader(program,vertex); GLES20.glAttachShader(program,fragment); GLES20.glLinkProgram(program);
        int[] ok=new int[1]; GLES20.glGetProgramiv(program,GLES20.GL_LINK_STATUS,ok,0);
        if(ok[0]==0) throw new IllegalStateException("OpenGL link failed: "+GLES20.glGetProgramInfoLog(program));
        GLES20.glDeleteShader(vertex); GLES20.glDeleteShader(fragment); return program;
    }

    private static int loadShader(int type,String source) {
        int shader=GLES20.glCreateShader(type); GLES20.glShaderSource(shader,source); GLES20.glCompileShader(shader);
        int[] ok=new int[1]; GLES20.glGetShaderiv(shader,GLES20.GL_COMPILE_STATUS,ok,0);
        if(ok[0]==0) throw new IllegalStateException("OpenGL shader failed: "+GLES20.glGetShaderInfoLog(shader));
        return shader;
    }

    private static float clamp(float x) { return Math.max(0f,Math.min(1f,x)); }

    private static final String MESH_VERTEX =
            "uniform mat4 uMvp; uniform mat4 uModel; attribute vec3 aPos; attribute vec3 aNormal;"+
            "varying vec3 vNormal; varying vec3 vPos; varying float vDepth;"+
            "void main(){ vec4 wp=uModel*vec4(aPos,1.0); vPos=wp.xyz; vNormal=normalize(mat3(uModel)*aNormal);"+
            "vec4 clip=uMvp*vec4(aPos,1.0); gl_Position=clip; vDepth=clip.w; }";

    private static final String MESH_FRAGMENT =
            "precision mediump float; uniform vec4 uPrimary; uniform vec4 uAccent; uniform float uAlpha; uniform float uMetallic;"+
            "varying vec3 vNormal; varying vec3 vPos; varying float vDepth;"+
            "void main(){ vec3 n=normalize(vNormal); vec3 l=normalize(vec3(-0.35,0.82,0.48)); vec3 v=normalize(vec3(0.0,0.7,5.0)-vPos);"+
            "vec3 h=normalize(l+v); float diff=max(dot(n,l),0.0); float spec=pow(max(dot(n,h),0.0),18.0+58.0*uMetallic);"+
            "float rim=pow(1.0-max(dot(n,v),0.0),2.4); vec3 base=mix(uPrimary.rgb,uAccent.rgb,0.12+0.16*uMetallic);"+
            "vec3 c=base*(0.18+0.92*diff)+vec3(spec)*(0.22+0.9*uMetallic)+uAccent.rgb*rim*0.40;"+
            "float fog=clamp((vDepth-4.0)/25.0,0.0,0.52); c=mix(c,vec3(0.04,0.06,0.09),fog);"+
            "gl_FragColor=vec4(c,uAlpha); }";

    private static final String SIMPLE_VERTEX =
            "uniform mat4 uMvp; uniform float uPointSize; attribute vec3 aPos;"+
            "void main(){ gl_Position=uMvp*vec4(aPos,1.0); gl_PointSize=uPointSize; }";

    private static final String SIMPLE_FRAGMENT =
            "precision mediump float; uniform vec4 uColor; uniform float uRoundPoint;"+
            "void main(){ float a=1.0; if(uRoundPoint>0.5){ vec2 p=gl_PointCoord-vec2(0.5); float d=dot(p,p); a=smoothstep(0.25,0.02,d); } gl_FragColor=vec4(uColor.rgb,uColor.a*a); }";
}
