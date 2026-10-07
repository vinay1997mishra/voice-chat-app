import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "verify_apk_certificate", Path(__file__).with_name("verify_apk_certificate.py"))
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class ApkSigningTest(unittest.TestCase):
    def test_sdk_signer_formats_match_the_same_release_certificate(self):
        digest = "3b" * 32
        colon = ":".join(["3B"] * 32)
        for prefix in ("Signer #1", "V2 Signer:", "V3 Signer:", "V3.1 Signer:"):
            with self.subTest(prefix=prefix):
                verify.verify(prefix + " certificate SHA-256 digest: " + digest, colon)
        verify.verify("V2 Signer: certificate SHA-256 digest: " + digest
                      + "\nV3 Signer: certificate SHA-256 digest: " + digest, digest)

    def test_missing_different_or_additional_signer_is_rejected(self):
        expected = "ab" * 32
        wrong = "cd" * 32
        for output in ("", "V2 Signer: certificate SHA-1 digest: " + expected,
                       "V2 Signer: certificate SHA-256 digest: " + wrong,
                       "Signer #1 certificate SHA-256 digest: " + expected
                       + "\nSigner #2 certificate SHA-256 digest: " + wrong):
            with self.subTest(output=output), self.assertRaises(ValueError):
                verify.verify(output, expected)

    def test_malformed_expected_fingerprint_is_rejected(self):
        with self.assertRaises(ValueError):
            verify.verify("V2 Signer: certificate SHA-256 digest: " + "ab" * 32, "not-a-digest")


if __name__ == "__main__":
    unittest.main()
