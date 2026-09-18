class_name SurvivalSearchable
extends Area3D
## A finite inventory owned by a corpse or container. Searching reveals; taking transfers.
const Items=preload("res://scripts/survival/items.gd")
var source_id: String=""
var caption: String="储物处"
var kind: String="cabinet"
var gate: String=""
var owner_enemy: String=""
var searched: bool=false
var duration: float=1.25
var contents: Array[Dictionary]=[]
var bounds: Vector3=Vector3(.7,.65,.65)
var collision: CollisionShape3D
var active: bool=true

func _ready() -> void:
	collision_layer=2;collision_mask=0
	collision=CollisionShape3D.new()
	var box:=BoxShape3D.new();box.size=bounds;collision.shape=box
	add_child(collision)
	set_meta("search_source",true)
	set_available(active)
func set_available(value: bool) -> void:
	active=value
	collision_layer=2 if active else 0
func description() -> String:
	if not searched: return "尚未检索"
	return "已搜空" if contents.is_empty() else "已检索 · 剩余 %d 件" % contents.size()
func reveal() -> bool:
	if not active: return false
	searched=true
	return true
func take(uid: String,state: SurvivalState) -> bool:
	if not searched or not active or state.phase!="run": return false
	for index in range(contents.size()):
		if contents[index].uid==uid:
			if not state.pickup(contents[index]): return false
			contents.remove_at(index)
			return true
	return false
func serialize() -> Dictionary:
	return {"id":source_id,"caption":caption,"kind":kind,"gate":gate,"owner":owner_enemy,"searched":searched,"contents":contents.duplicate(true),"position":[position.x,position.y,position.z],"bounds":[bounds.x,bounds.y,bounds.z]}
