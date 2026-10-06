"""Physical surface finishes and extra modeled detail for every premium gift.
All changes are confined to Normal/CP scenes; national flags and Rocket hardware
retain their verified geometry, textures and timing.
"""
import math
import bpy

TAU = math.tau

def enhance(h):
    spec, root, rng = h["spec"], h["root"], h["rng"]
    scene, builder = h["scene"], h["spec"]["builder"]
    if builder in ("country", "rocket"):
        return
    sphere, tube, box, ring = (h[n] for n in ("sphere", "tube", "box", "ring"))
    cone, mesh, material, key = (h[n] for n in ("cone", "mesh", "material", "key"))
    gold, ivory, black = (h[n] for n in ("gold", "ivory", "black"))
    # Shadows and a neutral key expose the modeled shape without tinting food blue.
    for obj in scene.objects:
        if obj.type == "LIGHT":
            obj.data.use_shadow = True
            if obj.name == "Softbox key":
                obj.data.color = (1, .88, .74)
            elif obj.name == "Front fill":
                obj.data.color = (.72, .84, 1)
                obj.data.energy = 600
    scene.eevee.taa_render_samples = max(h["args"].samples, 16)

    # PBR finishes are shared by objects, keeping the scene and APK compact.
    for mat in list(bpy.data.materials):
        if not mat.use_nodes or not mat.users:
            continue
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        shader = nodes.get("Principled BSDF")
        if not shader:
            continue
        name = mat.name.lower()
        shader.inputs["Coat Weight"].default_value = .18
        shader.inputs["Coat Roughness"].default_value = .16
        rough, scale, depth = .3, 80, .018
        base = tuple(shader.inputs["Base Color"].default_value[:3])
        if any(s in name for s in ("gold", "steel", "graphite")):
            rough, scale, depth = .23, 150, .008
            shader.inputs["Metallic"].default_value = .88
            anisotropy = shader.inputs.get("Anisotropic") or shader.inputs.get("Anisotropic IOR Level")
            if anisotropy is not None:
                anisotropy.default_value = .22
        if any(s in name for s in ("velvet", "living leaves", "animal coat", "hair", "bamboo", "basmati", "saffron")):
            shader.inputs["Metallic"].default_value = 0
            shader.inputs["Coat Weight"].default_value = .03
            rough, scale, depth = .58, 95, .035
            shader.inputs["Sheen Weight"].default_value = .22
        if any(s in name for s in ("porcelain", "ceramic", "quartz", "pearl")):
            rough, scale, depth = .2, 45, .01
            shader.inputs["Subsurface Weight"].default_value = .07
            shader.inputs["Coat Weight"].default_value = .38
        if "skin" in name:
            rough, scale, depth = .48, 120, .016
            shader.inputs["Metallic"].default_value = 0
            shader.inputs["Subsurface Weight"].default_value = .18
            shader.inputs["Subsurface Radius"].default_value = (1, .45, .22)
        if "chocolate" in name or "salmon" in name:
            rough, scale, depth = .22, 24, .018
            shader.inputs["Coat Weight"].default_value = .45
            shader.inputs["Subsurface Weight"].default_value = .12
        if "glass" in name or "ice crystal" in name or "amethyst" in name:
            shader.inputs["Emission Strength"].default_value = .05
            shader.inputs["Metallic"].default_value = .05
            shader.inputs["Transmission Weight"].default_value = .28
            shader.inputs["IOR"].default_value = 1.31 if "ice" in name else 1.65
            shader.inputs["Coat Weight"].default_value = .65
            rough, scale, depth = .11, 45, .008
        if any(s in name for s in ("flame", "hot", "steam")):
            continue
        shader.inputs["Roughness"].default_value = rough
        coords = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 2
        links.new(coords.outputs["Generated"], noise.inputs["Vector"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .24
        bump.inputs["Distance"].default_value = depth
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*(max(0, c*.78) for c in base), 1)
        ramp.color_ramp.elements[1].color = (*(min(1, c*1.06+.015) for c in base), 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])

    def make_surface(name, color, rough=.4, metal=0, noise_scale=35, depth=.02):
        mat = material(name, color, metal, rough)
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        shader = nodes["Principled BSDF"]
        coords = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = noise_scale
        noise.inputs["Detail"].default_value = 3
        links.new(coords.outputs["Generated"], noise.inputs["Vector"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .35
        bump.inputs["Distance"].default_value = depth
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*(c*.6 for c in color), 1)
        ramp.color_ramp.elements[1].color = (*(min(1, c*1.13+.02) for c in color), 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        return mat

    def remove_named(prefixes):
        for obj in list(scene.objects):
            if obj.parent == root and any(obj.name.startswith(n) for n in prefixes):
                bpy.data.objects.remove(obj, do_unlink=True)

    def glass(name, color, ior=1.45):
        mat = material(name, color, .05, .09)
        shader = mat.node_tree.nodes["Principled BSDF"]
        shader.inputs["Transmission Weight"].default_value = .35
        shader.inputs["IOR"].default_value = ior
        shader.inputs["Coat Weight"].default_value = .8
        return mat

    if builder in ("rice", "feast"):
        toasted = make_surface("Roasted saffron and spice", (.72, .24, .035), .48)
        fresh = make_surface("Fresh coriander garnish", (.065, .30, .055), .55)
        grain = next(o for o in scene.objects if o.name.startswith("Basmati grain"))
        for i in range(500):
            a, r = rng.uniform(0, TAU), math.sqrt(rng.random())*.96
            obj = bpy.data.objects.new("Individual long-grain basmati", grain.data)
            bpy.context.collection.objects.link(obj)
            obj.parent = root
            obj.scale = grain.scale.copy()
            obj.location = (r*math.cos(a), r*math.sin(a), .64+.18*(1-r*r)+rng.uniform(.025, .075))
            obj.rotation_euler.z = rng.uniform(0, TAU)
        for i in range(12):
            a, r = i*2.4, .22+.52*rng.random()
            x, y = r*math.cos(a), r*math.sin(a)
            leaf = sphere("Fresh coriander leaf", (x, y, .88), (.10, .046, .008), fresh, root)
            leaf.rotation_euler.z = a
            if i%3 == 0:
                sphere("Roasted spice garnish", (x*.7, y*.7, .89), (.07, .048, .026), toasted, root)
        ring("Hand-painted porcelain foot", .65, (0, 0, .19), gold, root, .018)
    elif builder == "dumplings":
        dough = make_surface("Soft steamed dumpling dough", (.93, .82, .63), .48, depth=.008)
        dough.node_tree.nodes["Principled BSDF"].inputs["Subsurface Weight"].default_value = .2
        for obj in scene.objects:
            if obj.name.startswith(("Pleated dumpling", "Dumpling fold")):
                obj.data.materials.clear()
                obj.data.materials.append(dough)
        bamboo = make_surface("Woven bamboo grain", (.55, .28, .08), .6, noise_scale=18)
        for i in range(32):
            a = i*TAU/32
            slat = box("Steamer vertical bamboo weave", (1.055*math.cos(a), 1.055*math.sin(a), .43),
                       (.025, .07, .4), bamboo, root, .006)
            slat.rotation_euler.z = a
    elif builder == "sushi":
        wasabi = make_surface("Fresh wasabi", (.32, .5, .055), .63)
        ginger = make_surface("Pickled ginger", (.88, .45, .32), .32)
        sphere("Wasabi accompaniment", (1.05, .48, .48), (.14, .14, .10), wasabi, root)
        for i in range(5):
            petal = sphere("Ginger petal", (1.04, -.50+.055*i, .42+.017*i), (.15, .06, .012), ginger, root)
            petal.rotation_euler.z = i*.45
        wood = make_surface("Polished wooden chopsticks", (.3, .1, .035), .24, noise_scale=12)
        for y in [-.87, -.97]:
            tube("Serving chopstick", [(-1.2, y, .42), (1.2, y+.12, .42)], .018, wood, root)
    elif builder == "cake":
        cream = make_surface("Whipped icing", (.95, .88, .74), .37, depth=.008)
        cream.node_tree.nodes["Principled BSDF"].inputs["Subsurface Weight"].default_value = .1
        for r, z in [(1.05, .84), (.78, 1.31), (.48, 1.71)]:
            for i in range(24):
                a = i*TAU/24
                sphere("Piped frosting rosette", (r*.91*math.cos(a), r*.91*math.sin(a), z),
                       (.07, .07, .055), cream, root, 12)

    if builder in ("rice", "feast", "dumplings"):
        remove_named(("Rising steam wisp",))
        mist = material("Transparent rising steam", (.9, .94, 1), 0, 1)
        mist.surface_render_method = "DITHERED"
        shader = mist.node_tree.nodes["Principled BSDF"]
        shader.inputs["Alpha"].default_value = .065
        shader.inputs["Emission Color"].default_value = (.65, .75, .9, 1)
        shader.inputs["Emission Strength"].default_value = .1
        for i in range(12):
            a = i*2.4
            x, y = .55*math.cos(a), .35*math.sin(a)
            obj = sphere("Soft hot food vapor", (x, y, 1+i*.04), (.075, .075, .22), mist, root, 12)
            for f in (1, scene.frame_end//2, scene.frame_end):
                p = f/scene.frame_end
                key(obj, f, "location", (x+.09*math.sin(i+p*TAU), y, 1+i*.04+.38*p))
                key(obj, f, "scale", (.065+.06*p, .065+.06*p, .18+.15*p))

    if builder == "dragon":
        remove_named(("Flight creature body", "Creature head", "Sculpted flight wing",
                      "Creature curling tail", "Crest plume", "Dragon horn", "Dragon fire breath"))
        color = (.09, .4, .7) if "ice" in spec["id"] else (.36, .035, .014) if "fire" in spec["id"] else (.62, .32, .07)
        scales = make_surface("Armored dragon scales", color, .34, .38, 25, .06)
        nodes, links = scales.node_tree.nodes, scales.node_tree.links
        cell = nodes.new("ShaderNodeTexVoronoi")
        cell.feature = "DISTANCE_TO_EDGE"
        cell.inputs["Scale"].default_value = 26
        links.new(nodes.get("Texture Coordinate").outputs["Generated"], cell.inputs["Vector"])
        scale_bump = nodes.new("ShaderNodeBump")
        scale_bump.inputs["Strength"].default_value = .55
        scale_bump.inputs["Distance"].default_value = .055
        links.new(cell.outputs["Distance"], scale_bump.inputs["Height"])
        links.new(scale_bump.outputs["Normal"], nodes["Principled BSDF"].inputs["Normal"])
        membrane = make_surface("Dragon wing membrane", tuple(c*.5 for c in color), .58, .05, 12, .026)
        horn = make_surface("Polished dragon horn", (.72, .60, .39), .28)
        belly = make_surface("Dragon belly plates", tuple(min(1,c*1.5+.12) for c in color), .45)
        sphere("Muscular dragon chest", (0, 0, 1.3), (.36, .42, .69), scales, root, 32)
        sphere("Dragon long neck", (0, -.1, 1.96), (.23, .25, .38), scales, root, 24)
        sphere("Dragon angular skull", (0, -.22, 2.19), (.26, .31, .24), scales, root, 24)
        sphere("Dragon extended muzzle", (0, -.5, 2.13), (.21, .32, .13), scales, root, 24)
        tube("Dragon lower jaw", [(-.17, -.69, 2.05), (0, -.77, 2.04), (.17, -.69, 2.05)], .04, belly, root)
        for side in (-1, 1):
            x = side*.20
            socket = sphere("Dragon eye socket", (x, -.4, 2.23), (.09, .07, .065), black, root)
            eye_mat = h["cyan"] if "ice" in spec["id"] else h["fire"]
            sphere("Luminous dragon iris", (x, -.455, 2.23), (.042, .032, .034), eye_mat, root)
            sphere("Dragon vertical pupil", (x, -.48, 2.23), (.009, .01, .03), black, root, 12)
            tube("Dragon swept brow", [(side*.11, -.46, 2.29), (side*.24, -.40, 2.33),
                                      (side*.29, -.3, 2.28)], .033, scales, root)
            tube("Dragon curved horn", [(side*.17, -.04, 2.35), (side*.23, .03, 2.54),
                                       (side*.31, .16, 2.68)], .055, horn, root)
            for tooth in range(4):
                fang = cone("Dragon ivory fang", .013, 0, .055,
                            (side*.14, -.44-tooth*.055, 2.025), ivory, root, 12)
                fang.rotation_euler.x = math.pi
            tube("Dragon powerful hind limb", [(side*.26, .13, 1.08), (side*.52, .05, .64),
                                               (side*.48, -.23, .32)], .12, scales, root)
            sphere("Dragon clawed foot", (side*.48, -.32, .28), (.16, .23, .08), scales, root)
            tube("Dragon forelimb", [(side*.27, -.05, 1.65), (side*.5, -.3, 1.32),
                                    (side*.38, -.48, 1.21)], .07, scales, root)
            for i in range(3):
                tube("Dragon talon", [(side*.48+(i-1)*.07, -.43, .3),
                                     (side*.48+(i-1)*.07, -.57, .24)], .016, horn, root)
            wing = h["empty"]("Articulated dragon wing")
            wing.parent = root
            wing.location = (side*.25, .14, 1.65)
            verts = [(0,0,0), (side*.42,.1,.68), (side*1.15,.08,.90),
                     (side*1.65,.06,.35), (side*1.2,.03,.18),
                     (side*1.35,0,-.18), (side*.88,-.02,-.08),
                     (side*.70,-.04,-.38), (side*.26,-.02,-.18)]
            mesh("Scalloped leathery dragon wing", verts,
                 [(0, i, i+1) for i in range(1, len(verts)-1)], membrane, wing)
            for tip in (2,3,5,7):
                tube("Dragon wing finger", [verts[0], verts[1], verts[tip]], .025, scales, wing)
            for f in range(1, scene.frame_end+1, 12):
                key(wing, f, "rotation_euler", (.06*math.sin(f*.12), side*.25*math.sin(f*.12), 0))
        tail = tube("Tapered coiling dragon tail", [(0,.24,.84), (.1,.65,.63),
                    (.6,.9,.42), (1.1,.74,.47), (1.37,.55,.73)], .13, scales, root)
        for i,p in enumerate(tail.data.splines[0].bezier_points):
            p.radius = 1-i*.21
        for i in range(9):
            z = .84+i*.16
            cone("Dragon spine armor", .066, 0, .18, (0,.34,z), horn, root, 16)
        for i in range(7):
            sphere("Dragon segmented breastplate", (0,-.375,.95+i*.12),
                   (.24-i*.009,.025,.055), belly, root, 16)
        if "fire" in spec["id"]:
            flame = sphere("Dragon fire jet", (0,-1.15,2.1), (.11,.45,.09), h["fire"], root)
            for f in range(1, scene.frame_end+1, 12):
                key(flame, f, "scale", (.10,.32+.1*math.sin(f*.22),.09))
        if "ice" in spec["id"]:
            frost = glass("Frozen dragon horn", (.25,.64,.93), 1.31)
            for obj in scene.objects:
                if obj.name.startswith(("Dragon curved horn","Dragon spine armor")):
                    obj.data.materials.clear()
                    obj.data.materials.append(frost)

    if builder in ("fountain","heart-fountain","yacht","whale","swan","waterfall","pearl"):
        water = make_surface("Reflective moving water", (.025,.13,.2), .13, .25, 12, .08)
        water.node_tree.nodes["Principled BSDF"].inputs["Coat Weight"].default_value = .8
        pool = cone("Reflective water surface", 2.25,2.25,.035,(0,0,.13),water,root,64)
        ripple_mat = glass("Foamy wake reflection", (.34,.66,.79),1.333)
        for i in range(4):
            obj = ring("Animated water ripple", .65+i*.35,(0,0,.16),ripple_mat,root,.008)
            for f in (1,scene.frame_end//2,scene.frame_end):
                p=f/scene.frame_end
                key(obj,f,"scale",(1+.12*p,1+.12*p,1))
        if builder in ("fountain","heart-fountain"):
            fluid = glass("Clear fountain water",(.20,.52,.7),1.333)
            for obj in scene.objects:
                if obj.name.startswith("Continuous flowing cascade"):
                    obj.data.materials.clear()
                    obj.data.materials.append(fluid)

    if builder in ("tiger","leopard","lion","horse"):
        nose = make_surface("Animal soft nose",(.045,.027,.018),.35)
        sphere("Animal muzzle",(0,-1.075,1.54),(.16,.13,.09),ivory,root,24)
        sphere("Animal nose",(0,-1.185,1.57),(.07,.032,.04),nose,root,16)
        for side in (-1,1):
            for i in range(3):
                tube("Animal whisker",[(side*.055,-1.15,1.52+i*.015),
                     (side*.25,-1.13,1.49+i*.04)],.002,ivory,root)
        if builder == "horse":
            hair=make_surface("Silvery flowing horse mane",(.50,.54,.61),.62)
            for i in range(14):
                tube("Horse mane strand",[(.025*(i%3-1),-.48,1.92),
                     (.08*math.sin(i),-.36,1.6),(.09*math.sin(i),-.21,1.35)],.012,hair,root)

    if builder in ("rose","bouquet","garden","forest"):
        leaf_mat = make_surface("Veined botanical leaf",(.028,.24,.068),.55,noise_scale=26)
        vein_mat = material("Leaf vein",(.17,.34,.10),0,.65)
        for obj in list(scene.objects):
            if obj.name.startswith("Rose leaf"):
                obj.data.materials.clear()
                obj.data.materials.append(leaf_mat)
                x,y,z=obj.location
                tube("Leaf central vein",[(x-.16,y-.01,z+.005),(x+.17,y-.01,z+.005)],.003,vein_mat,root)
        if builder in ("garden","forest"):
            bark=make_surface("Tree bark and garden soil",(.19,.09,.033),.85,noise_scale=18,depth=.05)
            cone("Living garden ground",1.5,1.5,.05,(0,0,.15),bark,root,64)
            for i in range(48):
                a,r=i*2.4,.3+1.1*rng.random()
                x,y=r*math.cos(a),r*math.sin(a)
                tube("Garden grass blade",[(x,y,.19),(x+.05,y,.28),(x+.075,y,.34)],
                     .006,leaf_mat,root)
            for obj in scene.objects:
                if obj.name.startswith("Forest tree trunk"):
                    obj.data.materials.clear()
                    obj.data.materials.append(bark)

    if builder in ("car","carriage"):
        chrome=glass("Reflective smoked vehicle glass",(.025,.065,.10))
        for obj in scene.objects:
            if obj.name.startswith(("Windshield","Car canopy")):
                obj.data.materials.clear()
                obj.data.materials.append(chrome)
        for side in (-1,1):
            x=side*.70
            for y in (-.62,.62):
                for i in range(10):
                    a=i*TAU/10
                    tube("Machined alloy wheel spoke",[(x,y,.4),
                         (x,y+.18*math.cos(a),.4+.18*math.sin(a))],.012,gold,root)
            tube("Coachwork door seam",[(side*.608,-.4,.62),(side*.608,.46,.62),
                 (side*.608,.46,.82)],.006,black,root)
            box("Polished door handle",(side*.62,.28,.83),(.015,.15,.025),gold,root,.005)
    elif builder in ("jet","shuttle"):
        for x in (-.6,.6):
            intake=ring("Turbine intake collar",.145,(x,.0,.9),h["silver"],root,.012)
            intake.rotation_euler.x=math.pi/2
            for i in range(8):
                a=i*TAU/8
                tube("Engine fan blade",[(x,0,.9),(x+.13*math.cos(a),0,.9+.13*math.sin(a))],
                     .008,h["silver"],root)
    elif builder == "yacht":
        teak=make_surface("Natural yacht teak",(.38,.19,.065),.48,noise_scale=18)
        for i in range(11):
            box("Teak deck plank",(i*.1-.5,-.77,.969),(.08,.87,.02),teak,root,.004)
        for side in (-1,1):
            tube("Stainless yacht safety rail",[(side*.57,-1.2,1.07),(side*.57,.95,1.07)],
                 .016,h["silver"],root)

    if builder in ("castle","palace","temple"):
        marble=make_surface("Veined architectural marble",(.72,.72,.65),.32,noise_scale=6,depth=.007)
        for obj in scene.objects:
            if obj.name.startswith(("Marble foundation","Palace hall","Palace tower")):
                obj.data.materials.clear()
                obj.data.materials.append(marble)
        for x in (-.51,.51):
            for dz in (-.085,0,.085):
                box("Architectural window mullion",(x,-.383,1+dz),(.19,.014,.01),gold,root,.002)
            box("Architectural vertical mullion",(x,-.383,1),(.01,.014,.28),gold,root,.002)
        for z in (.35,1.43):
            box("Hand-carved palace cornice",(0,.22,z),(1.5,1.22,.035),gold,root,.01)
        for i in range(4):
            box("Palace entrance step",(0,-.69-i*.11,.22-i*.025),(.78+i*.1,.20,.05),
                marble,root,.01)

    # Fine facets, glossy jewelry and silk rather than emissive plastic.
    if builder in ("jewel","ring","crown","pearl"):
        jewel=glass("Cut optical gemstone",(.045,.38,.66),2.42)
        if "emerald" in spec["id"]:
            jewel=glass("Cut emerald gemstone",(.025,.44,.13),1.58)
        for obj in scene.objects:
            if obj.name.startswith(("Cut gemstone","Ring shoulder diamond")):
                obj.data.materials.clear()
                obj.data.materials.append(jewel)
        if builder == "pearl":
            pearl=make_surface("Iridescent ocean pearl",(.85,.81,.70),.16,noise_scale=42,depth=.004)
            shader=pearl.node_tree.nodes["Principled BSDF"]
            shader.inputs["Coat Weight"].default_value=.8
            shader.inputs["Coat IOR"].default_value=1.5
            shader.inputs["Sheen Weight"].default_value=.28
            for obj in scene.objects:
                if obj.name.startswith("Ocean pearl"):
                    obj.data.materials.clear()
                    obj.data.materials.append(pearl)

    # Keep the artistic CP sculptures, with actual fabric and warm skin finishes.
    for obj in scene.objects:
        if obj.name.startswith("Partner eye"):
            obj.data.materials.clear()
            obj.data.materials.append(glass("Glossy eye",(.012,.018,.025),1.38))
        if obj.name.startswith(("Sculpted flight wing","Scalloped leathery dragon wing")):
            if not any(mod.type=="SOLIDIFY" for mod in obj.modifiers):
                mod=obj.modifiers.new("Physical wing thickness","SOLIDIFY")
                mod.thickness=.008
