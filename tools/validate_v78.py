#!/usr/bin/env python3
from pathlib import Path
import sys, json, xml.etree.ElementTree as ET, re
root=Path(__file__).resolve().parents[1]
errors=[]
required=[
 'settings.gradle','build.gradle','app/build.gradle','app/src/main/AndroidManifest.xml',
 'app/src/main/java/com/anamika/ai/MainActivity.java','app/src/main/java/com/anamika/ai/OfflineCodeValidator.java',
 'app/src/main/java/com/anamika/ai/CompilerPackManager.java','app/src/main/java/com/anamika/ai/research/AppSearchController.java',
 'app/src/main/java/com/anamika/ai/research/ResearchLearningStore.java','app/src/main/java/com/anamika/ai/language/UniversalLanguageRouter.java',
 'app/src/main/java/com/anamika/ai/upgrade/SelfUpgradeWorkspace.java','app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java',
 'app/src/main/assets/toolchains/compiler_packs.json','V7_8_EVERGREEN_FEATURES.md'
]
for r in required:
    if not (root/r).is_file(): errors.append('missing '+r)
for x in root.rglob('*.xml'):
    try: ET.parse(x)
    except Exception as e: errors.append(f'xml {x.relative_to(root)}: {e}')
try:
    packs=json.loads((root/'app/src/main/assets/toolchains/compiler_packs.json').read_text())
    langs={p['language'] for p in packs['packs']}
    for lang in ['HTML5','CSS3','Kotlin','Java','JavaScript','TypeScript','Android project','SQL']:
        if lang not in langs: errors.append('toolchain registry missing '+lang)
except Exception as e: errors.append('compiler_packs.json: '+str(e))
main=(root/'app/src/main/java/com/anamika/ai/MainActivity.java').read_text()
for t in ['AppSearchController.searchYouTube','AppSearchController.searchGoogle','ResearchLearningStore.start','SelfUpgradeWorkspace.prepare','UniversalLanguageRouter.interpret','answerWithLocalConversation','SoftVoiceProfile.apply']:
    if t not in main: errors.append('MainActivity missing '+t)
service=(root/'app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java').read_text()
if 'ResearchLearningStore.capture' not in service: errors.append('Accessibility service not wired to research capture')
build=(root/'app/build.gradle').read_text()
version_ok = ("versionName '7.8.2'" in build) or ('ANAMIKA_VERSION_NAME' in build and '"7.8.2"' in build)
if not version_ok: errors.append('build.gradle missing V7.8.2-compatible versionName')
for t in ['bundleAnamikaSelfSource','self_source/app/src/main/java','self_source/app/src/main/res']:
    if t not in build: errors.append('build.gradle missing '+t)
validator=(root/'app/src/main/java/com/anamika/ai/OfflineCodeValidator.java').read_text()
for t in ['validateHtml','validateCss','HTML5 doctype','Unbalanced CSS braces']:
    if t not in validator: errors.append('validator missing '+t)
# lightweight quote/braces sanity after stripping strings/comments is intentionally conservative
for j in root.rglob('*.java'):
    txt=j.read_text()
    if txt.count('{')!=txt.count('}'):
        errors.append('brace count mismatch '+str(j.relative_to(root)))
if errors:
    print('\n'.join('ERROR: '+e for e in errors)); sys.exit(1)
print('V7.8.2 Evergreen validation passed.')
