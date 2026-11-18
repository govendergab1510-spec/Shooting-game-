extends Node3D

const SAVE_PATH := "user://outpost_save.cfg"

enum State { MENU, PLAYING, GAMEOVER }

var _actors_res = null
var _ready_done: bool = false
var _match_active: bool = false
var _state: State = State.MENU
var _score: int = 0
var _best_score: int = 0
var _best_wave: int = 1
var _kills: int = 0
var _combo: int = 1
var _combo_timer: float = 0.0
var _wave: int = 1
var _to_spawn: int = 0
var _spawn_cd: float = 0.0

var _gfx_preset: int = 1
var _shadows_on: bool = true
var _fog_on: bool = true
var _msaa_on: bool = false
var _fps_cap: int = 60
var _show_fps: bool = true
var _muted: bool = false
var _sens_idx: int = 1

var _arena: Node3D
var _player: CharacterBody3D
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
var _menu_cam: Camera3D
var _menu_cam_angle: float = 0.0
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
var _gfx_panel: PanelContainer
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
var _lbl_best: Label
var _fire_btn_rect: Rect2

var _btn_resume: Button
var _btn_deploy: Button
var _btn_autofire: Button
var _btn_sens: Button
var _btn_audio: Button
var _btn_preset: Button
var _btn_shadows: Button
var _btn_fog: Button
var _btn_msaa: Button
var _btn_fpscap: Button
var _btn_showfps: Button

func _play_sfx(key: String, vol_db: float = -2.0, jitter: float = 0.05) -> void:
	var ab := get_node_or_null("/root/AudioBank")
	if ab != null:
		ab.play(key, vol_db, jitter)

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

	_load_settings()
	await get_tree().process_frame

	_actors_res = load("res://scripts/Actors.gd")
	if _actors_res == null:
		_loading_lbl.text = "ERROR: Could not load Actors.gd"
		return

	_setup_env()
	_loading_lbl.text = "OUTPOST ZERO\nBuilding Poly Haven Street..."
	await get_tree().process_frame
	_setup_world()
	_loading_lbl.text = "OUTPOST ZERO\nPreparing Tactical Gear..."
	await get_tree().process_frame
	_setup_pools()
	_setup_ui()
	_apply_graphics_settings()

	_loading_bg.queue_free()
	_ready_done = true

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best_score = int(cfg.get_value("stats", "best_score", 0))
		_best_wave = int(cfg.get_value("stats", "best_wave", 1))
		_gfx_preset = int(cfg.get_value("gfx", "preset", 1))
		_shadows_on = bool(cfg.get_value("gfx", "shadows", true))
		_fog_on = bool(cfg.get_value("gfx", "fog", true))
		_msaa_on = bool(cfg.get_value("gfx", "msaa", false))
		_fps_cap = int(cfg.get_value("gfx", "fps_cap", 60))
		_show_fps = bool(cfg.get_value("gfx", "show_fps", true))
		_muted = bool(cfg.get_value("audio", "muted", false))
		_sens_idx = int(cfg.get_value("ctrl", "sens", 1))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best_score", _best_score)
	cfg.set_value("stats", "best_wave", _best_wave)
	cfg.set_value("gfx", "preset", _gfx_preset)
	cfg.set_value("gfx", "shadows", _shadows_on)
	cfg.set_value("gfx", "fog", _fog_on)
	cfg.set_value("gfx", "msaa", _msaa_on)
	cfg.set_value("gfx", "fps_cap", _fps_cap)
	cfg.set_value("gfx", "show_fps", _show_fps)
	cfg.set_value("audio", "muted", _muted)
	cfg.set_value("ctrl", "sens", _sens_idx)
	cfg.save(SAVE_PATH)

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
	top_bar.offset_left = 26
	top_bar.offset_right = -26
	top_bar.offset_top = 14
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
	btn_pause.text = " ☰ "
	btn_pause.custom_minimum_size = Vector2(54, 42)
	btn_pause.pressed.connect(_open_pause_menu)
	top_bar.add_child(btn_pause)

	var RadarScript := load("res://scripts/RadarWidget.gd")
	_radar = RadarScript.new()
	_radar.position = Vector2(24, 58)
	_radar.size = Vector2(124, 124)
	_radar.player_ref = _player
	_radar.enemies_ref = _bots
	_radar.barrels_ref = _arena.barrels
	_radar.pickups_ref = _pickups
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_radar)

	_lbl_banner = Label.new()
	_lbl_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_banner.offset_top = 64
	_lbl_banner.offset_left = -280
	_lbl_banner.offset_right = 280
	_lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_banner.add_theme_font_size_override("font_size", 28)
	_lbl_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	_lbl_banner.visible = false
	_hud.add_child(_lbl_banner)

	_lbl_crit = Label.new()
	_lbl_crit.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_crit.offset_top = -65
	_lbl_crit.offset_left = -140
	_lbl_crit.offset_right = 140
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
		cr.position = r.position
		cr.size = r.size
		cr.color = Color(1.0, 1.0, 1.0, 0.90)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)

	_hit_marker = Control.new()
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.visible = false
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hit_marker)
	for pos in [Vector2(-10, -10), Vector2(6, -10), Vector2(-10, 6), Vector2(6, 6)]:
		var hm := ColorRect.new()
		hm.position = pos
		hm.size = Vector2(4, 4)
		hm.color = Color(1.0, 0.35, 0.20)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hit_marker.add_child(hm)

	_lbl_ammo = Label.new()
	_lbl_ammo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lbl_ammo.offset_left = 26
	_lbl_ammo.offset_bottom = -20
	_lbl_ammo.offset_top = -64
	_lbl_ammo.add_theme_font_size_override("font_size", 24)
	_lbl_ammo.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_hud.add_child(_lbl_ammo)

	_joy_ring = ColorRect.new()
	_joy_ring.size = Vector2(128, 128)
	_joy_ring.color = Color(1, 1, 1, 0.14)
	_joy_ring.visible = false
	_joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_ring)

	_joy_knob = ColorRect.new()
	_joy_knob.size = Vector2(48, 48)
	_joy_knob.color = Color(1.0, 0.62, 0.18, 0.65)
	_joy_knob.visible = false
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_knob)

	_add_action_btn("SWAP", Vector2(-354, -98), Vector2(80, 64), _player.switch_weapon)
	_add_action_btn("RELOAD", Vector2(-266, -98), Vector2(80, 64), _player.start_reload)
	_add_action_btn("ROLL", Vector2(-178, -98), Vector2(80, 64), _player.queue_roll)
	_add_action_btn("CROUCH", Vector2(-90, -98), Vector2(76, 64), _player.toggle_crouch)
	_add_action_btn("JUMP", Vector2(-90, -176), Vector2(76, 70), _player.queue_jump)
	_add_action_btn("AIM", Vector2(-90, -255), Vector2(76, 70), _player.toggle_ads)
	_add_action_btn("NADE", Vector2(-310, -176), Vector2(84, 62), _player.throw_grenade)
	_add_action_btn("CAM", Vector2(-310, -246), Vector2(84, 62), _player.toggle_camera_mode)

	var fire_panel := ColorRect.new()
	fire_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_panel.offset_left = -215
	fire_panel.offset_right = -97
	fire_panel.offset_top = -255
	fire_panel.offset_bottom = -150
	fire_panel.color = Color(1.0, 0.42, 0.12, 0.52)
	fire_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fire_panel)

	var fire_lbl := Label.new()
	fire_lbl.text = "FIRE"
	fire_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fire_lbl.add_theme_font_size_override("font_size", 22)
	fire_panel.add_child(fire_lbl)

	# --- MAIN MENU ---
	_menu_panel = _make_panel(540)
	_ui.add_child(_menu_panel)
	var mv := _menu_panel.get_node("VBox") as VBoxContainer
	var title := Label.new()
	title.text = "OUTPOST ZERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.18))
	mv.add_child(title)

	_lbl_best = Label.new()
	_lbl_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_best.add_theme_font_size_override("font_size", 15)
	_lbl_best.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	mv.add_child(_lbl_best)

	_btn_resume = Button.new()
	_btn_resume.text = "RESUME MATCH"
	_btn_resume.custom_minimum_size = Vector2(0, 50)
	_btn_resume.visible = false
	_btn_resume.pressed.connect(_resume_match)
	mv.add_child(_btn_resume)

	_btn_deploy = Button.new()
	_btn_deploy.text = "PLAY"
	_btn_deploy.custom_minimum_size = Vector2(0, 54)
	_btn_deploy.add_theme_font_size_override("font_size", 22)
	_btn_deploy.pressed.connect(_start_match)
	mv.add_child(_btn_deploy)

	var btn_gfx := Button.new()
	btn_gfx.text = "GRAPHICS SETTINGS"
	btn_gfx.custom_minimum_size = Vector2(0, 46)
	btn_gfx.pressed.connect(_on_open_gfx)
	mv.add_child(btn_gfx)

	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	mv.add_child(ctrl_row)

	_btn_autofire = Button.new()
	_btn_autofire.custom_minimum_size = Vector2(0, 44)
	_btn_autofire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_autofire.pressed.connect(_on_toggle_autofire)
	ctrl_row.add_child(_btn_autofire)

	_btn_sens = Button.new()
	_btn_sens.custom_minimum_size = Vector2(0, 44)
	_btn_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_sens.pressed.connect(_on_cycle_sens)
	ctrl_row.add_child(_btn_sens)

	_btn_audio = Button.new()
	_btn_audio.custom_minimum_size = Vector2(0, 44)
	_btn_audio.pressed.connect(_on_toggle_audio)
	mv.add_child(_btn_audio)

	# --- GRAPHICS SETTINGS ---
	_gfx_panel = _make_panel(540)
	_gfx_panel.visible = false
	_ui.add_child(_gfx_panel)
	var gv_set := _gfx_panel.get_node("VBox") as VBoxContainer
	var gfx_title := Label.new()
	gfx_title.text = "GRAPHICS SETTINGS"
	gfx_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gfx_title.add_theme_font_size_override("font_size", 28)
	gfx_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.18))
	gv_set.add_child(gfx_title)

	_btn_preset = Button.new()
	_btn_preset.custom_minimum_size = Vector2(0, 46)
	_btn_preset.pressed.connect(_cycle_preset)
	gv_set.add_child(_btn_preset)

	var g_row1 := HBoxContainer.new()
	g_row1.add_theme_constant_override("separation", 8)
	gv_set.add_child(g_row1)

	_btn_shadows = Button.new()
	_btn_shadows.custom_minimum_size = Vector2(0, 44)
	_btn_shadows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_shadows.pressed.connect(_on_toggle_shadows)
	g_row1.add_child(_btn_shadows)

	_btn_fog = Button.new()
	_btn_fog.custom_minimum_size = Vector2(0, 44)
	_btn_fog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fog.pressed.connect(_on_toggle_fog)
	g_row1.add_child(_btn_fog)

	var g_row2 := HBoxContainer.new()
	g_row2.add_theme_constant_override("separation", 8)
	gv_set.add_child(g_row2)

	_btn_msaa = Button.new()
	_btn_msaa.custom_minimum_size = Vector2(0, 44)
	_btn_msaa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_msaa.pressed.connect(_on_toggle_msaa)
	g_row2.add_child(_btn_msaa)

	_btn_fpscap = Button.new()
	_btn_fpscap.custom_minimum_size = Vector2(0, 44)
	_btn_fpscap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fpscap.pressed.connect(_on_toggle_fpscap)
	g_row2.add_child(_btn_fpscap)

	_btn_showfps = Button.new()
	_btn_showfps.custom_minimum_size = Vector2(0, 44)
	_btn_showfps.pressed.connect(_on_toggle_showfps)
	gv_set.add_child(_btn_showfps)

	var btn_back := Button.new()
	btn_back.text = "SAVE & BACK"
	btn_back.custom_minimum_size = Vector2(0, 48)
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(_on_close_gfx)
	gv_set.add_child(btn_back)

	# --- GAME OVER ---
	_gameover_panel = _make_panel(520)
	_gameover_panel.visible = false
	_ui.add_child(_gameover_panel)
	var gv := _gameover_panel.get_node("VBox") as VBoxContainer
	var go_lbl := Label.new()
	go_lbl.text = "WASTED"
	go_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_lbl.add_theme_font_size_override("font_size", 40)
	go_lbl.add_theme_color_override("font_color", Color(0.95, 0.20, 0.20))
	gv.add_child(go_lbl)

	_lbl_final = Label.new()
	_lbl_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_final.add_theme_font_size_override("font_size", 22)
	gv.add_child(_lbl_final)

	var btn_retry := Button.new()
	btn_retry.text = "RESPAWN"
	btn_retry.custom_minimum_size = Vector2(0, 52)
	btn_retry.pressed.connect(_start_match)
	gv.add_child(btn_retry)

	var btn_go_menu := Button.new()
	btn_go_menu.text = "MAIN MENU"
	btn_go_menu.custom_minimum_size = Vector2(0, 46)
	btn_go_menu.pressed.connect(_return_to_title)
	gv.add_child(btn_go_menu)

	_refresh_menu_labels()

func _on_open_gfx() -> void:
	_menu_panel.visible = false
	_gfx_panel.visible = true

func _on_close_gfx() -> void:
	_save_settings()
	_gfx_panel.visible = false
	_menu_panel.visible = true

func _on_toggle_autofire() -> void:
	_player.auto_fire_assist = not _player.auto_fire_assist
	_refresh_menu_labels()

func _on_cycle_sens() -> void:
	_sens_idx = (_sens_idx + 1) % 3
	_apply_graphics_settings()
	_save_settings()

func _on_toggle_audio() -> void:
	_muted = not _muted
	_apply_graphics_settings()
	_save_settings()

func _on_toggle_shadows() -> void:
	_shadows_on = not _shadows_on
	_apply_graphics_settings()
	_save_settings()

func _on_toggle_fog() -> void:
	_fog_on = not _fog_on
	_apply_graphics_settings()
	_save_settings()


