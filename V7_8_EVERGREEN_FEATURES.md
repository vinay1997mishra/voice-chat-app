# Anamika AI V7.8 Evergreen

## Permanent capability layers

- Android development: Kotlin, Java, XML, Gradle, SQL, C/C++ and registered toolchain packs.
- Web development: HTML5, CSS3, JavaScript, TypeScript plus backend language packs already registered in V7.7.
- HTML/CSS are validated with built-in markup/stylesheet validators because they do not have a traditional compiler.
- Strict verification remains: missing real compiler/runtime pack means no FULL VERIFIED label.

## Evergreen self-upgrade

The APK build now embeds a read-only snapshot of Anamika's current Java/Kotlin/resources/manifest/Gradle source under `self_source/`.
Owner command/UI can extract that snapshot into a private `self_upgrade/current` workspace. Anamika may generate changes locally, but owner review/approval, compiler validation, APK signing/build and Android install rules still apply.

## Universal app/search control

- Installed launchable apps are discovered by label instead of only a hard-coded app list.
- Google searches can be launched directly.
- YouTube searches can open the YouTube app when installed, with browser fallback.
- Existing Plugin Center remains owner-controlled. Generic tap/type/scroll/back automation is only attempted for apps the owner enabled and for UI Android exposes through Accessibility.

## Research / learn mode

`search karke seekho`, `research mode`, or the Research button starts an explicit local research session.
While Accessibility is enabled, Anamika can save visible/public UI text from screens the owner opens into a local JSONL knowledge file. This is a searchable reference notebook; it does not secretly retrain model weights and it cannot bypass secure/DRM/private app data.

## Multilingual commands

Speech capture no longer hard-codes Hindi. It requests multilingual/language-switch behavior from the installed speech-recognition service. Unknown-language text can be normalized locally through the bundled on-device model when available. Actual coverage depends on the speech service, installed language packs and the bundled model; no system can guarantee every human language/dialect at 100% accuracy.
