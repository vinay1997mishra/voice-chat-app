# V7.8 Full Toolchain Status

Anamika's registry covers the major Android/web development language families: C, C++, Rust, Go, Python, JavaScript, TypeScript, Java, Kotlin, C#, Ruby, PHP, Dart, Shell, SQL, HTML5, CSS3 and the Android SDK/Gradle/aapt2 verification pack.

HTML5 and CSS3 do not have traditional compilers. V7.8 therefore marks them through dedicated built-in structural/runtime-format validators. JavaScript/TypeScript still require their real runtime/compiler packs for FULL VERIFIED status.

For compiler-based languages, source support does **not** mean the binary compiler is magically present. The final APK build must physically package each Android/ABI-compatible compiler/runtime pack listed in `app/src/main/assets/toolchains/compiler_packs.json`. V7.8 deliberately reports `MISSING` for any absent pack.

Future languages/frameworks should be added as new registry/plugin packs rather than redesigning Anamika's core.


V7.8.2 focus: Swift and Lua were removed from the bundled toolchain registry because this build is focused on Android apps and websites/web apps.
