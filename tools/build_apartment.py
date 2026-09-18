"""Build editable Blender scenery and glTF assets. Coordinates below use Godot Y-up."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/models'
SOURCE = ROOT / 'art'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(exist_ok=True)
random.seed(302)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
collisions = []

def xyz(v): return (v[0], -v[2], v[1])
def material(name, color, rough=.7, metal=0, source=None):
    m = bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if source:
        folder=ROOT/'game/assets/materials'/source
        for suffix, socket in [('Color','Base Color'),('Roughness','Roughness')]:
            files=list(folder.glob('*_'+suffix+'.jpg'))
            if files:
                n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(files[0]),check_existing=True)
                if suffix!='Color': n.image.colorspace_settings.name='Non-Color'
                m.node_tree.links.new(n.outputs['Color'],p.inputs[socket])
        files=list(folder.glob('*_NormalGL.jpg'))
        if files:
            n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(files[0]),check_existing=True);n.image.colorspace_settings.name='Non-Color'
            norm=m.node_tree.nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.45
            m.node_tree.links.new(n.outputs['Color'],norm.inputs['Color']);m.node_tree.links.new(norm.outputs['Normal'],p.inputs['Normal'])
    return m

plaster=material('aged_plaster',(.52,.55,.51),.95,source='Plaster001')
floor=material('stone_floor',(.28,.3,.29),.70,source='Terrazzo003')
paint=material('cabinet_paint',(.19,.26,.235),.69)
paint_dark=material('cabinet_edges',(.09,.135,.12),.8)
wood=material('old_wood',(.115,.072,.048),.74)
rubber=material('rubber',(.023,.027,.027),.94)
steel=material('brushed_steel',(.3,.34,.35),.34,.8)
rust=material('oxidized_iron',(.20,.105,.063),.82,.45)
brass=material('old_brass',(.31,.21,.105),.41,.75)
red=material('valve_red',(.32,.067,.045),.56,.25)
ceramic=material('enamel',(.68,.7,.65),.28)
cloth=material('linen',(.43,.42,.36),.99)
plaster_dark=material('stained_plaster',(.23,.245,.22),1)
window=material('window_glass',(.18,.24,.28),.84,0)
window.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.24
window.surface_render_method='DITHERED'
blue=material('enamel_rim',(.04,.08,.13),.4,.25)
lightmat=material('light_diffuser',(.74,.80,.79),.35)
p=lightmat.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.56,.70,.77,1);p.inputs['Emission Strength'].default_value=1.8
tiles=[material('tile_%02d'%i,(.19+i*.004,.275+i*.003,.25+i*.004),.36+i*.012) for i in range(10)]

def finish(o,name,mat):
    o.name=name
    if mat:o.data.materials.append(mat)
    return o

def box(name, pos, size, mat, bevel=.008, solid=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(pos));o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,name,mat)
    # World-scaled UVs keep walls and cabinet surfaces consistent.
    uv=o.data.uv_layers.active
    for face in o.data.polygons:
        normal=face.normal;axis=max(range(3),key=lambda a:abs(normal[a]));axes=[a for a in range(3) if a!=axis]
        for idx in face.loop_indices:
            co=o.data.vertices[o.data.loops[idx].vertex_index].co
            uv.data[idx].uv=(co[axes[0]]*.55,co[axes[1]]*.55)
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    if solid:collisions.append({'pos':list(pos),'size':list(size)})
    return o

def rod(name,a,b,r,mat,verts=16,r2=None):
    aa=Vector(xyz(a));bb=Vector(xyz(b));d=bb-aa
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(aa+bb)/2)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    finish(o,name,mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def tube(name,points,r,mat):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=3;cu.resolution_u=8
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,v in zip(sp.points,points):p.co=(*xyz(v),1)
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);cu.materials.append(mat)
    return o

def ring(name,center,r,thick,mat,axis='y'):
    pts=[]
    for i in range(49):
        a=i*math.tau/48;v=[0,0,0]
        axes={'x':(1,2),'y':(0,2),'z':(0,1)}[axis]
        v[axes[0]]=r*math.cos(a);v[axes[1]]=r*math.sin(a)
        pts.append(tuple(center[j]+v[j] for j in range(3)))
    return tube(name,pts,thick,mat)

def sphere(name,p,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=xyz(p))
    o=bpy.context.object;o.scale=(scale[0],scale[2],scale[1]);finish(o,name,mat)
    for f in o.data.polygons:f.use_smooth=True
    return o

def lathe(name,pos,profile,mat,segments=32):
    verts=[];faces=[]
    for r,h in profile:
        for i in range(segments):
            a=i*math.tau/segments;verts.append(xyz((pos[0]+r*math.cos(a),pos[1]+h,pos[2]+r*math.sin(a))))
    for j in range(len(profile)-1):
        for i in range(segments):
            k=j*segments+i;n=j*segments+(i+1)%segments;faces.append((k,n,n+segments,k+segments))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,mat)
    for f in mesh.polygons:f.use_smooth=True
    return o

def text(name,txt,pos,size,mat,rotation=(90,0,0)):
    cu=bpy.data.curves.new(name,'FONT');cu.body=txt;cu.size=size;cu.extrude=.0004;cu.align_x='CENTER'
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.location=xyz(pos);o.rotation_euler=tuple(math.radians(a) for a in rotation);cu.materials.append(mat)
    return o

# Architecture, kitchen (-3..3), lounge (3..7), corridor (z=1..3).
box('Whole floor',(2,-.10,-1),(10.3,.2,8.3),floor,.015,True)
box('Ceiling',(2,3.24,-1),(10.3,.18,8.3),plaster,0,True)
box('Back wall',(2,1.6,-5.08),(10.3,3.2,.16),plaster,0,True)
box('Right wall',(7.08,1.6,-1),(.16,3.2,8.3),plaster,0,True)
box('Corridor back',(2,1.6,3.08),(10.3,3.2,.16),plaster,0,True)
# Left wall window opening.
box('Window wall lower',(-3.08,.48,-1),(.16,.96,8.3),plaster,0,True)
box('Window wall upper',(-3.08,2.97,-1),(.16,.46,8.3),plaster,0,True)
box('Left wall near',(-3.08,1.84,1.28),(.16,1.76,3.44),plaster,0,True)
box('Left wall far',(-3.08,1.84,-4.61),(.16,1.76,.94),plaster,0,True)
box('Divider rear',(3,1.6,-3.15),(.16,3.2,3.7),plaster,0,True)
box('Divider front',(3,1.6,.65),(.16,3.2,.7),plaster,0,True)
box('Divider header',(3,2.82,-.5),(.16,.76,1.6),plaster,0,True)
for xa,xb in [(-3,-.78),(.78,4.15),(5.7,7)]:
    box('Hall partition',((xa+xb)/2,1.6,1.08),(xb-xa,3.2,.16),plaster,0,True)
for x,w in [(0,1.56),(4.925,1.55)]:box('Door lintel',(x,2.88,1.08),(w,.64,.16),plaster,0,True)
for x in [-.84,.84]:box('302 door jamb',(x,1.23,1.04),(.12,2.46,.24),wood,.012)
box('302 frame top',(0,2.46,1.04),(1.8,.12,.24),wood,.012)
box('302 opened door',(-.83,1.2,.26),(.085,2.36,1.48),wood,.012,True)
rod('Door handle',(-.74,1.05,-.34),(-.60,1.05,-.34),.016,brass)
box('Number plate',(-1.25,1.85,1.19),(.42,.23,.025),paint_dark,.005)
text('302 number','302',(-1.25,1.78,1.215),.15,ceramic,rotation=(90,0,180))
for y in [.10,1.30]:
    box('Skirting rear',(2,y,-4.97),(10,.08,.04),wood,.004)
    box('Skirting hall',(2,y,2.96),(10,.08,.04),paint_dark,.003)

# Individually glazed tiles along the counter and back wall.
for row in range(4):
    for col in range(20):
        box('Glazed backsplash',(-2.982,.17+row*.31,-4.83+col*.3),(.02,.298,.29),random.choice(tiles),.003)
    for col in range(20):
        box('Back tile',(-2.85+col*.30,.17+row*.31,-4.979),(.29,.298,.02),random.choice(tiles),.003)

# Window with sill, seals, metal mullions and exterior silhouettes.
box('Window glass',(-3.10,1.85,-2.73),(.025,1.74,2.8),window,.001)
for z in [-4.15,-2.73,-1.3]:box('Window mullion',(-3.00,1.85,z),(.12,1.85,.055),steel,.005)
for y in [.92,1.87,2.78]:box('Window crossbar',(-3.00,y,-2.73),(.12,.055,2.9),steel,.005)
box('Stone sill',(-2.91,.91,-2.73),(.40,.07,3.02),ceramic,.006)
# Low detail courtyard is visible through rain, giving the window actual depth.
exterior=material('courtyard_concrete',(.28,.32,.34),.95)
exterior_glass=material('courtyard_windows',(.07,.10,.12),.6)
box('Opposite apartment block',(-8,3,-2),(1,12,15),exterior,.03)
for y in [-.7,1.9,4.5,7.1]:
    for z in [-7,-4.4,-1.8,.8,3.4]:
        box('Courtyard window',(-7.47,y,z),(.025,1.4,1.2),exterior_glass,.005)
        box('Courtyard window sill',(-7.37,y-.73,z),(.25,.08,1.35),exterior,.005)
        box('Courtyard window bar',(-7.43,y,z),(.03,1.4,.035),exterior,.002)
    box('Facade seam',(-7.47,y-1.15,-2),(.03,.04,15),plaster_dark,.002)
for i in range(130):
    y=random.uniform(1,2.70);z=random.uniform(-4.08,-1.38)
    rod('Rain on glass',(-2.975,y,z),(-2.975,y-random.uniform(.016,.09),z+.004),random.uniform(.001,.003),steel,6)

# Cabinet carcasses and separate inset doors.
for z in [-4.42,-3.70,-2.98,-2.26,-1.54]:
    box('Cabinet carcass',(-2.58,.44,z),(.78,.83,.7),paint_dark,.012,True)
    box('Cabinet door',(-2.173,.44,z),(.032,.75,.66),paint,.008)
    for yy in [.10,.77]:box('Door rail',(-2.15,yy,z),(.035,.055,.64),paint,.003)
    for zz in [z-.29,z+.29]:box('Door stile',(-2.15,.44,zz),(.035,.64,.05),paint,.003)
    rod('Pull',(-2.11,.69,z-.11),(-2.11,.69,z+.11),.012,brass)
    for k in range(7):
        box('Paint chip',(-2.128,random.uniform(.10,.75),z+random.uniform(-.3,.3)),(.003,random.uniform(.004,.018),random.uniform(.012,.04)),wood,0)
# Worktop with actual sink hole bounded by four solid sections.
for z,size in [(-4.07,1.4),(-1.57,.84)]:box('Stone counter',(-2.54,.9,z),(.93,.075,size),ceramic,.012,True)
for x in [-2.94,-2.12]:box('Sink rim',(x,.92,-2.85),(.11,.055,1.0),steel,.008)
for z in [-3.35,-2.35]:box('Sink rim',(-2.53,.92,z),(.91,.055,.09),steel,.008)
box('Sink bottom',(-2.53,.69,-2.85),(.64,.04,.79),steel,.06)
for x in [-2.85,-2.21]:box('Sink bowl side',(x,.80,-2.85),(.045,.23,.79),steel,.017)
for z in [-3.25,-2.45]:box('Sink bowl end',(-2.53,.80,z),(.64,.23,.045),steel,.017)
rod('Drain',(-2.53,.712,-2.85),(-2.53,.72,-2.85),.048,rubber)
ring('Drain ring',(-2.53,.725,-2.85),.048,.005,steel)
faucet=[(-2.87,.94,-2.83),(-2.87,1.21,-2.83),(-2.82,1.32,-2.83),(-2.66,1.34,-2.83),(-2.57,1.25,-2.83),(-2.57,1.17,-2.83)]
tube('Swan neck tap',faucet,.022,steel)
rod('Tap handle',(-2.86,1.04,-2.67),(-2.70,1.04,-2.67),.017,steel)

# Cup, pan, drying rack, chopping board and linen establish domestic scale.
box('Chopping board',(-2.72,1.10,-4.6),(.06,.40,.30),wood,.035)
lathe('Saucepan',(-2.47,.94,-4.05),[(0,0),(.18,0),(.20,.17),(.18,.18),(.17,.02),(0,.02)],steel)
rod('Pan handle',(-2.29,1.06,-4.05),(-1.95,1.06,-4.05),.034,rubber)
for z in [-1.77,-1.47]:
    for x in [-2.88,-2.2]:rod('Rack leg',(x,.94,z),(x,1.1,z),.006,steel)
for i in range(9):
    z=-1.87+i*.055;tube('Dish rack',[(-2.88,.96,z),(-2.88,1.1,z),(-2.2,1.1,z),(-2.2,.96,z)],.004,steel)
for z in [-1.75,-1.61,-1.47]:
    ring('Plate rim',(-2.53,1.13,z),.14,.009,ceramic,'z')
    rod('Plate face',(-2.53,1.13,z-.008),(-2.53,1.13,z+.008),.137,ceramic,32)
for z in [-3.6,-4.3]:
    box('Upper cabinet',(-2.73,2.40,z),(.53,.66,.66),paint,.01,True)
    rod('Upper handle',(-2.44,2.20,z-.1),(-2.44,2.20,z+.1),.012,brass)
box('Under cabinet light',(-2.47,2.04,-3.97),(.08,.04,1.28),lightmat,.008)
# Hanging towel with a draped mesh.
verts=[];faces=[]
for j in range(17):
    for i in range(9):
        t=j/16;u=i/8
        verts.append(xyz((-2.10+.025*math.sin(u*math.tau*3),.91-t*.43,-3.93+u*.33)))
for j in range(16):
    for i in range(8):a=j*9+i;faces.append((a,a+1,a+10,a+9))
me=bpy.data.meshes.new('Towel mesh');me.from_pydata(verts,[],faces);me.update()
o=bpy.data.objects.new('Hanging towel',me);bpy.context.collection.objects.link(o);finish(o,o.name,cloth)
for z in [-3.1,-2.7]:
    rod('Mug hooks',(-2.94,1.65,z),(-2.86,1.65,z),.01,brass)
# Back wall: hung kitchen implements and small patch repairs.
rod('Wall utensil rail',(-1.5,1.78,-4.9),(.15,1.78,-4.9),.012,brass)
for x in [-1.25,-.79,-.30]:
    rod('Utensil hook',(x,1.8,-4.9),(x,1.72,-4.82),.006,steel)
    rod('Hanging pan handle',(x,1.74,-4.83),(x,1.49,-4.83),.018,steel)
    rod('Hanging pan bowl',(x,1.34,-4.83),(x,1.34,-4.77),.155,steel,40)
    ring('Pan outer lip',(x,1.34,-4.76),.151,.008,steel,'z')
# Stool.
box('Stool seat',(-1.6,.50,-4.35),(.42,.08,.42),wood,.025,True)
for x in [-1.75,-1.45]:
    for z in [-4.5,-4.2]:rod('Stool leg',(x,.04,z),(x,.47,z),.024,wood)

# Recessed service box facing into kitchen. Interactive parts are added in Godot.
box('Service backing',(2.895,1.52,-3.15),(.12,1.90,1.20),paint_dark,.012)
for z in [-3.77,-2.53]:box('Service frame',(2.78,1.52,z),(.24,1.98,.045),steel,.008)
for y in [.53,2.51]:box('Service frame',(2.78,y,-3.15),(.24,.045,1.28),steel,.008)
for z in [-3.48,-2.9]:
    rod('Service pipe',(2.68,.64,z),(2.68,2.45,z),.038,brass)
    for y in [.8,1.25,1.9,2.35]:rod('Pipe coupling',(2.68,y-.035,z),(2.68,y+.035,z),.055,steel,6)
rod('Cross connection',(2.68,1.50,-3.48),(2.68,1.50,-2.90),.038,brass)
rod('Kitchen branch',(2.7,2.65,-4.9),(2.7,2.65,-3.48),.025,steel)
rod('Kitchen branch across',(-2.7,2.65,-4.9),(2.7,2.65,-4.9),.025,steel)
rod('Lounge branch',(2.7,2.65,-2.9),(2.7,2.65,-.6),.025,steel)
for z in [-4.6,-3.9,-2.1,-1.4]:box('Pipe bracket',(2.84,2.65,z),(.20,.05,.07),rust,.003)
box('Service work lamp',(2.67,2.35,-3.17),(.12,.13,.27),brass,.01)
box('Service work diffuser',(2.59,2.35,-3.17),(.025,.08,.21),lightmat,.01)

# Lounge: furniture, radiator, table, cloth sofa, framed wall mark.
box('Lounge rug',(5.1,.014,-2.2),(2.2,.02,2.2),cloth,.01)
box('Sofa base',(6.46,.31,-3.25),(.9,.35,2.4),wood,.035,True)
for z in [-4.1,-3.25,-2.4]:box('Sofa cushion',(6.39,.57,z),(.86,.20,.76),cloth,.075)
box('Sofa back',(6.86,.92,-3.25),(.22,.90,2.4),cloth,.06)
for z in [-4.49,-2.01]:box('Sofa arm',(6.43,.72,z),(.96,.52,.2),cloth,.055)
box('Side table',(4.5,.65,-3.4),(.80,.08,.65),wood,.014,True)
for x in [4.17,4.83]:
    for z in [-3.66,-3.14]:box('Side table leg',(x,.31,z),(.045,.62,.045),wood,.003)
for i in range(12):box('Radiator rib',(4.0+i*.14,.51,-4.79),(.11,.65,.19),ceramic,.04)
box('Lounge picture',(5.5,1.95,-4.93),(.88,.68,.06),wood,.01)
box('Faded picture',(5.5,1.95,-4.89),(.75,.55,.012),plaster_dark,.001)
box('Small book',(4.55,.716,-3.6),(.31,.055,.22),red,.005)

# Corridor work station, records board and printer.
box('Station desk',(-2.0,.78,2.43),(1.55,.08,.6),wood,.008,True)
for x in [-2.65,-1.35]:
    for z in [2.2,2.66]:rod('Desk leg',(x,0,z),(x,.76,z),.025,steel)
box('Printer',(-2.20,.96,2.4),(.56,.29,.39),ceramic,.026)
box('Printer feed',(-2.20,1.01,2.17),(.43,.028,.025),rubber,.003)
box('Printed ticket',(-2.20,.87,2.04),(.34,.008,.37),ceramic,.001)
box('Bulletin board',(-.72,1.65,2.956),(1.28,.98,.05),wood,.008)
box('Building plan',(-.72,1.65,2.918),(1.13,.83,.01),ceramic,.001)
for i in range(3):
    box('Plan floor rule',(-.72,1.43+i*.22,2.906),(.8,.01,.003),paint_dark,0)
text('Floor plan caption','I  /  II  /  III',(-.72,1.95,2.89),.055,paint_dark)
for x in [-1.8,1.6,5.3]:box('Hall light',(x,3.12,2),(.75,.08,.12),lightmat,.008)

# Convert curves and text, apply modifiers, then consolidate static geometry by material.
bpy.ops.object.select_all(action='DESELECT')
for o in list(bpy.context.scene.objects):
    if o.type in {'CURVE','FONT','MESH'}:
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        if o.type!='MESH':bpy.ops.object.convert(target='MESH')
        else:
            for mod in list(o.modifiers):
                try:bpy.ops.object.modifier_apply(modifier=mod.name)
                except Exception:pass
        o.select_set(False)
# Save editable objects before joining, with a reference camera.
bpy.ops.object.camera_add(location=xyz((.8,1.68,.35)))
cam=bpy.context.object;direction=Vector(xyz((-1.1,1.4,-2.8)))-cam.location;cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler();cam.data.lens=24
bpy.context.scene.camera=cam
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'apartment_302.blend'))
groups={}
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':groups.setdefault(o.data.materials[0].name if o.data.materials else 'none',[]).append(o)
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name='Architecture_'+name
bpy.ops.object.select_all(action='SELECT')
if cam:cam.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(OUT/'apartment_302.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)
(OUT/'collision_layout.json').write_text(json.dumps(collisions,indent=2))
print('APARTMENT_BUILD_OK',len(collisions),'collision boxes',len(groups),'material groups')
