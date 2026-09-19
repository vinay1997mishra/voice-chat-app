package com.anamika.ai;

import android.content.Context;

import java.util.Locale;

/**
 * V7.8 Evergreen standalone developer orchestrator with optional local App Blueprint context.
 *
 * Runtime rule: this class never performs a network request. It first tries the
 * optional on-device model adapter. If no model/runtime is bundled, it falls
 * back to deterministic offline project generators and validators.
 */
public final class StandaloneDeveloperEngine {

    public interface Callback {
        void onSuccess(Result result);
        void onError(String error);
    }

    public static final class Result {
        public final String generatedText;
        public final OfflineCodeValidator.Report validation;
        public final String engine;
        public final CompilerPackManager.Report compilerVerification;

        Result(String generatedText, OfflineCodeValidator.Report validation, CompilerPackManager.Report compilerVerification, String engine) {
            this.generatedText = generatedText;
            this.validation = validation;
            this.compilerVerification = compilerVerification;
            this.engine = engine;
        }
    }

    private StandaloneDeveloperEngine() { }

    public static void generate(Context context, String prompt, Callback callback) {
        new Thread(() -> {
            try {
                String request = prompt == null ? "" : prompt.trim();
                if (request.isEmpty()) throw new IllegalArgumentException("Developer request is empty.");
                String lowerRequest=request.toLowerCase(Locale.ROOT);
                if (lowerRequest.contains("same app") || lowerRequest.contains("aisa hi") || lowerRequest.contains("waisa hi") || lowerRequest.contains("blueprint") || lowerRequest.contains("reference app") || lowerRequest.contains("same functions")) {
                    String blueprint=com.anamika.ai.plugins.AppBlueprintStore.latestSummary(context,14000);
                    if(!blueprint.isEmpty()) request += "\n\n"+blueprint+"\nReimplement the observable behavior with original code and assets. Do not claim hidden/private backend behavior was captured.";
                }
                if(lowerRequest.contains("research") || lowerRequest.contains("seekha") || lowerRequest.contains("learned") || lowerRequest.contains("search se")) {
                    String learned=com.anamika.ai.research.ResearchLearningStore.latestSummary(context,12000);
                    if(!learned.isEmpty()) request += "\n\n"+learned+"\nUse this only as owner-collected visible/public reference context; verify assumptions in code and do not invent hidden behavior.";
                }

                String output;
                String engine;
                LocalModelBridge.ModelStatus status = LocalModelBridge.getStatus(context);
                if (status.ready) {
                    output = LocalModelBridge.generate(context, buildLocalModelPrompt(request));
                    engine = "On-device coding model";
                } else {
                    output = generateOfflineProject(request);
                    engine = "Standalone deterministic generator (local model not bundled)";
                }

                OfflineCodeValidator.Report first = OfflineCodeValidator.validateGeneratedText(output);
                if (!first.isClean()) {
                    output = AutoRepairEngine.repairKnownIssues(output, first);
                }
                OfflineCodeValidator.Report finalReport = OfflineCodeValidator.validateGeneratedText(output);
                CompilerPackManager.Report compilerReport = CompilerPackManager.verifyGeneratedText(context, output);
                callback.onSuccess(new Result(output, finalReport, compilerReport, engine));
            } catch (Exception e) {
                callback.onError(e.getMessage() == null ? e.toString() : e.getMessage());
            }
        }, "anamika-standalone-developer").start();
    }

    private static String buildLocalModelPrompt(String request) {
        return "You are Anamika AI V7.8 Evergreen Full Toolchain Developer. Work fully offline. " +
                "Create original, buildable software from the owner's request. " +
                "Return every project file exactly as <<<FILE:path>>> then content then <<<END FILE>>>. " +
                "Do not use remote APIs unless the owner explicitly asks the generated app to use one. " +
                "Prefer Android Java/Kotlin for Android requests. Add permissions only when needed. " +
                "Before answering, self-review for syntax, missing files, unsafe secrets, and build configuration.\n\n" +
                "OWNER REQUEST:\n" + request;
    }

    private static String generateOfflineProject(String request) {
        String p = request.toLowerCase(Locale.ROOT);
        if (isVideoEditorRequest(p)) return androidVideoEditorProject(request);
        if (p.contains("website") || p.contains("web app") || p.contains("html") || p.contains("css")) return webProject(request);
        if (p.contains("python")) return pythonProject(request);
        if (p.contains("javascript") || p.contains("node")) return javascriptProject(request);
        if (p.contains("typescript")) return languageWorkspace(request, "TypeScript", "src/index.ts", "export function main(): void { console.log('Anamika TypeScript workspace ready'); }\nmain();\n");
        if (p.contains("kotlin") && !p.contains("android")) return languageWorkspace(request, "Kotlin", "Main.kt", "fun main() { println(\"Anamika Kotlin workspace ready\") }\n");
        if (p.contains("java") && !p.contains("javascript") && !p.contains("android")) return languageWorkspace(request, "Java", "Main.java", "public class Main { public static void main(String[] args) { System.out.println(\"Anamika Java workspace ready\"); } }\n");
        if (p.contains("c++") || p.contains("cpp")) return languageWorkspace(request, "C++", "main.cpp", "#include <iostream>\nint main(){ std::cout << \"Anamika C++ workspace ready\\n\"; return 0; }\n");
        if (p.matches(".*(^|[^a-z])c([^a-z]|$).*") || p.contains(" c language")) return languageWorkspace(request, "C", "main.c", "#include <stdio.h>\nint main(void){ puts(\"Anamika C workspace ready\"); return 0; }\n");
        if (p.contains("c#") || p.contains("csharp")) return languageWorkspace(request, "C#", "Program.cs", "using System; class Program { static void Main() { Console.WriteLine(\"Anamika C# workspace ready\"); } }\n");
        if (p.contains("golang") || p.contains(" go ") || p.startsWith("go ")) return languageWorkspace(request, "Go", "main.go", "package main\nimport \"fmt\"\nfunc main(){ fmt.Println(\"Anamika Go workspace ready\") }\n");
        if (p.contains("rust")) return languageWorkspace(request, "Rust", "src/main.rs", "fn main(){ println!(\"Anamika Rust workspace ready\"); }\n");
        if (p.contains("php")) return languageWorkspace(request, "PHP", "index.php", "<?php\necho \"Anamika PHP workspace ready\\n\";\n");
        if (p.contains("ruby")) return languageWorkspace(request, "Ruby", "main.rb", "puts 'Anamika Ruby workspace ready'\n");
        if (p.contains("sql")) return languageWorkspace(request, "SQL", "schema.sql", "CREATE TABLE IF NOT EXISTS anamika_items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);\n");
        if (p.contains("android") || p.contains("apk") || p.contains("app banao") || p.contains("app bana")) return genericAndroidProject(request);
        return genericCodeWorkspace(request);
    }

    private static boolean isVideoEditorRequest(String p) {
        return p.contains("video") && (p.contains("edit") || p.contains("editor") || p.contains("editing"));
    }

    private static String header(String request, String type) {
        return "ANAMIKA V7.8 EVERGREEN OFFLINE GENERATION\n" +
                "Engine: deterministic standalone generator\n" +
                "Project type: " + type + "\n" +
                "Owner request: " + request + "\n\n";
    }

    private static String androidVideoEditorProject(String request) {
        return header(request, "Android video editor starter") +
                file("settings.gradle", "pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\n" +
                        "dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\n" +
                        "rootProject.name='AnamikaVideoEditor'\ninclude ':app'\n") +
                file("build.gradle", "plugins {\n    id 'com.android.application' version '9.4.0' apply false\n}\n") +
                file("gradle.properties", "org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8\nandroid.useAndroidX=true\n") +
                file("app/build.gradle", "plugins { id 'com.android.application' }\n\n" +
                        "android {\n    namespace 'com.anamika.generated.videoeditor'\n    compileSdk 36\n" +
                        "    defaultConfig { applicationId 'com.anamika.generated.videoeditor'; minSdk 26; targetSdk 36; versionCode 1; versionName '1.0' }\n}\n\n" +
                        "dependencies {\n    implementation 'androidx.media3:media3-transformer:1.8.0'\n    implementation 'androidx.media3:media3-effect:1.8.0'\n    implementation 'androidx.media3:media3-common:1.8.0'\n}\n") +
                file("app/src/main/AndroidManifest.xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n" +
                        "    <uses-permission android:name=\"android.permission.READ_MEDIA_VIDEO\" />\n" +
                        "    <application android:theme=\"@style/AppTheme\" android:label=\"Anamika Video Editor\">\n" +
                        "        <activity android:name=\".MainActivity\" android:exported=\"true\">\n" +
                        "            <intent-filter><action android:name=\"android.intent.action.MAIN\"/><category android:name=\"android.intent.category.LAUNCHER\"/></intent-filter>\n" +
                        "        </activity>\n    </application>\n</manifest>\n") +
                file("app/src/main/res/values/styles.xml", "<resources><style name=\"AppTheme\" parent=\"android:style/Theme.Material.Light.NoActionBar\" /></resources>\n") +
                file("app/src/main/res/layout/activity_main.xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                        "<LinearLayout xmlns:android=\"http://schemas.android.com/apk/res/android\" android:layout_width=\"match_parent\" android:layout_height=\"match_parent\" android:orientation=\"vertical\" android:padding=\"20dp\">\n" +
                        "    <TextView android:layout_width=\"match_parent\" android:layout_height=\"wrap_content\" android:text=\"Anamika Video Editor\" android:textSize=\"24sp\" android:textStyle=\"bold\"/>\n" +
                        "    <Button android:id=\"@+id/selectVideo\" android:layout_width=\"match_parent\" android:layout_height=\"wrap_content\" android:text=\"Select video\"/>\n" +
                        "    <Button android:id=\"@+id/exportVideo\" android:layout_width=\"match_parent\" android:layout_height=\"wrap_content\" android:text=\"Export edited video\"/>\n" +
                        "    <TextView android:id=\"@+id/status\" android:layout_width=\"match_parent\" android:layout_height=\"wrap_content\" android:text=\"Ready: trim/speed/mute/export pipeline starter\"/>\n" +
                        "</LinearLayout>\n") +
                file("app/src/main/java/com/anamika/generated/videoeditor/MainActivity.java", "package com.anamika.generated.videoeditor;\n\n" +
                        "import android.app.Activity;\nimport android.content.Intent;\nimport android.net.Uri;\nimport android.os.Bundle;\nimport android.provider.MediaStore;\nimport android.widget.Button;\nimport android.widget.TextView;\n\n" +
                        "public class MainActivity extends Activity {\n" +
                        "    private static final int PICK_VIDEO = 7;\n    private Uri selected;\n    private TextView status;\n" +
                        "    @Override protected void onCreate(Bundle b) { super.onCreate(b); setContentView(R.layout.activity_main); status=findViewById(R.id.status);\n" +
                        "        Button pick=findViewById(R.id.selectVideo); Button export=findViewById(R.id.exportVideo);\n" +
                        "        pick.setOnClickListener(v -> { Intent i=new Intent(Intent.ACTION_PICK, MediaStore.Video.Media.EXTERNAL_CONTENT_URI); startActivityForResult(i,PICK_VIDEO); });\n" +
                        "        export.setOnClickListener(v -> { if(selected==null){status.setText(\"Select a video first.\");return;} status.setText(\"Project skeleton ready. Connect Media3 Transformer composition here for trim/speed/effects/export.\"); });\n" +
                        "    }\n" +
                        "    @Override protected void onActivityResult(int r,int c,Intent d){ super.onActivityResult(r,c,d); if(r==PICK_VIDEO && c==RESULT_OK && d!=null){selected=d.getData();status.setText(\"Video selected.\");}}\n" +
                        "}\n") +
                "\nBUILD NOTES\nOffline template created. Media3 is declared, but advanced timeline UI/effects must be expanded by the local coding model or owner-requested template modules.\n";
    }

    private static String genericAndroidProject(String request) {
        return header(request, "Generic Android application") +
                file("settings.gradle", "pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\n" +
                        "dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\n" +
                        "rootProject.name='AnamikaGeneratedApp'\ninclude ':app'\n") +
                file("build.gradle", "plugins { id 'com.android.application' version '9.4.0' apply false }\n") +
                file("gradle.properties", "org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8\nandroid.useAndroidX=false\n") +
                file("app/build.gradle", "plugins { id 'com.android.application' }\nandroid { namespace 'com.anamika.generated'; compileSdk 36; defaultConfig { applicationId 'com.anamika.generated'; minSdk 26; targetSdk 36; versionCode 1; versionName '1.0' } }\n") +
                file("app/src/main/AndroidManifest.xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?><manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"><application android:label=\"Anamika Generated App\" android:theme=\"@style/AppTheme\"><activity android:name=\".MainActivity\" android:exported=\"true\"><intent-filter><action android:name=\"android.intent.action.MAIN\"/><category android:name=\"android.intent.category.LAUNCHER\"/></intent-filter></activity></application></manifest>\n") +
                file("app/src/main/res/values/styles.xml", "<resources><style name=\"AppTheme\" parent=\"android:style/Theme.Material.Light.NoActionBar\" /></resources>\n") +
                file("app/src/main/res/layout/activity_main.xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?><LinearLayout xmlns:android=\"http://schemas.android.com/apk/res/android\" android:layout_width=\"match_parent\" android:layout_height=\"match_parent\" android:gravity=\"center\" android:orientation=\"vertical\" android:padding=\"24dp\"><TextView android:id=\"@+id/message\" android:layout_width=\"wrap_content\" android:layout_height=\"wrap_content\" android:text=\"Generated by Anamika V7.8\" android:textSize=\"22sp\"/></LinearLayout>\n") +
                file("app/src/main/java/com/anamika/generated/MainActivity.java", "package com.anamika.generated;\nimport android.app.Activity;\nimport android.os.Bundle;\npublic class MainActivity extends Activity { @Override protected void onCreate(Bundle b){ super.onCreate(b); setContentView(R.layout.activity_main); } }\n") +
                "\nBUILD NOTES\nStandalone Android project skeleton generated locally.\n";
    }

    private static String webProject(String request) {
        return header(request, "Offline web app") +
                file("index.html", "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Anamika Generated</title><link rel=\"stylesheet\" href=\"style.css\"></head><body><main><h1>Anamika Generated Web App</h1><p id=\"request\"></p><button id=\"action\">Run</button></main><script src=\"app.js\"></script></body></html>\n") +
                file("style.css", "body{font-family:sans-serif;margin:0;padding:24px}main{max-width:720px;margin:auto}button{padding:12px 18px}\n") +
                file("app.js", "document.getElementById('request').textContent=" + jsString(request) + ";document.getElementById('action').addEventListener('click',()=>alert('Offline app ready'));\n") +
                "\nBUILD NOTES\nNo server required for this static web project.\n";
    }

    private static String pythonProject(String request) {
        return header(request, "Python workspace") +
                file("main.py", "\"\"\"Generated locally by Anamika V7.8.\nOwner request: " + pyEscape(request) + "\n\"\"\"\n\ndef main():\n    print('Anamika standalone Python project ready')\n\nif __name__ == '__main__':\n    main()\n") +
                file("README.md", "# Anamika Python Project\n\nOwner request:\n" + request + "\n") +
                "\nBUILD NOTES\nRun with a local Python interpreter.\n";
    }

    private static String javascriptProject(String request) {
        return header(request, "JavaScript workspace") +
                file("package.json", "{\"name\":\"anamika-generated\",\"version\":\"1.0.0\",\"private\":true,\"scripts\":{\"start\":\"node index.js\"}}\n") +
                file("index.js", "'use strict';\nconsole.log('Anamika standalone JavaScript project ready');\nconsole.log(" + jsString(request) + ");\n") +
                "\nBUILD NOTES\nRun with a local Node.js runtime.\n";
    }


    private static String languageWorkspace(String request, String language, String path, String code) {
        return header(request, language + " workspace") +
                file(path, code) +
                file("README.md", "# Anamika " + language + " Workspace\n\nOwner request:\n" + request + "\n") +
                "\nBUILD NOTES\nGenerated entirely offline. A real " + language + " compiler/interpreter is still required for final semantic/build verification.\n";
    }

    private static String genericCodeWorkspace(String request) {
        return header(request, "Generic coding workspace") +
                file("README.md", "# Anamika Standalone Coding Workspace\n\nRequest:\n" + request + "\n\nA bundled on-device coding model can expand this request into arbitrary multi-file code. Without model weights, V7.8 uses deterministic project templates and validators rather than pretending to be a full LLM.\n") +
                "\nBUILD NOTES\nLocal model required for arbitrary advanced generation outside built-in templates.\n";
    }

    private static String file(String path, String content) {
        return "<<<FILE:" + path + ">>>\n" + content + "<<<END FILE>>>\n\n";
    }

    private static String jsString(String value) {
        String v = value == null ? "" : value.replace("\\", "\\\\").replace("'", "\\'").replace("\r", " ").replace("\n", " ");
        return "'" + v + "'";
    }

    private static String pyEscape(String value) {
        return value == null ? "" : value.replace("\\", "\\\\").replace("\"\"\"", "\\\"\\\"\\\"");
    }
}
