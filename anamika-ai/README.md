# Anamika AI Android Bootstrap

Anamika now has two development layers:

1. **Offline local development layer** — works without GitHub.
2. **GitHub remote layer** — used for GitHub-only operations when an authenticated connection is available.

## Offline features
- Local Git repository initialization
- Status
- Branch create/list/switch
- Commit
- Log/history
- Diff
- Tag creation
- Merge
- Local workspace storage inside the app
- Offline queue for remote GitHub actions

Voice/text command examples:
- `git init anamika`
- `git status`
- `git branch feature-x`
- `git checkout feature-x`
- `git commit add feature x`
- `git log`
- `git diff`
- `git tag v1`
- `git merge feature-x`
- `git push`
- `git pull`
- `github queue`

## Owner Permission System
Risk levels:
- NORMAL: read-only operations; no credential prompt
- PROTECTED: local writes, commits, branch changes, pull
- CRITICAL: merges, tags, push, PR creation, releases, workflows, self-update
- ULTRA_CRITICAL: PR merge, repository/security setting changes, secrets, repository deletion

Protected actions require Android device-owner authentication. Ultra-critical actions require an additional confirmation before device authentication.

## GitHub capability catalog
The app models repository/file operations, commits, branches, tags, push/pull, pull requests, issues, releases, workflow runs, logs, artifacts, commit status, security scan status, collaborators, settings and secrets.

Operations that inherently live on GitHub (for example PRs, GitHub Issues, GitHub Actions and GitHub Releases) cannot exist while GitHub itself is unavailable. When remote connectivity/authentication is not configured, Anamika preserves the requested action in an offline queue instead of silently failing.

## Remote authentication rule
Do not put a personal access token, GitHub password, signing key or long-lived secret inside the APK. The production remote layer should use a GitHub App/OAuth flow and short-lived credentials from a protected backend.

## Existing assistant features
- Hindi/English speech input
- Hindi/English text-to-speech replies
- Local memory
- Search command
- GitHub release checker
- Owner-approved self-update handoff
- AI code-generation backend interface
- Link/video-learning backend interface
- GitHub Actions APK build
- Unit tests and lint
- CodeQL security scanning
- Dependabot dependency updates

## Still requiring external services
- AI model backend for real code generation
- Video/link fetch, transcription and analysis backend
- True speaker verification model for owner voice identity
- Authenticated GitHub App/OAuth backend for live remote GitHub actions
- Production APK signing
