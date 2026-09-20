package com.anamika.ai;

import android.content.Context;

import com.chaquo.python.PyObject;
import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;

import org.eclipse.jdt.core.compiler.batch.BatchCompiler;
import org.mozilla.javascript.Function;
import org.mozilla.javascript.NativeArray;
import org.mozilla.javascript.NativeObject;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;

import org.jetbrains.kotlin.cli.jvm.compiler.EnvironmentConfigFiles;
import org.jetbrains.kotlin.cli.jvm.compiler.KotlinCoreEnvironment;
import org.jetbrains.kotlin.com.intellij.openapi.Disposable;
import org.jetbrains.kotlin.com.intellij.openapi.util.Disposer;
import org.jetbrains.kotlin.com.intellij.psi.PsiErrorElement;
import org.jetbrains.kotlin.com.intellij.psi.util.PsiTreeUtil;
import org.jetbrains.kotlin.config.CompilerConfiguration;
import org.jetbrains.kotlin.psi.KtFile;
import org.jetbrains.kotlin.psi.KtPsiFactory;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.List;

/**
 * Real in-process language verifiers bundled with Anamika.
 *
 * These are upstream compiler/runtime artifacts, not renamed placeholder binaries:
 *  - Python: Chaquopy CPython runtime.
 *  - Java: Eclipse ECJ compiler.
 *  - JavaScript: Mozilla Rhino compiler/parser.
 *  - TypeScript: Microsoft TypeScript compiler JS evaluated by Rhino.
 *  - Kotlin: JetBrains Kotlin compiler frontend parser.
 *
 * Full Android project builds still require Android SDK/aapt2/Gradle and are therefore
 * verified by the authoritative build workflow rather than faked on-device.
 */
public final class BundledToolchainVerifier {
    public static final class Outcome {
        public final boolean available;
        public final boolean pass;
        public final String pack;
        public final String detail;
        Outcome(boolean available, boolean pass, String pack, String detail) {
            this.available = available;
            this.pass = pass;
            this.pack = pack;
            this.detail = detail;
        }
    }

    private BundledToolchainVerifier() {}

    public static Outcome verify(Context context, String language, File root, List<String> relFiles) {
        try {
            if ("Python".equals(language)) return verifyPython(context, root, relFiles);
            if ("JavaScript".equals(language)) return verifyJavaScript(root, relFiles);
            if ("TypeScript".equals(language)) return verifyTypeScript(context, root, relFiles);
            if ("Java".equals(language)) return verifyJava(root, relFiles);
            if ("Kotlin".equals(language)) return verifyKotlin(root, relFiles);
            if ("Shell".equals(language)) return verifyShell(root, relFiles);
            return new Outcome(false, false, "none", "No bundled in-process verifier for " + language + ".");
        } catch (Throwable t) {
            return new Outcome(true, false, language + " bundled verifier",
                    t.getClass().getSimpleName() + ": " + String.valueOf(t.getMessage()));
        }
    }

    public static Outcome inventory(Context context, String language) {
        try {
            if ("Python".equals(language)) {
                Class.forName("com.chaquo.python.Python");
                return new Outcome(true, true, "Chaquopy CPython 3.13", "Bundled Android Python runtime.");
            }
            if ("Java".equals(language)) {
                Class.forName("org.eclipse.jdt.core.compiler.batch.BatchCompiler");
                return new Outcome(true, true, "Eclipse ECJ 3.46.100", "Bundled Java compiler.");
            }
            if ("JavaScript".equals(language)) {
                Class.forName("org.mozilla.javascript.Context");
                return new Outcome(true, true, "Mozilla Rhino 1.9.1", "Bundled JavaScript compiler/runtime.");
            }
            if ("TypeScript".equals(language)) {
                Class.forName("org.mozilla.javascript.Context");
                try (InputStream in = context.getAssets().open("toolchains/typescript.js")) {
                    if (in.read() >= 0) return new Outcome(true, true, "Microsoft TypeScript 5.9.3", "Bundled compiler asset + Rhino runtime.");
                }
                return new Outcome(false, false, "Microsoft TypeScript 5.9.3", "Compiler asset empty.");
            }
            if ("Kotlin".equals(language)) {
                Class.forName("org.jetbrains.kotlin.cli.jvm.compiler.KotlinCoreEnvironment");
                return new Outcome(true, true, "JetBrains Kotlin compiler 2.2.21", "Bundled Kotlin compiler frontend.");
            }
            if ("Shell".equals(language)) {
                File sh = new File("/system/bin/sh");
                return new Outcome(sh.isFile() && sh.canExecute(), sh.isFile() && sh.canExecute(),
                        "Android system shell",
                        sh.isFile() && sh.canExecute() ? "Real /system/bin/sh interpreter available." : "Android shell interpreter unavailable.");
            }
        } catch (Throwable t) {
            return new Outcome(false, false, language + " bundled verifier",
                    "Not usable in this APK: " + t.getClass().getSimpleName() + ": " + String.valueOf(t.getMessage()));
        }
        return new Outcome(false, false, "none", "No bundled verifier registered.");
    }

    private static Outcome verifyPython(Context context, File root, List<String> relFiles) throws Exception {
        if (!Python.isStarted()) Python.start(new AndroidPlatform(context));
        PyObject module = Python.getInstance().getModule("anamika_python_verifier");
        for (String rel : relFiles) {
            String src = read(new File(root, rel));
            String error = module.callAttr("verify", src, rel).toString();
            if (error != null && !error.trim().isEmpty()) {
                return new Outcome(true, false, "Chaquopy CPython 3.13", error.trim());
            }
        }
        return new Outcome(true, true, "Chaquopy CPython 3.13",
                "All " + relFiles.size() + " Python file(s) compiled successfully.");
    }

    private static Outcome verifyJavaScript(File root, List<String> relFiles) throws Exception {
        org.mozilla.javascript.Context cx = org.mozilla.javascript.Context.enter();
        try {
            cx.setOptimizationLevel(-1);
            cx.setLanguageVersion(org.mozilla.javascript.Context.VERSION_ES6);
            Scriptable scope = cx.initStandardObjects();
            for (String rel : relFiles) {
                String src = read(new File(root, rel));
                cx.compileString(src, rel, 1, null);
            }
            return new Outcome(true, true, "Mozilla Rhino 1.9.1",
                    "All " + relFiles.size() + " JavaScript file(s) compiled successfully.");
        } finally {
            org.mozilla.javascript.Context.exit();
        }
    }

    private static Outcome verifyTypeScript(Context context, File root, List<String> relFiles) throws Exception {
        String compiler;
        try (InputStream in = context.getAssets().open("toolchains/typescript.js")) {
            compiler = readAll(in);
        }
        org.mozilla.javascript.Context cx = org.mozilla.javascript.Context.enter();
        try {
            cx.setOptimizationLevel(-1);
            Scriptable scope = cx.initStandardObjects();

            // TypeScript's UMD build supports CommonJS. Supplying module/exports makes
            // the exported compiler API accessible without a Node runtime.
            NativeObject exports = new NativeObject();
            NativeObject module = new NativeObject();
            ScriptableObject.putProperty(module, "exports", exports);
            ScriptableObject.putProperty(scope, "exports", exports);
            ScriptableObject.putProperty(scope, "module", module);
            cx.evaluateString(scope, compiler, "typescript.js", 1, null);

            Object tsObj = ScriptableObject.getProperty(module, "exports");
            if (!(tsObj instanceof Scriptable) || ((Scriptable) tsObj).get("transpileModule", (Scriptable) tsObj) == Scriptable.NOT_FOUND) {
                tsObj = ScriptableObject.getProperty(scope, "ts");
            }
            if (!(tsObj instanceof Scriptable)) {
                return new Outcome(true, false, "Microsoft TypeScript 5.9.3",
                        "TypeScript compiler API did not initialize.");
            }
            Scriptable ts = (Scriptable) tsObj;
            Object fnObj = ScriptableObject.getProperty(ts, "transpileModule");
            if (!(fnObj instanceof Function)) {
                return new Outcome(true, false, "Microsoft TypeScript 5.9.3",
                        "transpileModule API not found.");
            }
            Function transpile = (Function) fnObj;

            for (String rel : relFiles) {
                NativeObject options = new NativeObject();
                NativeObject compilerOptions = new NativeObject();
                ScriptableObject.putProperty(options, "compilerOptions", compilerOptions);
                ScriptableObject.putProperty(options, "reportDiagnostics", true);
                ScriptableObject.putProperty(options, "fileName", rel);

                Object resultObj = transpile.call(cx, scope, ts, new Object[]{read(new File(root, rel)), options});
                if (!(resultObj instanceof Scriptable)) {
                    return new Outcome(true, false, "Microsoft TypeScript 5.9.3",
                            rel + ": compiler returned no result.");
                }
                Object diagnosticsObj = ScriptableObject.getProperty((Scriptable) resultObj, "diagnostics");
                if (diagnosticsObj instanceof NativeArray && ((NativeArray) diagnosticsObj).getLength() > 0) {
                    NativeArray diagnostics = (NativeArray) diagnosticsObj;
                    Object first = diagnostics.get(0, diagnostics);
                    String msg = "TypeScript diagnostic";
                    if (first instanceof Scriptable) {
                        Object mt = ScriptableObject.getProperty((Scriptable) first, "messageText");
                        if (mt != Scriptable.NOT_FOUND) msg = org.mozilla.javascript.Context.toString(mt);
                    }
                    return new Outcome(true, false, "Microsoft TypeScript 5.9.3", rel + ": " + msg);
                }
            }
            return new Outcome(true, true, "Microsoft TypeScript 5.9.3",
                    "All " + relFiles.size() + " TypeScript file(s) passed compiler transpile diagnostics.");
        } finally {
            org.mozilla.javascript.Context.exit();
        }
    }

    private static Outcome verifyJava(File root, List<String> relFiles) throws Exception {
        StringBuilder cmd = new StringBuilder("-proc:none -source 17 -target 17 -d ");
        File outDir = new File(root, "ecj_classes");
        if (!outDir.exists()) outDir.mkdirs();
        cmd.append(quote(outDir.getAbsolutePath()));
        for (String rel : relFiles) cmd.append(' ').append(quote(new File(root, rel).getAbsolutePath()));

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ByteArrayOutputStream err = new ByteArrayOutputStream();
        boolean ok = BatchCompiler.compile(cmd.toString(),
                new PrintWriter(out, true), new PrintWriter(err, true), null);
        String detail = (out.toString("UTF-8") + "\n" + err.toString("UTF-8")).trim();
        if (ok) {
            return new Outcome(true, true, "Eclipse ECJ 3.46.100",
                    "Java sources compiled successfully.");
        }
        if (detail.isEmpty()) detail = "ECJ returned failure.";
        return new Outcome(true, false, "Eclipse ECJ 3.46.100", detail);
    }

    private static Outcome verifyShell(File root, List<String> relFiles) throws Exception {
        File sh = new File("/system/bin/sh");
        if (!sh.isFile() || !sh.canExecute()) {
            return new Outcome(false, false, "Android system shell", "/system/bin/sh is unavailable.");
        }
        for (String rel : relFiles) {
            Process process = new ProcessBuilder(sh.getAbsolutePath(), "-n", new File(root, rel).getAbsolutePath())
                    .redirectErrorStream(true).start();
            boolean done = process.waitFor(15, java.util.concurrent.TimeUnit.SECONDS);
            if (!done) {
                process.destroyForcibly();
                return new Outcome(true, false, "Android system shell", rel + ": syntax check timed out.");
            }
            String output = readAll(process.getInputStream()).trim();
            if (process.exitValue() != 0) {
                return new Outcome(true, false, "Android system shell",
                        rel + ": " + (output.isEmpty() ? "shell syntax error" : output));
            }
        }
        return new Outcome(true, true, "Android system shell",
                "All " + relFiles.size() + " shell file(s) passed /system/bin/sh -n.");
    }

    private static Outcome verifyKotlin(File root, List<String> relFiles) throws Exception {
        Disposable disposable = Disposer.newDisposable();
        try {
            CompilerConfiguration cfg = new CompilerConfiguration();
            KotlinCoreEnvironment env = KotlinCoreEnvironment.createForProduction(
                    disposable, cfg, EnvironmentConfigFiles.JVM_CONFIG_FILES);
            KtPsiFactory factory = new KtPsiFactory(env.getProject(), false);
            for (String rel : relFiles) {
                KtFile file = factory.createFile(rel, read(new File(root, rel)));
                Collection<PsiErrorElement> errors = PsiTreeUtil.collectElementsOfType(file, PsiErrorElement.class);
                if (!errors.isEmpty()) {
                    PsiErrorElement first = errors.iterator().next();
                    return new Outcome(true, false, "JetBrains Kotlin compiler 2.2.21",
                            rel + ": " + first.getErrorDescription());
                }
            }
            return new Outcome(true, true, "JetBrains Kotlin compiler 2.2.21",
                    "Kotlin compiler frontend parsed all " + relFiles.size() + " file(s) without syntax errors.");
        } finally {
            Disposer.dispose(disposable);
        }
    }

    private static String read(File file) throws Exception {
        try (FileInputStream in = new FileInputStream(file)) {
            return readAll(in);
        }
    }

    private static String readAll(InputStream in) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[32768];
        int n;
        while ((n = in.read(buf)) >= 0) out.write(buf, 0, n);
        return new String(out.toByteArray(), StandardCharsets.UTF_8);
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}
