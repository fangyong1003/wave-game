class_name SurvivalEffects
extends Node3D
const P = preload("res://scripts/props.gd")
var fragments: Array[Dictionary] = []
var marks: Array[Node3D] = []
var blood := true
var materials := {}
var audio_voices: Array[AudioStreamPlayer3D] = []
var ambience: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for key in {"wood":Color("947454"),"metal":Color("daa46b"),"stone":Color("b2b0a3"),"glass":Color("a8ced4"),"flesh":Color("713c33"),"dust":Color("83857c")}:
		var color: Color = {"wood":Color("947454"),"metal":Color("daa46b"),"stone":Color("b2b0a3"),"glass":Color("a8ced4"),"flesh":Color("713c33"),"dust":Color("83857c")}[key]
		var mat := P.material(color,.75,.2 if key=="metal" else 0.0)
		if key == "metal":
			mat.emission_enabled = true
			mat.emission = color*.7
		materials[key] = mat
	for name in ["rain","room_tone"]:
		var a := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load("res://assets/audio/"+name+".wav").duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length()*stream.mix_rate)
		a.stream = stream
		a.volume_db = -18 if name=="rain" else -22
		add_child(a)
		a.play()
		ambience.append(a)

func sound(name: String, at: Vector3, db: float = -10) -> void:
	for i in range(audio_voices.size()-1,-1,-1):
		if not is_instance_valid(audio_voices[i]): audio_voices.remove_at(i)
	if audio_voices.size()>=16:
		var oldest: AudioStreamPlayer3D = audio_voices.pop_front()
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.stream = load("res://assets/audio/"+name+".wav")
	voice.volume_db = db
	voice.pitch_scale = randf_range(.93,1.07) if name != "level" else 1.0
	voice.max_distance = 18
	voice.position = at
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
	audio_voices.append(voice)

func burst(at: Vector3, normal: Vector3, surface: String, heavy: bool = false) -> void:
	var material_key := surface if materials.has(surface) else "stone"
	if surface=="flesh" and not blood: material_key = "dust"
	for i in range(18 if heavy else 11):
		while fragments.size()>=100:
			var old: Dictionary = fragments.pop_front()
			if is_instance_valid(old.node): old.node.queue_free()
		var scale0 := Vector3(randf_range(.008,.025),randf_range(.009,.03),randf_range(.006,.017))
		if surface=="wood": scale0.x *= 2
		if surface=="metal": scale0.z *= 3
		var obj := P.box(self,at+normal*.018,scale0,materials[material_key])
		obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var direction := (normal+Vector3(randf_range(-1,1),randf_range(-.2,1.2),randf_range(-1,1))).normalized()
		fragments.append({"node":obj,"velocity":direction*randf_range(.8,3.2),"life":randf_range(.3,.8),"spin":Vector3(randf(),randf(),randf())*12})
	if surface != "flesh": add_mark(at,normal,surface)

func add_mark(at: Vector3, normal: Vector3, surface: String) -> void:
	while marks.size()>=32:
		var old: Node3D = marks.pop_front()
		if is_instance_valid(old): old.queue_free()
	var root := Node3D.new()
	add_child(root)
	root.position = at+normal*.007
	root.quaternion = Quaternion(Vector3.BACK,normal.normalized())
	var mat := P.material(Color("605b4d") if surface == "wood" else Color("393f3c"),.98)
	for i in range(3):
		var crack := P.box(root,Vector3(randf_range(-.03,.03),randf_range(-.02,.02),0),Vector3(randf_range(.045,.12),.006,.002),mat)
		crack.rotation.z = randf_range(-1,1)
	marks.append(root)

func _process(delta: float) -> void:
	for i in range(fragments.size()-1,-1,-1):
		var f: Dictionary = fragments[i]
		f.life -= delta
		if f.life<=0:
			f.node.queue_free()
			fragments.remove_at(i)
			continue
		f.velocity.y -= delta*7
		f.node.position += f.velocity*delta
		f.node.rotation += f.spin*delta
		if f.node.position.y<.025:
			f.node.position.y = .025
			f.velocity *= .5
			f.velocity.y = absf(f.velocity.y)*.25
		f.node.scale = Vector3.ONE*minf(1,f.life*5)

func set_outdoors(outdoors: bool) -> void:
	if ambience.size()>=2:
		ambience[0].volume_db=-14 if outdoors else -18
		ambience[1].volume_db=-32 if outdoors else -22
func clear_region() -> void:
	for voice in audio_voices:
		if is_instance_valid(voice): voice.stop();voice.stream=null;voice.queue_free()
	audio_voices.clear()
	for fragment in fragments:
		if is_instance_valid(fragment.node): fragment.node.queue_free()
	fragments.clear()
	for mark in marks:
		if is_instance_valid(mark): mark.queue_free()
	marks.clear()
func stop_audio() -> void:
	for a in ambience+audio_voices:
		if is_instance_valid(a):
			a.stop()
			a.stream = null
func _exit_tree() -> void: stop_audio()
