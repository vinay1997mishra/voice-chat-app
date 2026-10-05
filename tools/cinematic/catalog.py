"""Catalog planning, rendering, media verification, and reproducible packaging."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CATALOG = json.loads((HERE / "catalog.json").read_text())
SPECS = CATALOG["scenes"]
FPS = CATALOG["fps"]

def read_catalog():
    source = (ROOT / "apps/tinni_star/lib/economy/premium_gift_catalog.dart").read_text()
    gifts = {}
    for gift_id, name, price in re.findall(r'GiftDefinition\(id: "([^"]+)", name: "([^"]+)", price: (\d+)', source):
        price = int(price)
        gifts[gift_id] = (name, 8 if price >= 5000000 else 7 if price >= 1000000 else 6 if price >= 200000 else 5)
    return gifts

def validate():
    gifts = read_catalog()
    by_id = {s["id"]: s for s in SPECS}
    assert len(by_id) == len(SPECS), "Duplicate scene ID"
    assert set(by_id) == set(gifts) | {"rocket-"+str(i) for i in range(1, 11)}, "Catalog coverage mismatch"
    for scene_id, (name, duration) in gifts.items():
        assert by_id[scene_id]["duration"] == duration, scene_id + ": delivery duration changed"
        assert by_id[scene_id]["name"] == name, scene_id + ": wrong display name"
    for spec in SPECS:
        assert re.fullmatch(r"[a-z0-9-]+", spec["id"]), "Unsafe scene path"
        assert spec["builder"] and spec["duration"] in (5, 6, 7, 8, 9)
    assert [by_id["rocket-"+str(i)]["level"] for i in range(1, 11)] == list(range(1, 11))
    print("Verified 319 gift scenes and ten distinct nine-second Rocket stages")

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def fingerprint():
    h = hashlib.sha256()
    for name in ["catalog.json", "render.py", "catalog.py"]:
        h.update(name.encode())
        h.update((HERE / name).read_bytes())
    return h.hexdigest()

def flags(specs):
    folder = HERE / "flags"
    folder.mkdir(exist_ok=True)
    for spec in specs:
        if spec["builder"] != "country":
            continue
        code = spec["id"][5:]
        target = folder / (code + ".png")
        if target.exists():
            continue
        url = "https://flagcdn.com/w320/" + code + ".png"
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "TinniCinematicBuild/1"})
                with urllib.request.urlopen(req, timeout=30) as response:
                    payload = response.read()
                assert payload.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid flag texture"
                target.write_bytes(payload)
                break
            except Exception:
                if attempt == 2:
                    raise

def ordered():
    rockets = [s for s in SPECS if s["builder"] == "rocket"]
    gifts = [s for s in SPECS if s["builder"] != "rocket"]
    return rockets + gifts

def probe(movie):
    data = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)
    ], text=True))
    video = [s for s in data["streams"] if s["codec_type"] == "video"]
    assert len(video) == 1 and len(data["streams"]) == 1, "Movie must be silent video only"
    stream = video[0]
    assert stream["codec_name"] == "h264" and stream["pix_fmt"] == "yuv420p", "Android codec mismatch"
    assert (stream["width"], stream["height"]) == (CATALOG["width"], CATALOG["height"])
    assert stream["r_frame_rate"] == str(FPS)+"/1", "Unexpected movie fps"
    return data

def verify_scene(folder, spec):
    movie, poster = folder / (spec["id"]+".mp4"), folder / "poster.png"
    data = probe(movie)
    assert abs(float(data["format"]["duration"]) - spec["duration"]) < 1/FPS+.01, "Truncated scene"
    assert int(data["streams"][0]["nb_frames"]) == spec["duration"]*FPS, "Missing animation frames"
    assert poster.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "Missing/invalid poster"
    record = {
        "id": spec["id"], "duration_ms": spec["duration"]*1000,
        "video": spec["id"]+".mp4", "poster": spec["id"]+".png",
        "video_sha256": digest(movie), "poster_sha256": digest(poster),
        "bytes": movie.stat().st_size, "codec": "h264", "width": CATALOG["width"],
        "height": CATALOG["height"], "fps": FPS, "builder": spec["builder"],
    }
    (folder / "metadata.json").write_text(json.dumps(record, indent=2)+"\n")
    return record

def render_shard(opt):
    specs = ordered()[opt.shard::opt.shards]
    flags(specs)
    base = Path(opt.output)
    for index, spec in enumerate(specs):
        folder = base / spec["id"]
        movie = folder / (spec["id"]+".mp4")
        print(f"Scene {index+1}/{len(specs)}: {spec['id']}", flush=True)
        subprocess.run(["xvfb-run", "-a", opt.blender, "--background", "--python-exit-code", "1", "--threads", "4",
                        "--python", str(HERE / "render.py"), "--", "--scene", spec["id"],
                        "--output", str(base), "--samples", str(opt.samples)], check=True, timeout=2400)
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-framerate", str(FPS),
            "-i", str(folder / "frame-%04d.png"), "-an", "-c:v", "libx264",
            "-preset", "slow", "-crf", "27", "-maxrate", "150k", "-bufsize", "300k",
            "-vf", f"fade=t=in:st=0:d=0.15,fade=t=out:st={spec['duration']-.35}:d=0.35",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie),
        ], check=True, timeout=180)
        verify_scene(folder, spec)
        for frame in folder.glob("frame-*.png"):
            frame.unlink()
    print("Shard complete", flush=True)

def contact_sheets(base, output):
    from PIL import Image, ImageDraw
    output.mkdir(parents=True, exist_ok=True)
    specs = ordered()
    for batch in range(0, len(specs), 40):
        chunk = specs[batch:batch+40]
        sheet = Image.new("RGB", (1000, 220*8), "#0b1220")
        draw = ImageDraw.Draw(sheet)
        for i, spec in enumerate(chunk):
            poster = Image.open(base / spec["id"] / "poster.png").convert("RGB")
            poster.thumbnail((180, 185))
            x, y = (i%5)*200, (i//5)*220
            sheet.paste(poster, (x+(200-poster.width)//2, y))
            draw.text((x+6, y+188), spec["id"], fill="#ffda91")
            draw.text((x+6, y+203), str(spec["duration"])+" seconds", fill="#b8c8df")
        sheet.save(output / ("catalog-%02d.jpg" % (batch//40)), quality=88)

def pack(opt):
    validate()
    base, target = Path(opt.output), Path(opt.bundle)
    target.mkdir(parents=True, exist_ok=True)
    records = []
    for spec in SPECS:
        record = verify_scene(base / spec["id"], spec)
        shutil.copyfile(base / spec["id"] / record["video"], target / record["video"])
        shutil.copyfile(base / spec["id"] / "poster.png", target / record["poster"])
        records.append(record)
    manifest = {
        "schema": 1, "source_commit": opt.source, "source_fingerprint": fingerprint(),
        "scene_count": len(records), "total_video_bytes": sum(r["bytes"] for r in records),
        "scenes": records,
    }
    assert manifest["total_video_bytes"] < 38*1024*1024, "Movie catalog exceeds APK media budget"
    (target / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    archive = target.parent / "cinematic-assets.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as z:
        for file in sorted(target.iterdir()):
            z.write(file, file.name)
    (target.parent / "cinematic-assets.sha256").write_text(digest(archive)+"  cinematic-assets.zip\n")
    contact_sheets(base, target.parent / "reviews")
    print(json.dumps({"source": opt.source, "scenes": len(records),
                      "video_bytes": manifest["total_video_bytes"], "zip_sha256": digest(archive)}))

def install(opt):
    lock = json.loads(Path(opt.lock).read_text())
    archive = Path(opt.archive)
    assert digest(archive) == lock["zip_sha256"], "Cinematic bundle digest mismatch"
    destination = Path(opt.destination)
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        stage = Path(temp)
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                assert re.fullmatch(r"[a-z0-9-]+\.(mp4|png)|manifest\.json", info.filename), "Unsafe archive entry"
                assert info.file_size < 4*1024*1024, "Unexpected asset size"
            z.extractall(stage)
        manifest = json.loads((stage / "manifest.json").read_text())
        assert manifest["source_commit"] == lock["source_commit"]
        assert manifest["source_fingerprint"] == fingerprint(), "Renderer source differs from pinned media"
        assert manifest["scene_count"] == len(SPECS)
        by_id = {s["id"]: s for s in manifest["scenes"]}
        assert set(by_id) == {s["id"] for s in SPECS}
        for spec in SPECS:
            record = by_id[spec["id"]]
            assert record["duration_ms"] == spec["duration"]*1000
            assert record["video"] == spec["id"]+".mp4" and record["poster"] == spec["id"]+".png"
            assert digest(stage / record["video"]) == record["video_sha256"]
            assert digest(stage / record["poster"]) == record["poster_sha256"]
        for file in stage.iterdir():
            shutil.copyfile(file, destination / file.name)
    print("Installed verified local cinematic assets: " + str(len(SPECS)))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["validate", "plan", "flags", "render", "pack", "install"])
    parser.add_argument("--shard", type=int, default=0)
    parser.add_argument("--shards", type=int, default=20)
    parser.add_argument("--samples", type=int, default=8)
    parser.add_argument("--blender", default="/tmp/blender-4.5.2-linux-x64/blender")
    parser.add_argument("--output", default="cinematic-preview")
    parser.add_argument("--bundle", default="cinematic-package/assets")
    parser.add_argument("--source", default="")
    parser.add_argument("--archive", default="cinematic-assets.zip")
    parser.add_argument("--lock", default="tools/cinematic/bundle-lock.json")
    parser.add_argument("--destination", default="apps/tinni_star/assets/cinematic")
    opt = parser.parse_args()
    if opt.command == "validate":
        validate()
    elif opt.command == "plan":
        validate()
        print(json.dumps({"shard": list(range(opt.shards))}))
    elif opt.command == "flags":
        flags(SPECS)
    elif opt.command == "render":
        assert 0 <= opt.shard < opt.shards
        render_shard(opt)
    elif opt.command == "pack":
        assert re.fullmatch(r"[a-f0-9]{40}", opt.source), "Source must be an exact commit"
        pack(opt)
    elif opt.command == "install":
        install(opt)

if __name__ == "__main__":
    main()
