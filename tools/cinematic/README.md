# Original cinematic gift assets

The `tinnistar` pipeline renders original animated 3D mesh geometry with Blender 4.5.2. Its catalog covers all 50 Normal, 20 CP and 249 Country gifts, plus the ten locked Rocket stages. Normal and CP gift durations match the existing 5/6/7/8-second delivery policy. Country gifts show their ordinary, correctly proportioned national flag waving at the screen center for two seconds before recipient flight. Rocket shows 9→1 over nine seconds: it builds pressure on its pad during 9–2 and lifts off only at 1.

Rocket hardware stays integrated: graphite body, glossy nose, red-accented fins, blue glass, steel nozzles, white-hot/amber exhaust, attached tier-specific boosters and armour, launch smoke and falling wrapped gifts. Other scenes model curved rose petals, food, steam, jewels, architecture, creatures, vehicles, romantic couples and deformed textured flags. Country textures are downloaded from FlagCDN at build time; a missing texture fails its scene. Blender and source frames are not shipped in the APK.

## Build and review

```sh
python3 tools/cinematic/catalog.py validate
python3 -m unittest discover -s tools/cinematic -p 'test_*.py'
python3 tools/cinematic/catalog.py render --shard 0 --shards 20
python3 tools/cinematic/catalog.py pack --source FULL_COMMIT_SHA
```

Before rendering, the pipeline builds and checks all 329 real Blender scene graphs and publishes representative review posters. The render workflow then has 20 bounded shards. A reusable publish job runs in the same workflow on `tinnistar`, so publishing does not depend on a `workflow_run` file on `main`. It publishes an immutable `cinematic-<source SHA prefix>` prerelease containing the ZIP, SHA-256, manifest and contact sheets showing every poster. The preview branch contains the review sheets and manifest. After all media verifies, the publish job pins the immutable bundle hash on `tinnistar`, increments the APK version, and invokes the existing Android workflow with that exact source commit. The pin preserves newer app commits on `tinnistar` when their cinematic source fingerprint still matches; changed render sources fail safely. A concurrent push is rejected instead of being overwritten. Movies are silent H.264/yuv420p, 360×640 at 24 fps, capped to a total media budget of 38 MiB.

Packaging fails for missing scenes, truncated movies, audio tracks, wrong codec/dimensions/frame count/duration, invalid posters or excessive size. APK installation verifies the pinned ZIP, every movie/poster hash, source fingerprint and all catalog IDs/durations before bundling. The Android workflow refuses to package without the verified pin. Runtime playback uses local hardware-decoded movies and retains the existing painted scene as a fallback. Gifts and Rocket launches share a fair lane, pause while the app is in the background, and respect the existing master, gift and Rocket effect controls.

A successful encode proves media structure. Contact sheets and real Android playback still require visual/device review; never claim photorealism or device approval from codec checks alone. Gift recipients, Lucky Combo, economy, Rocket thresholds and server rewards remain authoritative.

After a newly completed Rocket's nine-second sequence, the app requests `/gifts/rocket-reward` using the authenticated session. The server returns only that viewer's actually awarded coins/frame/medal; neither public ranking nor room events include other users' received reward details. Winners see a private card for six foreground seconds, with an immediate close button. Non-winners see no invented reward. Reopening the room does not replay historical launches or reward cards. This display does not change the existing seven-second server eligibility window or payout policy.

Country presentation uses a centered viewport spanning 96% of screen width and 66% of its height, with a close frontal camera and real wind-deformed flag cloth. After the two-second hold, its recipient flight shrinks from a large flag to the selected receiver's DP; other gift flights retain their existing motion.

Flag framing retains the complete national artwork, including corner emblems; the Nepal flag mesh respects its transparent, nonrectangular silhouette.
