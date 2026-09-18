"""Original, editable forged adjustable wrench. Blender 5.x background build."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def xyz(v):return (v[0],-v[2],v[1])
def mat(name,color,rough,metal):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
steel=mat('Forged steel',(.31,.34,.34),.32,.85)
dark=mat('Recessed steel',(.08,.095,.09),.5,.7)
brass=mat('Adjustment screw',(.29,.23,.12),.42,.8)
def finish(o,name,m,bevel=.003):
    o.name=name;o.data.materials.append(m)
    mod=o.modifiers.new('Rounded forged edges','BEVEL');mod.width=bevel;mod.segments=4
    o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o
def profile(name,points,depth,m,z=0,bevel=.003):
    n=len(points);verts=[xyz((x,y,z+d)) for d in [-depth/2,depth/2] for x,y in points]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):j=(i+1)%n;faces.append((i,j,j+n,i+n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,m,bevel)
profile('Forged wrench body',[(-.017,-.135),(-.024,-.10),(-.018,.09),(-.029,.16),(-.071,.196),(-.094,.255),(-.079,.288),(-.059,.295),(-.052,.255),(-.037,.231),(-.006,.216),(.027,.225),(.043,.208),(.033,.180),(.018,.143),(.014,.06),(.022,-.108),(.014,-.135)],.023,steel)
profile('Sliding jaw',[(.003,.23),(.031,.224),(.057,.241),(.068,.280),(.052,.288),(.034,.258),(.006,.251)],.025,steel)
profile('Handle recess',[(-.010,-.102),(-.008,.08),(.003,.098),(.008,.068),(.011,-.100),(.003,-.115)],.002,dark,.013,.002)
profile('Jaw contact face',[(-.052,.253),(-.037,.231),(-.031,.230),(-.046,.256)],.026,dark,0,.0007)
def cylinder(name,a,b,r,m):
    aa=Vector(xyz(a));bb=Vector(xyz(b));d=bb-aa
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=d.length,location=(aa+bb)/2)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(o,name,m,.0008)
cylinder('Thumb adjustment screw',(-.015,.196,.005),(.022,.196,.005),.012,brass)
for i in range(10):
    x=-.013+i*.0036;cylinder('Screw ridges',(x,.196,.005),(x+.001,.196,.005),.013,steel)
cu=bpy.data.curves.new('Forging mark','FONT');cu.body='302';cu.size=.012;cu.extrude=.00025;cu.align_x='CENTER'
o=bpy.data.objects.new('Forging mark',cu);bpy.context.collection.objects.link(o);o.location=xyz((0,.135,.0125));o.rotation_euler=(math.pi/2,0,0);cu.materials.append(dark)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/maintenance_tools.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/models/wrench.glb'),export_format='GLB',use_selection=True)
print('MAINTENANCE_TOOL_BUILD_OK')
