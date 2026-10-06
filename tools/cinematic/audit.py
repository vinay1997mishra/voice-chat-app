"""Build every scene without rendering, checking real Blender APIs and geometry."""
import json
import runpy
import sys
from pathlib import Path
import bpy
import catalog

catalog.validate()
catalog.flags(catalog.SPECS)
for index, spec in enumerate(catalog.SPECS):
    print(f"Geometry {index+1}/{len(catalog.SPECS)}: {spec['id']}", flush=True)
    sys.argv = ["blender", "--", "--scene", spec["id"], "--geometry-only"]
    try:
        runpy.run_path(str(catalog.HERE / "render.py"), run_name="__main__")
    except SystemExit as error:
        if error.code not in (None, 0):
            raise
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    assert all(len(o.data.vertices) > 0 for o in meshes), "Empty modeled mesh"
    if spec["builder"] == "rocket":
        hull = bpy.data.objects.get("Graphite pressure hull")
        assert hull and hull.parent and "Rocket level" in hull.parent.name
        for frame in (1, 48, 120, 192, 193):
            bpy.context.scene.frame_set(frame)
            assert abs(hull.parent.location.z) < 1e-6, "Rocket lifts before countdown 1"
        bpy.context.scene.frame_set(216)
        assert hull.parent.location.z > 9, "Rocket never completes liftoff"
        for o in meshes:
            if "booster" in o.name.lower() or "mounting bracket" in o.name.lower():
                assert o.parent == hull.parent, "Detached Rocket hardware"
    elif spec["builder"] == "country":
        flag = next(o for o in meshes if "national flag" in o.name)
        assert flag.data.uv_layers and flag.data.shape_keys, "Flag lacks real texture/wind geometry"
    if spec["builder"] not in ("country", "rocket"):
        assert any(m.use_nodes and any(n.type == "BUMP" for n in m.node_tree.nodes)
                   for m in bpy.data.materials if m.users), "Gift lacks detailed physical surface"
    if spec["builder"] == "dragon":
        assert any(o.name.startswith("Muscular dragon chest") for o in meshes)
        assert any(o.name.startswith("Dragon ivory fang") for o in meshes)
        wings = [o for o in meshes if o.name.startswith("Scalloped leathery dragon wing")]
        assert len(wings) == 2 and all(o.parent.animation_data for o in wings)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.data.orphans_purge(do_recursive=True)
print("All 329 real Blender scene graphs verified", flush=True)
