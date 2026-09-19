from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
for x in root.rglob('*.xml'): ET.parse(x)
renderer=(root/'app/src/main/java/com/anamika/ai/media3d/Premium3DRenderer.java').read_text()
for token in ['drawSubject(', 'drawDragon(', 'drawBird(', 'drawSupercar(', 'drawSpaceship(', 'drawRobot(']: assert token in renderer, token
service=(root/'app/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java').read_text()
for token in ['TYPE_ACCESSIBILITY_OVERLAY','executeNaturalCommand','ACTION_SET_TEXT','dispatchGesture','AppBlueprintStore.start','takeScreenshot']:
    assert token in service, token
creator=(root/'app/src/main/java/com/anamika/ai/creator/InternetCinematicCreator.java').read_text()
for token in ['video_url','status_url','MediaMetadataRetriever','1920x1080','Authorization']:
    assert token in creator, token
engine=(root/'app/src/main/java/com/anamika/ai/StandaloneDeveloperEngine.java').read_text()
assert 'AppBlueprintStore.latestSummary' in engine
for req in ["CompilerPackManager.java","FULL_TOOLCHAIN_STATUS.md","compiler_packs.json"]:
    hits=list(root.rglob(req))
    assert hits, "Missing V7.7 toolchain file: "+req
manager=(root/'app/src/main/java/com/anamika/ai/CompilerPackManager.java').read_text()
for token in ['libanamika_clang.so','libanamika_rustc.so','libanamika_python.so','isFullyVerified','Android SQLite']:
    assert token in manager, token
print('V7.7 feature validation passed')

