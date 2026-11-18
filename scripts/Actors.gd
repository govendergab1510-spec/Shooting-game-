extends RefCounted

class ArenaBuilder extends Node3D:
	signal barrel_exploded(pos: Vector3, radius: float, damage: int)
	const BLOCK_HALF := 26.0
	var barrels: Array[Node3D] = []
	var _blob_tex: ImageTexture

	func _ready() -> void:
		_blob_tex = _create_blob_shadow_texture()

	func get_blob_texture() -> ImageTexture:
		if _blob_tex == null:
			_blob_tex = _create_blob_shadow_texture()
		return _blob_tex

	func add_contact_shadow(parent: Node3D, radius: float = 0.75, alpha: float = 0.55) -> void:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(radius * 2.0, radius * 2.0)
		mi.mesh = pm
		mi.position.y = 0.015
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = get_blob_texture()
		mat.albedo_color = Color(0.02, 0.03, 0.05, alpha)
		mi.material_override = mat
		parent.add_child(mi)

	func _create_blob_shadow_texture() -> ImageTexture:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var dx := (float(x) - 15.5) / 15.5
				var dy := (float(y) - 15.5) / 15.5
				var d := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, pow(d, 1.7)))
		return ImageTexture.create_from_image(img)

	func build_arena() -> void:
		_build_street_and_sidewalks()
		_build_perimeter_buildings()
		_build_distant_skyline()
		_build_gta_street_props()

	func _load_pbr_mat(folder: String, uv_scale: Vector3, fallback_col: Color) -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.uv1_scale = uv_scale
		var diff := "res://assets/polyhaven/%s/diff.jpg" % folder
		var nor := "res://assets/polyhaven/%s/nor.jpg" % folder
		var rough := "res://assets/polyhaven/%s/rough.jpg" % folder
		if ResourceLoader.exists(diff):
			mat.albedo_texture = load(diff)
		else:
			mat.albedo_color = fallback_col
		if ResourceLoader.exists(nor):
			mat.normal_enabled = true
			mat.normal_texture = load(nor)
			mat.normal_scale = 0.90
		if ResourceLoader.exists(rough):
			mat.roughness_texture = load(rough)
		return mat

	func _build_street_and_sidewalks() -> void:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(58.0, 1.0, 58.0)
		cs.shape = box
		cs.position = Vector3(0, -0.5, 0)
		floor_body.add_child(cs)
		var road := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(58.0, 58.0)
		road.mesh = pm
		road.material_override = _load_pbr_mat("asphalt_02", Vector3(16, 16, 1), Color(0.16, 0.17, 0.19))
		floor_body.add_child(road)
		add_child(floor_body)

		var yellow_mat := StandardMaterial3D.new()
		yellow_mat.albedo_color = Color(0.86, 0.66, 0.14)
		yellow_mat.roughness = 0.85
		for sx in [-0.18, 0.18]:
			var line := MeshInstance3D.new()
			var lm := PlaneMesh.new()
			lm.size = Vector2(0.14, 52.0)
			line.mesh = lm
			line.position = Vector3(sx, 0.01, 0)
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.material_override = yellow_mat
			add_child(line)

		var white_mat := StandardMaterial3D.new()
		white_mat.albedo_color = Color(0.82, 0.82, 0.80)
		white_mat.roughness = 0.88
		for z_off in [-15.0, 15.0]:
			for ix in range(-4, 5):
				var stripe := MeshInstance3D.new()
				var sm := PlaneMesh.new()
				sm.size = Vector2(0.55, 2.2)
				stripe.mesh = sm
				stripe.position = Vector3(float(ix) * 1.4, 0.011, z_off)
				stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				stripe.material_override = white_mat
				add_child(stripe)

		var pave_mat := _load_pbr_mat("concrete_pavement", Vector3(3, 14, 1), Color(0.42, 0.41, 0.39))
		for side_x in [-18.5, 18.5]:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.position = Vector3(side_x, 0.08, 0)
			var col := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(14.0, 0.16, 54.0)
			col.shape = bx
			sb.add_child(col)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(14.0, 0.16, 54.0)
			mi.mesh = bm
			mi.material_override = pave_mat
			sb.add_child(mi)
			add_child(sb)

	func _build_perimeter_buildings() -> void:
		var brick_mat := _load_pbr_mat("brick_wall_001", Vector3(6, 2.2, 1), Color(0.48, 0.26, 0.20))
		var iron_mat := _load_pbr_mat("corrugated_iron", Vector3(4, 1.5, 1), Color(0.32, 0.35, 0.38))
		var wall_mat := _load_pbr_mat("concrete_wall_008", Vector3(8, 1.5, 1), Color(0.38, 0.37, 0.35))
		var walls := [
			[Vector3(0, 3.0, -BLOCK_HALF), Vector3(54.0, 6.0, 2.0), wall_mat],
			[Vector3(0, 3.0, BLOCK_HALF), Vector3(54.0, 6.0, 2.0), wall_mat],
			[Vector3(-BLOCK_HALF, 4.5, 0), Vector3(2.0, 9.0, 54.0), brick_mat],
			[Vector3(BLOCK_HALF, 4.5, 0), Vector3(2.0, 9.0, 54.0), brick_mat],
			[Vector3(-19.5, 3.2, -10.0), Vector3(8.5, 6.4, 12.0), brick_mat],
			[Vector3(19.5, 2.8, 10.0), Vector3(8.5, 5.6, 11.0), iron_mat],
		]
		for w in walls:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.position = w[0]
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = w[1]
			cs.shape = bx
			sb.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = w[1]
			mi.mesh = bm
			mi.material_override = w[2]
			sb.add_child(mi)
			add_child(sb)
		_spawn_prop("exterior_aircon_unit", Vector3(-15.0, 2.6, -9.0), 90.0, Vector3(0.9, 0.65, 0.4), Color(0.6, 0.6, 0.6), false, true)
		_spawn_prop("exterior_aircon_unit", Vector3(-15.0, 2.6, -12.5), 90.0, Vector3(0.9, 0.65, 0.4), Color(0.6, 0.6, 0.6), false, true)

	func _build_distant_skyline() -> void:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.instance_count = 44
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		mm.mesh = bm
		for i in range(44):
			var angle := (float(i) / 44.0) * TAU + randf_range(-0.04, 0.04)
			var radius := randf_range(44.0, 88.0)
			var w := randf_range(8.0, 18.0)
			var d := randf_range(8.0, 18.0)
			var h := randf_range(16.0, 56.0)
			var pos := Vector3(cos(angle) * radius, h * 0.5 - 1.0, sin(angle) * radius)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(w, h, d)), pos))
			var shade := randf_range(0.14, 0.28)
			mm.set_instance_color(i, Color(shade * 1.1, shade * 1.0, shade * 1.15))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.85
		mmi.material_override = mat
		add_child(mmi)

	func _build_gta_street_props() -> void:
		for c in [[Vector3(-8.5, 0, -4.5), 14.0], [Vector3(8.5, 0, 5.5), -168.0], [Vector3(-8.2, 0, 12.0), -6.0], [Vector3(8.2, 0, -13.5), 174.0]]:
			_spawn_prop("covered_car", c[0], c[1], Vector3(2.1, 1.45, 4.4), Color(0.55, 0.52, 0.46), false, false, 1.9)
		for b in [[Vector3(-3.2, 0, -8.5), 12.0, "concrete_road_barrier"], [Vector3(3.4, 0, -6.0), -18.0, "concrete_road_barrier_02"], [Vector3(-2.8, 0, 6.5), -10.0, "concrete_road_barrier_02"], [Vector3(3.2, 0, 9.0), 15.0, "concrete_road_barrier"], [Vector3(0.0, 0, -18.0), 0.0, "concrete_road_barrier"]]:
			_spawn_prop(b[2], b[0], b[1], Vector3(2.6, 1.05, 0.8), Color(0.5, 0.5, 0.5))
		for cr in [[Vector3(-12.5, 0, 2.0), 22.0, "wooden_crate_01"], [Vector3(12.5, 0, -2.5), -15.0, "plastic_crate_02"], [Vector3(-13.0, 0, 14.0), 8.0, "portable_generator"], [Vector3(13.0, 0, -16.0), -30.0, "portable_generator"]]:
			_spawn_prop(cr[2], cr[0], cr[1], Vector3(1.5, 1.2, 1.2), Color(0.36, 0.34, 0.28))
		for cl in [[Vector3(-11.8, 0.16, -2.0), 0.0, "fire_hydrant"], [Vector3(11.8, 0.16, 1.5), 180.0, "fire_hydrant"], [Vector3(-12.0, 0.16, 7.5), 25.0, "metal_trash_can"], [Vector3(12.2, 0.16, -8.5), -20.0, "metal_trash_can"], [Vector3(-14.0, 0.16, -1.5), 40.0, "cardboard_box_01"], [Vector3(14.0, 0.16, 16.5), -15.0, "metal_jerrycan_green"]]:
			_spawn_prop(cl[2], cl[0], cl[1], Vector3(0.6, 0.9, 0.6), Color(0.4, 0.35, 0.3), false, true)
		spawn_barrels()

	func spawn_barrels() -> void:
		for old in barrels:
			if is_instance_valid(old):
				old.queue_free()
		barrels.clear()
		for pos in [Vector3(-5.8, 0, -3.5), Vector3(5.8, 0, -10.5), Vector3(-5.5, 0, 10.5), Vector3(6.2, 0, 2.5), Vector3(0.0, 0, -12.0), Vector3(11.5, 0.16, -1.0)]:
			barrels.append(_spawn_prop("propane_tank", pos, randf() * 360.0, Vector3(0.7, 1.15, 0.7), Color(0.85, 0.18, 0.12), true))

	func _spawn_prop(slug: String, pos: Vector3, yaw_deg: float, fallback_size: Vector3, fallback_col: Color, is_barrel: bool = false, cull_far: bool = false, shadow_radius: float = 1.0) -> Node3D:
		var root := StaticBody3D.new()
		root.position = pos
		root.rotation_degrees.y = yaw_deg
		root.collision_layer = 9 if is_barrel else 1
		var gltf_path := "res://assets/polyhaven/%s/model.gltf" % slug
		var visual: Node3D = null
		if ResourceLoader.exists(gltf_path):
			var packed := load(gltf_path)
			if packed is PackedScene:
				visual = packed.instantiate()
		if visual == null:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = fallback_size
			mi.mesh = bm
			mi.position.y = fallback_size.y * 0.5
			var mat := StandardMaterial3D.new()
			mat.albedo_color = fallback_col
			mi.material_override = mat
			visual = mi
		if cull_far:
			_apply_distance_cull(visual, 42.0)
		root.add_child(visual)
		var bounds := _get_bounds(visual)
		if bounds.size.length() < 0.05:
			bounds = AABB(Vector3(-fallback_size.x * 0.5, 0, -fallback_size.z * 0.5), fallback_size)
		else:
			visual.position.y -= bounds.position.y
			bounds.position.y = 0.0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size.max(Vector3(0.4, 0.4, 0.4))
		cs.shape = box
		cs.position = bounds.get_center()
		root.add_child(cs)
		add_contact_shadow(root, maxf(shadow_radius, maxf(bounds.size.x, bounds.size.z) * 0.52), 0.48)
		if is_barrel:
			root.set_meta("is_barrel", true)
			root.set_meta("exploded", false)
		add_child(root)
		return root

	func _apply_distance_cull(node: Node, max_dist: float) -> void:
		if node is GeometryInstance3D:
			var gi := node as GeometryInstance3D
			gi.visibility_range_end = max_dist
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for c in node.get_children():
			_apply_distance_cull(c, max_dist)

	func trigger_barrel(barrel_node: Node3D) -> void:
		if not is_instance_valid(barrel_node) or barrel_node.get_meta("exploded", false):
			return
		barrel_node.set_meta("exploded", true)
		var p := barrel_node.global_position + Vector3(0, 0.6, 0)
		barrel_node.visible = false
		barrel_node.collision_layer = 0
		AudioBank.play("explosion", 1.5, 0.05)
		barrel_exploded.emit(p, 7.8, 185)

	func _get_bounds(node: Node) -> AABB:
		var box := AABB()
		var found := false
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				box = mi.mesh.get_aabb()
				found = true
		for c in node.get_children():
			var cb := _get_bounds(c)
			if cb.size.length() > 0.01:
				box = cb if not found else box.merge(cb)
				found = true
		return box


class EnemyBot extends CharacterBody3D:
	signal died(bot: Node3D, was_headshot: bool)
	signal fired_at_player(origin: Vector3, dir: Vector3)
	enum Archetype { TROOPER, RUSHER, JUGGERNAUT }
	var bot_type: Archetype = Archetype.TROOPER
	var hp: int = 95
	var max_hp: int = 95
	var move_speed: float = 3.8
	var fire_rate: float = 1.4
	var target_player: Node3D
	var _visual: Node3D
	var _head_area: Area3D
	var _hp_bar: MeshInstance3D
	var _fire_cd: float = 1.2
	var _strafe_dir: float = 1.0
	var _strafe_cd: float = 1.8
	var _dead: bool = false
	var _death_timer: float = 0.0

	func setup(kind: int, wave: int, player_ref: Node3D, blob_tex: Texture2D) -> void:
		bot_type = kind as Archetype
		target_player = player_ref
		if bot_type == Archetype.RUSHER:
			max_hp = 72 + wave * 8; move_speed = 5.4; fire_rate = 1.15
		elif bot_type == Archetype.JUGGERNAUT:
			max_hp = 200 + wave * 28; move_speed = 2.7; fire_rate = 0.85
		else:
			max_hp = 95 + wave * 12; move_speed = 3.8; fire_rate = 1.35
		hp = max_hp
		_fire_cd = randf_range(0.8, 1.8)
		set_meta("blob_tex", blob_tex)
		set_meta("is_dead", false)

	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1 | 2
		var body_col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.34
		cap.height = 1.38
		body_col.shape = cap
		body_col.position = Vector3(0, 0.72, 0)
		add_child(body_col)

		_head_area = Area3D.new()
		_head_area.collision_layer = 4
		_head_area.collision_mask = 0
		_head_area.position = Vector3(0, 1.62, 0)
		_head_area.set_meta("bot_owner", self)
		var head_col := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.24
		head_col.shape = sp
		_head_area.add_child(head_col)
		add_child(_head_area)

		var SoldierScript := load("res://scripts/SoldierVisual.gd")
		_visual = SoldierScript.new()
		var ucol := Color(0.24, 0.22, 0.23)
		var acol := Color(0.45, 0.14, 0.14)
		var vcol := Color(1.0, 0.25, 0.15)
		var scl := 1.0
		if bot_type == Archetype.RUSHER:
			ucol = Color(0.32, 0.22, 0.18); acol = Color(0.68, 0.38, 0.12); vcol = Color(1.0, 0.85, 0.15)
		elif bot_type == Archetype.JUGGERNAUT:
			ucol = Color(0.14, 0.15, 0.18); acol = Color(0.55, 0.12, 0.32); vcol = Color(1.0, 0.12, 0.55); scl = 1.16
		add_child(_visual)
		_visual.build_soldier(ucol, acol, vcol, scl)

		_hp_bar = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.85, 0.09)
		_hp_bar.mesh = qm
		_hp_bar.position = Vector3(0, 2.05 * scl, 0)
		_hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hp_mat := StandardMaterial3D.new()
		hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hp_mat.albedo_color = Color(0.95, 0.22, 0.18)
		_hp_bar.material_override = hp_mat
		_hp_bar.visible = false
		add_child(_hp_bar)

		if has_meta("blob_tex"):
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.25 * scl, 1.25 * scl)
			mi.mesh = pm
			mi.position.y = 0.02
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_texture = get_meta("blob_tex")
			sm.albedo_color = Color(0.02, 0.02, 0.04, 0.52)
			mi.material_override = sm
			add_child(mi)

	func take_damage(amount: int, is_headshot: bool) -> void:
		if _dead:
			return
		hp -= amount
		_hp_bar.visible = true
		_hp_bar.scale.x = clampf(float(hp) / float(max_hp), 0.02, 1.0)
		if hp <= 0:
			_dead = true
			set_meta("is_dead", true)
			collision_layer = 0
			collision_mask = 1
			_head_area.collision_layer = 0
			_hp_bar.visible = false
			_death_timer = 2.1
			_visual.play_action("death", 2.1, true)
			died.emit(self, is_headshot)
		else:
			_visual.play_action("hit_head" if is_headshot else "hit_chest", 0.34)

	func _physics_process(delta: float) -> void:
		if _dead:
			_death_timer -= delta
			if _death_timer <= 0.0:
				queue_free()
			return
		if target_player == null:
			return
		var to_player := target_player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized() if dist > 0.01 else Vector3.FORWARD
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))

		_strafe_cd -= delta
		if _strafe_cd <= 0.0:
			_strafe_cd = randf_range(1.2, 2.4)
			_strafe_dir = -1.0 if randf() < 0.5 else 1.0
		var right := dir.cross(Vector3.UP).normalized()
		var ideal_dist := 3.5 if bot_type == Archetype.RUSHER else 13.0
		var move_vec := (dir + right * _strafe_dir * 0.35) if dist > ideal_dist + 2.2 else ((-dir * 0.45 + right * _strafe_dir * 0.75) if dist < ideal_dist - 2.2 else right * _strafe_dir)
		velocity.y = (velocity.y - 22.0 * delta) if not is_on_floor() else 0.0
		var flat := move_vec.normalized() * move_speed
		velocity.x = flat.x
		velocity.z = flat.z
		move_and_slide()

		var spd := Vector2(velocity.x, velocity.z).length()
		_visual.set_locomotion("sprint" if spd > 4.4 else ("jog" if spd > 2.2 else ("walk" if spd > 0.45 else "idle")))

		_fire_cd -= delta
		if _fire_cd <= 0.0 and dist < 34.0:
			_fire_cd = fire_rate * randf_range(0.85, 1.2)
			var eye := global_position + Vector3(0, 1.42, 0)
			var target_pt := target_player.global_position + Vector3(0, 1.15, 0)
			var q := PhysicsRayQueryParameters3D.create(eye, target_pt, 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				AudioBank.play("enemy_fire", -7.0, 0.1)
				_visual.play_action("shoot", 0.25)
				var shot_dir := (target_pt - eye).normalized()
				fired_at_player.emit(eye + shot_dir * 0.5, shot_dir)


class PlayerTPS extends CharacterBody3D:
	signal stats_changed()
	signal hit_confirmed(is_headshot: bool, is_kill: bool)
	signal player_died()
	signal tracer_spawned(start_pt: Vector3, end_pt: Vector3)
	signal grenade_thrown(origin: Vector3, vel: Vector3)
	const WEAPONS := [
		{"name": "CARBINE", "sfx": "rifle", "dmg": 36, "rate": 0.115, "mag": 30, "reload": 1.35, "pellets": 1, "spread": 0.013, "ads_fov": 48.0},
		{"name": "SHOTGUN", "sfx": "shotgun", "dmg": 23, "rate": 0.68, "mag": 6, "reload": 1.55, "pellets": 7, "spread": 0.065, "ads_fov": 54.0},
		{"name": "PISTOL", "sfx": "pistol", "dmg": 44, "rate": 0.20, "mag": 12, "reload": 1.05, "pellets": 1, "spread": 0.008, "ads_fov": 50.0},
	]
	var hp: int = 100
	var max_hp: int = 100
	var armor: int = 50
	var grenades: int = 2
	var look_sensitivity: float = 0.0040
	var auto_fire_assist: bool = true
	var first_person: bool = false
	var is_ads: bool = false
	var is_crouching: bool = false
	var weapon_idx: int = 0
	var ammo: Array[int] = [30, 6, 12]
	var reserve: Array[int] = [180, 36, 999]
	var is_reloading: bool = false
	var camera: Camera3D
	var _cam_rig: Node3D
	var _spring: SpringArm3D
	var _visual: Node3D
	var _muzzle_light: OmniLight3D
	var _yaw: float = 0.0
	var _pitch: float = -0.10
	var _move_input: Vector2 = Vector2.ZERO
	var _firing_held: bool = false
	var _jump_queued: bool = false
	var _roll_timer: float = 0.0
	var _roll_dir: Vector3 = Vector3.ZERO
	var _fire_timer: float = 0.0
	var _reload_timer: float = 0.0
	var _flash_timer: float = 0.0
	var _shake: float = 0.0

	func setup_visual(blob_tex: Texture2D) -> void:
		var SoldierScript := load("res://scripts/SoldierVisual.gd")
		_visual = SoldierScript.new()
		add_child(_visual)
		_visual.build_soldier(Color(0.24, 0.28, 0.22), Color(0.18, 0.22, 0.26), Color(0.0, 0.90, 1.0), 1.0)
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.25, 1.25)
		mi.mesh = pm
		mi.position.y = 0.02
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_texture = blob_tex
		sm.albedo_color = Color(0.02, 0.02, 0.04, 0.55)
		mi.material_override = sm
		add_child(mi)

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.75
		cs.shape = cap
		cs.position = Vector3(0, 0.88, 0)
		add_child(cs)
		_cam_rig = Node3D.new()
		_cam_rig.position = Vector3(0.58, 1.56, 0.0)
		add_child(_cam_rig)
		_spring = SpringArm3D.new()
		_spring.collision_mask = 1
		_spring.spring_length = 2.85
		_spring.margin = 0.25
		_cam_rig.add_child(_spring)
		camera = Camera3D.new()
		camera.fov = 66.0
		camera.near = 0.08
		camera.far = 160.0
		camera.current = true
		_spring.add_child(camera)
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.light_color = Color(1.0, 0.72, 0.28)
		_muzzle_light.light_energy = 4.0
		_muzzle_light.
