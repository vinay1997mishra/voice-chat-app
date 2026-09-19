package com.anamika.ai.media3d;

import android.content.Context;
import android.opengl.GLSurfaceView;

public final class Premium3DSurfaceView extends GLSurfaceView {
    private final Premium3DRenderer renderer;

    public Premium3DSurfaceView(Context context) {
        super(context);
        setEGLContextClientVersion(2);
        setEGLConfigChooser(8,8,8,8,24,0);
        renderer=new Premium3DRenderer();
        setRenderer(renderer);
        setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
    }

    public void setPreset(ScenePreset preset) { queueEvent(() -> renderer.setPreset(preset)); }
    public void setScene(CinematicSceneConfig scene) { queueEvent(() -> renderer.setScene(scene)); }
    public Premium3DRenderer getRenderer() { return renderer; }
}
