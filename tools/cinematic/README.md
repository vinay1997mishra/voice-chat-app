# Original cinematic gift assets

The `tinnistar` pipeline renders original animated 3D mesh geometry with Blender 4.5.2. Its catalog covers all 50 Normal, 20 CP and 249 Country gifts, plus the ten locked Rocket stages. Gift durations match the existing 5/6/7/8-second delivery policy; each Rocket launches vertically for nine seconds.

Rocket hardware stays integrated: graphite body, glossy nose, red-accented fins, blue glass, steel nozzles, white-hot/amber exhaust, attached tier-specific boosters and armour, launch smoke and falling wrapped gifts. Other scenes model curved rose petals, food, steam, jewels, architecture, creatures, vehicles, romantic couples and deformed textured flags. Country textures are downloaded from FlagCDN at build time; a missing texture fails its scene. Blender and source frames are not shipped in the APK.

## Build and review

```sh
python3 tools/cinematic/catalog.py validate
python3 -m unittest discover -s tools/cinematic -p 'test_*.py'
python3 tools/cinematic/catalog.py render --shard 0 --shards 20
python3 tools/cinematic/catalog.py pack --source FULL_COMMIT_SHA
```

Before rendering, the pipeline builds and checks all 329 real Blender scene graphs and publishes representative review posters. The render workflow then has 20 bounded shards. A reusable publish job runs in the same workflow on `tinnistar`, so publishing does not depend on a `workflow_run` file on `main`. It publishes an immutable `cinematic-<source SHA prefix>` prerelease containing the ZIP, SHA-256, manifest and contact sheets showing every poster. The preview branch contains the review sheets and manifest. After all media verifies, the publish job pins the immutable bundle hash on `tinnistar`, increments the APK version, and invokes the existing Android workflow with that exact source commit. If another change moved `tinnistar` during rendering, the pin fails safely instead of overwriting it. Movies are silent H.264/yuv420p, 360×640 at 24 fps, capped to a total media budget of 38 MiB.

Packaging fails for missing scenes, truncated movies, audio tracks, wrong codec/dimensions/frame count/duration, invalid posters or excessive size. APK installation verifies the pinned ZIP, every movie/poster hash, source fingerprint and all catalog IDs/durations before bundling. The Android workflow refuses to package without the verified pin. Runtime playback uses local hardware-decoded movies and retains the existing painted scene as a fallback.

A successful encode proves media structure. Contact sheets and real Android playback still require visual/device review; never claim photorealism or device approval from codec checks alone. Gift recipients, Lucky Combo, economy, Rocket thresholds and server rewards remain authoritative.
