package com.anamika.ai.media3d;

/** Immutable offline cinematic scene configuration. */
public final class CinematicSceneConfig {
    public final ScenePreset preset;
    public final SceneSubject subject;
    public final boolean fireBreath;
    public final boolean cinematicFog;
    public final boolean impactShake;
    public final float intensity;
    public final int durationSeconds;
    public final String brief;

    public CinematicSceneConfig(ScenePreset preset, SceneSubject subject, boolean fireBreath,
                                boolean cinematicFog, boolean impactShake,
                                float intensity, int durationSeconds, String brief) {
        this.preset = preset == null ? ScenePreset.CINEMATIC_DRAGON : preset;
        this.subject = subject == null ? SceneSubject.DRAGON : subject;
        this.fireBreath = fireBreath;
        this.cinematicFog = cinematicFog;
        this.impactShake = impactShake;
        this.intensity = Math.max(0.2f, Math.min(2.0f, intensity));
        this.durationSeconds = Math.max(6, Math.min(30, durationSeconds));
        this.brief = brief == null ? "" : brief;
    }

    public static CinematicSceneConfig defaultDragon() {
        return new CinematicSceneConfig(ScenePreset.CINEMATIC_DRAGON, SceneSubject.DRAGON,
                true, true, true, 1.0f, 12, "cinematic dragon");
    }
}
