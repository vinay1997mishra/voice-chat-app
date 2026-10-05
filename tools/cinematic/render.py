"""Original animated 3D geometry prototypes; Blender 4.5."""
import argparse, math, random, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser()
p.add_argument("--scene",required=True)
p.add_argument("--output",default="cinematic-preview")
opt=p.parse_args(sys.argv[sys.argv.index("--")+1:])
random.seed(73)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
s=bpy.context.scene
s.render.engine="BLENDER_EEVEE_NEXT"
s.render.resolution_x=480
s.render.resolution_y=854
s.render.resolution_percentage=100
s.render.fps=24
s.render.image_settings.file_format="PNG"
s.world.color=(.008,.012,.022)
s.view_settings.view_transform="AgX"
out=Path(opt.output)/opt.scene
out.mkdir(parents=True,exist_ok=True)
def mat(name,c,metal=0,rough=.3,emit=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 b=m.node_tree.nodes.get("Principled BSDF")
 b.inputs["Base Color"].default_value=(*c,1)
 b.inputs["Metallic"].default_value=metal
 b.inputs["Roughness"].default_value=rough
 if emit:
  b.inputs["Emission Color"].default_value=(*c,1)
  b.inputs["Emission Strength"].default_value=emit
 return m
black=mat("Brushed black titanium",(.018,.023,.03),.85,.22)
gold=mat("Machined warm gold",(.8,.46,.13),.82,.2)
silver=mat("Polished steel",(.45,.5,.55),.88,.18)
cyan=mat("Cyan running lights",(.03,.6,1),.2,.16,6)
fire=mat("Amber exhaust",(1,.23,.03),.1,.3,5)
core=mat("White hot exhaust",(1,.85,.48),.1,.2,12)
red=mat("Velvet rose petals",(.34,.008,.025),.05,.36)
green=mat("Living leaf",(.025,.15,.045),.05,.4)
ceramic=mat("Glazed porcelain",(.87,.82,.69),.1,.19)
def finish(o,m,parent=None):
 o.data.materials.append(m)
 if parent:o.parent=parent
 for poly in o.data.polygons:poly.use_smooth=True
 return o
def cone(name,r1,r2,d,loc,m,parent=None):
 bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=r1,radius2=r2,depth=d,location=loc)
 o=bpy.context.object;o.name=name
 return finish(o,m,parent)
def sphere(name,loc,scale,m,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale
 return finish(o,m,parent)
def box(name,loc,scale,m,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale
 b=o.modifiers.new("Machined edges","BEVEL");b.width=.06;b.segments=3
 o.modifiers.new("Weighted normals","WEIGHTED_NORMAL")
 return finish(o,m,parent)
def ring(name,r,z,m,parent=None,thickness=.025):
 bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=12,major_radius=r,minor_radius=thickness,location=(0,0,z))
 o=bpy.context.object;o.name=name
 return finish(o,m,parent)
def key(o,f,prop,value):
 setattr(o,prop,value);o.keyframe_insert(data_path=prop,frame=f)
def aim(o,target):return (Vector(target)-o.location).to_track_quat("-Z","Y").to_euler()
for name,loc,power,color,size in [
 ("Cinematic key",(4,-5,8),1600,(.75,.85,1),5),
 ("Gold rim",(-4,1,6),1900,(1,.63,.23),4),
 ("Soft front",(0,-6,3),650,(.4,.6,1),4)]:
 bpy.ops.object.light_add(type="AREA",location=loc)
 o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.size=size;o.rotation_euler=aim(o,(0,0,2))
bpy.ops.object.camera_add(location=(8,-14,7))
camera=bpy.context.object;s.camera=camera;camera.data.lens=48;camera.rotation_euler=aim(camera,(0,0,2.5))
cone("Reflective stage",10,10,.1,(0,0,-.2),mat("Dark stage",(.015,.022,.03),.55,.24))
def plume(parent,x,y,z,r):
 for material,length,width in [(fire,2.3,1),(core,1.1,.4)]:
  o=cone("Animated shaped exhaust",0,r*width,length,(x,y,z-length/2),material,parent)
  for f,amp in [(1,.001),(24,.001),(36,.45),(48,1),(72,1.25),(108,1.4),(144,1.2),(180,1.5),(216,1.4)]:
   key(o,f,"scale",(1,1,amp))
def rocket(level):
 bpy.ops.object.empty_add();root=bpy.context.object;root.name="Single integrated black Rocket"
 cone("Black pressure hull",.43,.43,3.2,(0,0,2.2),black,root)
 cone("Black aerodynamic nose",.43,0,1.1,(0,0,4.35),black,root)
 for z in [.65,1.1,2,3,3.65]:ring("Gold structural collar",.437,z,gold,root)
 for a in [0,math.pi/2,math.pi,3*math.pi/2]:
  o=box("Attached stabilizer",(.57*math.cos(a),.57*math.sin(a),.95),(.16,.65,.75),black,root);o.rotation_euler.z=a
 for z in [1.5,2.5,3.2]:sphere("Cyan porthole",(0,-.425,z),(.09,.03,.09),cyan,root)
 for i in range(level-1):
  a=2*math.pi*i/max(1,level-1);radius=.72 if level<6 else .93
  x,y=radius*math.cos(a),radius*math.sin(a);d=1.6+level*.08;r=.16+level*.01
  cone("Attached heavy booster",r,r,d,(x,y,1.25+d/2),black,root)
  cone("Booster nose",r,0,.5,(x,y,1.5+d),gold,root)
  box("Integral mounting bracket",(x*.6,y*.6,2),(.24,.24,.18),silver,root)
  plume(root,x,y,1,.15)
 if level>=3:
  for z in [1.3,1.7,2.1]:ring("Armoured band",.46,z,silver if level<5 else gold,root,.055)
 if level>=5:
  for i in range(level):
   a=i*2*math.pi/level
   o=box("Attached black outer armour",(.48*math.cos(a),.48*math.sin(a),2.7),(.14,.21,.7+level*.06),black,root);o.rotation_euler.z=a
 if level>=7:
  for z in [2.2,2.6,3]:ring("Cyan plasma cage",.57,z,cyan,root)
 cone("Bell nozzle",.28,.19,.5,(0,0,.45),silver,root);plume(root,0,0,.22,.3)
 for f,z in [(1,0),(24,0),(42,.08),(66,.32),(96,.8),(132,1.8),(168,3.5),(192,5.3),(216,8.2)]:
  key(root,f,"location",(0,0,z))
 for f,z in [(1,2.5),(66,2.65),(132,3.8),(216,8)]:key(camera,f,"rotation_euler",aim(camera,(0,0,z)))
 colors=[(.9,.03,.12),(.03,.6,.9),(.9,.6,.04),(.25,.04,.7),(.02,.7,.3)]
 for i in range(35):
  x,y=random.uniform(-2.2,2.2),random.uniform(-1,1)
  o=box("Falling celebration box",(x,y,8),(.16,.16,.16),mat("Gift box "+str(i),colors[i%5],.35,.25))
  for f,z in [(1,-5),(48+i,9),(110+i,-.4),(216,-.5)]:
   key(o,f,"location",(x,y,z));key(o,f,"rotation_euler",(f*.025,f*.03,f*.02))
 return 9
def petal(center,radius,angle,parent):
 vertices=[];faces=[];nu,nv=10,8
 for u in range(nu+1):
  t=u/nu
  for v in range(nv+1):
   w=(v/nv-.5)*1.9;r=radius*(.35+.65*t);a=angle+w*math.sin(t*math.pi*.75)
   vertices.append((center[0]+r*math.cos(a),center[1]+r*math.sin(a),center[2]+.08+.3*t-.25*t*t+.08*w*w))
 for u in range(nu):
  for v in range(nv):
   a=u*(nv+1)+v;faces.append((a,a+1,a+nv+2,a+nv+1))
 mesh=bpy.data.meshes.new("Real curved petal");mesh.from_pydata(vertices,[],faces);mesh.update()
 o=bpy.data.objects.new("Velvet rose petal",mesh);bpy.context.collection.objects.link(o);finish(o,red,parent)
 m=o.modifiers.new("Petal thickness","SOLIDIFY");m.thickness=.005
def bouquet():
 bpy.ops.object.empty_add();root=bpy.context.object
 for i in range(12):
  a=i*2.39996;r=.19*math.sqrt(i);x,y=r*math.cos(a),r*math.sin(a)
  cone("Green rose stem",.018,.014,1.7,(x*.65,y*.65,1),green,root)
  for layer in range(4):
   n=5+layer*2
   for j in range(n):petal((x,y,1.7+.05*layer),.09+layer*.065,j*2*math.pi/n+layer*.35,root)
  for z in [.65,1.1]:sphere("Rose leaf",(x+.14,y,z),(.2,.035,.06),green,root)
 cone("Gold bouquet sleeve",.16,.6,.8,(0,0,.8),gold,root)
 for f,a in [(1,-.22),(48,0),(120,.23)]:key(root,f,"rotation_euler",(0,0,a))
 camera.location=(4,-7,4);camera.rotation_euler=aim(camera,(0,0,1.35));camera.data.lens=62
 return 5
def food():
 cone("Porcelain serving bowl",.8,1.2,.55,(0,0,.4),ceramic)
 ring("Gold bowl rim",1.19,.68,gold,thickness=.045)
 rice=mat("Saffron rice",(.82,.59,.23),0,.55);white=mat("Basmati rice",(.88,.82,.59),0,.57)
 spice=mat("Roasted garnish",(.26,.065,.015),0,.45)
 for i in range(650):
  a=random.uniform(0,math.tau);r=math.sqrt(random.random())*1.06;z=.65+.2*(1-r*r)+random.uniform(0,.09)
  o=sphere("Individual rice grain",(r*math.cos(a),r*math.sin(a),z),(.07,.018,.014),rice if i%3==0 else white);o.rotation_euler.z=random.uniform(0,math.tau)
 for i in range(15):
  a=random.uniform(0,math.tau);r=random.uniform(.2,.9)
  sphere("Roasted garnish",(r*math.cos(a),r*math.sin(a),.86),(.12,.07,.04),spice)
 steam=bpy.data.materials.new("Drifting lit volume steam");steam.use_nodes=True
 n=steam.node_tree.nodes;n.clear();output=n.new("ShaderNodeOutputMaterial");volume=n.new("ShaderNodeVolumePrincipled")
 volume.inputs["Density"].default_value=.07;volume.inputs["Color"].default_value=(.9,.94,1,1)
 steam.node_tree.links.new(volume.outputs["Volume"],output.inputs["Volume"])
 for i in range(16):
  x,y=random.uniform(-.55,.55),random.uniform(-.3,.3)
  o=sphere("Moving steam curl",(x,y,.9),(.1,.08,.15),steam)
  for f in [1,48,96,120]:
   t=((f+i*11)%120)/120
   key(o,f,"location",(x+.18*math.sin(t*6),y,1+t*1.8));key(o,f,"scale",(.08+t*.22,.08+t*.15,.15+t*.28))
 camera.location=(4,-6,4.6);camera.rotation_euler=aim(camera,(0,0,1));camera.data.lens=58
 return 5
if opt.scene.startswith("rocket-"):duration=rocket(int(opt.scene.split("-")[1]))
elif opt.scene=="rose-bouquet":duration=bouquet()
elif opt.scene=="hot-biryani":duration=food()
else:raise ValueError("Cinematic scene not implemented: "+opt.scene)
s.frame_start=1;s.frame_end=duration*s.render.fps
s.frame_set(60);s.render.filepath=str(out/"poster.png")
bpy.ops.render.render(write_still=True)
s.render.filepath=str(out/"frame-")
bpy.ops.render.render(animation=True)
