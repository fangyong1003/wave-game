"""Build editable first-person hands from the pinned CC0 Godot XR Tools source.
Run in Blender. No XR plugin/runtime is required by the exported game assets.
"""
import bpy, math, json, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/external/godot_xr_hands';OUT=ROOT/'game/assets/survival/hands';OUT.mkdir(parents=True,exist_ok=True)
for source in list((SOURCE/'textures').glob('*.png'))+list((SOURCE/'animations').glob('*/*.res')):
 relative=source.relative_to(SOURCE) if source.suffix=='.res' else Path(source.name)
 destination=OUT/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,destination)
bpy.ops.wm.read_factory_settings(use_empty=True)
mat=bpy.data.materials.new('Worn dark fingerless gloves');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
for filename,kind in [('glove_caucasian_dark_camo','color'),('glove_fingerless_normal','normal'),('glove_fingerless_occlusionRoughnessMetallic','orm')]:
 image=bpy.data.images.load(str(SOURCE/'textures'/f'{filename}.png'));image.pack()
 tex=nodes.new('ShaderNodeTexImage');tex.image=image
 if kind=='color':links.new(tex.outputs['Color'],p.inputs['Base Color'])
 else:
  image.colorspace_settings.name='Non-Color'
  if kind=='normal':
   normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
  else:
   split=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs['Color'],split.inputs['Color']);links.new(split.outputs['Green'],p.inputs['Roughness']);links.new(split.outputs['Blue'],p.inputs['Metallic'])
report={}
for suffix,side in [('R','right'),('L','left')]:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(SOURCE/'model'/f'Hand_Glove_{suffix}.gltf'));objects=set(bpy.data.objects)-before
 mesh=max((o for o in objects if o.type=='MESH'),key=lambda o:len(o.data.vertices));rig=next(o for o in objects if o.type=='ARMATURE')
 mesh.data.materials.clear();mesh.data.materials.append(mat)
 for face in mesh.data.polygons:face.use_smooth=True
 # Retain the authored finger topology and skinning; no primitive finger replacements.
 bpy.ops.object.select_all(action='DESELECT')
 for o in [mesh,rig]:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 # Keep original joint rest transforms exactly compatible with the authored poses.
 shutil.copy2(SOURCE/'model'/f'Hand_Glove_{suffix}.gltf',OUT/f'{side}_hand.gltf')
 report[side]={'vertices':len(mesh.data.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'bones':len(rig.data.bones),'bounds':[list(v) for v in mesh.bound_box]}
 # Separate the two editable rigs in the authoring scene only.
 rig.location.x=.24 if side=='right' else -.24
# Detailed sleeve with an elliptical forearm, wrist taper and irregular fabric folds.
verts=[];faces=[];rings=45;sides=40
for j in range(rings):
 t=j/(rings-1)
 for i in range(sides):
  a=2*math.pi*i/sides
  fold=(.0012*math.sin(t*math.pi*13+math.sin(a*2)*1.1)+.0006*math.sin(t*math.pi*27-a*3))*math.sin(t*math.pi)**.6
  radius=.049+.027*(1-t)+fold
  if t>.94:radius=.0495+.0012*math.sin(a*20) # fitted ribbed wrist cuff
  verts.append((radius*math.cos(a),t,radius*.83*math.sin(a)))
for j in range(rings-1):
 for i in range(sides):
  a=j*sides+i;b=j*sides+(i+1)%sides;faces.append((a,b,b+sides,a+sides))
mesh=bpy.data.meshes.new('Folded sleeve mesh');mesh.from_pydata(verts,[],faces);mesh.update()
sleeve=bpy.data.objects.new('Sleeve',mesh);bpy.context.collection.objects.link(sleeve)
uv=mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
 poly.use_smooth=True
 for li in poly.loop_indices:
  vi=mesh.loops[li].vertex_index;uv.data[li].uv=((vi%sides)/sides,vi//sides/(rings-1))
bpy.ops.object.select_all(action='DESELECT');sleeve.select_set(True);bpy.context.view_layer.objects.active=sleeve
bpy.ops.export_scene.gltf(filepath=str(OUT/'sleeve.glb'),use_selection=True,export_format='GLB',export_materials='NONE',export_animations=False)
sleeve.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/first_person_hands.blend'))
(OUT/'import-report.json').write_text(json.dumps(report,indent=2))
print('HANDS_READY',report)
