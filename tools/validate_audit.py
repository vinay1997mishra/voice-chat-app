#!/usr/bin/env python3
from pathlib import Path
import sys, re, xml.etree.ElementTree as ET
R=Path(__file__).resolve().parents[1]
errors=[]

def txt(rel):
    p=R/rel
    if not p.is_file(): errors.append('missing '+rel); return ''
    return p.read_text(encoding='utf-8')

manifest=txt('app/src/main/AndroidManifest.xml')
if 'android:allowBackup="false"' not in manifest: errors.append('backup must be disabled for owner credentials')
if 'android:usesCleartextTraffic="false"' not in manifest: errors.append('cleartext traffic must be disabled')

owner=txt('app/src/main/java/com/anamika/ai/OwnerAuth.java')
for token in ['PBKDF2WithHmacSHA256','owner_pin_hash','owner_pin_salt','MessageDigest.isEqual','refusing to reset PIN automatically']:
    if token not in owner: errors.append('OwnerAuth missing '+token)


owner_session=txt('app/src/main/java/com/anamika/ai/OwnerSession.java')
for token in ['SESSION_MS','isDeviceLocked','valid_until']:
    if token not in owner_session: errors.append('Owner session gate missing '+token)
for rel in ['app/src/main/java/com/anamika/ai/MainActivity.java','app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java','app/src/main/java/com/anamika/ai/plugins/VoiceCommandActivity.java','app/src/main/java/com/anamika/ai/plugins/PluginManagerActivity.java']:
    if 'OwnerSession' not in txt(rel): errors.append('OwnerSession not wired into '+rel)

main=txt('app/src/main/java/com/anamika/ai/MainActivity.java')
for token in ['PIN_LOCK_UNTIL','onRequestPermissionsResult','ActivityNotFoundException',"versionName"]:
    if token=='versionName': continue
    if token not in main: errors.append('MainActivity missing '+token)

blue=txt('app/src/main/java/com/anamika/ai/plugins/AppBlueprintStore.java')
for token in ['<password-redacted>','<typed-text-redacted>','containsPasswordField','actions.jsonl']:
    if token not in blue: errors.append('Blueprint privacy fix missing '+token)

research=txt('app/src/main/java/com/anamika/ai/research/ResearchLearningStore.java')
if 'LinkedHashSet' not in research or 'n.isPassword()' not in research: errors.append('Research password/order hardening missing')

svc=txt('app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java')
for token in ['submitCommand','dispatchVerticalSwipe','clearPending','containsPasswordField']:
    if token not in svc: errors.append('Accessibility reliability fix missing '+token)
if 'dispatchSwipe(540' in svc: errors.append('hard-coded swipe coordinates remain')

creator=txt('app/src/main/java/com/anamika/ai/creator/InternetCinematicCreator.java')
for token in ['requireHttps','sameOrigin','longSide>=1920 && shortSide>=1080','setInstanceFollowRedirects(false)']:
    if token not in creator: errors.append('Creator hardening missing '+token)


motion=txt('app/src/main/java/com/anamika/ai/media3d/CinematicMotionPath.java')
renderer=txt('app/src/main/java/com/anamika/ai/media3d/Premium3DRenderer.java')
if 'groundRun' not in motion or 'CinematicMotionPath.sample' not in renderer: errors.append('subject-specific cinematic motion fix missing')

exporter=txt('app/src/main/java/com/anamika/ai/media3d/Premium3DVideoExporter.java')
if 'Encoder EOS timed out' not in exporter: errors.append('3D exporter EOS timeout missing')
if 'KEY_BITRATE_MODE' in exporter: errors.append('forced bitrate mode remains')

saver=txt('app/src/main/java/com/anamika/ai/GeneratedProjectSaver.java')
for token in ['getCanonicalPath','ANAMIKA_VERIFICATION.txt','deleteTree(project)']:
    if token not in saver: errors.append('Generated project saver hardening missing '+token)

compiler=txt('app/src/main/java/com/anamika/ai/CompilerPackManager.java')
for token in ['if (languagesDetected == 0) return false','deleteTree(root)','Covered by the Android SDK/aapt2/Gradle project verification pack','Parent traversal is not allowed']:
    if token not in compiler: errors.append('Compiler verifier fix missing '+token)

lang=txt('app/src/main/java/com/anamika/ai/language/UniversalLanguageRouter.java')
if 'looksCanonical' not in lang or 'LocalModelBridge.getStatus' not in lang: errors.append('Universal language router audit fix missing')


local=txt('app/src/main/java/com/anamika/ai/LocalModelBridge.java')
for token in ['SUPPORTED_ABIS','arm64-v8a','.partial','getUsableSpace']:
    if token not in local: errors.append('Local model extraction/ABI hardening missing '+token)

upgrade=txt('app/src/main/java/com/anamika/ai/upgrade/SelfUpgradeWorkspace.java')
for token in ['workspace_','LATEST_WORKSPACE.txt','pruneOldWorkspaces','separately built/signed APK']:
    if token not in upgrade: errors.append('Self-upgrade workspace hardening missing '+token)

autorepair=txt('app/src/main/java/com/anamika/ai/AutoRepairEngine.java')
if '<<<FILE:../' in autorepair: errors.append('AutoRepair must not silently rewrite path traversal')

workflow=txt('.github/workflows/build-apk.yml')
if 'validate_v75.py' in workflow: errors.append('old V7.5 validator still in CI')
for token in ['validate_v78.py','validate_audit.py',"gradle-version: '9.6.0'",'MODEL_SHA256','38f6bab61d341b23a6c00226f32c0d6148bf9f43']:
    if token not in workflow: errors.append('workflow missing '+token)

build=txt('app/build.gradle')
root_build=txt('build.gradle')
if 'org.jetbrains.kotlin.android' in build: errors.append('AGP 9 module still applies incompatible external kotlin-android plugin')
if "id 'com.android.application' version '9.4.0'" not in root_build: errors.append('AGP 9.4 plugin missing from root build')

for token in ['self_source/app/src/main/assets','exclude("**/*.gguf")','self_source/tools','self_source/.github/workflows','gradle.properties']:
    if token not in build: errors.append('self-upgrade snapshot missing '+token)

if "versionName '7.8.2'" not in build or 'versionCode 17' not in build: errors.append('version not bumped to 7.8.2/17')



# Native Test Lab must use Android's real PackageInstaller and owner session gate.
testlab=txt('app/src/main/java/com/anamika/ai/TestLabActivity.java')
for token in ['PackageInstaller','canRequestPackageInstalls','STATUS_PENDING_USER_ACTION','OwnerSession.isActive','getPackageArchiveInfo']:
    if token not in testlab: errors.append('Test Lab missing '+token)
if 'REQUEST_INSTALL_PACKAGES' not in manifest: errors.append('Test Lab install permission missing')
if '.TestLabActivity' not in manifest: errors.append('TestLabActivity missing from manifest')
if 'testLabButton' not in txt('app/src/main/res/layout/activity_main.xml'): errors.append('Test Lab button missing from main UI')

# Android + Web focused language set: Swift/Lua must not be advertised or registered.
compiler_json=txt('app/src/main/assets/toolchains/compiler_packs.json')
for removed in ['Swift','Lua','libanamika_swiftc.so','libanamika_lua.so']:
    if removed in compiler_json or removed in compiler:
        errors.append('removed nonessential toolchain still present: '+removed)
for required in ['Kotlin','Java','C++','Rust','Dart','JavaScript','TypeScript','Python','PHP','C#','Go','Ruby','HTML5','CSS3','SQL']:
    if required not in compiler_json:
        errors.append('focused app/web toolchain missing '+required)

for p in R.rglob('*.xml'):
    try: ET.parse(p)
    except Exception as e: errors.append(f'XML parse {p.relative_to(R)}: {e}')

if errors:
    print('\n'.join('ERROR: '+e for e in errors)); sys.exit(1)
print('V7.8.2 audit validation passed.')
