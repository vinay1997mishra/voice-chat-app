package com.anamika.ai.media3d;

/** Offline procedural/PBR-inspired cinematic palettes. */
public enum ScenePreset {
    CINEMATIC_DRAGON("Cinematic Dragon", new float[]{0.008f,0.012f,0.025f,1f}, new float[]{0.11f,0.24f,0.34f,1f}, new float[]{1f,0.24f,0.035f,1f}),
    ROYAL_FIRE("Royal Fire Dragon", new float[]{0.018f,0.009f,0.003f,1f}, new float[]{0.38f,0.16f,0.035f,1f}, new float[]{1f,0.64f,0.08f,1f}),
    ICE_DRAGON("Ice Dragon", new float[]{0.004f,0.015f,0.035f,1f}, new float[]{0.12f,0.48f,0.66f,1f}, new float[]{0.58f,0.92f,1f,1f}),
    NEON_CORE("Neon Core", new float[]{0.015f,0.02f,0.07f,1f}, new float[]{0.15f,0.75f,1f,1f}, new float[]{0.8f,0.15f,1f,1f}),
    GOLD_LUXURY("Gold Luxury", new float[]{0.025f,0.018f,0.008f,1f}, new float[]{1f,0.72f,0.12f,1f}, new float[]{1f,0.92f,0.55f,1f}),
    BLACK_DIAMOND("Black Diamond", new float[]{0.005f,0.005f,0.008f,1f}, new float[]{0.18f,0.22f,0.28f,1f}, new float[]{0.6f,0.08f,0.04f,1f}),
    LOVE_CRYSTAL("Love Crystal", new float[]{0.05f,0.006f,0.025f,1f}, new float[]{1f,0.2f,0.55f,1f}, new float[]{1f,0.65f,0.82f,1f});

    public final String title;
    public final float[] background;
    public final float[] primary;
    public final float[] accent;

    ScenePreset(String title, float[] background, float[] primary, float[] accent) {
        this.title = title;
        this.background = background;
        this.primary = primary;
        this.accent = accent;
    }

    @Override public String toString() { return title; }
}
