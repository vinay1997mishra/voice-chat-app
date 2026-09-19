from __future__ import annotations

import base64
import json
import os
import time
from pathlib import Path
from threading import Lock

import jwt
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import FastAPI, Header, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from pydantic import BaseModel, Field

APP = FastAPI(title="Anamika Owner Policy Service", version="2.0")

ADMIN_TOKEN = os.environ.get("ANAMIKA_POLICY_ADMIN_TOKEN", "").strip()
PRIVATE_KEY_PEM = os.environ.get("ANAMIKA_POLICY_PRIVATE_KEY_PEM", "").encode()
GOOGLE_CLIENT_ID = os.environ.get("ANAMIKA_GOOGLE_CLIENT_ID", "").strip()
SESSION_SECRET = os.environ.get("ANAMIKA_SESSION_SECRET", "").strip()
OWNER_BOOTSTRAP_EMAIL = os.environ.get("ANAMIKA_OWNER_BOOTSTRAP_EMAIL", "").strip().lower()
OWNER_GOOGLE_SUB = os.environ.get("ANAMIKA_OWNER_GOOGLE_SUB", "").strip()
STORE = Path(os.environ.get("ANAMIKA_POLICY_STORE", "/tmp/anamika-entitlements.json"))
LOCK = Lock()

BUILTIN_FEATURES = {
    "chat": "Chat",
    "voice_input": "Voice input",
    "voice_reply": "Voice reply",
    "memory": "Memory",
    "search": "Search",
    "internet": "Internet",
    "local_coding": "Local coding",
    "link_analysis": "Link analysis",
    "local_git": "Local Git",
    "github_remote": "GitHub remote",
    "app_study": "App Study",
    "cross_app_control": "Cross-app control",
    "apk_build": "APK build",
    "self_update": "Self update",
}


class EntitlementUpdate(BaseModel):
    features: dict[str, bool] = Field(default_factory=dict)
    expiresAtEpochMs: int | None = None


class GoogleAuthRequest(BaseModel):
    idToken: str = Field(min_length=20)


class OwnerFeatureUpdate(BaseModel):
    ownerEnabled: bool
    userEnabled: bool


class RegisterFeatureRequest(BaseModel):
    key: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=160)


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


def ensure_catalog(data: dict) -> dict:
    catalog = data.setdefault("_catalog", {})
    for key, name in BUILTIN_FEATURES.items():
        catalog.setdefault(
            key,
            {
                "name": name,
                "ownerEnabled": True,
                "userEnabled": False,
                "builtin": True,
            },
        )
    return catalog


def require_admin(authorization: str | None) -> None:
    if not ADMIN_TOKEN:
        raise HTTPException(status_code=503, detail="Admin token is not configured")
    if authorization != f"Bearer {ADMIN_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")


def private_key():
    if not PRIVATE_KEY_PEM:
        raise HTTPException(status_code=503, detail="Owner signing key is not configured")
    return serialization.load_pem_private_key(PRIVATE_KEY_PEM, password=None)


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


def resolve_role(subject: str, email: str) -> str:
    with LOCK:
        data = read_store()
        owner = data.get("_owner", {})
        stored_subject = str(owner.get("subject", "")).strip()

        if OWNER_GOOGLE_SUB and subject == OWNER_GOOGLE_SUB:
            if stored_subject != subject:
                data["_owner"] = {"subject": subject, "email": email}
                write_store(data)
            return "OWNER"

        if stored_subject:
            return "OWNER" if subject == stored_subject else "USER"

        if OWNER_BOOTSTRAP_EMAIL and email.lower() == OWNER_BOOTSTRAP_EMAIL:
            data["_owner"] = {"subject": subject, "email": email}
            write_store(data)
            return "OWNER"

    return "USER"


def issue_session(subject: str, role: str) -> str:
    if not SESSION_SECRET:
        raise HTTPException(status_code=503, detail="Session secret is not configured")
    now = int(time.time())
    return jwt.encode(
        {
            "sub": subject,
            "role": role,
            "iat": now,
            "exp": now + 3600,
        },
        SESSION_SECRET,
        algorithm="HS256",
    )


def require_session(authorization: str | None, owner_only: bool = False) -> dict:
    if not SESSION_SECRET:
        raise HTTPException(status_code=503, detail="Session secret is not configured")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication required")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        claims = jwt.decode(token, SESSION_SECRET, algorithms=["HS256"])
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired session") from exc

    if owner_only and claims.get("role") != "OWNER":
        raise HTTPException(status_code=403, detail="Owner access required")
    return claims


@APP.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "signing_key_configured": bool(PRIVATE_KEY_PEM),
        "admin_token_configured": bool(ADMIN_TOKEN),
        "google_client_id_configured": bool(GOOGLE_CLIENT_ID),
        "session_secret_configured": bool(SESSION_SECRET),
        "owner_bootstrap_configured": bool(OWNER_BOOTSTRAP_EMAIL or OWNER_GOOGLE_SUB),
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

    role = resolve_role(subject, email)
    session_token = issue_session(subject, role)

    return {
        "subject": subject,
        "email": email,
        "displayName": name or None,
        "role": role,
        "sessionToken": session_token,
    }


@APP.get("/entitlements")
def get_entitlement(subject: str) -> dict:
    with LOCK:
        data = read_store()
        catalog = ensure_catalog(data)
        policy = data.get(subject) or data.get("*") or {}

        features = {
            key: bool(item.get("userEnabled", False))
            for key, item in catalog.items()
        }
        for key, value in policy.get("features", {}).items():
            if key in catalog:
                features[key] = bool(value)
        expires = policy.get("expiresAtEpochMs")

    if expires is not None and int(expires) <= int(time.time() * 1000):
        features = {
            key: bool(item.get("userEnabled", False))
            for key, item in catalog.items()
        }

    payload = canonical(subject, expires, features)
    return {
        "subject": subject,
        "features": features,
        "expiresAtEpochMs": expires,
        "signature": sign_payload(payload),
    }


@APP.get("/owner/catalog")
def owner_catalog(authorization: str | None = Header(default=None)) -> dict:
    require_session(authorization, owner_only=True)
    with LOCK:
        data = read_store()
        catalog = ensure_catalog(data)
        write_store(data)
        items = [
            {
                "key": key,
                "name": item.get("name", key),
                "ownerEnabled": bool(item.get("ownerEnabled", False)),
                "userEnabled": bool(item.get("userEnabled", False)),
                "builtin": bool(item.get("builtin", False)),
            }
            for key, item in sorted(catalog.items())
        ]
    return {"features": items}


@APP.put("/owner/catalog/{feature_key}")
def update_owner_feature(
    feature_key: str,
    update: OwnerFeatureUpdate,
    authorization: str | None = Header(default=None),
) -> dict:
    require_session(authorization, owner_only=True)
    with LOCK:
        data = read_store()
        catalog = ensure_catalog(data)
        if feature_key not in catalog:
            raise HTTPException(status_code=404, detail="Unknown feature")
        catalog[feature_key]["ownerEnabled"] = update.ownerEnabled
        catalog[feature_key]["userEnabled"] = update.userEnabled
        write_store(data)
    return {"ok": True, "key": feature_key}


@APP.post("/owner/catalog/register")
def register_owner_feature(
    request: RegisterFeatureRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    require_session(authorization, owner_only=True)
    key = request.key.strip().lower().replace(" ", "_")
    if not key or key.startswith("_"):
        raise HTTPException(status_code=400, detail="Invalid feature key")

    with LOCK:
        data = read_store()
        catalog = ensure_catalog(data)
        catalog.setdefault(
            key,
            {
                "name": request.name.strip(),
                "ownerEnabled": False,
                "userEnabled": False,
                "builtin": False,
            },
        )
        write_store(data)

    return {"ok": True, "key": key}


@APP.put("/admin/entitlements/{subject}")
def set_entitlement(
    subject: str,
    update: EntitlementUpdate,
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)

    with LOCK:
        data = read_store()
        catalog = ensure_catalog(data)
        unknown = set(update.features) - set(catalog)
        if unknown:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown feature keys: {sorted(unknown)}",
            )

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
