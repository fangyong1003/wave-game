"""Original, editable first street block. Godot Y-up; no downloaded assets.
Run with Blender --background --python tools/build_district.py.
The existing CC0 plaster/terrazzo textures retain their recorded attribution.
"""
import ast, bpy, json, math, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/survival'
collisions = []
tree = ast.parse((ROOT / 'tools/build_apartment.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)], type_ignores=[]), '<geometry helpers>', 'exec'))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(916)
plaster = material('district_plaster', (.48,.51,.47), .94, source='Plaster001')
concrete = material('district_concrete', (.25,.28,.27), .9, source='Plaster001')
asphalt = material('district_asphalt', (.13,.16,.17), .72)
tile = material('district_tile', (.37,.40,.37), .8, source='Terrazzo003')
green = material('district_paint', (.13,.23,.20), .83)
rust = material('district_rust', (.29,.14,.09), .88, .2)
metal = material('district_metal', (.24,.28,.28), .56, .65)
dark = material('district_dark', (.027,.043,.049), .83)
glass = material('district_glass', (.095,.17,.20), .23, .28)
paper = material('district_cardboard', (.46,.40,.28), .98)
white = material('district_marking', (.61,.61,.51), .92)
red = material('district_red', (.35,.075,.055), .87)
cloth = material('district_canvas', (.23,.28,.25), .96)
puddle = material('district_water', (.14,.20,.22), .13, .15)
lamp = material('district_lamp', (.78,.67,.44), .4)
p = lamp.node_tree.nodes.get('Principled BSDF')
p.inputs['Emission Color'].default_value = (.8,.53,.25,1); p.inputs['Emission Strength'].default_value = 2

def wall(name, pos, size, mat=plaster): return box(name, pos, size, mat, .015, True)
def carton(name, x, y, z, w=.7, h=.6, d=.6, mat=paper):
    box(name, (x,y,z), (w,h,d), mat, .025)
    box(name+' strap', (x,y+h/2+.008,z), (.09,.016,d+.02), white, .002)
    for xx in [x-w*.34,x+w*.34]: box(name+' latch',(xx,y,z+d/2+.016),(.035,h*.27,.022),metal,.003)

def frontage(name, x0, x1, z, door_x, width=2.0, mat=plaster):
    for a,b in [(x0,door_x-width/2),(door_x+width/2,x1)]:
        if b>a: wall(name+' pier',((a+b)/2,1.65,z),(b-a,3.3,.22),mat)
    wall(name+' lintel',(door_x,2.94,z),(width,.72,.22),mat)
    for x in [door_x-width/2,door_x+width/2]: box(name+' frame',(x,1.25,z),(.09,2.5,.29),metal,.012)

def shop(name,x0,x1,z0,z1,entry,back):
    # All gameplay surfaces meet the street at Y=0: no invisible steps at doorways.
    box(name+' floor',((x0+x1)/2,.006,(z0+z1)/2),(x1-x0,.012,z1-z0),tile,0)
    wall(name+' left',(x0,1.65,(z0+z1)/2),(.22,3.3,z1-z0))
    wall(name+' right',(x1,1.65,(z0+z1)/2),(.22,3.3,z1-z0))
    frontage(name+' front',x0,x1,z1,entry)
    frontage(name+' rear',x0,x1,z0,back)
    box(name+' roof',((x0+x1)/2,3.4,(z0+z1)/2),(x1-x0+.6,.25,z1-z0+.6),concrete,.035)
    box(name+' fascia',((x0+x1)/2,2.95,z1+.16),(x1-x0-.4,.52,.12),green,.018)
    for z,face in [(z1,1),(z0,-1)]:
        box(name+' damp footing',((x0+x1)/2,.23,z+face*.13),(x1-x0,.45,.045),concrete,.006)
        box(name+' cornice',((x0+x1)/2,3.22,z+face*.14),(x1-x0+.12,.10,.24),metal,.01)
    for x in [x0+2.1,x1-2.1]:
        if abs(x-entry)<2.2: continue
        box(name+' display reveal',(x,1.55,z1+.13),(2.5,1.6,.04),dark,.008)
        box(name+' display glass',(x,1.55,z1+.16),(2.30,1.42,.035),glass,.008)
        for xx in [x-1.2,x,x+1.2]: box(name+' window bar',(xx,1.55,z1+.19),(.06,1.57,.06),metal,.004)
        for y in [.77,2.33]: box(name+' window sill',(x,y,z1+.22),(2.55,.065,.18),metal,.008)
        plank=box(name+' boarded lower window',(x,1.03,z1+.27),(2.58,.16,.055),rust,.009)
        plank.rotation_euler.y=.04
    for x in [x0+.5,x1-.5]:
        rod(name+' drain',(x,3.45,z1+.24),(x,.05,z1+.24),.065,metal)
    box(name+' exterior lamp',(entry,2.58,z1+.25),(.8,.10,.16),lamp,.015)

# Continuous ground and a broad central road with crossing, drains and narrow service paths.
wall('Street ground',(0,-.1,0),(52,.2,44),asphalt)
for x in [-6,6]:
    box('Pavement seam',(x,.012,0),(.14,.025,42),concrete,0)
for z in range(-19,21,5): box('Faded road dash',(0,.016,z),(.12,.016,2.1),white,0)
for z in [3.7,4.5,5.3,6.1]: box('Pedestrian crossing',(0,.018,z),(8,.012,.34),white,0)
for x in [-5.5,5.5]:
    for z in [-13,-1,12]:
        box('Storm drain',(x,.025,z),(.48,.025,.82),dark,.008)
        for dz in range(6): box('Drain bars',(x,.042,z-.32+dz*.13),(.47,.012,.025),metal,0)
# Visible enclosing walls and closed roads make the playable perimeter legible.
for x in [-25.5,25.5]: wall('Perimeter wall',(x,1.45,0),(.4,2.9,43),concrete)
for z in [-21.5,21.5]:
    for x,w in [(-15.5,20),(15.5,20)]: wall('Boundary wall',(x,1.45,z),(w,2.9,.4),concrete)
    wall('Road closure',(0,1.5,z),(11,3,.4),green)
    for x in range(-5,6,2): box('Closure stripe',(x,1.5,z-.23),(.22,2.7,.03),white,0)

# Existing third-floor rooms are reached through this stairwell entry.
wall('South block mass',(-13,5.6,-18.6),(21,11.2,5.6),plaster)
box('South block damp footing',(-13,.45,-15.76),(21,.9,.10),concrete,.01)
box('Stairwell door',(-12,1.22,-15.68),(1.75,2.44,.12),green,.025)
box('Stairwell inset',(-12,1.35,-15.59),(1.42,1.65,.04),dark,.012)
rod('Stairwell handle',(-11.4,.95,-15.54),(-11.4,1.24,-15.54),.025,metal)
box('Entrance canopy',(-12,2.9,-15.0),(3.8,.18,1.8),concrete,.035)
box('Stairwell light',(-12,2.65,-15.57),(.76,.12,.16),lamp,.015)
for x in [-21,-17,-13,-9,-5]:
    for y in [4.4,7.2,10]:
        box('South window reveal',(x,y,-15.73),(1.65,1.9,.08),dark,.014)
        box('South window',(x,y,-15.67),(1.42,1.65,.055),glass,.005)
        box('South window mullion',(x,y,-15.60),(.07,1.7,.06),metal,.004)
        box('South sill',(x,y-.91,-15.57),(1.9,.10,.35),concrete,.015)
        if int(x+y)%3==0: box('AC outdoor unit',(x+1.14,y-.5,-15.43),(.70,.48,.43),concrete,.015)

shop('Grocery',-23,-9,-7,3,-17,-12)
shop('Clinic',7,21,-14,-4,13,17)
shop('Garage',10,23,6,17,19,16)
box('Clinic red cross vertical',(19,2.15,-3.82),(.16,.85,.045),red,.01)
box('Clinic red cross horizontal',(19,2.15,-3.80),(.70,.16,.045),red,.01)
for x in [12,20]:
    box('Garage rear shutter',(x,1.45,5.84),(2.8,2.6,.075),metal,.01)
    for y in range(11): box('Shutter ribs',(x,.30+y*.22,5.78),(2.8,.045,.045),dark,.003)
for x,z in [(-20,3.28),(8,-3.73),(22,17.28)]:
    for y in [.8,1.05,1.3]:
        box('Peeling notice',(x,y,z),(.23,.20,.005),paper,0)
# Store: shelves on the sides, empty gaps and a checkout island preserve movement lanes.
for x in [-22,-14]:
    for z in [-3,.2]:
        wall('Shelf body',(x,.76,z),(.60,1.52,2.5),green)
        for y in [.38,.83,1.28]:
            box('Shelf lip',(x+.33,y,z),(.10,.065,2.5),metal,.005)
            for dz in [-.8,.0,.7]: carton('Dusty stock',x+.02,y+.18,z+dz,.36,.30,.40)
wall('Checkout',(-10.1,.48,1),(.85,.96,2.1),green)
box('Dead register',(-10.1,1.13,.6),(.55,.3,.46),dark,.025)
# Clinic: stretchers, divider and emergency supply counter.
for x in [9.1,12.1]:
    wall('Bed collision',(x,.38,-11),(1.6,.76,2.4),metal)
    box('Bed mattress',(x,.79,-11),(1.55,.16,2.3),cloth,.065)
    box('Pillow',(x,.92,-11.7),(1,.15,.46),white,.05)
    for z in [-12.12,-9.88]: rod('Bed end',(x-.79,.84,z),(x+.79,.84,z),.035,metal)
wall('Medical counter',(19.6,.40,-11),(.72,.8,3.1),green)
for y in [1.5,1.95]: box('Medical shelves',(20.4,y,-11),(.75,.06,3),metal,.008)
for z in [-12,-10]: box('Medicine cabinet',(20.6,1.72,z),(.3,.33,.45),white,.005)
# Garage: inspection bench, wheels, posts and scattered oil pans.
wall('Garage workbench',(21.75,.41,13),(.8,.82,3.7),green)
wall('Garage lockers',(11.0,.9,15.6),(.80,1.8,1.9),metal)
for z in [15.1,15.8]: box('Locker handle',(11.43,1,z),(.04,.22,.08),dark,.004)
for x in [13.3,18.2]: wall('Lift post',(x,1.45,10.6),(.36,2.9,.45),rust)
for x in [13,13.6]:
    for y in [.22,.62]: ring('Spare tire',(x,y,14),.30,.105,dark,axis='y')

def car(x,z,col):
    wall('Abandoned vehicle',(x,.56,z),(1.9,1.12,4.0),col)
    box('Car cabin',(x,1.17,z-.2),(1.65,.65,1.95),glass,.18)
    box('Car roof',(x,1.52,z-.2),(1.65,.13,1.9),col,.055)
    for zz in [z-1.22,z+1.24]:
        for xx in [x-.93,x+.93]: rod('Car wheel',(xx-.13,.36,zz),(xx+.13,.36,zz),.35,dark,20)
    for zz in [z-2.02,z+2.02]:
        box('Car bumper',(x,.44,zz),(1.91,.19,.12),metal,.04)
        for xx in [x-.63,x+.63]: box('Car lamp',(xx,.77,zz),(.35,.16,.045),white if zz<z else red,.015)
car(3,-7,green);car(-3,13,rust);car(16,10.8,concrete)
wall('Closed residential block',(-17,4.8,15),(13,9.6,9),concrete)
for x in [-21,-17,-13]:
    for y in [2,4.8,7.6]: box('Boarded windows',(x,y,10.46),(1.5,1.7,.05),dark,.008)
for z in [-12,0,15]:
    for x in [-6.5,6.5]:
        rod('Streetlight pole',(x,0,z),(x,5,z),.07,metal)
        rod('Streetlight arm',(x,5,z),(x+.9,5,z),.06,metal)
        box('Streetlight hood',(x+.9,4.96,z),(.9,.14,.40),metal,.04)
        box('Streetlight glass',(x+.9,4.87,z),(.72,.035,.28),lamp,.018)
for x,z in [(-7,-10),(5,16),(-23.8,5),(23,2)]:
    wall('Raised planter',(x,.28,z),(1.3,.56,2.6),concrete)
    for i in range(9):
        xx=x+random.uniform(-.5,.5);zz=z+random.uniform(-1,1)
        rod('Dead stalk',(xx,.53,zz),(xx+.17,random.uniform(.8,1.6),zz-.1),.013,rust,6)
# Finite search targets align with visible boxes. Boxes have no physics obstruction at their centres.
for name,x,y,z,w,h,d,mat in [
    ('Market shelf cache',-21.55,1.10,-3,.70,.42,.82,paper),
    ('Market rear stock',-10.5,.40,-5.5,.90,.80,.75,paper),
    ('Clinic supplies',19.3,1.02,-11,.70,.42,.80,white),
    ('Clinic bag',8.5,.28,-6.5,.70,.50,.55,cloth),
    ('Garage tool chest',21.5,1.07,13,.70,.44,.80,red),
    ('Garage locker case',11.46,1.05,15.7,.40,.65,.62,green),
    ('Courtyard reserves',-18,.40,-11.5,1,.80,.80,paper),
    ('Back alley case',-4,.35,18,.80,.70,.65,cloth)]:
    carton(name,x,y,z,w,h,d,mat)
for i in range(80):
    x=random.uniform(-24,24);z=random.uniform(-20,20)
    obj=box('Windblown litter',(x,.028,z),(.12+random.random()*.17,.006,.15+random.random()*.18),paper,0)
    obj.rotation_euler.z=random.random()*math.tau
for x,z,w,d in [(-10,-10,3.1,1.4),(1,1,3,1.5),(-4,8,2.6,1),(5,-16,1.8,3),(5,9,1.4,2),(-7,18,1.8,1.4)]:
    sphere('Rain puddle',(x,.01,z),(w,.012,d),puddle)
# Distant, low-detail shells are visual context only, beyond the fenced bounds.
for x,z,w,h,d in [(-34,-14,12,16,13),(32,-18,13,20,12),(33,9,12,15,20),(-32,14,11,18,16),(0,30,25,13,12)]:
    box('Distant block',(x,h/2,z),(w,h,d),concrete,.04)
    for xx in range(int(x-w/2+2),int(x+w/2),3):
        for y in range(3,int(h),3): box('Distant window',(xx,y,z-d/2-.04),(1.2,1.7,.04),dark,0)

# Keep named pieces editable in .blend; join exported meshes by material to limit draw calls.
for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    if obj.type=='CURVE': bpy.ops.object.convert(target='MESH')
    if obj.type=='MESH':
        for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/south_district.blend'))
groups={}
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH': groups.setdefault(obj.data.materials[0].name,[]).append(obj)
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
bpy.ops.export_scene.gltf(filepath=str(OUT/'south_district.glb'),export_format='GLB',export_cameras=False,export_lights=False)
(OUT/'district_collision.json').write_text(json.dumps(collisions,indent=2))
print('DISTRICT_ASSETS_OK',len(collisions),'collision boxes')
