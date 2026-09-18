class_name SurvivalNavigation
extends RefCounted
## The floor union and obstacle grid are derived from the same boxes as world collision.
var grid := AStarGrid2D.new()
const CELL := .25
var obstacles: Array = []
var floors: Array[Rect2]=[]
var bounds:=Rect2()
static func floor_rectangles(boxes: Array) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for box in boxes:
		var p: Vector3=box.pos
		var s: Vector3=box.size
		if p.y<0 and s.y<.31 and absf(p.y+s.y/2)<.06:
			result.append(Rect2(Vector2(p.x-s.x/2,p.z-s.z/2),Vector2(s.x,s.z)))
	return result
static func floor_bounds(boxes: Array) -> Rect2:
	var result:=Rect2()
	for rect in floor_rectangles(boxes): result=rect if result.size==Vector2.ZERO else result.merge(rect)
	return result
func has_floor(point: Vector2) -> bool:
	# Check the whole footprint against the union; shrinking each rectangle would split seams.
	for offset in [Vector2.ZERO,Vector2(-.26,-.26),Vector2(.26,-.26),Vector2(-.26,.26),Vector2(.26,.26)]:
		var supported:=false
		for rect in floors:
			if rect.has_point(point+offset): supported=true;break
		if not supported: return false
	return true
func rebuild(boxes: Array) -> void:
	obstacles=boxes;floors=floor_rectangles(boxes);bounds=floor_bounds(boxes)
	var start:=Vector2i(floori(bounds.position.x/CELL)-1,floori(bounds.position.y/CELL)-1)
	var end:=Vector2i(ceili(bounds.end.x/CELL)+1,ceili(bounds.end.y/CELL)+1)
	grid.region=Rect2i(start,end-start)
	grid.cell_size=Vector2(CELL,CELL)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	# Mark floor coverage once, then stamp only the cells covered by each obstacle.
	# This avoids testing every building against every cell in the outdoor region.
	for x in range(grid.region.position.x,grid.region.end.x):
		for z in range(grid.region.position.y,grid.region.end.y):
			grid.set_point_solid(Vector2i(x,z),not has_floor(Vector2(x*CELL,z*CELL)))
	for box in boxes:
		var p: Vector3=box.pos;var s: Vector3=box.size
		if p.y+s.y/2<.16 or p.y-s.y/2>1.7: continue
		var lo:=Vector2i(floori((p.x-s.x/2-.26)/CELL),floori((p.z-s.z/2-.26)/CELL))
		var hi:=Vector2i(ceili((p.x+s.x/2+.26)/CELL),ceili((p.z+s.z/2+.26)/CELL))
		for x in range(maxi(lo.x,grid.region.position.x),mini(hi.x+1,grid.region.end.x)):
			for z in range(maxi(lo.y,grid.region.position.y),mini(hi.y+1,grid.region.end.y)):
				if absf(x*CELL-p.x)<s.x/2+.26 and absf(z*CELL-p.z)<s.z/2+.26: grid.set_point_solid(Vector2i(x,z),true)

func cell_of(point: Vector3) -> Vector2i:
	var candidate:=Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	for radius in range(1,7):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var p:=candidate+Vector2i(x,z)
				if grid.is_in_boundsv(p) and not grid.is_point_solid(p): return p
	return Vector2i(-999,-999)
func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	var a:=cell_of(from);var b:=cell_of(to)
	var result:=PackedVector3Array()
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b): return result
	for v in grid.get_point_path(a,b): result.append(Vector3(v.x,.02,v.y))
	return result
