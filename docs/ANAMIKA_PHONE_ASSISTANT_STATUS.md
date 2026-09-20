# Phone assistant implementation status

Scope: owner-controlled Anamika Android app on `anamika-v7.8.2-final`.
The Flutter voice-chat demo on `main` is a different app and its CI results do not validate Anamika.

## Existing Android source inspected

- Full-height chat with attachment, microphone, send and left menu.
- Plugin enrollment and one-shot discovery without enrollment.
- Installed application label discovery, accessibility bridge, device profile storage.
- Local model adapter and generated-source validation/candidate workspace.

These are source-level observations, not end-to-end device validation.

## Changes in this branch

- Correct speech switching extra type and request hi-IN, ur-IN, en-IN with offline preference.
- Fix escaped whitespace in mixed-language search parsing and prompt newlines.
- Prevent English substrings (e.g. “show”) from falsely becoming Hinglish.
- Add deterministic Urdu search/open commands and Indian Urdu/English locale selection.
- Stop persisting unconfirmed model classifications as learned commands.
- Refresh device profile after firmware changes.
- Do not skip requested phone setting actions because a cached route exists.
- Do not derive an executable settings route from untrusted web snippet keywords.
- Recheck remembered settings routes and ask before saving newly discovered routes.
- Label the menu Phone Assistant Manager and set mixed-direction multiline chat input.

## Validation

`python tools/test_language_router.py`: 15 assertions against the real Java router,
compiled using JDK 17 with minimal Android/model stubs. No real inference or speech test.
`python tools/validate_source.py` and `python tools/validate_audit.py`: passed structural checks.
Full Android compilation, installation and physical-device tests remain pending.

## Open requirements

- DeviceFunctionDiscovery currently fetches DuckDuckGo snippets; AppSearchController opens Google in the foreground. Neither is a background Google API integration.
- A phone has no universal API key. A named search service and secure credential configuration are needed; do not collect another app's credentials or put keys in Git.
- Offline generation is separate from building/signing a complete Android APK on-device. Source extraction and syntax checks are not a complete offline APK compiler pipeline.
- Preserve owner approval of the actual candidate, signing identity continuity and explicit Android installation consent.
- Voice recognition language-switch extras are recognizer-dependent; an offline preference is not proof that a recognizer never uses the network.
- Natural Hindi/Urdu pronunciation requires installed appropriate voices and human listening tests. Keyword additions are not language-model training.
- Discovery only covers visible/exported/permission-accessible app features. It cannot guarantee all apps or all functions. Ambiguous commands must ask a focused question.
- Repository was public when checked. Do not push new changes until the owner's existing private-source preference is reconciled.
