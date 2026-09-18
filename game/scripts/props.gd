class_name RepairProps
extends RefCounted

static func material(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = shape
	obj.position = pos
	obj.material_override = mat
	parent.add_child(obj)
	return obj

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, mat)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 32
	return mesh(parent, shape, pos, mat)

static func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, scale_y: float = 1) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 16
	shape.rings = 8
	var obj := mesh(parent, shape, pos, mat)
	obj.scale.y = scale_y
	return obj

static func line(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var obj := cylinder(parent, (start + end) / 2, radius, start.distance_to(end), mat)
	var direction := (end - start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		obj.quaternion = Quaternion(Vector3.UP, direction)
	return obj

static func torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 32
	shape.ring_segments = 12
	return mesh(parent, shape, pos, mat)

static func label(parent: Node3D, caption: String, pos: Vector3, font_size: int = 26, pixel: float = 0.002) -> Label3D:
	var l := Label3D.new()
	l.text = caption
	l.position = pos
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = Color("c9ccc3")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
	l.font = f
	parent.add_child(l)
	return l
