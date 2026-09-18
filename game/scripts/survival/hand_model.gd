class_name SurvivalHandModel
extends Node3D
# CC0 hand mesh and authored finger poses by Miodrag Sejic / Godot XR Tools.
const RIGHT=preload("res://assets/survival/hands/right_hand.gltf")
const LEFT=preload("res://assets/survival/hands/left_hand.gltf")
static var glove_material: ORMMaterial3D
var left:=false
var skeleton: Skeleton3D
var wrist_bone: int
var model: Node3D
var poses: Dictionary={}
var pose_name:=""
func _ready() -> void:
	model=(LEFT if left else RIGHT).instantiate();add_child(model)
	model.position=Vector3(-.023 if left else .023,-.07,.070)
	skeleton=model.find_child("Skeleton3D",true,false)
	wrist_bone=skeleton.find_bone("Wrist_L" if left else "Wrist_R")
	if glove_material==null:
		glove_material=ORMMaterial3D.new()
		glove_material.albedo_texture=load("res://assets/survival/hands/glove_caucasian_dark_camo.png")
		glove_material.orm_texture=load("res://assets/survival/hands/glove_fingerless_occlusionRoughnessMetallic.png")
		glove_material.normal_enabled=true;glove_material.normal_scale=.65
		glove_material.normal_texture=load("res://assets/survival/hands/glove_fingerless_normal.png")
		glove_material.ao_light_affect=.15
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			child.material_override=glove_material
			child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for pose in ["Grip","Grip Shaft","Pistol","Straight","Cup"]:
		var animation: Animation=load("res://assets/survival/hands/animations/"+("left" if left else "right")+"/"+pose+".res")
		var rotations: Dictionary={}
		for track in range(animation.get_track_count()):
			if animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
			var bone: int=skeleton.find_bone(str(animation.track_get_path(track).get_subname(0)))
			if bone>=0: rotations[bone]=animation.track_get_key_value(track,0)
		poses[pose]=rotations
	set_pose("Grip",1)
func set_pose(value: String,blend: float=1.0) -> void:
	if not poses.has(value): return
	pose_name=value
	for bone in poses[value]: skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(poses[value][bone],clampf(blend,0,1)))
func wrist_global() -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(wrist_bone).origin
