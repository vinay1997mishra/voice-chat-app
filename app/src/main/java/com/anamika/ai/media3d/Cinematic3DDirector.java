package com.anamika.ai.media3d;

import java.util.Locale;

/** Offline prompt-to-scene director. No website, API or server is used. */
public final class Cinematic3DDirector {
    private Cinematic3DDirector() { }

    public static CinematicSceneConfig fromBrief(String brief) {
        String q = brief == null ? "" : brief.toLowerCase(Locale.ROOT);
        ScenePreset preset = ScenePreset.CINEMATIC_DRAGON;
        if (contains(q, "ice", "snow", "blue", "frost")) preset = ScenePreset.ICE_DRAGON;
        else if (contains(q, "gold", "royal", "king", "vip")) preset = ScenePreset.ROYAL_FIRE;
        else if (contains(q, "dark", "black", "night", "demon")) preset = ScenePreset.BLACK_DIAMOND;
        else if (contains(q, "love", "pink", "romantic")) preset = ScenePreset.LOVE_CRYSTAL;
        else if (contains(q, "neon", "cyber", "electric")) preset = ScenePreset.NEON_CORE;

        SceneSubject subject = SceneSubject.DRAGON;
        if (contains(q, "phoenix", "फीनिक्स")) subject = SceneSubject.PHOENIX;
        else if (contains(q, "eagle", "baaz", "बाज़", "गरुड़")) subject = SceneSubject.EAGLE;
        else if (contains(q, "wolf", "भेड़िया")) subject = SceneSubject.WOLF;
        else if (contains(q, "lion", "sher", "शेर")) subject = SceneSubject.LION;
        else if (contains(q, "car", "supercar", "lambo", "ferrari", "गाड़ी", "कार")) subject = SceneSubject.SUPERCAR;
        else if (contains(q, "spaceship", "space ship", "ufo", "rocket", "स्पेसशिप")) subject = SceneSubject.SPACESHIP;
        else if (contains(q, "robot", "android", "mech", "रोबोट")) subject = SceneSubject.ROBOT;
        else if (contains(q, "logo", "crystal", "diamond", "name reveal", "लोगो")) subject = SceneSubject.CRYSTAL;
        else if (contains(q, "custom asset", "gltf", "glb", "3d model")) subject = SceneSubject.CUSTOM_ASSET;

        boolean fire = subject == SceneSubject.DRAGON || subject == SceneSubject.PHOENIX;
        fire = fire && !contains(q, "no fire", "without fire", "ice breath");
        boolean fog = !contains(q, "clear sky", "no fog");
        boolean shake = !contains(q, "no shake", "stable camera");
        float intensity = contains(q, "extreme", "epic", "movie", "cinematic", "premium", "4d") ? 1.35f : 1.0f;
        int duration = contains(q, "long", "20 second", "20s") ? 20 : 12;
        return new CinematicSceneConfig(preset, subject, fire, fog, shake, intensity, duration, brief);
    }

    private static boolean contains(String q, String... terms) {
        for (String term : terms) if (q.contains(term)) return true;
        return false;
    }
}
