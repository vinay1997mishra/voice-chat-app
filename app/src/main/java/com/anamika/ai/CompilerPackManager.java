package com.anamika.ai;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/**
 * V7.8 strict compiler/runtime-pack verifier.
 *
 * Design rule:
 *  - A source file is only marked FULL VERIFIED when a real compiler/interpreter
 *    pack for that language is present and returns success.
 *  - Missing packs are never silently replaced by regex checks.
 *  - Native executable packs must be packaged read-only in the APK nativeLibDir.
 *
 * IMPORTANT: this class is the orchestration layer. It does not magically turn
 * placeholder files into compilers. The actual Android/ABI-specific toolchain
 * binaries must be supplied at APK build time.
 */
public final class CompilerPackManager {

    public enum State { PASS, FAIL, MISSING, SKIPPED }

    public static final class Check {
        public final String language;
        public final String pack;
        public final State state;
        public final String detail;
        Check(String language, String pack, State state, String detail) {
            this.language = language; this.pack = pack; this.state = state; this.detail = detail;
        }
        @Override public String toString() {
            return state + " • " + language + " • " + pack + " • " + detail;
        }
    }

    public static final class Report {
        public final List<Check> checks;
        public final int languagesDetected;
        Report(List<Check> checks, int languagesDetected) {
            this.checks = Collections.unmodifiableList(checks);
            this.languagesDetected = languagesDetected;
        }
        public boolean isFullyVerified() {
            if (languagesDetected == 0) return false;
            boolean sawPass = false;
            for (Check c : checks) {
                if (c.state == State.FAIL || c.state == State.MISSING) return false;
                if (c.state == State.PASS) sawPass = true;
            }
            return sawPass;
        }
        public String summary() {
            int pass=0, fail=0, missing=0, skipped=0;
            for (Check c:checks) {
                if(c.state==State.PASS) pass++;
                else if(c.state==State.FAIL) fail++;
                else if(c.state==State.MISSING) missing++;
                else skipped++;
            }
            return "Languages: " + languagesDetected + " | Compiler pass: " + pass +
                    " | Fail: " + fail + " | Missing packs: " + missing + " | Skipped: " + skipped;
        }
        public String details() {
            StringBuilder sb = new StringBuilder(summary());
            for (Check c:checks) sb.append("\n").append(c.toString());
            return sb.toString();
        }
    }

    private static final class Spec {
        final String lang, binary;
        Spec(String lang, String binary) { this.lang=lang; this.binary=binary; }
    }

    private static final Map<String,Spec> EXT = new LinkedHashMap<>();
    static {
        EXT.put(".c", new Spec("C", "libanamika_clang.so"));
        EXT.put(".cc", new Spec("C++", "libanamika_clangxx.so"));
        EXT.put(".cpp", new Spec("C++", "libanamika_clangxx.so"));
        EXT.put(".cxx", new Spec("C++", "libanamika_clangxx.so"));
        EXT.put(".rs", new Spec("Rust", "libanamika_rustc.so"));
        EXT.put(".go", new Spec("Go", "libanamika_go.so"));
        EXT.put(".py", new Spec("Python", "libanamika_python.so"));
        EXT.put(".js", new Spec("JavaScript", "libanamika_node.so"));
        EXT.put(".mjs", new Spec("JavaScript", "libanamika_node.so"));
        EXT.put(".ts", new Spec("TypeScript", "libanamika_tsc.so"));
        EXT.put(".java", new Spec("Java", "libanamika_javac.so"));
        EXT.put(".kt", new Spec("Kotlin", "libanamika_kotlinc.so"));
        EXT.put(".cs", new Spec("C#", "libanamika_csc.so"));
        EXT.put(".rb", new Spec("Ruby", "libanamika_ruby.so"));
        EXT.put(".php", new Spec("PHP", "libanamika_php.so"));
        EXT.put(".dart", new Spec("Dart", "libanamika_dart.so"));
        EXT.put(".sh", new Spec("Shell", "libanamika_bash.so"));
    }

    private CompilerPackManager() { }

    public static Report verifyGeneratedText(Context context, String generatedText) {
        Map<String,String> files = OfflineCodeValidator.parse(generatedText);
        return verifyFiles(context, files);
    }

    public static Report verifyFiles(Context context, Map<String,String> files) {
        List<Check> out = new ArrayList<>();
        Map<String,List<String>> byLanguage = new LinkedHashMap<>();
        Map<String,Spec> specs = new LinkedHashMap<>();
        List<String> sqlFiles = new ArrayList<>();
        List<String> htmlFiles = new ArrayList<>();
        List<String> cssFiles = new ArrayList<>();
        File root = null;
        boolean androidProject = files.containsKey("app/src/main/AndroidManifest.xml") || files.containsKey("AndroidManifest.xml");

        try {
            root = new File(context.getCacheDir(), "anamika_compile_" + System.nanoTime());
            if (!root.mkdirs()) throw new IllegalStateException("Cannot create compiler workspace");
            for (Map.Entry<String,String> e:files.entrySet()) {
                String path = safePath(e.getKey());
                File f = new File(root, path);
                File parent=f.getParentFile(); if(parent!=null&&!parent.exists() && !parent.mkdirs()) {
                    throw new IllegalStateException("Cannot create compiler folder for " + path);
                }
                try(FileOutputStream fos=new FileOutputStream(f)) {
                    fos.write(e.getValue().getBytes(StandardCharsets.UTF_8));
                }
                String lower=path.toLowerCase(Locale.ROOT);
                if(lower.endsWith(".sql")) { sqlFiles.add(path); continue; }
                if(lower.endsWith(".html") || lower.endsWith(".htm")) { htmlFiles.add(path); continue; }
                if(lower.endsWith(".css") || lower.endsWith(".scss")) { cssFiles.add(path); continue; }
                Spec spec = specFor(lower);
                if(spec!=null) {
                    byLanguage.computeIfAbsent(spec.lang, k -> new ArrayList<>()).add(path);
                    specs.put(spec.lang,spec);
                }
            }

            if(!sqlFiles.isEmpty()) out.add(verifySql(root, sqlFiles));
            if(!htmlFiles.isEmpty()) out.add(verifyWebText(root, htmlFiles, "HTML5"));
            if(!cssFiles.isEmpty()) out.add(verifyWebText(root, cssFiles, "CSS3"));

            for(Map.Entry<String,List<String>> e:byLanguage.entrySet()) {
                Spec spec=specs.get(e.getKey());
                // Android Java/Kotlin must be checked with the Android build pack, because plain
                // javac/kotlinc lacks android.jar/resources and would produce false failures.
                if(androidProject && ("Java".equals(spec.lang) || "Kotlin".equals(spec.lang))) {
                    out.add(new Check(spec.lang, "Android project verifier", State.SKIPPED,
                            "Covered by the Android SDK/aapt2/Gradle project verification pack."));
                    continue;
                }
                File bin=new File(context.getApplicationInfo().nativeLibraryDir, spec.binary);
                if(!bin.isFile()) {
                    out.add(new Check(spec.lang, spec.binary, State.MISSING,
                            "Real compiler/interpreter pack is not physically bundled in this APK."));
                    continue;
                }
                out.add(runCompiler(root, spec, bin, e.getValue()));
            }

            if(androidProject) {
                File androidPack=new File(context.getApplicationInfo().nativeLibraryDir,"libanamika_androidcheck.so");
                if(!androidPack.isFile()) {
                    out.add(new Check("Android project", "libanamika_androidcheck.so", State.MISSING,
                            "Android SDK/aapt2/Gradle verification pack is required for FULL VERIFIED status."));
                } else {
                    out.add(runProcess(root,"Android project","libanamika_androidcheck.so",androidPack,
                            list("--project", root.getAbsolutePath())));
                }
            }
        } catch(Exception e) {
            out.add(new Check("Compiler manager","internal",State.FAIL,e.getMessage()==null?e.toString():e.getMessage()));
        } finally {
            deleteTree(root);
        }

        Set<String> langs=new LinkedHashSet<>(byLanguage.keySet());
        if(!sqlFiles.isEmpty()) langs.add("SQL");
        if(!htmlFiles.isEmpty()) langs.add("HTML5");
        if(!cssFiles.isEmpty()) langs.add("CSS3");
        if(androidProject) langs.add("Android project");
        return new Report(out, langs.size());
    }

    private static Check runCompiler(File root, Spec s, File bin, List<String> relFiles) {
        if ("JavaScript".equals(s.lang) || "Ruby".equals(s.lang) || "PHP".equals(s.lang) || "Shell".equals(s.lang)) {
            StringBuilder details=new StringBuilder();
            for(String rel:relFiles){
                List<String> one=new ArrayList<>();
                if("JavaScript".equals(s.lang)){ one.add("--check"); one.add(new File(root,rel).getAbsolutePath()); }
                else if("Ruby".equals(s.lang)){ one.add("-c"); one.add(new File(root,rel).getAbsolutePath()); }
                else if("PHP".equals(s.lang)){ one.add("-l"); one.add(new File(root,rel).getAbsolutePath()); }
                else { one.add("-n"); one.add(new File(root,rel).getAbsolutePath()); }
                Check c=runProcess(root,s.lang,s.binary,bin,one);
                details.append(rel).append(": ").append(c.detail).append('\n');
                if(c.state!=State.PASS) return new Check(s.lang,s.binary,c.state,details.toString().trim());
            }
            return new Check(s.lang,s.binary,State.PASS,"All "+relFiles.size()+" file(s) passed real "+s.lang+" syntax verification.");
        }
        List<String> args=new ArrayList<>();
        if("C".equals(s.lang) || "C++".equals(s.lang)) {
            args.add("-fsyntax-only"); for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
        } else if("Rust".equals(s.lang)) {
            args.add("--emit=metadata"); args.add("--crate-type=lib"); args.add(new File(root,relFiles.get(0)).getAbsolutePath());
            args.add("-o"); args.add(new File(root,"anamika_check.rmeta").getAbsolutePath());
        } else if("Go".equals(s.lang)) {
            args.add("build"); args.add("-o"); args.add(new File(root,"anamika_go_check.bin").getAbsolutePath()); args.add(".");
        } else if("Python".equals(s.lang)) {
            args.add("-m"); args.add("py_compile"); for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
        } else if("JavaScript".equals(s.lang)) {
            args.add("--check"); args.add(new File(root,relFiles.get(0)).getAbsolutePath());
        } else if("TypeScript".equals(s.lang)) {
            args.add("--noEmit"); for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
        } else if("Java".equals(s.lang)) {
            File classes = new File(root,"java_classes"); if(!classes.exists()) classes.mkdirs();
            args.add("-proc:none"); args.add("-Xlint:all"); args.add("-d"); args.add(classes.getAbsolutePath());
            for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
        } else if("Kotlin".equals(s.lang)) {
            for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
            args.add("-d"); args.add(new File(root,"kotlin_check.jar").getAbsolutePath());
        } else if("C#".equals(s.lang)) {
            args.add("-target:library"); args.add("-out:"+new File(root,"check.dll").getAbsolutePath());
            for(String p:relFiles) args.add(new File(root,p).getAbsolutePath());
        } else if("Ruby".equals(s.lang)) {
            args.add("-c"); args.add(new File(root,relFiles.get(0)).getAbsolutePath());
        } else if("PHP".equals(s.lang)) {
            args.add("-l"); args.add(new File(root,relFiles.get(0)).getAbsolutePath());
        } else if("Dart".equals(s.lang)) {
            args.add("analyze"); args.add(root.getAbsolutePath());
        } else if("Shell".equals(s.lang)) {
            args.add("-n"); args.add(new File(root,relFiles.get(0)).getAbsolutePath());
        } else {
            return new Check(s.lang,s.binary,State.SKIPPED,"No compiler command profile configured.");
        }
        return runProcess(root,s.lang,s.binary,bin,args);
    }

    private static Check runProcess(File root, String lang, String pack, File bin, List<String> args) {
        List<String> cmd=new ArrayList<>(); cmd.add(bin.getAbsolutePath()); cmd.addAll(args);
        Process p=null;
        File logFile=new File(root,"process_"+Math.abs((lang+System.nanoTime()).hashCode())+".log");
        try {
            p=new ProcessBuilder(cmd).directory(root).redirectErrorStream(true).redirectOutput(logFile).start();
            boolean done=p.waitFor(90, TimeUnit.SECONDS);
            if(!done) {
                p.destroy();
                if(!p.waitFor(2,TimeUnit.SECONDS)) p.destroyForcibly();
                return new Check(lang,pack,State.FAIL,"Compiler timed out after 90 seconds.");
            }
            int code=p.exitValue();
            String detail="";
            if(logFile.isFile()) {
                byte[] bytes=java.nio.file.Files.readAllBytes(logFile.toPath());
                int limit=Math.min(bytes.length,12000);
                detail=new String(bytes,0,limit,StandardCharsets.UTF_8).trim();
                if(bytes.length>limit) detail += "\n… compiler log truncated …";
            }
            if(detail.isEmpty()) detail="exit="+code;
            return new Check(lang,pack,code==0?State.PASS:State.FAIL,detail);
        } catch(Exception e) {
            return new Check(lang,pack,State.FAIL,e.getMessage()==null?e.toString():e.getMessage());
        } finally {
            if(p!=null && p.isAlive()) p.destroyForcibly();
            try{logFile.delete();}catch(Exception ignored){}
        }
    }


    private static Check verifyWebText(File root, List<String> relFiles, String language) {
        try {
            for(String p:relFiles) {
                String s=new String(java.nio.file.Files.readAllBytes(new File(root,p).toPath()), StandardCharsets.UTF_8);
                if("HTML5".equals(language)) {
                    String lower=s.toLowerCase(Locale.ROOT);
                    if(!lower.contains("<html") && !lower.contains("<!doctype html")) return new Check(language,"built-in web validator",State.FAIL,"No HTML document root/doctype in "+p);
                    int lt=0,gt=0; for(int i=0;i<s.length();i++){if(s.charAt(i)=='<')lt++;else if(s.charAt(i)=='>')gt++;}
                    if(lt!=gt) return new Check(language,"built-in web validator",State.FAIL,"Unbalanced angle brackets in "+p);
                } else {
                    int b=0; boolean comment=false; char quote=0; boolean esc=false;
                    for(int i=0;i<s.length();i++){
                        char c=s.charAt(i), n=i+1<s.length()?s.charAt(i+1):'\0';
                        if(comment){if(c=='*'&&n=='/'){comment=false;i++;}continue;}
                        if(quote!=0){if(esc){esc=false;continue;}if(c=='\\'){esc=true;continue;}if(c==quote)quote=0;continue;}
                        if(c=='/'&&n=='*'){comment=true;i++;continue;} if(c=='\''||c=='\"'){quote=c;continue;}
                        if(c=='{')b++; else if(c=='}')b--; if(b<0)return new Check(language,"built-in web validator",State.FAIL,"CSS brace mismatch in "+p);
                    }
                    if(b!=0||comment||quote!=0)return new Check(language,"built-in web validator",State.FAIL,"CSS structure not closed in "+p);
                }
            }
            return new Check(language,"built-in web validator",State.PASS,"Structural runtime-format checks passed for "+relFiles.size()+" file(s). HTML/CSS do not have a traditional compiler.");
        } catch(Exception e) { return new Check(language,"built-in web validator",State.FAIL,e.getMessage()==null?e.toString():e.getMessage()); }
    }

    private static Check verifySql(File root, List<String> relFiles) {
        SQLiteDatabase db=null;
        try {
            db=SQLiteDatabase.create(null);
            for(String p:relFiles) {
                String s=new String(java.nio.file.Files.readAllBytes(new File(root,p).toPath()), StandardCharsets.UTF_8);
                for(String stmt:splitSql(s)) {
                    String t=stmt.trim(); if(t.isEmpty()) continue;
                    if(t.toUpperCase(Locale.ROOT).startsWith("SELECT") || t.toUpperCase(Locale.ROOT).startsWith("WITH")) {
                        try(Cursor c=db.rawQuery(t,null)) { if(c!=null) c.getColumnCount(); }
                    } else db.execSQL(t);
                }
            }
            return new Check("SQL","Android SQLite",State.PASS,"Parsed/executed successfully in isolated SQLite database.");
        } catch(Exception e) {
            return new Check("SQL","Android SQLite",State.FAIL,e.getMessage()==null?e.toString():e.getMessage());
        } finally { if(db!=null) db.close(); }
    }

    private static List<String> splitSql(String s) {
        List<String> out=new ArrayList<>(); StringBuilder cur=new StringBuilder(); boolean single=false,dbl=false;
        for(int i=0;i<s.length();i++) {
            char c=s.charAt(i);
            if(c=='\''&&!dbl) single=!single; else if(c=='\"'&&!single) dbl=!dbl;
            if(c==';'&&!single&&!dbl) { out.add(cur.toString()); cur.setLength(0); } else cur.append(c);
        }
        if(cur.length()>0) out.add(cur.toString()); return out;
    }

    private static Spec specFor(String lower) {
        for(Map.Entry<String,Spec> e:EXT.entrySet()) if(lower.endsWith(e.getKey())) return e.getValue();
        return null;
    }

    private static String safePath(String p) {
        String s=(p==null?"":p.trim()).replace('\\','/');
        if(s.isEmpty()||s.startsWith("/")||s.indexOf('\0')>=0) throw new SecurityException("Unsafe compiler workspace path: "+p);
        StringBuilder out=new StringBuilder();
        for(String part:s.split("/")){
            if(part.isEmpty()||".".equals(part)) continue;
            if("..".equals(part)) throw new SecurityException("Parent traversal is not allowed: "+p);
            if(out.length()>0) out.append('/');
            out.append(part);
        }
        if(out.length()==0) throw new SecurityException("Unsafe compiler workspace path: "+p);
        return out.toString();
    }

    private static void deleteTree(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File child : children) deleteTree(child);
        }
        try { f.delete(); } catch (Exception ignored) { }
    }

    private static List<String> list(String... v) {
        List<String> a=new ArrayList<>(); Collections.addAll(a,v); return a;
    }
}
