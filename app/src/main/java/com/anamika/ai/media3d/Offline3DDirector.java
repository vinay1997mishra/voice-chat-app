package com.anamika.ai.media3d;

import java.util.Locale;

/** Lightweight no-network prompt director for choosing a procedural 3D look. */
public final class Offline3DDirector {
    private Offline3DDirector() { }

    public static ScenePreset choosePreset(String brief) {
        String b = brief == null ? "" : brief.toLowerCase(Locale.ROOT);
        if (containsAny(b, "love", "romantic", "heart", "pink", "couple", "प्यार", "लव")) return ScenePreset.LOVE_CRYSTAL;
        if (containsAny(b, "gold", "royal", "king", "queen", "vip", "luxury", "crown", "गोल्ड", "रॉयल")) return ScenePreset.GOLD_LUXURY;
        if (containsAny(b, "black", "danger", "eagle", "dark", "diamond", "power", "ब्लैक", "डेंजर")) return ScenePreset.BLACK_DIAMOND;
        return ScenePreset.NEON_CORE;
    }

    private static boolean containsAny(String text, String... terms) {
        for (String term : terms) if (text.contains(term)) return true;
        return false;
    }
}
