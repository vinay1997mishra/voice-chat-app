#!/usr/bin/env python3
"""Create a backed-up release key and install Tinni's five GitHub secrets."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPO = "vinay1997mishra/voice-chat-app"
SECRET_NAMES = (
    "TINNI_RELEASE_KEYSTORE_B64",
    "TINNI_RELEASE_STORE_PASSWORD",
    "TINNI_RELEASE_KEY_PASSWORD",
    "TINNI_RELEASE_KEY_ALIAS",
    "TINNI_RELEASE_CERT_SHA256",
)


class SetupError(Exception):
    pass


def run(command, *, input_data=None, env=None):
    result = subprocess.run(command, input=input_data, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        # Tool output can contain sensitive material; report only the operation.
        raise SetupError(f"{Path(command[0]).name} operation failed. "
                         "Check installation, authentication and repository permissions.")
    return result.stdout


def signing_environment(settings):
    env = os.environ.copy()
    env["TINNI_SIGNING_STORE_PASS"] = settings["store_password"]
    env["TINNI_SIGNING_KEY_PASS"] = settings["key_password"]
    return env


def certificate(keystore, settings):
    return run([
        "keytool", "-exportcert", "-alias", settings["alias"],
        "-keystore", str(keystore), "-storetype", "PKCS12",
        "-storepass:env", "TINNI_SIGNING_STORE_PASS",
    ], env=signing_environment(settings))


def ensure_material(backup):
    backup = Path(backup).expanduser().resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if backup.is_relative_to(repository_root):
        raise SetupError("Choose a backup directory outside the source repository.")
    if backup.exists():
        if not backup.is_dir() or backup.stat().st_mode & 0o077:
            raise SetupError("The existing backup directory must be private (chmod 700).")
        keystore = backup / "release.p12"
        credentials = backup / "credentials.json"
        if not keystore.is_file() or not credentials.is_file():
            raise SetupError("Incomplete backup directory; existing files were preserved.")
        if any(path.stat().st_mode & 0o077 for path in (keystore, credentials)):
            raise SetupError("Backup files must be private (chmod 600).")
        settings = json.loads(credentials.read_text())
        if not isinstance(settings, dict):
            raise SetupError("Invalid signing backup settings.")
        if any(not isinstance(settings.get(key), str) or not settings[key]
               for key in ("alias", "store_password", "key_password")):
            raise SetupError("Invalid signing backup settings.")
    else:
        backup.parent.mkdir(parents=True, exist_ok=True)
        password = secrets.token_urlsafe(32)
        settings = {"alias": "tinni-release", "store_password": password,
                    "key_password": password}
        with tempfile.TemporaryDirectory(prefix=".tinni-signing-", dir=backup.parent) as staging:
            stage = Path(staging)
            keystore = stage / "release.p12"
            run([
                "keytool", "-genkeypair", "-noprompt", "-storetype", "PKCS12",
                "-alias", settings["alias"], "-keyalg", "RSA", "-keysize", "3072",
                "-validity", "10000", "-dname", "CN=Tinni Star, OU=Android Release, O=Tinni Star",
                "-keystore", str(keystore),
                "-storepass:env", "TINNI_SIGNING_STORE_PASS",
                "-keypass:env", "TINNI_SIGNING_KEY_PASS",
            ], env=signing_environment(settings))
            keystore.chmod(0o600)
            credentials = stage / "credentials.json"
            credentials.write_text(json.dumps(settings))
            credentials.chmod(0o600)
            certificate(keystore, settings)
            # Keep a stable private backup before attempting any GitHub writes.
            if backup.exists():
                raise SetupError("Backup directory appeared during setup; rerun to reuse it.")
            stage.rename(backup)
        keystore = backup / "release.p12"
    der = certificate(keystore, settings)
    # Verify that the stored private-key password works, without changing the key.
    with tempfile.TemporaryDirectory(prefix="tinni-key-check-") as temporary:
        run([
            "keytool", "-certreq", "-alias", settings["alias"],
            "-keystore", str(keystore), "-storetype", "PKCS12",
            "-file", str(Path(temporary) / "request.csr"),
            "-storepass:env", "TINNI_SIGNING_STORE_PASS",
            "-keypass:env", "TINNI_SIGNING_KEY_PASS",
        ], env=signing_environment(settings))
    values = dict(zip(SECRET_NAMES, (
        base64.b64encode(keystore.read_bytes()).decode("ascii"),
        settings["store_password"], settings["key_password"], settings["alias"],
        hashlib.sha256(der).hexdigest(),
    )))
    if any(len(value.encode()) > 48 * 1024 for value in values.values()):
        raise SetupError("Signing material exceeds GitHub's 48 KB secret limit.")
    return backup, values


def upload_secrets(repo, values):
    installed = 0
    for name in SECRET_NAMES:
        try:
            run(["gh", "secret", "set", name, "--repo", repo],
                input_data=values[name].encode())
        except SetupError as error:
            raise SetupError(f"{installed}/5 secrets saved; failed at {name}. "
                             "Fix GitHub access and rerun with the same backup directory.") from error
        installed += 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--backup-dir", type=Path,
                        default=Path.home() / ".tinnistar-signing")
    parser.add_argument("--prepare-only", action="store_true",
                        help="Create and validate the backup without writing GitHub secrets.")
    args = parser.parse_args(argv)
    try:
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
            raise SetupError("Repository must use owner/name format.")
        if not shutil.which("keytool"):
            raise SetupError("Install Java 17 or newer to provide keytool.")
        if not args.prepare_only:
            if not shutil.which("gh"):
                raise SetupError("Install GitHub CLI, then run gh auth login.")
            # Check repository access before creating new private material.
            run(["gh", "api", f"repos/{args.repo}/actions/secrets/public-key"])
        backup, values = ensure_material(args.backup_dir)
        if args.prepare_only:
            print(f"Signing backup created and validated: {backup}")
            print("No GitHub secrets were changed.")
        else:
            upload_secrets(args.repo, values)
            print(f"All five release signing secrets saved to {args.repo}.")
            print(f"Private backup: {backup}")
            print("Keep this backup outside Git and retain it for future updates.")
        return 0
    except (SetupError, OSError, ValueError) as error:
        # JSON/keytool/CLI errors never print passwords, Base64 or subprocess output.
        message = str(error) if isinstance(error, SetupError) else "Signing setup failed; check the private backup and local permissions."
        print(message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
