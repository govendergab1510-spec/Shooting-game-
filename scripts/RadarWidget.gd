extends Control

var player_ref: Node3D
var enemies_ref: Array[Node3D] = []
var barrels_ref: Array[Node3D] = []
var pickups_ref: Array[Node3D] = []
const RADAR_RANGE := 26.0

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(c.x, c.y) - 3.0
	draw_circle(c, r, Color(0.06, 0.08, 0.11, 0.72))
	draw_arc(c, r, 0.0, TAU, 32, Color(1.0, 0.60, 0.20, 0.85), 2.0)
	draw_arc(c, r * 0.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.12), 1.0)

	if player_ref == null or not is_instance_valid(player_ref):
		return

	var ppos := player_ref.global_position
	var yaw := player_ref.rotation.y
	var cy := cos(yaw)
	var sy := sin(yaw)

	for b in barrels_ref:
		if is_instance_valid(b) and b.visible:
			var pt := _world_to_radar(b.global_position - ppos, cy, sy, c, r)
			draw_circle(pt, 3.0, Color(1.0, 0.55, 0.12))

	for pk in pickups_ref:
		if is_instance_valid(pk):
			var pt := _world_to_radar(pk.global_position - ppos, cy, sy, c, r)
			draw_circle(pt, 3.5, Color(0.20, 0.95, 0.45))

	for e in enemies_ref:
		if is_instance_valid(e) and not e.get_meta("is_dead", false):
			var pt := _world_to_radar(e.global_position - ppos, cy, sy, c, r)
			draw_circle(pt, 4.2, Color(1.0, 0.22, 0.22))

	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(-4.5, 5), c + Vector2(4.5, 5)]), Color(0.25, 0.95, 1.0))

func _world_to_radar(diff: Vector3, cy: float, sy: float, c: Vector2, r: float) -> Vector2:
	var rx := diff.x * cy - diff.z * sy
	var rz := diff.x * sy + diff.z * cy
	var v := Vector2(rx, rz) / RADAR_RANGE
	if v.length() > 0.92:
		v = v.normalized() * 0.92
	return c + v * r
