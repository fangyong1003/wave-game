"""Adapt the editable apartment, preserve articulated parts, author original survival props and infected.
Run using Blender --background --python. The repair assets are read but never overwritten.
"""
import ast, bpy, json, math, random, runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'game/assets/survival';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art';collisions=[]
# Share the established Y-up geometry helpers, not their scene-building side effects.
tree=ast.parse((ROOT/'tools/build_apartment.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'<apartment helpers>','exec'))
random.seed(714)

def empty(name,pos):
    obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);obj.location=xyz(pos)
    return obj
def parent_keep(obj,parent):
    # Blender setters are lazy: flush scale/location before preserving a world matrix.
    # Otherwise newly scaled UV spheres export at the primitive's full one-metre radius.
    bpy.context.view_layer.update()
    matrix=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=matrix
    bpy.context.view_layer.update()
    return obj
def godot_pos(obj):return (obj.location.x,obj.location.z,-obj.location.y)
def apply_and_export(filename,save_name=None,join=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {'MESH','CURVE','FONT'}:continue
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        if obj.type!='MESH':bpy.ops.object.convert(target='MESH')
        for mod in list(obj.modifiers):
            try:bpy.ops.object.modifier_apply(modifier=mod.name)
            except Exception:pass
        obj.select_set(False)
    if save_name:
        bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/save_name))
    if join:
        groups={}
        for obj in list(bpy.context.scene.objects):
            if obj.type=='MESH' and obj.parent is None:
                groups.setdefault(obj.data.materials[0].name if obj.data.materials else 'none',[]).append(obj)
        for name,objects in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects:obj.select_set(True)
            bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name='Architecture_'+name
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type not in {'CAMERA','LIGHT'}:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)

bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'apartment_302.blend'))
collisions=json.loads((ROOT/'game/assets/models/collision_layout.json').read_text())
plaster=bpy.data.materials['aged_plaster'];floor=bpy.data.materials['stone_floor']
wood=bpy.data.materials['old_wood'];steel=bpy.data.materials['brushed_steel'];paint=bpy.data.materials['cabinet_paint']
dark=bpy.data.materials['cabinet_edges'];brass=bpy.data.materials['old_brass'];cloth=bpy.data.materials['linen']
paper=material('supply_paper',(.57,.55,.45),.98)
red=material('emergency_red',(.39,.10,.07),.7)

for obj in list(bpy.context.scene.objects):
    x,y,z=godot_pos(obj)
    if obj.name.startswith('302 number'):obj.rotation_euler=(math.pi/2,0,0)
    remove=obj.name.startswith(('Corridor back','302 opened door','Door handle','Printer','Printed ticket'))
    if y<.85 and abs(z+1.54)<.38 and -3<x<-2 and obj.name.startswith(('Cabinet carcass','Cabinet door','Door rail','Door stile','Pull','Paint chip')):remove=True
    if remove:bpy.data.objects.remove(obj,do_unlink=True)
collisions=[c for c in collisions if c['pos'] not in [[2,1.6,3.08],[-.83,1.2,.26],[-2.58,.44,-1.54]]]
# Hall aperture and compact 303, with an actual route back through the original two entrances.
for x,w in [(.24,6.56),(6.0,2.4)]:box('Hall rear partition',(x,1.6,3.08),(w,3.2,.16),plaster,0,True)
box('303 lintel',(4.17,2.85,3.08),(1.3,.70,.16),plaster,0,True)
box('303 floor',(4.94,-.1,4.92),(4.52,.2,3.84),floor,.006,True)
box('303 ceiling',(4.94,3.24,4.92),(4.52,.18,3.84),plaster,0,True)
box('303 left',(2.72,1.6,4.96),(.16,3.2,3.76),plaster,0,True)
box('303 right',(7.16,1.6,4.96),(.16,3.2,3.76),plaster,0,True)
box('303 rear',(4.94,1.6,6.8),(4.52,3.2,.16),plaster,0,True)
for x in [3.51,4.83]:box('303 jamb',(x,1.24,3.06),(.08,2.48,.22),wood,.01)
box('303 door plate',(5.03,1.8,2.973),(.39,.22,.03),dark,.005)
text('303 number','303',(5.03,1.76,2.95),.13,paper,rotation=(90,0,180))
# Hollow lower cabinet. The leaf remains a separate pivot in glTF.
for yy in [.08,.82]:box('Open cabinet shelf',(-2.58,yy,-1.54),(.76,.055,.69),dark,.008,True)
for zz in [-1.89,-1.19]:box('Open cabinet side',(-2.58,.46,zz),(.76,.78,.035),paint,.006,True)
box('Open cabinet backing',(-2.95,.46,-1.54),(.035,.78,.69),dark,.004,True)
door=empty('Dynamic_KitchenCabinet',(-2.16,.08,-1.89))
parent_keep(box('Kitchen cabinet leaf',(-2.14,.455,-1.55),(.035,.75,.67),paint,.008),door)
parent_keep(rod('Kitchen cabinet pull',(-2.10,.69,-1.53),(-2.10,.69,-1.32),.012,brass),door)
# Living room door, separately articulated with matching runtime collision.
door=empty('Dynamic_LivingDoor',(4.17,0,1.04))
parent_keep(box('Living door leaf',(4.86,1.20,1.04),(1.38,2.4,.065),wood,.012),door)
for y in [.55,1.65]:parent_keep(box('Door inset',(4.86,y,1.078),(1.12,.78,.012),dark,.014),door)
parent_keep(rod('Living door handle',(5.37,1.02,1.12),(5.53,1.02,1.12),.015,brass),door)
# Glass-fronted cache; only the glass disappears when broken.
for x in [5.73,6.69]:box('Locker upright',(x,1.02,6.34),(.055,1.9,.63),wood,.007,True)
for y in [.10,.78,1.96]:box('Locker shelf',(6.21,y,6.34),(1.0,.055,.63),wood,.007,True)
box('Locker backing',(6.21,1.02,6.65),(1.0,1.9,.04),dark,.004,True)
glass=material('cache_glass',(.27,.34,.32),.16,.05)
glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.24;glass.surface_render_method='DITHERED'
door=empty('Dynamic_GlassLocker',(5.74,.16,6.01))
parent_keep(box('Locker glass',(6.21,1.05,6.0),(.9,1.76,.018),glass,.004),door)
for x in [5.76,6.65]:parent_keep(box('Glass edge',(x,1.05,5.988),(.028,1.80,.035),brass,.003),door)
parent_keep(box('Locker lock',(6.59,.98,5.966),(.07,.12,.05),brass,.008),door)
# Shelf and evacuation clutter in 303.
for y in [.35,.90,1.50]:box('Storage rack shelf',(3.08,y,5.78),(.6,.055,1.58),steel,.004,True)
for z in [5.0,6.52]:box('Storage rack post',(2.85,.92,z),(.045,1.85,.045),steel,.003,True)
for x,y,z in [(3.07,.55,6.18),(3.08,1.12,6.16),(6.72,.18,4.55),(6.7,.47,4.64)]:
    box('Evacuation cardboard',(x,y,z),(.44,.36,.42),paper,.018)
    box('Carton tape',(x,y+.183,z),(.12,.004,.42),cloth,.001)
box('Safehouse door',(-2.977,1.18,2.15),(.065,2.36,1.23),paint,.016)
for y in [.53,1.64]:box('Safehouse door panel',(-2.93,y,2.15),(.035,.83,.97),dark,.009)
rod('Safehouse handle',(-2.91,1.03,2.49),(-2.79,1.03,2.49),.015,brass)
box('Safehouse emergency light',(-2.87,2.45,2.15),(.13,.10,.48),paper,.016)
for x,z in [(1.85,-4.7),(2.45,2.64),(6.8,-1.45)]:
    box('Abandoned crate',(x,.23,z),(.48,.46,.44),wood,.012,True)
    for yy in [.12,.32]:box('Crate slat',(x,yy,z+.23),(.50,.075,.025),paper,.003)
runpy.run_path(str(ROOT/'tools/build_east_wing.py'))['build'](globals())
apply_and_export('south_block.glb','south_block_survival.blend',True)
(OUT/'collision_layout.json').write_text(json.dumps(collisions,indent=2))

# Original articulated infected, authored as nested pivots for runtime animation.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
skin=material('infected_skin',(.34,.36,.29),.95)
coat=material('infected_coat',(.14,.18,.17),.93)
pants=material('infected_trousers',(.085,.10,.11),.95)
black=material('infected_shadow',(.035,.032,.027),.96)
boot=material('infected_boot',(.046,.044,.034),.85)
seam=material('infected_stitch',(.25,.25,.20),.97)
root=empty('InfectedRig',(0,0,0))
torso=empty('Torso',(0,1.13,0));parent_keep(torso,root)
parts=[sphere('Coat torso',(0,1.24,0),(.245,.30,.15),coat),box('Coat hem',(0,.97,0),(.41,.26,.29),coat,.06),box('Shirt opening',(0,1.36,.145),(.072,.31,.012),black,.009)]
for obj in parts:parent_keep(obj,torso)
for side in [-1,1]:
    lapel=box('Folded collar',(side*.085,1.45,.15),(.08,.18,.032),coat,.012);lapel.rotation_euler.y=side*.28;parent_keep(lapel,torso)
    parent_keep(box('Chest pocket',(side*.136,1.22,.155),(.105,.105,.025),coat,.015),torso)
for y in [1.33,1.22,1.10,.99]:parent_keep(sphere('Coat button',(.04,y,.173),(.009,.009,.006),black),torso)
head=empty('Head',(0,1.53,.005));parent_keep(head,torso)
for obj in [rod('Neck',(0,1.45,0),(0,1.58,0),.06,skin),sphere('Cranium',(0,1.68,0),(.105,.145,.091),skin),box('Lower jaw',(0,1.578,.037),(.139,.095,.11),skin,.028),sphere('Nose',(0,1.651,.097),(.023,.041,.025),skin)]:parent_keep(obj,head)
for side in [-1,1]:
    parent_keep(sphere('Ear',(side*.104,1.655,.002),(.019,.039,.017),skin),head)
    parent_keep(sphere('Eye socket',(side*.042,1.695,.080),(.030,.022,.012),black),head)
    parent_keep(sphere('Clouded eye',(side*.042,1.693,.091),(.013,.010,.007),seam),head)
    parent_keep(sphere('Brow',(side*.043,1.723,.079),(.037,.014,.020),skin),head)
parent_keep(box('Mouth shadow',(0,1.590,.097),(.070,.013,.010),black,.005),head)
parent_keep(sphere('Cropped hair',(0,1.766,-.013),(.105,.068,.084),black),head)
for side,label in [(-1,'L'),(1,'R')]:
    arm=empty('Arm_'+label,(side*.24,1.42,0));parent_keep(arm,torso)
    for obj in [sphere('Coat shoulder',(side*.248,1.40,0),(.11,.13,.12),coat),rod('Coat upper sleeve',(side*.27,1.39,0),(side*.31,1.12,.024),.080,coat,24,r2=.07),sphere('Sleeve elbow',(side*.31,1.10,.025),(.075,.08,.075),coat),rod('Coat lower sleeve',(side*.31,1.10,.03),(side*.32,.88,.08),.063,coat,24,r2=.05),box('Sleeve cuff',(side*.32,.91,.077),(.12,.075,.125),coat,.014),sphere('Hand',(side*.325,.825,.091),(.05,.077,.03),skin)]:parent_keep(obj,arm)
    for i in range(4):parent_keep(rod('Finger',(side*(.291+i*.021),.80,.105),(side*(.287+i*.022),.729,.131),.009,skin,12),arm)
    leg=empty('Leg_'+label,(side*.113,.89,0));parent_keep(leg,root)
    for obj in [rod('Trouser thigh',(side*.11,.89,0),(side*.12,.53,.025),.10,pants,24,r2=.08),sphere('Trouser knee',(side*.12,.49,.025),(.08,.09,.08),pants),rod('Trouser shin',(side*.12,.49,.02),(side*.12,.16,0),.074,pants,24,r2=.057),box('Boot',(side*.12,.092,.053),(.15,.17,.31),boot,.034),box('Boot sole',(side*.12,.027,.058),(.16,.04,.32),black,.016)]:parent_keep(obj,leg)
apply_and_export('infected.glb','infected_survival.blend')

# Baseball bat uses a smooth lathed silhouette; grip wrap and maker stamp stay readable close up.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
batwood=material('bat_wood',(.30,.20,.105),.65)
wrap=material('bat_grip',(.045,.055,.051),.9)
lathe('Baseball bat',(0,-.14,0),[(.022,0),(.027,.008),(.025,.02),(.016,.04),(.014,.20),(.024,.39),(.038,.59),(.041,.73),(.038,.81),(.025,.825),(0,.83)],batwood,40)
for i in range(19):ring('Grip wrap',(0,-.08+i*.008,0),.016,.003,wrap)
apply_and_export('bat.glb','baseball_bat.blend')
print('SURVIVAL_ASSETS_OK',len(collisions),'static collision boxes')
