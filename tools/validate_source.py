#!/usr/bin/env python3
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
required = [
    'settings.gradle','build.gradle','app/build.gradle','app/src/main/AndroidManifest.xml',
    'app/src/main/java/com/anamika/ai/MainActivity.java',
    'app/src/main/java/com/anamika/ai/media3d/CinematicMotionPath.java',
    'app/src/main/java/com/anamika/ai/GeneratedProjectSaver.java',
    'app/src/main/java/com/anamika/ai/OwnerAuth.java',
    'app/src/main/java/com/anamika/ai/StandaloneDeveloperEngine.java',
    'app/src/main/java/com/anamika/ai/OfflineCodeValidator.java',
    'app/src/main/java/com/anamika/ai/CompilerPackManager.java',
    'app/src/main/assets/toolchains/compiler_packs.json',
    'FULL_TOOLCHAIN_STATUS.md',
    'V7_8_EVERGREEN_FEATURES.md',
    'app/src/main/java/com/anamika/ai/research/AppSearchController.java',
    'app/src/main/java/com/anamika/ai/research/ResearchLearningStore.java',
    'app/src/main/java/com/anamika/ai/language/UniversalLanguageRouter.java',
    'app/src/main/java/com/anamika/ai/upgrade/SelfUpgradeWorkspace.java',
    'app/src/main/kotlin/com/anamika/ai/KotlinLlamaRunner.kt',
    'app/src/main/java/com/anamika/ai/media3d/Premium3DActivity.java',
    'app/src/main/java/com/anamika/ai/media3d/Premium3DRenderer.java',
    'app/src/main/java/com/anamika/ai/media3d/Premium3DVideoExporter.java',
    'app/src/main/java/com/anamika/ai/creator/CreatorHubActivity.java',
    'app/src/main/java/com/anamika/ai/creator/InternetCinematicCreator.java',
    'app/src/main/java/com/anamika/ai/plugins/AppBlueprintStore.java',
    'app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java',
    'app/src/main/res/layout/activity_creator_hub.xml',
    'app/src/main/res/layout/activity_plugin_manager.xml',
    'app/src/main/res/xml/anamika_accessibility_service.xml',
]
for rel in required:
    if not (ROOT/rel).is_file(): errors.append('Missing required file: '+rel)
for p in ROOT.rglob('*.xml'):
    try: ET.parse(p)
    except Exception as e: errors.append(f'Invalid XML {p.relative_to(ROOT)}: {e}')
for p in ROOT.rglob('*.java'):
    text=p.read_text(encoding='utf-8')
    if text.count('{') != text.count('}'):
        errors.append(f'Brace count mismatch: {p.relative_to(ROOT)}')
manifest=(ROOT/'app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
for token in ['android.permission.INTERNET','AppAutomationAccessibilityService','.creator.CreatorHubActivity']:
    if token not in manifest: errors.append('Manifest missing '+token)
acc=(ROOT/'app/src/main/res/xml/anamika_accessibility_service.xml').read_text(encoding='utf-8')
if 'android:canTakeScreenshot="true"' not in acc: errors.append('Accessibility screenshot capability missing')
build=(ROOT/'app/build.gradle').read_text(encoding='utf-8')
if "versionName '7.8.2'" not in build: errors.append('Version is not 7.8.2')
if errors:
    print('\n'.join('ERROR: '+e for e in errors)); sys.exit(1)
print('V7.8.2 source validation passed.')
