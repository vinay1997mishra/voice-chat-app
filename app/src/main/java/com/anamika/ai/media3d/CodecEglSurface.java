package com.anamika.ai.media3d;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.view.Surface;

/** Minimal EGL wrapper for rendering OpenGL ES frames directly into MediaCodec. */
final class CodecEglSurface {
    private static final int EGL_RECORDABLE_ANDROID = 0x3142;

    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface eglSurface = EGL14.EGL_NO_SURFACE;
    private final Surface surface;

    CodecEglSurface(Surface surface) {
        this.surface = surface;
        setup();
    }

    private void setup() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (display == EGL14.EGL_NO_DISPLAY) throw new IllegalStateException("Unable to get EGL display");
        int[] version = new int[2];
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
            throw new IllegalStateException("Unable to initialize EGL");
        }
        int[] attrib = {
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_DEPTH_SIZE, 16,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL_RECORDABLE_ANDROID, 1,
                EGL14.EGL_NONE
        };
        EGLConfig[] configs = new EGLConfig[1];
        int[] count = new int[1];
        if (!EGL14.eglChooseConfig(display, attrib, 0, configs, 0, 1, count, 0) || count[0] <= 0) {
            throw new IllegalStateException("No recordable EGL config");
        }
        int[] ctxAttrib = {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE};
        context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttrib, 0);
        check("eglCreateContext");
        int[] surfaceAttrib = {EGL14.EGL_NONE};
        eglSurface = EGL14.eglCreateWindowSurface(display, configs[0], surface, surfaceAttrib, 0);
        check("eglCreateWindowSurface");
    }

    void makeCurrent() {
        if (!EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) {
            throw new IllegalStateException("eglMakeCurrent failed");
        }
    }

    void setPresentationTime(long nanos) {
        EGLExt.eglPresentationTimeANDROID(display, eglSurface, nanos);
    }

    boolean swapBuffers() {
        return EGL14.eglSwapBuffers(display, eglSurface);
    }

    void release() {
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            EGL14.eglDestroySurface(display, eglSurface);
            EGL14.eglDestroyContext(display, context);
            EGL14.eglReleaseThread();
            EGL14.eglTerminate(display);
        }
        surface.release();
        display = EGL14.EGL_NO_DISPLAY;
        context = EGL14.EGL_NO_CONTEXT;
        eglSurface = EGL14.EGL_NO_SURFACE;
    }

    private void check(String op) {
        int error = EGL14.eglGetError();
        if (error != EGL14.EGL_SUCCESS) throw new IllegalStateException(op + " EGL error 0x" + Integer.toHexString(error));
    }
}
