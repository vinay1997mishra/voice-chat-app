ANAMIKA V7.8 COMPILER PACK DIRECTORY

This source project contains the strict toolchain ORCHESTRATOR, not fake compiler binaries.
At APK build time, real Android/ABI-compatible compiler packs must be placed in:
  app/src/main/jniLibs/arm64-v8a/
(or the matching ABI folder) using the exact names from compiler_packs.json.

Android 10+ blocks execve of arbitrary executables from writable app home. Toolchain
executables therefore need to be shipped as read-only APK-native payloads/JNI wrappers,
not downloaded into app storage and executed later.

Do not mark a project FULL VERIFIED unless CompilerPackManager returns PASS for every
language and (for Android projects) the Android SDK/resource verification pack.
