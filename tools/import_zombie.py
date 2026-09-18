"""Convert Pixelhouse's CC BY 3.0 FBX source into an editable textured, animated actor.
Run with Blender 5.2+. Original source and attribution: art/external/pixelhouse_zombie/.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/external/pixelhouse_zombie'
OUT=ROOT/'game/assets/survival/zombie';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.fbx_import(filepath=str(SOURCE/'walk.FBX'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
keepers={rig,mesh}
rig.name='ZombieRig';mesh.name='ZombieBody'
clips={'Walk':rig.animation_data.action}
for file,name in [('fury.FBX','Attack'),('dead.FBX','Death')]:
    before=set(bpy.data.objects)
    bpy.ops.wm.fbx_import(filepath=str(SOURCE/file))
    imported=set(bpy.data.objects)-before
    other=next(o for o in imported if o.type=='ARMATURE')
    clips[name]=other.animation_data.action
    clips[name].use_fake_user=True
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
for obj in list(bpy.context.scene.objects):
    if obj not in keepers:bpy.data.objects.remove(obj,do_unlink=True)

for name,action in clips.items():
    action.name=name
    action.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action)
    if hasattr(strip,'action_slot'):strip.action_slot=action.slots[0]
    strip.action_frame_start=action.frame_range[0];strip.action_frame_end=action.frame_range[1]
    strip.extrapolation='NOTHING'
    track.mute=True
rig.animation_data.action=clips['Walk']
rig.animation_data.action_slot=clips['Walk'].slots[0]
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()

# Retain original rig transforms; a root converts old source units into game metres.
corners=[mesh.matrix_world@Vector(v) for v in mesh.bound_box]
low=Vector(tuple(min(v[i] for v in corners) for i in range(3)))
high=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
scale=1.78/(high.z-low.z)
root=bpy.data.objects.new('PixelhouseZombie',None);bpy.context.collection.objects.link(root)
root.scale=Vector((scale,scale,scale))
root.location=Vector((-(high.x+low.x)/2*scale,-(high.y+low.y)/2*scale,-low.z*scale))
for obj in [rig,mesh]:
    if obj.parent is None:obj.parent=root

material=bpy.data.materials.new('Pixelhouse zombie skin and clothing');material.use_nodes=True
p=material.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.9
for file,socket in [('difusse.jpg','Base Color'),('normal.JPG','Normal')]:
    image=bpy.data.images.load(str(SOURCE/file));image.pack()
    tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    if socket=='Normal':
        image.colorspace_settings.name='Non-Color'
        normal=material.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65
        material.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
        material.node_tree.links.new(normal.outputs['Normal'],p.inputs[socket])
    else:material.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
mesh.data.materials.clear();mesh.data.materials.append(material)
for face in mesh.data.polygons:face.material_index=0;face.use_smooth=True

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/pixelhouse_zombie.blend'))
# ACTIONS exports each rig action independently with the same skeleton.
bpy.ops.export_scene.gltf(filepath=str(OUT/'pixelhouse_zombie.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_nla_strips=True,export_force_sampling=True,export_cameras=False,export_lights=False)
(OUT/'import-report.json').write_text(json.dumps({'source':'https://opengameart.org/content/zombie','license':'CC BY 3.0','author':'Pixelhouse','source_scale':scale,'bounds':[list(low),list(high)],'vertices':len(mesh.data.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'actions':{n:list(a.frame_range) for n,a in clips.items()},'bones':[b.name for b in rig.data.bones]},indent=2))
print('PIXELHOUSE_ZOMBIE_READY',scale,{n:list(a.frame_range) for n,a in clips.items()})
