package com.anamika.ai;

import java.io.StringReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.xml.parsers.DocumentBuilderFactory;
import org.xml.sax.InputSource;

public final class OfflineCodeValidator {
    private static final Pattern FILE_PATTERN = Pattern.compile("<<<FILE:([^>]+)>>>\\s*([\\s\\S]*?)<<<END FILE>>>", Pattern.MULTILINE);

    public static final class Issue {
        public final String level;
        public final String file;
        public final String message;
        Issue(String level, String file, String message) { this.level = level; this.file = file; this.message = message; }
        @Override public String toString() { return level + " • " + file + " • " + message; }
    }

    public static final class Report {
        public final List<Issue> issues;
        public final int filesChecked;
        Report(List<Issue> issues, int filesChecked) { this.issues = Collections.unmodifiableList(issues); this.filesChecked = filesChecked; }
        public boolean isClean() { for (Issue i : issues) if ("ERROR".equals(i.level)) return false; return true; }
        public String summary() {
            int errors=0,warnings=0;
            for (Issue i:issues) { if("ERROR".equals(i.level)) errors++; else warnings++; }
            return "Files checked: " + filesChecked + " | Errors: " + errors + " | Warnings: " + warnings;
        }
        public String details() {
            StringBuilder sb=new StringBuilder(summary());
            for(Issue i:issues) sb.append("\n").append(i.toString());
            return sb.toString();
        }
    }

    private OfflineCodeValidator() { }

    public static Report validateGeneratedText(String text) {
        Map<String,String> files = parse(text);
        List<Issue> issues = new ArrayList<>();
        if (files.isEmpty()) {
            issues.add(new Issue("ERROR", "generation", "No <<<FILE:path>>> blocks found."));
            return new Report(issues, 0);
        }
        for (Map.Entry<String,String> e : files.entrySet()) validateFile(e.getKey(), e.getValue(), issues);
        validateProjectCompleteness(files, issues);
        return new Report(issues, files.size());
    }

    public static Map<String,String> parse(String text) {
        Map<String,String> files=new LinkedHashMap<>();
        Matcher m=FILE_PATTERN.matcher(text==null?"":text);
        while(m.find()) files.put(m.group(1).trim().replace('\\','/'), m.group(2));
        return files;
    }

    private static void validateFile(String path, String content, List<Issue> issues) {
        String p=path.toLowerCase();
        if (path.contains("../") || path.startsWith("/")) issues.add(new Issue("ERROR", path, "Unsafe output path."));
        if (content.contains("sk-") || content.matches("(?s).*AIza[0-9A-Za-z_-]{20,}.*")) issues.add(new Issue("ERROR", path, "Possible hard-coded API secret."));
        if (content.contains("Runtime.getRuntime().exec") || content.contains("ProcessBuilder(")) issues.add(new Issue("WARNING", path, "Process execution found; owner review required."));

        if (p.endsWith(".xml")) validateXml(path, content, issues);
        if (p.endsWith(".html") || p.endsWith(".htm")) validateHtml(path, content, issues);
        if (p.endsWith(".css") || p.endsWith(".scss")) validateCss(path, content, issues);
        if (p.endsWith(".java") || p.endsWith(".kt") || p.endsWith(".js") || p.endsWith(".ts") || p.endsWith(".c") || p.endsWith(".cpp") || p.endsWith(".cs")) {
            validateBalanced(path, content, issues);
        }
        if (p.endsWith(".py")) validatePython(path, content, issues);
        if (p.endsWith(".json")) validateJsonShape(path, content, issues);
        if (p.endsWith("build.gradle") && content.contains("compileSdk") && !content.contains("minSdk")) {
            issues.add(new Issue("WARNING", path, "Android module has compileSdk but no minSdk."));
        }
    }

    private static void validateXml(String path, String content, List<Issue> issues) {
        try {
            DocumentBuilderFactory f=DocumentBuilderFactory.newInstance();
            try { f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true); } catch (Exception ignored) { }
            f.setExpandEntityReferences(false);
            f.newDocumentBuilder().parse(new InputSource(new StringReader(content)));
        } catch(Exception e) {
            issues.add(new Issue("ERROR", path, "Invalid XML: " + compact(e.getMessage())));
        }
    }


    private static void validateHtml(String path, String content, List<Issue> issues) {
        String s = content == null ? "" : content;
        String lower=s.toLowerCase();
        if(!lower.contains("<!doctype html")) issues.add(new Issue("WARNING",path,"HTML5 doctype is missing."));
        if(!lower.contains("<meta") || !lower.contains("viewport")) issues.add(new Issue("WARNING",path,"Responsive viewport meta tag is missing."));
        String cleaned=s.replaceAll("(?s)<!--.*?-->","").replaceAll("(?is)<script\\b[^>]*>.*?</script>","<script></script>").replaceAll("(?is)<style\\b[^>]*>.*?</style>","<style></style>");
        Pattern tag=Pattern.compile("<\\s*(/?)\\s*([A-Za-z][A-Za-z0-9:-]*)\\b([^>]*)>");
        java.util.ArrayDeque<String> stack=new java.util.ArrayDeque<>();
        java.util.Set<String> voids=new java.util.HashSet<>(java.util.Arrays.asList("area","base","br","col","embed","hr","img","input","link","meta","source","track","wbr"));
        Matcher m=tag.matcher(cleaned);
        while(m.find()){
            String closing=m.group(1), name=m.group(2).toLowerCase(), tail=m.group(3)==null?"":m.group(3);
            if(voids.contains(name)||tail.trim().endsWith("/")) continue;
            if(closing.isEmpty()) stack.push(name);
            else if(stack.isEmpty()||!stack.pop().equals(name)){ issues.add(new Issue("ERROR",path,"Mismatched HTML closing tag: "+name)); return; }
        }
        if(!stack.isEmpty()) issues.add(new Issue("ERROR",path,"Unclosed HTML tag: "+stack.peek()));
    }

    private static void validateCss(String path, String content, List<Issue> issues) {
        String s=content==null?"":content;
        int braces=0; boolean comment=false; char quote=0; boolean esc=false;
        for(int i=0;i<s.length();i++){
            char c=s.charAt(i), n=i+1<s.length()?s.charAt(i+1):'\0';
            if(comment){ if(c=='*'&&n=='/'){comment=false;i++;} continue; }
            if(quote!=0){ if(esc){esc=false;continue;} if(c=='\\'){esc=true;continue;} if(c==quote)quote=0; continue; }
            if(c=='/'&&n=='*'){comment=true;i++;continue;} if(c=='\''||c=='\"'){quote=c;continue;}
            if(c=='{')braces++; else if(c=='}')braces--;
            if(braces<0){issues.add(new Issue("ERROR",path,"CSS closing brace without opener."));return;}
        }
        if(braces!=0)issues.add(new Issue("ERROR",path,"Unbalanced CSS braces: "+braces));
        if(quote!=0)issues.add(new Issue("ERROR",path,"Unclosed CSS string."));
        if(comment)issues.add(new Issue("ERROR",path,"Unclosed CSS comment."));
    }

    private static void validateBalanced(String path, String s, List<Issue> issues) {
        int curly=0, round=0, square=0; boolean single=false,dbl=false,escape=false,lineComment=false,blockComment=false;
        for(int i=0;i<s.length();i++) {
            char c=s.charAt(i), n=i+1<s.length()?s.charAt(i+1):'\0';
            if(lineComment){ if(c=='\n')lineComment=false; continue; }
            if(blockComment){ if(c=='*'&&n=='/'){blockComment=false;i++;} continue; }
            if(!single&&!dbl&&c=='/'&&n=='/'){lineComment=true;i++;continue;}
            if(!single&&!dbl&&c=='/'&&n=='*'){blockComment=true;i++;continue;}
            if(escape){escape=false;continue;}
            if((single||dbl)&&c=='\\'){escape=true;continue;}
            if(!dbl&&c=='\''){single=!single;continue;}
            if(!single&&c=='\"'){dbl=!dbl;continue;}
            if(single||dbl)continue;
            if(c=='{')curly++; else if(c=='}')curly--;
            if(c=='(')round++; else if(c==')')round--;
            if(c=='[')square++; else if(c==']')square--;
            if(curly<0||round<0||square<0){issues.add(new Issue("ERROR",path,"Closing bracket without matching opener."));return;}
        }
        if(single||dbl)issues.add(new Issue("ERROR",path,"Unclosed string literal."));
        if(curly!=0||round!=0||square!=0)issues.add(new Issue("ERROR",path,"Unbalanced brackets: {}="+curly+", ()="+round+", []="+square));
    }

    private static void validatePython(String path, String s, List<Issue> issues) {
        String[] lines=s.replace("\r","").split("\n",-1); int previousIndent=0;
        for(int i=0;i<lines.length;i++) {
            String line=lines[i]; if(line.trim().isEmpty()||line.trim().startsWith("#"))continue;
            if(line.contains("\t")) issues.add(new Issue("WARNING",path,"Tab indentation at line "+(i+1)+"; prefer spaces."));
            int indent=0; while(indent<line.length()&&line.charAt(indent)==' ')indent++;
            if(indent%4!=0) issues.add(new Issue("WARNING",path,"Non-4-space indentation at line "+(i+1)+"."));
            previousIndent=indent;
        }
    }

    private static void validateJsonShape(String path, String s, List<Issue> issues) {
        String t=s.trim();
        if(!((t.startsWith("{")&&t.endsWith("}"))||(t.startsWith("[")&&t.endsWith("]")))) issues.add(new Issue("ERROR",path,"JSON must start/end with matching object or array delimiters."));
        validateBalanced(path,s,issues);
    }

    private static void validateProjectCompleteness(Map<String,String> files, List<Issue> issues) {
        boolean android=false;
        for(String p:files.keySet()) if(p.endsWith("AndroidManifest.xml")) android=true;
        if(android) {
            require(files,issues,"settings.gradle");
            require(files,issues,"build.gradle");
            require(files,issues,"app/build.gradle");
            require(files,issues,"app/src/main/AndroidManifest.xml");
            boolean activity=false;
            for(String p:files.keySet()) if(p.endsWith("MainActivity.java")||p.endsWith("MainActivity.kt"))activity=true;
            if(!activity)issues.add(new Issue("ERROR","project","Android project is missing a MainActivity source file."));
        }
    }

    private static void require(Map<String,String> files,List<Issue> issues,String path){if(!files.containsKey(path))issues.add(new Issue("ERROR","project","Missing required file: "+path));}
    private static String compact(String s){if(s==null)return "parse error";return s.replace('\n',' ').replace('\r',' ').trim();}
}
