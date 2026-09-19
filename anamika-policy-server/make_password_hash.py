import base64
import getpass
import hashlib
import secrets

password = getpass.getpass("Owner password: ")
confirm = getpass.getpass("Confirm password: ")

if password != confirm:
    raise SystemExit("Passwords do not match")
if len(password) < 10:
    raise SystemExit("Use at least 10 characters")

salt = secrets.token_bytes(16)
derived = hashlib.scrypt(
    password.encode("utf-8"),
    salt=salt,
    n=2**15,
    r=8,
    p=1,
    dklen=32,
)

print(
    "scrypt$32768$8$1$"
    + base64.b64encode(salt).decode("ascii")
    + "$"
    + base64.b64encode(derived).decode("ascii")
)
