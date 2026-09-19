from __future__ import annotations

import base64
import json
import os
import time
from pathlib import Path
from threading import Lock

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import FastAPI, Header, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from pydantic import BaseModel, Field

APP = FastAPI(title="Anamika Owner Policy Service", version="1.0")

ADMIN_TOKEN = os.environ.get("ANAMIKA_POLICY_ADMIN_TOKEN", "").strip()
PRIVATE_KEY_PEM = os.environ.get("ANAMIKA_POLICY_PRIVATE_KEY_PEM", "").encode()
GOOGLE_CLIENT_ID = os.environ.get("ANAMIKA_GOOGLE_CLIENT_ID", "").strip()
STORE = Path(os.environ.get("ANAMIKA_POLICY_STORE", "/tmp/anamika-entitlements.json"))
LOCK = Lock()

FEATURE_KEYS = {
    "chat",
    "voice_input",
    "voice_reply",
    "memory",
    "search",
    "internet",
    "local_coding",
    "link_analysis",
    "local_git",
    "github_remote",
    "app_study",
    "cross_app_control",
    "apk_build",
    "self_update",
}


class EntitlementUpdate(BaseModel):
    features: dict[str, bool] = Field(default_factory=dict)
    expiresAtEpochMs: int | None = None


class GoogleAuthRequest(BaseModel):
    idToken: str = Field(min_length=20)


def require_admin(authorization: str | None) -> None:
    if not ADMIN_TOKEN:
        raise HTTPException(status_code=503, detail="Admin token is not configured")
    if authorization != f"Bearer {ADMIN_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")


def private_key():
    if not PRIVATE_KEY_PEM:
        raise HTTPException(status_code=503, detail="Owner signing key is not configured")
    return serialization.load_pem_private_key(PRIVATE_KEY_PEM, password=None)


def read_store() -> dict:
    if not STORE.exists():
        return {}
    try:
        return json.loads(STORE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def write_store(data: dict) -> None:
    STORE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STORE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    tmp.replace(STORE)


def canonical(subject: str, expires: int | None, features: dict[str, bool]) -> bytes:
    lines = [
        f"subject={subject}",
        f"expires={expires if expires is not None else 'none'}",
    ]
    for key in sorted(features):
        lines.append(f"{key}={'true' if features[key] else 'false'}")
    return "\n".join(lines).encode("utf-8")


def sign_payload(payload: bytes) -> str:
    signature = private_key().sign(payload, ec.ECDSA(hashes.SHA256()))
    return base64.b64encode(signature).decode("ascii")


@APP.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "signing_key_configured": bool(PRIVATE_KEY_PEM),
        "admin_token_configured": bool(ADMIN_TOKEN),
        "google_client_id_configured": bool(GOOGLE_CLIENT_ID),
    }



@APP.post("/auth/google")
def auth_google(request: GoogleAuthRequest) -> dict:
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google client ID is not configured")

    try:
        payload = google_id_token.verify_oauth2_token(
            request.idToken,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Google ID token") from exc

    subject = str(payload.get("sub", "")).strip()
    email = str(payload.get("email", "")).strip()
    email_verified = bool(payload.get("email_verified", False))
    name = str(payload.get("name", "")).strip()

    if not subject or not email or not email_verified:
        raise HTTPException(status_code=401, detail="Verified Google account required")

    return {
        "subject": subject,
        "email": email,
        "displayName": name or None,
    }


@APP.get("/entitlements")
def get_entitlement(subject: str) -> dict:
    with LOCK:
        data = read_store()
        policy = data.get(subject) or data.get("*")

    if not policy:
        policy = {"features": {}, "expiresAtEpochMs": None}

    features = {
        key: bool(value)
        for key, value in policy.get("features", {}).items()
        if key in FEATURE_KEYS
    }
    expires = policy.get("expiresAtEpochMs")

    if expires is not None and int(expires) <= int(time.time() * 1000):
        features = {}

    payload = canonical(subject, expires, features)
    return {
        "subject": subject,
        "features": features,
        "expiresAtEpochMs": expires,
        "signature": sign_payload(payload),
    }


@APP.put("/admin/entitlements/{subject}")
def set_entitlement(
    subject: str,
    update: EntitlementUpdate,
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)

    unknown = set(update.features) - FEATURE_KEYS
    if unknown:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown feature keys: {sorted(unknown)}",
        )

    with LOCK:
        data = read_store()
        data[subject] = {
            "features": update.features,
            "expiresAtEpochMs": update.expiresAtEpochMs,
        }
        write_store(data)

    return {"ok": True, "subject": subject}


@APP.delete("/admin/entitlements/{subject}")
def delete_entitlement(
    subject: str,
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)
    with LOCK:
        data = read_store()
        data.pop(subject, None)
        write_store(data)
    return {"ok": True}
