# Anamika repair and owner-approved candidate builds

Implemented path: Hindi/English owner request → configured coding model → up to
three isolated analyze/test/APK checks → draft pull request → owner reviews exact
commit → candidate debug APK. A failed run never replaces the installed app.

## One-time setup

1. Review/merge this implementation so workflows exist on `main`.
2. In repository Actions variables set `ANAMIKA_MODEL_URL` to an HTTPS
   OpenAI-compatible **chat completions endpoint**, and `ANAMIKA_MODEL` to the
   coding model available on that endpoint. Add `ANAMIKA_MODEL_KEY` as an Actions
   secret, never in chat, source, or the APK. Requests send this public repository's
   mobile source and diagnostics to the configured service; model usage may cost
   money. No provider is selected or provisioned automatically.
3. Enable “Allow GitHub Actions to create and approve pull requests” in repository
   Actions settings if disabled. This worker creates draft PRs; it never approves
   or merges them. Repository permissions may need an administrator to configure.
4. Owner opens **Anamika Repair Request**, selects main, enters a request and runs
   it. Only the repository-owner account can start the pipeline. Jobs require a
   Linux GitHub runner with Docker and access to `ghcr.io/cirruslabs/flutter:3.32.8`.
5. After successful checks, inspect the draft PR diff and the exact candidate SHA.
   Run **Anamika Safe Self-Upgrade Gate** on main with the PR number, complete SHA,
   and explicit approval. An outdated SHA is rejected. Download its candidate APK.

## Mobile entry points

`main_anamika.dart` is a dedicated owner console. In voice-chat builds, compile with
`--dart-define=ANAMIKA_OWNER_TOOLS=true` to expose Code Doctor. Normal builds hide it.
Visibility is not authentication: GitHub signs in and authorizes the owner.
The request button copies text and opens GitHub; paste it into **Run workflow**.
The APK does not contain GitHub/model credentials or pretend to run a local model.

## Safety and validation

Only application `.dart` files under `apps/mobile/lib` may be generated; repair
infrastructure, owner console, tests, dependencies, workflows and signing controls
are read-only to the model. Files cannot be deleted. SHA-256 preconditions reject
stale patches. Review data and Dart candidate snapshots are immutable; approvals
are bound to candidate contents/commit. Model/publish jobs never execute candidate
code. Check jobs run it in a Docker container with only source mounted read-only,
no host workflow/artifact files, no Docker socket and no GitHub/model credentials.
Failed real checks feed diagnostics into the next attempt. Malformed model output
or infrastructure errors stop explicitly; they are not reported as passing repairs.

The publishing job rechecks the candidate digest, protected paths and main SHA.
Checks mean compilation/tests passed, not that any arbitrary requested feature is
correct. Owner acceptance remains necessary. Bot-created PRs may not trigger other
workflows with `GITHUB_TOKEN`; the repair loop performs its own explicit checks.

## Remaining deployment boundaries

This is an **online repair backend**, not an offline Android compiler/model. An
on-device inference engine, model assets and native toolchain are not in this repo.
The Dart interfaces remain available for a future implementation.

Candidate builds are **debug-signed**, never advertised as production upgrades.
Repeated debug builds can use different signing keys, and older demo APKs use a
different application ID. A persistent protected release keystore, matching app
ID, increasing version code, and trusted certificate comparison must be configured
before reliable in-place updates. Never uninstall a user's app to bypass a mismatch.
Android installation remains explicit; there is no silent install or auto-merge.
Retain the previous signed release for rollback. No production signing key has been
created and no model service has been configured by this change.

Local validation: `python3 -m unittest discover -s tools/anamika -v`; Flutter checks
and tests use the pinned 3.32.8 toolchain. CI also checks formatting and V05 compile.
