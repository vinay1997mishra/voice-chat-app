#!/usr/bin/env python3
"""Execute the production Java language router with minimal Android/model stubs.
This checks parsing and locale selection, not device speech recognition or inference.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
java = os.environ.get('JAVA_BIN') or shutil.which('java') or '/usr/lib/jvm/java-17-openjdk-amd64/bin/java'
files = {
'android/content/Context.java': '''package android.content;
public class Context { public static final int MODE_PRIVATE=0;
public SharedPreferences getSharedPreferences(String name,int mode){throw new UnsupportedOperationException();} }''',
'android/content/SharedPreferences.java': '''package android.content;
public interface SharedPreferences { String getString(String k,String d); Editor edit();
interface Editor { Editor putString(String k,String v); void apply(); } }''',
'com/anamika/ai/LocalModelBridge.java': '''package com.anamika.ai;
import android.content.Context;
public class LocalModelBridge {
public static class ModelStatus { public boolean ready=false; }
public static ModelStatus getStatus(Context c){return new ModelStatus();}
public static String generate(Context c,String p){throw new AssertionError("Unexpected model call");} }''',
'RouterTest.java': '''import com.anamika.ai.language.UniversalLanguageRouter;
public class RouterTest {
static int count;
static void eq(Object actual,Object expected){count++; if(!actual.equals(expected)) throw new AssertionError(actual+" != "+expected);}
static void route(String text,String intent,String argument){
var r=UniversalLanguageRouter.interpret(null,text); eq(r.intent,intent); eq(r.argument,argument); }
public static void main(String[] args){
eq(UniversalLanguageRouter.detectStyle("show the weather").name(),"ENGLISH");
eq(UniversalLanguageRouter.detectStyle("mera phone kholo").name(),"HINGLISH");
eq(UniversalLanguageRouter.detectStyle("कृपया आवाज़ बढ़ाओ").name(),"HINDI");
eq(UniversalLanguageRouter.detectStyle("آواز بڑھاؤ").name(),"URDU");
route("youtube par search karo ghazal","YOUTUBE_SEARCH","ghazal");
route("تلاش کرو موسم","SEARCH","موسم");
route("WhatsApp کھولو","OPEN_APP","WhatsApp");
route("کھولو WhatsApp","OPEN_APP","WhatsApp");
eq(UniversalLanguageRouter.speechLocaleFor("hello there").toLanguageTag(),"en-IN");
eq(UniversalLanguageRouter.speechLocaleFor("آواز").toLanguageTag(),"ur-IN");
eq(UniversalLanguageRouter.speechLocaleFor("हिन्दी").toLanguageTag(),"hi-IN");
System.out.println(count+" Java router assertions passed (stubbed Android, no device test).");
} }'''
}
with tempfile.TemporaryDirectory(prefix='anamika-router-') as d:
    tmp = Path(d)
    files['com/anamika/ai/language/UniversalLanguageRouter.java'] = (root/'app/src/main/java/com/anamika/ai/language/UniversalLanguageRouter.java').read_text()
    for name, body in files.items():
        path = tmp/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
    subprocess.run([java, '-m', 'jdk.compiler/com.sun.tools.javac.Main', '-encoding', 'UTF-8', '-d', str(tmp/'classes'), *[str(tmp/n) for n in files]], check=True)
    subprocess.run([java, '-cp', str(tmp/'classes'), 'RouterTest'], check=True)
