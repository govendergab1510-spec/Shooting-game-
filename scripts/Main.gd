extends Node3D

enum State { MENU, PLAYING, GAMEOVER }

var _actors_res = null
var _ready_done: bool = false
var _match_active: bool = false
var _state: State = State.MENU
var _score: int = 0
var _kills: int = 0
var _combo: int = 1
var _combo_timer: float = 0.0
var _wave: int = 1
var _to_spawn: int = 0
var _spawn_cd: float = 0.0

var _arena: Node3D
var _player: CharacterBody3D
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
var _menu_cam: Camera3D
var _menu_cam_angle: float = 0.0
var _ui: CanvasLayer

var _bots: Array[Node3D] = []
var _pickups: Array[Node3D] = []
var _grenades: Array[Dictionary] = []
var _tracer_pool: Array[Dictionary] = []
var _shot_pool: Array[Dictionary] = []
var _blast_pool: Array[Dictionary] = []

var _joy_finger: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _look_finger: int = -1
var _fire_finger: int = -1

func _play_sfx(key: String, vol_db: float = -2.0, jitter: float = 0.05) -> void:
	var ab := get_node_or_null("/root/AudioBank")
	if ab != null:
		ab.play(key, vol_db, jitter)

func _ready() -> void:
	var ui_res = load("res://scripts/GameUI.gd")
	if ui_res == null:
		return
	_ui = ui_res.new()
	add_child(_ui)
	_ui.init_loading()
	await get_tree().process_frame

	_actors_res = load("res://scripts/Actors.gd")
	if _actors_res == null:
		_ui.loading_lbl.text = "ERROR: Failed to load Actors.gd"
		return

	_setup_env()
	_ui.loading_lbl.text = "OUTPOST ZERO\nBuilding Poly Haven Street..."
	await get_tree().process_frame

	_setup_world()
	_ui.loading_lbl.text = "OUTPOST ZERO\nPreparing Tactical Gear..."
	await get_tree().process_frame

	_setup_pools()
	_ui.play_clicked.connect(_start_match)
	_ui.resume_clicked.connect(_resume_match)
	_ui.title_clicked.connect(_return_to_title)
	_ui.pause_clicked.connect(_open_pause_menu)
	_ui.action_clicked.connect(_on_hud_action)
	_ui.settings_updated.connect(_apply_settings)
	_ui.build_ui(_player, _bots, _arena.barrels, _pickups)
	_ready_done = true

func _setup_env() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-28.0, 38.0, 0.0)
	_sun.light_color = Color(1.0, 0.84, 0.64)
	_sun.light_energy = 1.60
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 34.0
	add_child(_sun)

	_rim = DirectionalLight3D.new()
	_rim.rotation_degrees = Vector3(-35.0, -142.0, 0.0)
	_rim.light_color = Color(0.42, 0.62, 0.95)
	_rim.light_energy = 0.45
	_rim.shadow_enabled = false
	add_child(_rim)

	var sky := Sky.new()
	var pmat := ProceduralSkyMaterial.new()
	pmat.sky_top_color = Color(0.14, 0.28, 0.56)
	pmat.sky_horizon_color = Color(0.96, 0.54, 0.26)
	pmat.sky_curve = 0.18
	pmat.ground_bottom_color = Color(0.16, 0.14, 0.14)
	pmat.ground_horizon_color = Color(0.62, 0.38, 0.26)
	pmat.sun_angle_max = 12.0
	sky.sky_material = pmat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.adjustment_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.84, 0.58, 0.46)
	env.fog_density = 0.0075

	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 62.0
	_menu_cam.near = 0.2
	_menu_cam.far = 140.0
	_menu_cam.position = Vector3(14.0, 6.8, 14.0)
	add_child(_menu_cam)
	_menu_cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)
	_menu_cam.current = true

func _setup_world() -> void:
	_arena = _actors_res.ArenaBuilder.new()
	_arena.build_arena()
	_arena.barrel_exploded.connect(_on_blast)
	add_child(_arena)

	_player = _actors_res.PlayerTPS.new()
	_player.stats_changed.connect(_refresh_hud)
	_player.hit_confirmed.connect(_on_hit_confirmed)
	_player.player_died.connect(_on_player_died)
	_player.tracer_spawned.connect(_spawn_tracer)
	_player.grenade_thrown.connect(_spawn_grenade)
	add_child(_player)
	_player.setup_visual(_arena.get_blob_texture())
	_player.reset_player()
	_menu_cam.current = true

func _setup_pools() -> void:
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(0.022, 0.022, 1.0)
	var t_mat := StandardMaterial3D.new()
	t_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	t_mat.albedo_color = Color(1.0, 0.86, 0.35)
	for i in range(24):
		var m := MeshInstance3D.new()
		m.mesh = t_mesh
		m.material_override = t_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_tracer_pool.append({"node": m, "life": 0.0})

	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.075
	s_mesh.height = 0.15
	s_mesh.radial_segments = 8
	s_mesh.rings = 4
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(1.0, 0.32, 0.14)
	for i in range(18):
		var sm := MeshInstance3D.new()
		sm.mesh = s_mesh
		sm.material_override = s_mat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sm.visible = false
		add_child(sm)
		_shot_pool.append({"node": sm, "vel": Vector3.ZERO, "life": 0.0})

	var b_mesh := SphereMesh.new()
	b_mesh.radius = 1.0
	b_mesh.height = 2.0
	b_mesh.radial_segments = 14
	b_mesh.rings = 7
	for i in range(8):
		var bm := MeshInstance3D.new()
		bm.mesh = b_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
		bm.material_override = mat
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bm.visible = false
		add_child(bm)
		_blast_pool.append({"node": bm, "mat": mat, "life": 0.0})

func _apply_settings(preset: int, shadows: bool, fog: bool, msaa: bool, fps_cap: int, _show_fps: bool, muted: bool, sens_idx: int, auto_fire: bool) -> void:
	if _sun != null:
		_sun.shadow_enabled = shadows
		_sun.directional_shadow_max_distance = 28.0 if preset == 0 else (34.0 if preset == 1 else 44.0)
	if _rim != null:
		_rim.visible = (preset > 0)
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.fog_enabled = fog
	var far_dist := 90.0 if preset == 0 else (140.0 if preset == 1 else 180.0)
	if _player != null:
		_player.auto_fire_assist = auto_fire
		_player.look_sensitivity = [0.0028, 0.0040, 0.0056][sens_idx]
		if _player.camera != null:
			_player.camera.far = far_dist
	if _menu_cam != null:
		_menu_cam.far = far_dist
	get_viewport().msaa_3d = Viewport.MSAA_2X if msaa else Viewport.MSAA_DISABLED
	Engine.max_fps = fps_cap
	AudioServer.set_bus_mute(0, muted)

func _on_hud_action(act: String) -> void:
	if act == "swap":
		_player.switch_weapon()
	elif act == "reload":
		_player.start_reload()
	elif act == "roll":
		_player.queue_roll()
	elif act == "crouch":
		_player.toggle_crouch()
	elif act == "jump":
		_player.queue_jump()
	elif act == "aim":
		_player.toggle_ads()
	elif act == "nade":
		_player.throw_grenade()
	elif act == "cam":
		_player.toggle_camera_mode()

func _open_pause_menu() -> void:
	_state = State.MENU

func _resume_match() -> void:
	_player.camera.current = true
	_state = State.PLAYING

func _return_to_title() -> void:
	_match_active = false
	_state = State.MENU
	_menu_cam.current = true

func _start_match() -> void:
	for b in _bots:
		if is_instance_valid(b):
			b.queue_free()
	_bots.clear()
	for s in _shot_pool:
		s["life"] = 0.0
		s["node"].visible = false
	for tr in _tracer_pool:
		tr["life"] = 0.0
		tr["node"].visible = false
	for pk in _pickups:
		pk.queue_free()
	_pickups.clear()
	for g in _grenades:
		g["node"].queue_free()
	_grenades.clear()
	_arena.spawn_barrels()
	_player.reset_player()
	_player.camera.current = true
	_match_active = true
	_score = 0
	_kills = 0
	_combo = 1
	_combo_timer = 0.0
	_wave = 1
	_begin_wave(1)
	_state = State.PLAYING
	_refresh_hud()

func _begin_wave(w: int) -> void:
	_wave = w
	_to_spawn = 4 + w * 2
	_spawn_cd = 0.8
	_ui.show_banner("WAVE %d • HOSTILES INBOUND" % w, 2.4)
	_refresh_hud()

func _refresh_hud() -> void:
	if _ui == null or _ui.lbl_hp == null:
		return
	var spec: Dictionary = _player.get_spec()
	var idx: int = _player.weapon_idx
	var r_txt := " (RELOADING)" if _player.is_reloading else ""
	_ui.lbl_hp.text = "HP %d  •  ARMOR %d  •  NADE x%d" % [_player.hp, _player.armor, _player.grenades]
	_ui.lbl_ammo.text = "%s  %d | %d%s" % [spec["name"], _player.ammo[idx], _player.reserve[idx], r_txt]
	var c_txt := ("  %dx" % _combo) if _combo > 1 else ""
	_ui.lbl_wave.text = "WAVE %d  •  $%d%s" % [_wave, _score, c_txt]

func _input(event: InputEvent) -> void:
	if not _ready_done or _state != State.PLAYING:
		return
	var vp_sz := get_viewport().get_visible_rect().size
	var fire_rect := Rect2(vp_sz.x - 215, vp_sz.y - 255, 118, 105)
	if event is InputEventScreenTouch:
		if event.pressed:
			if fire_rect.has_point(event.position):
				_fire_finger = event.index
				_player.set_firing(true)
			elif event.position.x < vp_sz.x * 0.42 and _joy_finger == -1:
				_joy_finger = event.index
				_joy_origin = event.position
				_ui.joy_ring.position = _joy_origin - _ui.joy_ring.size * 0.5
				_ui.joy_knob.position = _joy_origin - _ui.joy_knob.size * 0.5
				_ui.joy_ring.visible = true
				_ui.joy_knob.visible = true
			elif _look_finger == -1:
				_look_finger = event.index
		else:
			if event.index == _fire_finger:
				_fire_finger = -1
				_player.set_firing(false)
			elif event.index == _joy_finger:
				_joy_finger = -1
				_ui.joy_ring.visible = false
				_ui.joy_knob.visible = false
				_player.set_move_vector(Vector2.ZERO)
			elif event.index == _look_finger:
				_look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			var diff: Vector2 = event.position - _joy_origin
			if diff.length() > 54.0:
				diff = diff.normalized() * 54.0
			_ui.joy_knob.position = _joy_origin + diff - _ui.joy_knob.size * 0.5
			_player.set_move_vector(diff / 54.0)
		elif event.index == _look_finger:
			_player.add_look_delta(event.relative)

func _process(delta: float) -> void:
	if not _ready_done:
		return
	_ui.tick_timers(delta, Engine.get_frames_per_second())

	if _state == State.MENU and not _match_active and _menu_cam != null:
		_menu_cam_angle += delta * 0.14
		_menu_cam.position = Vector3(cos(_menu_cam_angle) * 16.0, 6.8, sin(_menu_cam_angle) * 16.0)
		_menu_cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)
		return

	if _state != State.PLAYING:
		return
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 1
			_refresh_hud()

	var live_count := 0
	for i in range(_bots.size() - 1, -1, -1):
		if not is_instance_valid(_bots[i]):
			_bots.remove_at(i)
		elif not _bots[i].get_meta("is_dead", false):
			live_count += 1

	if _to_spawn > 0 and live_count < 6:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = 1.6
			_spawn_bot()
			_to_spawn -= 1
	elif _to_spawn == 0 and live_count == 0:
		_score += _wave * 300
		_player.heal_and_resupply()
		_begin_wave(_wave + 1)

	_update_enemy_shots(delta)
	_update_tracers(delta)
	_update_blasts(delta)
	_update_grenades(delta)
	_update_pickups(delta)

func _spawn_bot() -> void:
	var bot: CharacterBody3D = _actors_res.EnemyBot.new()
	var roll := randf()
	var kind := 1 if (_wave >= 2 and roll < 0.30) else (2 if (_wave >= 3 and roll > 0.80) else 0)
	bot.setup(kind, _wave, _player, _arena.get_blob_texture())
	bot.add_to_group("bots")
	var spots := [Vector3(-12, 0.2, -21), Vector3(12, 0.2, -21), Vector3(0, 0.2, -22), Vector3(-21, 0.2, -2), Vector3(21, 0.2, -4)]
	bot.position = spots[randi() % spots.size()]
	bot.died.connect(_on_bot_died)
	bot.fired_at_player.connect(_on_bot_fired)
	add_child(bot)
	_bots.append(bot)

func _on_bot_died(bot: Node3D, was_headshot: bool) -> void:
	_kills += 1
	_combo = mini(6, _combo + 1)
	_combo_timer = 5.0
	_score += (200 if was_headshot else 120) * _combo
	if randf() < 0.42:
		_spawn_pickup(bot.global_position + Vector3(0, 0.45, 0))
	_refresh_hud()

func _on_hit_confirmed(is_headshot: bool, is_kill: bool) -> void:
	_ui.show_hit(is_headshot, is_kill)

func _on_bot_fired(origin: Vector3, dir: Vector3) -> void:
	for s in _shot_pool:
		if s["life"] <= 0.0:
			var n: Node3D = s["node"]
			n.position = origin
			n.visible = true
			s["vel"] = dir * 24.0
			s["life"] = 2.2
			return

func _update_enemy_shots(delta: float) -> void:
	for s in _shot_pool:
		if s["life"] <= 0.0:
			continue
		s["life"] -= delta
		var n: Node3D = s["node"]
		var next_pos: Vector3 = n.position + s["vel"] * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(n.position, next_pos, 1 | 16))
		if not hit.is_empty():
			if hit["collider"] == _player:
				_player.take_damage(12)
				_ui.flash_damage()
			s["life"] = 0.0
		n.position = next_pos
		if s["life"] <= 0.0:
			n.visible = false

func on_barrel_shot(barrel_node: Node3D) -> void:
	_arena.trigger_barrel(barrel_node)

func _spawn_grenade(origin: Vector3, vel: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.42, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 2.0
	m.material_override = mat
	m.position = origin
	add_child(m)
	_grenades.append({"node": m, "vel": vel, "fuse": 1.35})

func _update_grenades(delta: float) -> void:
	for i in range(_grenades.size() - 1, -1, -1):
		var g := _grenades[i]
		g["fuse"] -= delta
		g["vel"].y -= 18.0 * delta
		var n: Node3D = g["node"]
		var next_pos: Vector3 = n.position + g["vel"] * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(n.position, next_pos, 1))
		if not hit.is_empty():
			g["vel"] = g["vel"].bounce(hit["normal"]) * 0.45
			next_pos = hit["position"] + hit["normal"] * 0.14
		if next_pos.y < 0.14:
			next_pos.y = 0.14
			g["vel"].y = absf(g["vel"].y) * 0.42
			g["vel"].x *= 0.72
			g["vel"].z *= 0.72
		n.position = next_pos
		if g["fuse"] <= 0.0:
			var pos := n.position
			n.queue_free()
			_grenades.remove_at(i)
			_play_sfx("explosion", 1.5, 0.05)
			_on_blast(pos, 8.5, 220)

func _on_blast(pos: Vector3, radius: float, dmg: int) -> void:
	for b in _blast_pool:
		if b["life"] <= 0.0:
			var n: Node3D = b["node"]
			n.position = pos
			n.scale = Vector3.ONE
			n.visible = true
			b["life"] = 0.45
			break
	for bot in _bots:
		if is_instance_valid(bot) and not bot.get_meta("is_dead", false) and bot.global_position.distance_to(pos) <= radius:
			bot.take_damage(dmg, false)
	for barrel in _arena.barrels:
		if is_instance_valid(barrel) and not barrel.get_meta("exploded", false) and barrel.global_position.distance_to(pos) <= radius:
			_arena.trigger_barrel(barrel)

func _update_blasts(delta: float) -> void:
	for b in _blast_pool:
		if b["life"] <= 0.0:
			continue
		b["life"] -= delta
		var n: Node3D = b["node"]
		var m: StandardMaterial3D = b["mat"]
		var t := 1.0 - clampf(float(b["life"]) / 0.45, 0.0, 1.0)
		n.scale = Vector3.ONE * (1.0 + t * 7.0)
		m.albedo_color.a = (1.0 - t) * 0.85
		if b["life"] <= 0.0:
			n.visible = false

func _spawn_tracer(start_pt: Vector3, end_pt: Vector3) -> void:
	var dist := start_pt.distance_to(end_pt)
	if dist < 0.25:
		return
	var dir := (end_pt - start_pt).normalized()
	var up_vec := Vector3.FORWARD if absf(dir.y) > 0.98 else Vector3.UP
	for tr in _tracer_pool:
		if tr["life"] <= 0.0:
			var n: Node3D = tr["node"]
			n.global_position = (start_pt + end_pt) * 0.5
			n.look_at(end_pt, up_vec)
			n.scale = Vector3(1.0, 1.0, dist)
			n.visible = true
			tr["life"] = 0.055
			return

func _update_tracers(delta: float) -> void:
	for tr in _tracer_pool:
		if tr["life"] <= 0.0:
			continue
		tr["life"] -= delta
		if tr["life"] <= 0.0:
			tr["node"].visible = false

func _spawn_pickup(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.35, 0.45)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.92, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.92, 0.45)
	mat.emission_energy_multiplier = 1.8
	m.material_override = mat
	m.position = pos
	add_child(m)
	_pickups.append(m)

func _update_pickups(delta: float) -> void:
	for i in range(_pickups.size() - 1, -1, -1):
		var p := _pickups[i]
		p.rotate_y(delta * 2.2)
		if p.global_position.distance_to(_player.global_position + Vector3(0, 0.8, 0)) < 1.9:
			_player.heal_and_resupply()
			_play_sfx("reload", -6.0, 0.05)
			p.queue_free()
			_pickups.remove_at(i)

func _on_player_died() -> void:
	_match_active = false
	_state = State.GAMEOVER
	_ui.show_gameover(_wave, _kills, _score)
