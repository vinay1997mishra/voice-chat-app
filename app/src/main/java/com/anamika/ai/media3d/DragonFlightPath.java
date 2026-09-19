package com.anamika.ai.media3d;

/** Deterministic cinematic flight choreography for the offline procedural dragon. */
public final class DragonFlightPath {
    public static final class Pose {
        public final float x, y, z;
        public final float yaw, pitch, roll;
        public final float wing;
        public final float fire;
        public final float landingImpact;

        Pose(float x, float y, float z, float yaw, float pitch, float roll,
             float wing, float fire, float landingImpact) {
            this.x = x; this.y = y; this.z = z;
            this.yaw = yaw; this.pitch = pitch; this.roll = roll;
            this.wing = wing; this.fire = fire; this.landingImpact = landingImpact;
        }
    }

    private DragonFlightPath() { }

    public static Pose sample(float seconds, float duration) {
        float d = Math.max(1f, duration);
        float u = clamp(seconds / d);
        float x, y, z, yaw, pitch, roll;

        if (u < 0.36f) {
            float p = smooth(u / 0.36f);
            float a = p * (float)(Math.PI * 2.2);
            float radius = 3.6f - 0.8f * p;
            x = (float)Math.sin(a) * radius;
            z = -2.0f + (float)Math.cos(a) * radius;
            y = 4.6f - 0.9f * p + 0.35f * (float)Math.sin(a * 1.7f);
            yaw = (float)Math.toDegrees(-a) + 90f;
            pitch = -8f - 12f * p;
            roll = 18f * (float)Math.sin(a);
        } else if (u < 0.74f) {
            float p = smooth((u - 0.36f) / 0.38f);
            float a = (float)(Math.PI * 0.75 + p * Math.PI * 0.85);
            x = 2.2f * (1f - p) * (float)Math.sin(a);
            z = -4.0f + 3.3f * p;
            y = 3.8f - 3.0f * p;
            yaw = 155f - 145f * p;
            pitch = -20f + 12f * p;
            roll = 12f * (1f - p) * (float)Math.sin(p * Math.PI * 2f);
        } else {
            float p = smooth((u - 0.74f) / 0.26f);
            x = 0.25f * (1f - p) * (float)Math.sin(p * 7f);
            z = -0.7f + 0.15f * p;
            y = 0.82f + 0.06f * (float)Math.sin(p * Math.PI) * (1f - p);
            yaw = 10f * (1f - p);
            pitch = -5f + 5f * p;
            roll = 5f * (1f - p) * (float)Math.sin(p * 8f);
        }

        float wing = (float)Math.sin(seconds * 7.4f) * (u < 0.78f ? 1f : (1f - smooth((u - 0.78f) / 0.22f)));
        float fire = pulse(u, 0.58f, 0.70f) + 0.65f * pulse(u, 0.88f, 0.96f);
        fire = Math.min(1f, fire);
        float impact = pulse(u, 0.765f, 0.81f);
        return new Pose(x, y, z, yaw, pitch, roll, wing, fire, impact);
    }

    private static float pulse(float x, float a, float b) {
        if (x <= a || x >= b) return 0f;
        float p = (x - a) / (b - a);
        return (float)Math.sin(p * Math.PI);
    }

    private static float smooth(float x) {
        x = clamp(x);
        return x * x * (3f - 2f * x);
    }

    private static float clamp(float x) { return Math.max(0f, Math.min(1f, x)); }
}
