# Offline Model Build Profile

The optional full standalone APK build bundles:

- Runtime: `dev.ffmpegkit-maintained:llama-android:0.1.1` (prebuilt llama.cpp Android AAR, MIT license)
- Model: `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF`, Q4_K_M quantization (Apache-2.0)
- APK asset name: `assets/models/anamika-coder.gguf`

The GitHub Actions workflow downloads the model **at build time only** and packages it in the APK. On first local-model use, Anamika copies the asset into its private model directory, then performs inference on-device. No API key or remote AI server is used at runtime.

Trade-offs:
- the Q4_K_M model is roughly 1.12 GB before APK overhead;
- first local-model initialization needs substantial free storage because the bundled asset is copied to app-private storage;
- 1.5B is a phone-friendly compromise, not equivalent to a large cloud coding model;
- final code correctness still requires compiler/build/test validation.

For stronger coding quality on a high-RAM device, the build workflow can later be changed to a larger compatible GGUF model, with a corresponding increase in APK size and RAM requirements.
