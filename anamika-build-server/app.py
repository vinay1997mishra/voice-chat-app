from __future__ import annotations

import os
import shutil
import subprocess
import threading
import time
import uuid
import zipfile
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse

APP = FastAPI(title="Anamika Build Server", version="1.0")

ROOT = Path(os.environ.get("ANAMIKA_BUILD_ROOT", "/tmp/anamika-builds")).resolve()
ROOT.mkdir(parents=True, exist_ok=True)
TOKEN = os.environ.get("ANAMIKA_BUILD_TOKEN", "").strip()
TIMEOUT_SECONDS = int(os.environ.get("ANAMIKA_BUILD_TIMEOUT_SECONDS", "1200"))
MAX_UPLOAD_BYTES = int(os.environ.get("ANAMIKA_MAX_UPLOAD_BYTES", str(250 * 1024 * 1024)))

JOBS: dict[str, "Job"] = {}
LOCK = threading.Lock()


@dataclass
class Job:
    id: str
    status: str
    message: str = ""
    artifact_path: Optional[str] = None
    created_at: float = 0.0
    finished_at: Optional[float] = None

    def public(self) -> dict:
        data = asdict(self)
        data["artifact_ready"] = bool(
            self.artifact_path and Path(self.artifact_path).exists()
        )
        data.pop("artifact_path", None)
        return data


def require_auth(authorization: Optional[str]) -> None:
    if not TOKEN:
        return
    expected = f"Bearer {TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")


def safe_extract(zip_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            candidate = (destination / member.filename).resolve()
            if destination not in candidate.parents and candidate != destination:
                raise ValueError("Unsafe path in zip")
            if member.is_dir():
                candidate.mkdir(parents=True, exist_ok=True)
                continue
            candidate.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as src, candidate.open("wb") as dst:
                shutil.copyfileobj(src, dst)


def find_project_root(extracted: Path) -> Path:
    candidates = [extracted]
    candidates += [p for p in extracted.iterdir() if p.is_dir()]
    for candidate in candidates:
        has_settings = (
            (candidate / "settings.gradle").exists()
            or (candidate / "settings.gradle.kts").exists()
        )
        has_build = (
            (candidate / "build.gradle").exists()
            or (candidate / "build.gradle.kts").exists()
        )
        if has_settings and has_build:
            return candidate
    raise RuntimeError("Android/Gradle project root not found")


def run_build(job_id: str, build_type: str) -> None:
    with LOCK:
        job = JOBS[job_id]
        job.status = "running"
        job.message = "Preparing Android build"

    job_dir = ROOT / job_id
    archive = job_dir / "project.zip"
    extracted = job_dir / "project"
    log_file = job_dir / "build.log"

    try:
        safe_extract(archive, extracted)
        project = find_project_root(extracted)

        if build_type != "debug":
            raise RuntimeError(
                "This reference server enables debug APK builds only. "
                "Production release signing must use a protected server-side keystore."
            )

        commands = [
            ["gradle", "--no-daemon", "testDebugUnitTest"],
            ["gradle", "--no-daemon", "lintDebug"],
            ["gradle", "--no-daemon", "assembleDebug"],
        ]

        env = os.environ.copy()
        env.setdefault("GRADLE_USER_HOME", str(job_dir / ".gradle"))

        with log_file.open("w", encoding="utf-8", errors="replace") as log:
            for command in commands:
                with LOCK:
                    JOBS[job_id].message = "Running " + " ".join(command[2:])

                result = subprocess.run(
                    command,
                    cwd=project,
                    env=env,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    timeout=TIMEOUT_SECONDS,
                    check=False,
                )
                if result.returncode != 0:
                    raise RuntimeError(
                        f"Build step failed with exit code {result.returncode}"
                    )

        apks = list(project.glob("**/build/outputs/apk/debug/*-debug.apk"))
        if not apks:
            raise RuntimeError("Build succeeded but debug APK was not found")

        artifact = job_dir / "Anamika-built.apk"
        shutil.copy2(max(apks, key=lambda p: p.stat().st_mtime), artifact)

        with LOCK:
            job = JOBS[job_id]
            job.status = "succeeded"
            job.message = "APK ready"
            job.artifact_path = str(artifact)
            job.finished_at = time.time()

    except Exception as exc:
        with LOCK:
            job = JOBS[job_id]
            job.status = "failed"
            job.message = str(exc)
            job.finished_at = time.time()


@APP.get("/health")
def health() -> dict:
    return {"ok": True}


@APP.post("/v1/builds")
async def create_build(
    project: UploadFile = File(...),
    build_type: str = Form("debug"),
    authorization: Optional[str] = Header(default=None),
) -> dict:
    require_auth(authorization)

    job_id = uuid.uuid4().hex
    job_dir = ROOT / job_id
    job_dir.mkdir(parents=True, exist_ok=False)
    archive = job_dir / "project.zip"

    total = 0
    with archive.open("wb") as output:
        while True:
            chunk = await project.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_UPLOAD_BYTES:
                shutil.rmtree(job_dir, ignore_errors=True)
                raise HTTPException(status_code=413, detail="Project archive too large")
            output.write(chunk)

    if total == 0:
        shutil.rmtree(job_dir, ignore_errors=True)
        raise HTTPException(status_code=400, detail="Empty project archive")

    try:
        with zipfile.ZipFile(archive) as zf:
            bad = zf.testzip()
            if bad:
                raise ValueError(f"Corrupt zip member: {bad}")
    except Exception as exc:
        shutil.rmtree(job_dir, ignore_errors=True)
        raise HTTPException(status_code=400, detail=f"Invalid zip: {exc}")

    with LOCK:
        JOBS[job_id] = Job(
            id=job_id,
            status="queued",
            message="Build queued",
            created_at=time.time(),
        )

    threading.Thread(
        target=run_build,
        args=(job_id, build_type),
        daemon=True,
    ).start()

    return JOBS[job_id].public()


@APP.get("/v1/builds/{job_id}")
def get_build(
    job_id: str,
    authorization: Optional[str] = Header(default=None),
) -> dict:
    require_auth(authorization)
    with LOCK:
        job = JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Build not found")
        return job.public()


@APP.get("/v1/builds/{job_id}/artifact")
def get_artifact(
    job_id: str,
    authorization: Optional[str] = Header(default=None),
):
    require_auth(authorization)
    with LOCK:
        job = JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Build not found")
        if job.status != "succeeded" or not job.artifact_path:
            raise HTTPException(status_code=409, detail="APK is not ready")
        artifact = Path(job.artifact_path)

    if not artifact.exists():
        raise HTTPException(status_code=410, detail="APK artifact expired")

    return FileResponse(
        artifact,
        media_type="application/vnd.android.package-archive",
        filename="Anamika-built.apk",
    )


@APP.get("/v1/builds/{job_id}/log")
def get_log(
    job_id: str,
    authorization: Optional[str] = Header(default=None),
):
    require_auth(authorization)
    log_file = ROOT / job_id / "build.log"
    if not log_file.exists():
        raise HTTPException(status_code=404, detail="Build log not available")
    return FileResponse(log_file, media_type="text/plain", filename="build.log")
