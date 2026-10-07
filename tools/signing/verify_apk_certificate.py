"""Check APK signers against the expected release certificate across SDK versions."""
import os
from pathlib import Path
import re
import sys

SIGNER = re.compile(
    r"^(?:Signer #\d+|V\d+(?:\.\d+)? Signer:) certificate SHA-256 digest:\s*([0-9A-Fa-f:]+)\s*$"
)


def normalize(value):
    digest = value.strip().replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Invalid SHA-256 certificate fingerprint.")
    return digest


def verify(output, expected):
    expected = normalize(expected)
    found = {normalize(match.group(1)) for line in output.splitlines()
             if (match := SIGNER.fullmatch(line.strip()))}
    if not found:
        raise ValueError("No supported SHA-256 signer digest found in apksigner output.")
    if found != {expected}:
        raise ValueError("APK signer does not match the configured release certificate.")


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Pass the apksigner output file.")
        verify(Path(sys.argv[1]).read_text(),
               os.environ.get("TINNI_RELEASE_CERT_SHA256", ""))
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print("APK release signing certificate verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
