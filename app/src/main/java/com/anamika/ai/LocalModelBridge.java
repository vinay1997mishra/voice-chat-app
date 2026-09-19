package com.anamika.ai;

import android.content.Context;
import android.os.Build;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/** Java-side adapter for the optional bundled on-device GGUF coding model. No network call is performed here. */
public final class LocalModelBridge {
    public static final String MODEL_FILE = "anamika-coder.gguf";

    public static final class ModelStatus {
        public final boolean ready;
        public final String message;
        ModelStatus(boolean ready, String message) { this.ready = ready; this.message = message; }
    }

    private LocalModelBridge() { }

    public static ModelStatus getStatus(Context context) {
        if (!supportsArm64()) {
            return new ModelStatus(false, "Bundled llama runtime requires arm64-v8a on this build.");
        }
        File model = new File(context.getFilesDir(), "models/" + MODEL_FILE);
        if (!model.isFile() || model.length() < 16L * 1024L * 1024L) tryInstallBundledModel(context, model);
        if (!runtimeAvailable()) {
            return new ModelStatus(false, "On-device llama runtime dependency is unavailable in this APK.");
        }
        if (!model.isFile() || model.length() < 16L * 1024L * 1024L) {
            return new ModelStatus(false, "Local coding model weights are not bundled/installed. Expected asset: models/" + MODEL_FILE);
        }
        return new ModelStatus(true, "On-device coding model ready: " + model.getAbsolutePath());
    }

    private static boolean supportsArm64() {
        for (String abi : Build.SUPPORTED_ABIS) if ("arm64-v8a".equals(abi)) return true;
        return false;
    }

    private static boolean runtimeAvailable() {
        try {
            Class.forName("dev.ffmpegkit.llama.Llama");
            return true;
        } catch (Throwable ignored) {
            return false;
        }
    }

    private static void tryInstallBundledModel(Context context, File target) {
        File tmp = new File(target.getParentFile(), target.getName() + ".partial");
        try {
            File parent = target.getParentFile();
            if (parent != null && !parent.exists() && !parent.mkdirs()) return;
            if (tmp.exists()) tmp.delete();
            long available = context.getFilesDir().getUsableSpace();
            // The bundled model used by the build is ~1.1 GB; leave headroom for extraction and runtime cache.
            if (available > 0 && available < 1400L * 1024L * 1024L) return;
            try (InputStream in = context.getAssets().open("models/" + MODEL_FILE);
                 FileOutputStream out = new FileOutputStream(tmp)) {
                byte[] buffer = new byte[1024 * 1024];
                int n;
                while ((n = in.read(buffer)) > 0) out.write(buffer, 0, n);
                out.getFD().sync();
            }
            if (tmp.length() < 16L * 1024L * 1024L) throw new IllegalStateException("Bundled model asset is incomplete.");
            if (target.exists() && !target.delete()) throw new IllegalStateException("Cannot replace local model.");
            if (!tmp.renameTo(target)) throw new IllegalStateException("Cannot finalize local model extraction.");
        } catch (Exception ignored) {
            if (tmp.exists()) tmp.delete();
            if (target.exists() && target.length() < 16L * 1024L * 1024L) target.delete();
        }
    }

    public static String generate(Context context, String prompt) {
        ModelStatus status = getStatus(context);
        if (!status.ready) throw new IllegalStateException(status.message);
        File model = new File(context.getFilesDir(), "models/" + MODEL_FILE);
        return KotlinLlamaRunner.generateBlocking(model.getAbsolutePath(), prompt);
    }
}
