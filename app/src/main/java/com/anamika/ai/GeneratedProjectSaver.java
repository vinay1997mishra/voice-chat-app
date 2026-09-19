package com.anamika.ai;

import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Map;

/** Saves only structurally clean + real-toolchain-verified generated projects. */
public final class GeneratedProjectSaver {
    private GeneratedProjectSaver() { }

    public static File save(Context context, String generatedText) throws Exception {
        Map<String,String> files = OfflineCodeValidator.parse(generatedText);
        if (files.isEmpty()) {
            throw new IllegalStateException("No <<<FILE:path>>> blocks were found; nothing was saved.");
        }

        OfflineCodeValidator.Report report = OfflineCodeValidator.validateGeneratedText(generatedText);
        if (!report.isClean()) {
            throw new IllegalStateException("Project has structural validation errors and will not be saved as verified. " + report.details());
        }
        CompilerPackManager.Report compilerReport = CompilerPackManager.verifyFiles(context, files);
        if (!compilerReport.isFullyVerified()) {
            throw new IllegalStateException("Real compiler verification is incomplete. " + compilerReport.details());
        }

        File root = context.getExternalFilesDir("generated_projects");
        if (root == null) root = new File(context.getFilesDir(), "generated_projects");
        if (!root.exists() && !root.mkdirs()) throw new IllegalStateException("Cannot create project storage.");

        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(new Date());
        File project = new File(root, "AnamikaGenerated_" + stamp);
        if (!project.mkdirs()) throw new IllegalStateException("Cannot create generated project folder.");

        boolean ok = false;
        try {
            String projectCanonical = project.getCanonicalPath() + File.separator;
            for (Map.Entry<String,String> entry : files.entrySet()) {
                String path = requireSafeRelativePath(entry.getKey());
                File out = new File(project, path);
                String outCanonical = out.getCanonicalPath();
                if (!outCanonical.startsWith(projectCanonical)) {
                    throw new SecurityException("Generated file escapes project folder: " + path);
                }
                File parent = out.getParentFile();
                if (parent != null && !parent.exists() && !parent.mkdirs()) {
                    throw new IllegalStateException("Cannot create folder for " + path);
                }
                try (FileOutputStream fos = new FileOutputStream(out)) {
                    fos.write((entry.getValue() == null ? "" : entry.getValue()).getBytes(StandardCharsets.UTF_8));
                }
            }

            write(new File(project, "ANAMIKA_GENERATION.txt"), generatedText == null ? "" : generatedText);
            write(new File(project, "ANAMIKA_VERIFICATION.txt"),
                    "STRUCTURAL VALIDATION\n" + report.details() +
                    "\n\nREAL TOOLCHAIN VERIFICATION\n" + compilerReport.details() +
                    "\n\nSaved only after all required checks passed.\n");
            ok = true;
            return project;
        } finally {
            if (!ok) deleteTree(project);
        }
    }

    private static String requireSafeRelativePath(String raw) {
        String path = raw == null ? "" : raw.trim().replace('\\', '/');
        if (path.isEmpty() || path.startsWith("/") || path.indexOf('\0') >= 0) {
            throw new SecurityException("Unsafe generated output path: " + raw);
        }
        String[] parts = path.split("/");
        StringBuilder clean = new StringBuilder();
        for (String part : parts) {
            if (part.isEmpty() || ".".equals(part)) continue;
            if ("..".equals(part)) throw new SecurityException("Parent path traversal is not allowed: " + raw);
            if (clean.length() > 0) clean.append('/');
            clean.append(part);
        }
        if (clean.length() == 0) throw new SecurityException("Unsafe generated output path: " + raw);
        return clean.toString();
    }

    private static void write(File file, String text) throws Exception {
        try (FileOutputStream fos = new FileOutputStream(file)) {
            fos.write(text.getBytes(StandardCharsets.UTF_8));
        }
    }

    private static void deleteTree(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File child : children) deleteTree(child);
        }
        try { f.delete(); } catch (Exception ignored) { }
    }
}
