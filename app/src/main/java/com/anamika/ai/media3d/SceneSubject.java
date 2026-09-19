package com.anamika.ai.media3d;

/** Built-in offline procedural cinematic subjects. CUSTOM_ASSET is a fallback slot for imported assets. */
public enum SceneSubject {
    DRAGON("Dragon"), PHOENIX("Phoenix"), EAGLE("Eagle"), WOLF("Wolf"), LION("Lion"),
    SUPERCAR("Supercar"), SPACESHIP("Spaceship"), ROBOT("Robot"),
    CRYSTAL("Crystal / Logo Object"), CUSTOM_ASSET("Custom 3D Asset");

    public final String title;
    SceneSubject(String title) { this.title = title; }
    @Override public String toString() { return title; }
}
