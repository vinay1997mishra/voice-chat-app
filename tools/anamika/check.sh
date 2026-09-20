#!/usr/bin/env bash
set -euo pipefail
source_root="$(cd "$1" && pwd)"
# Candidate code can access only this read-only source mount, not host workflow
# scripts, artifacts, runtime tokens, or the model/publisher credentials.
docker run --rm --cap-drop=ALL --security-opt=no-new-privileges \
  --pids-limit=1024 --memory=10g \
  -v "$source_root/apps/mobile:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.32.8 /bin/bash -lc '
    set -euo pipefail
    flutter create --platforms=android --org com.voicechat.anamika --project-name voice_chat_app /tmp/build
    rm -rf /tmp/build/lib /tmp/build/test
    cp -R /source/lib /tmp/build/lib
    cp -R /source/test /tmp/build/test
    cp /source/pubspec.yaml /tmp/build/pubspec.yaml
    cd /tmp/build
    flutter pub get
    flutter analyze --no-fatal-infos
    flutter test
    flutter build apk --debug -t lib/main_v05.dart
  '
