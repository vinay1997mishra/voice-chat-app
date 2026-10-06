"""Behavior checks for catalog coverage and tamper-proof APK installation."""
import hashlib
import json
import tempfile
import types
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch
import catalog

class CatalogTests(unittest.TestCase):
    def test_all_catalog_gifts_have_their_own_scene_and_exact_delivery_duration(self):
        catalog.validate()
        self.assertEqual(len(catalog.SPECS), 329)
        self.assertEqual(sum(s["builder"] == "country" for s in catalog.SPECS), 249)

    def test_country_flags_have_exact_two_second_movies(self):
        self.assertTrue(all(s["duration"] == 2 for s in catalog.SPECS if s["builder"] == "country"))

    def test_sharding_never_loses_or_duplicates_a_scene(self):
        shards = [catalog.ordered()[i::20] for i in range(20)]
        flattened = [s["id"] for shard in shards for s in shard]
        self.assertEqual(len(flattened), len(set(flattened)))
        self.assertEqual(set(flattened), {s["id"] for s in catalog.SPECS})

    def test_install_rejects_tampered_media_and_zip_path_traversal(self):
        spec = {"id": "rose", "duration": 5}
        movie, poster = b"original movie", b"original poster"
        manifest = {
            "source_commit": "a"*40, "source_fingerprint": catalog.fingerprint(),
            "scene_count": 1, "scenes": [{
                "id": "rose", "duration_ms": 5000, "video": "rose.mp4", "poster": "rose.png",
                "video_sha256": hashlib.sha256(movie).hexdigest(),
                "poster_sha256": hashlib.sha256(poster).hexdigest(),
            }],
        }
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            archive, lock = base/"bundle.zip", base/"lock.json"
            opt = types.SimpleNamespace(lock=str(lock), archive=str(archive), destination=str(base/"assets"))
            def write_bundle(payload=movie, path="rose.mp4"):
                with zipfile.ZipFile(archive, "w") as z:
                    z.writestr(path, payload)
                    z.writestr("rose.png", poster)
                    z.writestr("manifest.json", json.dumps(manifest))
                lock.write_text(json.dumps({"source_commit": "a"*40, "zip_sha256": catalog.digest(archive)}))
            with patch.object(catalog, "SPECS", [spec]):
                write_bundle()
                catalog.install(opt)
                self.assertEqual((base/"assets/rose.mp4").read_bytes(), movie)
                write_bundle(b"tampered movie")
                with self.assertRaises(AssertionError):
                    catalog.install(opt)
                write_bundle(path="../outside.mp4")
                with self.assertRaisesRegex(AssertionError, "Unsafe archive"):
                    catalog.install(opt)
                write_bundle()
                archive.write_bytes(archive.read_bytes()+b"changed")
                with self.assertRaisesRegex(AssertionError, "digest mismatch"):
                    catalog.install(opt)


    def test_reuse_retains_only_unchanged_flags_and_rocket_movies(self):
        specs = [{"id":"flag-in","builder":"country","duration":2},
                 {"id":"rose","builder":"rose","duration":5},
                 {"id":"rocket-1","builder":"rocket","duration":9}]
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp)
            archive, lock=base/"bundle.zip", base/"lock.json"
            records=[]
            with zipfile.ZipFile(archive,"w") as z:
                for spec in specs:
                    record={"id":spec["id"],"builder":spec["builder"],
                            "duration_ms":spec["duration"]*1000}
                    for key,ext in (("video",".mp4"),("poster",".png")):
                        data=(spec["id"]+key).encode()
                        name=spec["id"]+ext
                        record[key]=name
                        record[key+"_sha256"]=hashlib.sha256(data).hexdigest()
                        z.writestr(name,data)
                    records.append(record)
                z.writestr("manifest.json",json.dumps({
                    "source_commit":"a"*40,"source_fingerprint":"original","scenes":records}))
            lock.write_text(json.dumps({"source_commit":"a"*40,
                "source_fingerprint":"original","zip_sha256":catalog.digest(archive)}))
            opt=types.SimpleNamespace(lock=str(lock),archive=str(archive),output=str(base/"out"))
            with patch.object(catalog,"SPECS",specs), patch.object(catalog,"verify_scene",
                    side_effect=lambda folder,spec:{"id":spec["id"]}) as verify:
                catalog.reuse(opt)
                self.assertEqual(verify.call_count,2)
                self.assertTrue((base/"out/flag-in/flag-in.mp4").is_file())
                self.assertTrue((base/"out/rocket-1/rocket-1.mp4").is_file())
                self.assertFalse((base/"out/rose").exists())
                self.assertEqual(json.loads((base/"out/flag-in/metadata.json").read_text())
                                 ["reused_from_commit"],"a"*40)
                archive.write_bytes(archive.read_bytes()+b"tampered")
                with self.assertRaisesRegex(AssertionError,"digest mismatch"):
                    catalog.reuse(opt)

if __name__ == "__main__":
    unittest.main()
