"""Original game weapon props; Blender source keeps slide/magazine/bolt pivots editable."""
import ast, bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'game/assets/survival';collisions=[]
tree=ast.parse((ROOT/'tools/build_apartment.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'<prop helpers>','exec'))

def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def group(name):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
def parent(obj,root):
    bpy.context.view_layer.update();m=obj.matrix_world.copy();obj.parent=root;obj.matrix_world=m
    return obj
def export(name):
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {'MESH','CURVE','FONT'}:continue
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        if obj.type!='MESH':bpy.ops.object.convert(target='MESH')
        for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art'/f'{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',export_cameras=False,export_lights=False)

clean()
steel=material('ranged_steel',(.10,.13,.145),.44,.72)
edge=material('ranged_edge',(.27,.29,.28),.38,.75)
black=material('ranged_rubber',(.025,.030,.027),.93)
grip=material('ranged_grip',(.13,.155,.13),.94)
dot=material('ranged_sight',(.59,.70,.41),.5)
wood=material('ranged_stock',(.21,.16,.105),.8)
stringmat=material('ranged_string',(.24,.26,.25),.83)
boltmat=material('ranged_bolt',(.27,.29,.27),.42,.65)

# Generic compact pistol facing -Z; the root is the right-hand grip.
box('Frame',(0,.057,-.065),(.042,.070,.19),steel,.007)
slide=group('Slide')
parent(box('Slide casing',(0,.112,-.080),(.048,.045,.23),steel,.005),slide)
for x in [-.025,.025]:
    for z in [.004,-.008,-.020,-.032]: parent(box('Slide serration',(x,.112,z),(.002,.031,.003),edge,.0005),slide)
parent(box('Ejection opening',(.025,.116,-.09),(.002,.017,.042),black,.002),slide)
parent(box('Front sight',(0,.144,-.171),(.008,.014,.012),black,.001),slide)
parent(box('Front sight dot',(0,.148,-.164),(.005,.006,.002),dot,.001),slide)
for x in [-.016,.016]:
    parent(box('Rear sight',(x,.143,.015),(.013,.014,.016),black,.002),slide)
rod('Barrel',(0,.10,-.20),(0,.10,-.215),.012,edge,24)
rod('Muzzle bore',(0,.10,-.2155),(0,.10,-.217),.008,black,24)
handle=box('Grip',(0,-.031,.019),(.040,.135,.056),grip,.006);handle.rotation_euler.x=-.18
for x in [-.021,.021]:
    for y in [-.071,-.052,-.033,-.014,.005]: box('Grip texture',(x,y,.017),(.002,.006,.049),black,.001)
guard=[(-.020,.041,-.065),(-.020,-.032,-.065),(-.020,-.046,-.092),(-.020,-.031,-.130),(-.020,.046,-.130)]
for a,b in zip(guard,guard[1:]):rod('Trigger guard',a,b,.007,steel,12)
rod('Trigger',(-.005,.035,-.095),(-.005,-.013,-.082),.005,black,12)
mag=group('Magazine');parent(box('Magazine',(0,-.053,.019),(.028,.096,.034),edge,.003),mag)
parent(box('Magazine base',(0,-.106,.020),(.047,.014,.059),black,.003),mag)
text('Slide stamp','9 x 19',(.025,.11,-.069),.008,edge,rotation=(90,0,90))
export('pistol')

clean()
# Hunting crossbow: stock, rail, curved limbs, drawn string and visible loaded bolt.
box('Stock',(0,-.020,.125),(.073,.108,.31),wood,.018)
box('Butt pad',(0,-.014,.295),(.09,.15,.026),black,.014)
box('Receiver',(0,.055,-.110),(.086,.093,.27),steel,.012)
box('Foregrip',(0,.010,-.245),(.068,.088,.18),grip,.012)
box('Rail',(0,.108,-.185),(.029,.024,.43),edge,.003)
box('Hand grip',(0,-.061,-.010),(.058,.12,.065),grip,.008)
for x in [-.029,.029]:
    for y in [-.09,-.06,-.03]: box('Handle texture',(x,y,-.008),(.004,.009,.049),black,.001)
for sign in [-1,1]:
    points=[(0,.075,-.345),(sign*.12,.082,-.377),(sign*.24,.092,-.370),(sign*.34,.100,-.325)]
    for a,b in zip(points,points[1:]):rod('Bow limb',a,b,.020,grip,12,r2=.014)
    rod('Cable guide',(sign*.21,.10,-.375),(sign*.21,.10,-.275),.006,edge,8)
    for z in [-.2,-.15]:box('Rail screw',(sign*.035,.107,z),(.013,.006,.013),edge,.003)
strings=group('BowString')
for x in [-.34,.34]:parent(rod('Drawn string',(x,.107,-.325),(0,.117,-.04),.0025,stringmat,8),strings)
arrow=group('LoadedBolt')
parent(rod('Bolt shaft',(0,.132,-.04),(0,.132,-.465),.004,boltmat,12),arrow)
parent(rod('Bolt tip',(0,.132,-.465),(0,.132,-.505),.010,edge,12,r2=0),arrow)
for angle in [0,math.tau/3,math.tau*2/3]:
    o=box('Bolt vane',(math.sin(angle)*.010,.132+math.cos(angle)*.010,-.080),(.003,.021,.064),red if 'red' in globals() else dot,.001)
    parent(o,arrow)
for z in [-.02,-.29]:
    box('Sight mount',(0,.145,z),(.028,.051,.029),black,.003)
    box('Sight bead',(0,.175,z),(.006,.006,.007),dot,.001)
export('crossbow')
print('RANGED_ASSETS_OK')
