# Fresh Android release signing

Fresh installation is authorized for this release. Create one new private signing key,
then retain it so later APKs can update this fresh installation.

Run from a checkout of this branch on a computer with Python 3.10+, Java 17+ and GitHub CLI.
Sign in to GitHub CLI as a repository administrator with permission to write Actions secrets:

```sh
gh auth login
python3 tools/signing/setup_release_signing.py
```

The helper creates a random-password RSA 3072-bit PKCS12 key and private backup in
`~/.tinnistar-signing`, validates the certificate and key password, and sets these
five repository secrets through GitHub CLI stdin:

- `TINNI_RELEASE_KEYSTORE_B64`
- `TINNI_RELEASE_STORE_PASSWORD`
- `TINNI_RELEASE_KEY_PASSWORD`
- `TINNI_RELEASE_KEY_ALIAS`
- `TINNI_RELEASE_CERT_SHA256`

It does not print passwords or keystore Base64. Repeating the command reuses the same
backed-up key and repairs partially completed secret installation. It refuses to
overwrite incomplete backups or store signing material inside the repository.

Keep an encrypted offline copy of the private backup directory. In Codespaces,
download that backup to private storage before deleting the Codespace.

Use `--prepare-only` to generate and validate the local backup without writing secrets.
Use `--backup-dir /private/path/tinni-signing` to choose a different private location.
The default target is `vinay1997mishra/voice-chat-app`; `--repo owner/name` overrides it.

After all five secrets are installed, rerun the **Tinni Star Android** workflow on the
CP/VS branch. Its existing certificate checks verify the generated APK signing.
Publish the app and backend together, because updated gift sends require request IDs.

A fresh certificate may also need registration in Android OAuth/provider configuration.
Its SHA-1 can be read locally with `keytool -list -v` from the private keystore;
the helper-derived SHA-256 is the value stored in the fifth repository secret.
