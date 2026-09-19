from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
required=[
 'app/src/main/java/com/anamika/ai/media3d/CinematicSceneConfig.java',
 'app/src/main/java/com/anamika/ai/media3d/Cinematic3DDirector.java',
 'app/src/main/java/com/anamika/ai/media3d/SceneSubject.java',
 'app/src/main/java/com/anamika/ai/media3d/Premium3DRenderer.java',
 'app/src/main/java/com/anamika/ai/media3d/Premium3DVideoExporter.java',
 'app/src/main/java/com/anamika/ai/plugins/PluginRegistry.java',
 'app/src/main/java/com/anamika/ai/plugins/PluginManagerActivity.java',
 'app/src/main/java/com/anamika/ai/plugins/AppPluginEngine.java',
 'app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java',
 'app/src/main/java/com/anamika/ai/plugins/VoiceCommandActivity.java',
 'app/src/main/res/layout/activity_plugin_manager.xml',
 'app/src/main/res/xml/anamika_accessibility_service.xml',
]
for rel in required:
    assert (root/rel).exists(), f'missing {rel}'
for x in root.rglob('*.xml'):
    ET.parse(x)
manifest=(root/'app/src/main/AndroidManifest.xml').read_text()
assert 'android.permission.INTERNET' not in manifest, 'standalone runtime should not require internet'
assert 'AppAutomationAccessibilityService' in manifest
build=(root/'app/build.gradle').read_text()
assert "versionName '7.5'" in build
renderer=(root/'app/src/main/java/com/anamika/ai/media3d/Premium3DRenderer.java').read_text()
for token in ['drawSubject(', 'drawDragon(', 'drawBird(', 'drawSupercar(', 'drawSpaceship(', 'drawRobot(']:
    assert token in renderer, f'missing renderer feature {token}'
service=(root/'app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java').read_text()
for token in ['TYPE_ACCESSIBILITY_OVERLAY','executeNaturalCommand','ACTION_SET_TEXT','dispatchGesture']:
    assert token in service, f'missing app-control feature {token}'
print('V7.5 validation passed')
