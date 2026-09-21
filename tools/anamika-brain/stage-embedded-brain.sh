#!/usr/bin/env bash
set -euo pipefail

BRAIN_URL="https://github.com/vinay1997mishra/voice-chat-app/releases/download/anamika-brain-v13-2/AnamikaAI-13-BrainRuntime-arm64.zip"
BRAIN_SHA256="582f40f4bb44fc32664a4c30ca069ea316e270267abc66a741fd6d8e3954f35d"

TMP_DIR="${RUNNER_TEMP:-/tmp}/anamika-v13-brain-stage"
ZIP="$TMP_DIR/brain-runtime.zip"
OUT="app13/src/main/jniLibs/arm64-v8a/libanamika_llama_cli.so"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR" "$(dirname "$OUT")"

curl -fL "$BRAIN_URL" -o "$ZIP"
echo "$BRAIN_SHA256  $ZIP" | sha256sum -c -
unzip -p "$ZIP" payload/bin/llama-cli > "$OUT"
test -s "$OUT"
chmod 755 "$OUT"

file "$OUT"
stat -c%s "$OUT"
