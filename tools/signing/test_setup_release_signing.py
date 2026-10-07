import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "setup_release_signing", Path(__file__).with_name("setup_release_signing.py"))
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SigningSetupTest(unittest.TestCase):
    def test_real_key_has_matching_fingerprint_private_backup_and_stable_retries(self):
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root) / "backup"
            backup, values = setup.ensure_material(directory)
            settings = json.loads((backup / "credentials.json").read_text())
            der = setup.certificate(backup / "release.p12", settings)
            self.assertEqual(values["TINNI_RELEASE_CERT_SHA256"], hashlib.sha256(der).hexdigest())
            self.assertEqual(set(values), set(setup.SECRET_NAMES))
            self.assertEqual(backup.stat().st_mode & 0o077, 0)
            for name in ("release.p12", "credentials.json"):
                self.assertEqual((backup / name).stat().st_mode & 0o077, 0)
            self.assertEqual(setup.ensure_material(directory)[1], values)

    def test_existing_incomplete_backup_is_preserved(self):
        with tempfile.TemporaryDirectory() as root:
            backup = Path(root) / "backup"
            backup.mkdir(mode=0o700)
            marker = backup / "keep.txt"
            marker.write_text("preserved")
            with self.assertRaises(setup.SetupError):
                setup.ensure_material(backup)
            self.assertEqual(marker.read_text(), "preserved")

    def test_secrets_are_sent_by_stdin_and_failure_is_resumable(self):
        values = {name: "dummy-value" for name in setup.SECRET_NAMES}
        with patch.object(setup, "run") as run:
            setup.upload_secrets("owner/repo", values)
            self.assertEqual(run.call_count, 5)
            for call, name in zip(run.call_args_list, setup.SECRET_NAMES):
                self.assertEqual(call.args[0], ["gh", "secret", "set", name, "--repo", "owner/repo"])
                self.assertEqual(call.kwargs["input_data"], b"dummy-value")
        with patch.object(setup, "run", side_effect=[b"", setup.SetupError("private subprocess output")]):
            with self.assertRaisesRegex(setup.SetupError, "1/5 secrets saved"):
                setup.upload_secrets("owner/repo", values)

    def test_prepare_only_creates_material_without_github(self):
        with tempfile.TemporaryDirectory() as root, io.StringIO() as output:
            backup = Path(root) / "backup"
            with contextlib.redirect_stdout(output):
                self.assertEqual(setup.main(["--prepare-only", "--backup-dir", str(backup)]), 0)
            settings = json.loads((backup / "credentials.json").read_text())
            self.assertNotIn(settings["store_password"], output.getvalue())
            self.assertIn("No GitHub secrets were changed", output.getvalue())

    def test_backup_inside_repository_is_rejected(self):
        inside = Path(setup.__file__).resolve().parent / "private-backup"
        with self.assertRaisesRegex(setup.SetupError, "outside"):
            setup.ensure_material(inside)


if __name__ == "__main__":
    unittest.main()
