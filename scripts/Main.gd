extends Node3D

const Actors = preload("res://scripts/Actors.gd")

enum State { MENU, PLAYING, GAMEOVER }

var _ready_done: bool = false
var _state: State = State.MENU
var _score: int = 0
var _kills: int = 0
var _combo: int = 1
var _combo_timer: float = 0.0
var _wave: int = 1
var _to_spawn: int = 0
var _spawn_cd: float = 0.0
var _high_quality: bool = false

var _arena: Node3D
var _player: CharacterBody3D
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
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

var _ui: CanvasLayer
var _loading_bg: ColorRect
var _loading_lbl: Label
var _menu_panel: PanelContainer
var _gameover_panel: PanelContainer
var _hud: Control
var _radar: Control
var _joy_ring: ColorRect
var _joy_knob: ColorRect
var _hit_marker: Control
var _hit_timer: float = 0.0
var _dmg_vignette: ColorRect
var _dmg_timer: float = 0.0
var _lbl_hp: Label
var _lbl_ammo: Label
var _lbl_wave: Label
var _lbl_fps: Label
var _lbl_banner: Label
var _banner_timer: float = 0.0
var _lbl_crit: Label
var _crit_timer: float = 0.0
var _lbl_final: Label
var _btn_autofire: Button
var _btn_quality: Button
var _fire_btn_rect: Rect2

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	_loading_bg = ColorRect.new()
	_loading_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_bg.color = Color(0.08, 0.09, 0.12, 1.0)
	_ui.add_child(_loading_bg)

	_loading_lbl = Label.new()
	_loading_lbl.text = "OUTPOST ZERO\nLoading Urban Block..."
	_loading_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_loading_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.add_theme_font_size_override("font_size", 28)
	_loading_lbl.add_theme_color_override("font_color", Color(1.0, 0.58, 0.20))
	_loading_bg.add_child(_loading_lbl)

	await get_tree().process_frame
	_setup_env()
	_loading_lbl.text = "OUTPOST ZERO\nBuilding Poly Haven Street..."
	await get_tree().process_frame
	_setup_world()
	_loading_lbl.text = "OUTPOST ZERO\nPreparing Tactical Gear..."
	await get_tree().process_frame
	_setup_pools()
	_setup_ui()

	_loading_bg.queue_free()
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

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-35.0, -142.0, 0.0)
	rim.light_color = Color(0.42, 0.62, 0.95)
	rim.light_energy = 0.45
	rim.shadow_enabled = false
	add_child(rim)

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

func _setup_world() -> void:
	_arena = Actors.ArenaBuilder.new()
	_arena.build_arena()
	_arena.barrel_exploded.connect(_on_blast)
	add_child(_arena)

	_player = Actors.PlayerTPS.new()
	_player.stats_changed.connect(_refresh_hud)
	_player.hit_confirmed.connect(_on_hit_confirmed)
	_player.player_died.connect(_on_player_died)
	_player.tracer_spawned.connect(_spawn_tracer)
	_player.grenade_thrown.connect(_spawn_grenade)
	add_child(_player)
	_player.setup_visual(_arena.get_blob_texture())
	_player.reset_player()

func _setup_pools() -> void:
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(0.022, 0.022, 1.0)
	var t_mat := StandardMaterial3D.new()
	t_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	t_mat.albedo_color = Color(1.0, 0.86, 0.35)
	for i in range(24):
		var m := MeshInstance3D.new()
		m.mesh = t_mesh; m.material_override = t_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false; add_child(m)
		_tracer_pool.append({"node": m, "life": 0.0})

	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.075; s_mesh.height = 0.15; s_mesh.radial_segments = 8; s_mesh.rings = 4
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(1.0, 0.32, 0.14)
	for i in range(18):
		var sm := MeshInstance3D.new()
		sm.mesh = s_mesh; sm.material_override = s_mat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sm.visible = false; add_child(sm)
		_shot_pool.append({"node": sm, "vel": Vector3.ZERO, "life": 0.0})

	var b_mesh := SphereMesh.new()
	b_mesh.radius = 1.0; b_mesh.height = 2.0; b_mesh.radial_segments = 14; b_mesh.rings = 7
	for i in range(8):
		var bm := MeshInstance3D.new()
		bm.mesh = b_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
		bm.material_override = mat
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bm.visible = false; add_child(bm)
		_blast_pool.append({"node": bm, "mat": mat, "life": 0.0})

func _setup_ui() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	_ui.add_child(_hud)

	_dmg_vignette = ColorRect.new()
	_dmg_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	_dmg_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_dmg_vignette)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 26; top_bar.offset_right = -26; top_bar.offset_top = 14
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top_bar)

	_lbl_hp = Label.new()
	_lbl_hp.add_theme_font_size_override("font_size", 22)
	_lbl_hp.add_theme_color_override("font_color", Color(0.38, 0.96, 0.50))
	_lbl_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_lbl_hp)

	_lbl_wave = Label.new()
	_lbl_wave.add_theme_font_size_override("font_size", 22)
	_lbl_wave.add_theme_color_override("font_color", Color(0.98, 0.80, 0.28))
	top_bar.add_child(_lbl_wave)

	_lbl_fps = Label.new()
	_lbl_fps.text = "  60 FPS"
	_lbl_fps.add_theme_font_size_override("font_size", 16)
	_lbl_fps.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	top_bar.add_child(_lbl_fps)

	var btn_pause := Button.new()
	btn_pause.text = " ☰ "; btn_pause.custom_minimum_size = Vector2(54, 42)
	btn_pause.pressed.connect(func(): _state = State.MENU; _hud.visible = false; _menu_panel.visible = true)
	top_bar.add_child(btn_pause)

	var RadarScript := load("res://scripts/RadarWidget.gd")
	_radar = RadarScript.new()
	_radar.position = Vector2(24, 58); _radar.size = Vector2(124, 124)
	_radar.player_ref = _player; _radar.enemies_ref = _bots
	_radar.barrels_ref = _arena.barrels; _radar.pickups_ref = _pickups
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_radar)

	_lbl_banner = Label.new()
	_lbl_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_banner.offset_top = 64; _lbl_banner.offset_left = -280; _lbl_banner.offset_right = 280
	_lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_banner.add_theme_font_size_override("font_size", 28)
	_lbl_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	_lbl_banner.visible = false
	_hud.add_child(_lbl_banner)

	_lbl_crit = Label.new()
	_lbl_crit.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_crit.offset_top = -65; _lbl_crit.offset_left = -140; _lbl_crit.offset_right = 140
	_lbl_crit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_crit.add_theme_font_size_override("font_size", 20)
	_lbl_crit.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_lbl_crit.visible = false
	_hud.add_child(_lbl_crit)

	var crosshair := Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(crosshair)
	for r in [Rect2(-11, -1, 6, 2), Rect2(5, -1, 6, 2), Rect2(-1, -11, 2, 6), Rect2(-1, 5, 2, 6)]:
		var cr := ColorRect.new()
		cr.position = r.position; cr.size = r.size; cr.color = Color(1.0, 1.0, 1.0, 0.90)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)

	_hit_marker = Control.new()
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.visible = false; _hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hit_marker)
	for pos in [Vector2(-10, -10), Vector2(6, -10), Vector2(-10, 6), Vector2(6, 6)]:
		var hm := ColorRect.new()
		hm.position = pos; hm.size = Vector2(4, 4); hm.color = Color(1.0, 0.35, 0.20)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hit_marker.add_child(hm)

	_lbl_ammo = Label.new()
	_lbl_ammo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lbl_ammo.offset_left = 26; _lbl_ammo.offset_bottom = -20; _lbl_ammo.offset_top = -64
	_lbl_ammo.add_theme_font_size_override("font_size", 24)
	_lbl_ammo.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_hud.add_child(_lbl_ammo)

	_joy_ring = ColorRect.new(); _joy_ring.size = Vector2(128, 128); _joy_ring.color = Color(1, 1, 1, 0.14)
	_joy_ring.visible = false; _joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_ring)

	_joy_knob = ColorRect.new(); _joy_knob.size = Vector2(48, 48); _joy_knob.color = Color(1.0, 0.62, 0.18, 0.65)
	_joy_knob.visible = false; _joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_knob)

	_add_action_btn("SWAP", Vector2(-354, -98), Vector2(80, 64), func(): _player.switch_weapon())
	_add_action_btn("RELOAD", Vector2(-266, -98), Vector2(80, 64), func(): _player.start_reload())
	_add_action_btn("ROLL", Vector2(-178, -98), Vector2(80, 64), func(): _player.queue_roll())
	_add_action_btn("CROUCH", Vector2(-90, -98), Vector2(76, 64), func(): _player.toggle_crouch())
	_add_action_btn("JUMP", Vector2(-90, -176), Vector2(76, 70), func(): _player.queue_jump())
	_add_action_btn("AIM", Vector2(-90, -255), Vector2(76, 70), func(): _player.toggle_ads())
	_add_action_btn("NADE", Vector2(-310, -176), Vector2(84, 62), func(): _player.throw_grenade())
	_add_action_btn("CAM", Vector2(-310, -246), Vector2(84, 62), func(): _player.toggle_camera_mode())

	var fire_panel := ColorRect.new()
	fire_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_panel.offset_left = -215; fire_panel.offset_right = -97
	fire_panel.offset_top = -255; fire_panel.offset_bottom = -150
	fire_panel.color = Color(1.0, 0.42, 0.12, 0.52); fire_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fire_panel)

	var fire_lbl := Label.new()
	fire_lbl.text = "FIRE"; fire_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; fire_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fire_lbl.add_theme_font_size_override("font_size", 22)
	fire_panel.add_child(fire_lbl)

	_menu_panel = _make_panel(); _ui.add_child(_menu_panel)
	var mv := _menu_panel.get_node("VBox") as VBoxContainer
	var title := Label.new()
	title.text = "OUTPOST ZERO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38); title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.18))
	mv.add_child(title)

	var sub := Label.new()
	sub.text = "Quaternius CC0 Animations • Poly Haven Sunset • ElevenLabs SFX"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.add_theme_font_size_override("font_size", 14)
	mv.add_child(sub)

	_btn_autofire = Button.new(); _btn_autofire.text = "AUTO-FIRE ASSIST: ON"; _btn_autofire.custom_minimum_size = Vector2(0, 48)
	_btn_autofire.pressed.connect(func():
		_player.auto_fire_assist = not _player.auto_fire_assist
		_btn_autofire.text = "AUTO-FIRE ASSIST: " + ("ON" if _player.auto_fire_assist else "OFF (Manual)")
	)
	mv.add_child(_btn_autofire)

	_btn_quality = Button.new(); _btn_quality.text = "SHADOWS: ON (Standard)"; _btn_quality.custom_minimum_size = Vector2(0, 48)
	_btn_quality.pressed.connect(func():
		_high_quality = not _high_quality
		_sun.shadow_enabled = not _high_quality
		_btn_quality.text = "SHADOWS: " + ("OFF (Max FPS)" if _high_quality else "ON (Standard)")
	)
	mv.add_child(_btn_quality)

	var btn_play := Button.new(); btn_play.text = "ENTER DOWNTOWN BLOCK"; btn_play.custom_minimum_size = Vector2(0, 60)
	btn_play.add_theme_font_size_override("font_size", 22); btn_play.pressed.connect(_start_match)
	mv.add_child(btn_play)

	_gameover_panel = _make_panel(); _gameover_panel.visible = false; _ui.add_child(_gameover_panel)
	var gv := _gameover_panel.get_node("VBox") as VBoxContainer
	var go_lbl := Label.new(); go_lbl.text = "WASTED"; go_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_lbl.add_theme_font_size_override("font_size", 40); go_lbl.add_theme_color_override("font_color", Color(0.95, 0.20, 0.20))
	gv.add_child(go_lbl)

	_lbl_final = Label.new(); _lbl_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _lbl_final.add_theme_font_size_override("font_size", 22)
	gv.add_child(_lbl_final)

	var btn_retry := Button.new(); btn_retry.text = "RESPAWN"; btn_retry.custom_minimum_size = Vector2(0, 58)
	btn_retry.pressed.connect(_start_match)
	gv.add_child(btn_retry)

func _add_action_btn(txt: String, offset_br: Vector2, sz: Vector2, cb: Callable) -> void:
	var b := Button.new(); b.text = txt; b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = offset_br.x; b.offset_right = offset_br.x + sz.x
	b.offset_top = offset_br.y; b.offset_bottom = offset_br.y + sz.y
	b.pressed.connect(cb); _hud.add_child(b)

func _make_panel() -> PanelContainer:
	var p := PanelContainer.new(); p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(580, 0); p.grow_horizontal = Control.GROW_DIRECTION_BOTH; p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.09, 0.12, 0.90)
	sb.border_color = Color(1.0, 0.55, 0.18, 0.9); sb.set_border_width_all(2); sb.set_corner_radius_all(14); sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.name = "VBox"; v.add_theme_constant_override("separation", 12); p.add_child(v)
	return p

func _start_match() -> void:
	for b in _bots:
		if is_instance_valid(b): b.queue_free()
	_bots.clear()
	for s in _shot_pool: s["life"] = 0.0; s["node"].visible = false
	for tr in _tracer_pool: tr["life"] = 0.0; tr["node"].visible = false
	for pk in _pickups: pk.queue_free()
	_pickups.clear()
	for g in _grenades: g["node"].queue_free()
	_grenades.clear()
	_arena.spawn_barrels(); _player.reset_player()
	_score = 0; _kills = 0; _combo = 1; _combo_timer = 0.0; _wave = 1
	_begin_wave(1)
	_menu_panel.visible = false; _gameover_panel.visible = false; _hud.visible = true
	_state = State.PLAYING; _refresh_hud()

func _begin_wave(w: int) -> void:
	_wave = w; _to_spawn = 4 + w * 2; _spawn_cd = 0.8
	_show_banner("WAVE %d • HOSTILES INBOUND" % w, 2.4); _refresh_hud()

func _show_banner(txt: String, dur: float) -> void:
	_lbl_banner.text = txt; _lbl_banner.visible = true; _banner_timer = dur

func _refresh_hud() -> void:
	var spec: Dictionary = _player.get_spec()
	var idx: int = _player.weapon_idx
	var r_txt := " (RELOADING)" if _player.is_reloading else ""
	_lbl_hp.text = "HP %d  •  ARMOR %d  •  NADE x%d" % [_player.hp, _player.armor, _player.grenades]
	_lbl_ammo.text = "%s  %d | %d%s" % [spec["name"], _player.ammo[idx], _player.reserve[idx], r_txt]
	var c_txt := ("  %dx" % _combo) if _combo > 1 else ""
	_lbl_wave.text = "WAVE %d  •  $%d%s" % [_wave, _score, c_txt]

func _input(event: InputEvent) -> void:
	if not _ready_done or _state != State.PLAYING: return
	var vp_sz := get_viewport().get_visible_rect().size
	_fire_btn_rect = Rect2(vp_sz.x - 215, vp_sz.y - 255, 118, 105)
	if event is InputEventScreenTouch:
		if event.pressed:
			if _fire_btn_rect.has_point(event.position):
				_fire_finger = event.index; _player.set_firing(true)
			elif event.position.x < vp_sz.x * 0.42 and _joy_finger == -1:
				_joy_finger = event.index; _joy_origin = event.position
				_joy_ring.position = _joy_origin - _joy_ring.size * 0.5
				_joy_knob.position = _joy_origin - _joy_knob.size * 0.5
				_joy_ring.visible = true; _joy_knob.visible = true
			elif _look_finger == -1:
				_look_finger = event.index
		else:
			if event.index == _fire_finger: _fire_finger = -1; _player.set_firing(false)
			elif event.index == _joy_finger:
				_joy_finger = -1; _joy_ring.visible = false; _joy_knob.visible = false; _player.set_move_vector(Vector2.ZERO)
			elif event.index == _look_finger: _look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			var diff := event.position - _joy_origin
			if diff.length() > 54.0: diff = diff.normalized() * 54.0
			_joy_knob.position = _joy_origin + diff - _joy_knob.size * 0.5
			_player.set_move_vector(diff / 54.0)
		elif event.index == _look_finger:
			_player.add_look_delta(event.relative)

func _process(delta: float) -> void:
	if not _ready_done: return
	_lbl_fps.text = "  %d FPS" % Engine.get_frames_per_second()
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0: _lbl_banner.visible = false
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0: _hit_marker.visible = false
	if _crit_timer > 0.0:
		_crit_timer -= delta
		if _crit_timer <= 0.0: _lbl_crit.visible = false
	if _dmg_timer > 0.0:
		_dmg_timer -= delta
		_dmg_vignette.color.a = clampf(_dmg_timer * 1.4, 0.0, 0.45)
	if _state != State.PLAYING: return
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0: _combo = 1; _refresh_hud()

	var live_count := 0
	for i in range(_bots.size() - 1, -1, -1):
		if not is_instance_valid(_bots[i]): _bots.remove_at(i)
		elif not _bots[i].get_meta("is_dead", false): live_count += 1

	if _to_spawn > 0 and live_count < 6:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = 1.6; _spawn_bot(); _to_spawn -= 1
	elif _to_spawn == 0 and live_count == 0:
		_score += _wave * 300; _player.heal_and_resupply(); _begin_wave(_wave + 1)

	_update_enemy_shots(delta); _update_tracers(delta); _update_blasts(delta); _update_grenades(delta); _update_pickups(delta)

func _spawn_bot() -> void:
	var bot: CharacterBody3D = Actors.EnemyBot.new()
	var roll := randf()
	var kind := 1 if (_wave >= 2 and roll < 0.30) else (2 if (_wave >= 3 and roll > 0.80) else 0)
	bot.setup(kind, _wave, _player, _arena.get_blob_texture())
	bot.add_to_group("bots")
	var spots := [Vector3(-12, 0.2, -21), Vector3(12, 0.2, -21), Vector3(0, 0.2, -22), Vector3(-21, 0.2, -2), Vector3(21, 0.2, -4)]
	bot.position = spots[randi() % spots.size()]
	bot.died.connect(_on_bot_died); bot.fired_at_player.connect(_on_bot_fired)
	add_child(bot); _bots.append(bot)

func _on_bot_died(bot: Node3D, was_headshot: bool) -> void:
	_kills += 1; _combo = mini(6, _combo + 1); _combo_timer = 5.0
	_score += (200 if was_headshot else 120) * _combo
	if randf() < 0.42: _spawn_pickup(bot.global_position + Vector3(0, 0.45, 0))
	_r
