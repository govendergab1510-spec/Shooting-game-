extends CanvasLayer

const SAVE_PATH := "user://outpost_save.cfg"

signal play_clicked()
signal resume_clicked()
signal title_clicked()
signal pause_clicked()
signal action_clicked(act: String)
signal settings_updated(preset: int, shadows: bool, fog: bool, msaa: bool, fps_cap: int, show_fps: bool, muted: bool, sens_idx: int, auto_fire: bool)

var gfx_preset: int = 1
var shadows_on: bool = true
var fog_on: bool = true
var msaa_on: bool = false
var fps_cap: int = 60
var show_fps: bool = true
var muted: bool = false
var sens_idx: int = 1
var auto_fire: bool = true
var best_score: int = 0
var best_wave: int = 1

var loading_bg: ColorRect
var loading_lbl: Label
var hud: Control
var menu_panel: PanelContainer
var gfx_panel: PanelContainer
var gameover_panel: PanelContainer
var radar: Control
var joy_ring: ColorRect
var joy_knob: ColorRect
var dmg_vignette: ColorRect
var hit_marker: Control
var lbl_hp: Label
var lbl_ammo: Label
var lbl_wave: Label
var lbl_fps: Label
var lbl_banner: Label
var lbl_crit: Label
var lbl_final: Label
var lbl_best: Label

var _hit_timer: float = 0.0
var _banner_timer: float = 0.0
var _crit_timer: float = 0.0
var _dmg_timer: float = 0.0
var _match_active: bool = false

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

func init_loading() -> void:
	load_settings()
	loading_bg = ColorRect.new()
	loading_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_bg.color = Color(0.08, 0.09, 0.12, 1.0)
	add_child(loading_bg)

	loading_lbl = Label.new()
	loading_lbl.text = "OUTPOST ZERO\nLoading Urban Block..."
	loading_lbl.set_anchors_preset(Control.PRESET_CENTER)
	loading_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.add_theme_font_size_override("font_size", 28)
	loading_lbl.add_theme_color_override("font_color", Color(1.0, 0.58, 0.20))
	loading_bg.add_child(loading_lbl)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("stats", "best_score", 0))
		best_wave = int(cfg.get_value("stats", "best_wave", 1))
		gfx_preset = int(cfg.get_value("gfx", "preset", 1))
		shadows_on = bool(cfg.get_value("gfx", "shadows", true))
		fog_on = bool(cfg.get_value("gfx", "fog", true))
		msaa_on = bool(cfg.get_value("gfx", "msaa", false))
		fps_cap = int(cfg.get_value("gfx", "fps_cap", 60))
		show_fps = bool(cfg.get_value("gfx", "show_fps", true))
		muted = bool(cfg.get_value("audio", "muted", false))
		sens_idx = int(cfg.get_value("ctrl", "sens", 1))
		auto_fire = bool(cfg.get_value("ctrl", "auto_fire", true))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best_score", best_score)
	cfg.set_value("stats", "best_wave", best_wave)
	cfg.set_value("gfx", "preset", gfx_preset)
	cfg.set_value("gfx", "shadows", shadows_on)
	cfg.set_value("gfx", "fog", fog_on)
	cfg.set_value("gfx", "msaa", msaa_on)
	cfg.set_value("gfx", "fps_cap", fps_cap)
	cfg.set_value("gfx", "show_fps", show_fps)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("ctrl", "sens", sens_idx)
	cfg.set_value("ctrl", "auto_fire", auto_fire)
	cfg.save(SAVE_PATH)

func build_ui(player_ref: Node3D, bots_ref: Array[Node3D], barrels_ref: Array[Node3D], pickups_ref: Array[Node3D]) -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	add_child(hud)

	dmg_vignette = ColorRect.new()
	dmg_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	dmg_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dmg_vignette)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 26
	top_bar.offset_right = -26
	top_bar.offset_top = 14
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)

	lbl_hp = Label.new()
	lbl_hp.add_theme_font_size_override("font_size", 22)
	lbl_hp.add_theme_color_override("font_color", Color(0.38, 0.96, 0.50))
	lbl_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(lbl_hp)

	lbl_wave = Label.new()
	lbl_wave.add_theme_font_size_override("font_size", 22)
	lbl_wave.add_theme_color_override("font_color", Color(0.98, 0.80, 0.28))
	top_bar.add_child(lbl_wave)

	lbl_fps = Label.new()
	lbl_fps.text = "  60 FPS"
	lbl_fps.add_theme_font_size_override("font_size", 16)
	lbl_fps.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	top_bar.add_child(lbl_fps)

	var btn_pause := Button.new()
	btn_pause.text = " ☰ "
	btn_pause.custom_minimum_size = Vector2(54, 42)
	btn_pause.pressed.connect(_on_pause_btn)
	top_bar.add_child(btn_pause)

	var RadarScript := load("res://scripts/RadarWidget.gd")
	radar = RadarScript.new()
	radar.position = Vector2(24, 58)
	radar.size = Vector2(124, 124)
	radar.player_ref = player_ref
	radar.enemies_ref = bots_ref
	radar.barrels_ref = barrels_ref
	radar.pickups_ref = pickups_ref
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(radar)

	lbl_banner = Label.new()
	lbl_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_banner.offset_top = 64
	lbl_banner.offset_left = -280
	lbl_banner.offset_right = 280
	lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner.add_theme_font_size_override("font_size", 28)
	lbl_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	lbl_banner.visible = false
	hud.add_child(lbl_banner)

	lbl_crit = Label.new()
	lbl_crit.set_anchors_preset(Control.PRESET_CENTER)
	lbl_crit.offset_top = -65
	lbl_crit.offset_left = -140
	lbl_crit.offset_right = 140
	lbl_crit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_crit.add_theme_font_size_override("font_size", 20)
	lbl_crit.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	lbl_crit.visible = false
	hud.add_child(lbl_crit)

	var crosshair := Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	for r in [Rect2(-11, -1, 6, 2), Rect2(5, -1, 6, 2), Rect2(-1, -11, 2, 6), Rect2(-1, 5, 2, 6)]:
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.color = Color(1.0, 1.0, 1.0, 0.90)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)

	hit_marker = Control.new()
	hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	hit_marker.visible = false
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_marker)
	for pos in [Vector2(-10, -10), Vector2(6, -10), Vector2(-10, 6), Vector2(6, 6)]:
		var hm := ColorRect.new()
		hm.position = pos
		hm.size = Vector2(4, 4)
		hm.color = Color(1.0, 0.35, 0.20)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker.add_child(hm)

	lbl_ammo = Label.new()
	lbl_ammo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl_ammo.offset_left = 26
	lbl_ammo.offset_bottom = -20
	lbl_ammo.offset_top = -64
	lbl_ammo.add_theme_font_size_override("font_size", 24)
	lbl_ammo.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	hud.add_child(lbl_ammo)

	joy_ring = ColorRect.new()
	joy_ring.size = Vector2(128, 128)
	joy_ring.color = Color(1, 1, 1, 0.14)
	joy_ring.visible = false
	joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(joy_ring)

	joy_knob = ColorRect.new()
	joy_knob.size = Vector2(48, 48)
	joy_knob.color = Color(1.0, 0.62, 0.18, 0.65)
	joy_knob.visible = false
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(joy_knob)

	_add_action_btn("SWAP", Vector2(-354, -98), Vector2(80, 64), "swap")
	_add_action_btn("RELOAD", Vector2(-266, -98), Vector2(80, 64), "reload")
	_add_action_btn("ROLL", Vector2(-178, -98), Vector2(80, 64), "roll")
	_add_action_btn("CROUCH", Vector2(-90, -98), Vector2(76, 64), "crouch")
	_add_action_btn("JUMP", Vector2(-90, -176), Vector2(76, 70), "jump")
	_add_action_btn("AIM", Vector2(-90, -255), Vector2(76, 70), "aim")
	_add_action_btn("NADE", Vector2(-310, -176), Vector2(84, 62), "nade")
	_add_action_btn("CAM", Vector2(-310, -246), Vector2(84, 62), "cam")

	var fire_panel := ColorRect.new()
	fire_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_panel.offset_left = -215
	fire_panel.offset_right = -97
	fire_panel.offset_top = -255
	fire_panel.offset_bottom = -150
	fire_panel.color = Color(1.0, 0.42, 0.12, 0.52)
	fire_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fire_panel)

	var fire_lbl := Label.new()
	fire_lbl.text = "FIRE"
	fire_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fire_lbl.add_theme_font_size_override("font_size", 22)
	fire_panel.add_child(fire_lbl)

	_build_menus()
	if loading_bg != null:
		loading_bg.queue_free()
		loading_bg = null
	refresh_labels()
	emit_settings()

func _build_menus() -> void:
	menu_panel = _make_panel(540)
	add_child(menu_panel)
	var mv := menu_panel.get_node("VBox") as VBoxContainer
	var title := Label.new()
	title.text = "OUTPOST ZERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.18))
	mv.add_child(title)

	lbl_best = Label.new()
	lbl_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_best.add_theme_font_size_override("font_size", 15)
	lbl_best.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	mv.add_child(lbl_best)

	_btn_resume = Button.new()
	_btn_resume.text = "RESUME MATCH"
	_btn_resume.custom_minimum_size = Vector2(0, 50)
	_btn_resume.visible = false
	_btn_resume.pressed.connect(_on_resume_btn)
	mv.add_child(_btn_resume)

	_btn_deploy = Button.new()
	_btn_deploy.text = "PLAY"
	_btn_deploy.custom_minimum_size = Vector2(0, 54)
	_btn_deploy.add_theme_font_size_override("font_size", 22)
	_btn_deploy.pressed.connect(_on_play_btn)
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

	gfx_panel = _make_panel(540)
	gfx_panel.visible = false
	add_child(gfx_panel)
	var gv_set := gfx_panel.get_node("VBox") as VBoxContainer
	var gfx_title := Label.new()
	gfx_title.text = "GRAPHICS SETTINGS"
	gfx_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gfx_title.add_theme_font_size_override("font_size", 28)
	gfx_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.18))
	gv_set.add_child(gfx_title)

	_btn_preset = Button.new()
	_btn_preset.custom_minimum_size = Vector2(0, 46)
	_btn_preset.pressed.connect(_on_cycle_preset)
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

	gameover_panel = _make_panel(520)
	gameover_panel.visible = false
	add_child(gameover_panel)
	var gv := gameover_panel.get_node("VBox") as VBoxContainer
	var go_lbl := Label.new()
	go_lbl.text = "WASTED"
	go_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_lbl.add_theme_font_size_override("font_size", 40)
	go_lbl.add_theme_color_override("font_color", Color(0.95, 0.20, 0.20))
	gv.add_child(go_lbl)

	lbl_final = Label.new()
	lbl_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_final.add_theme_font_size_override("font_size", 22)
	gv.add_child(lbl_final)

	var btn_retry := Button.new()
	btn_retry.text = "RESPAWN"
	btn_retry.custom_minimum_size = Vector2(0, 52)
	btn_retry.pressed.connect(_on_play_btn)
	gv.add_child(btn_retry)

	var btn_go_menu := Button.new()
	btn_go_menu.text = "MAIN MENU"
	btn_go_menu.custom_minimum_size = Vector2(0, 46)
	btn_go_menu.pressed.connect(_on_title_btn)
	gv.add_child(btn_go_menu)

func _add_action_btn(txt: String, offset_br: Vector2, sz: Vector2, act: String) -> void:
	var b := Button.new()
	b.text = txt
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = offset_br.x
	b.offset_right = offset_br.x + sz.x
	b.offset_top = offset_br.y
	b.offset_bottom = offset_br.y + sz.y
	b.pressed.connect(_on_action_btn.bind(act))
	hud.add_child(b)

func _make_panel(min_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(min_w, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.90)
	sb.border_color = Color(1.0, 0.55, 0.18, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return p

func _on_action_btn(act: String) -> void:
	action_clicked.emit(act)

func _on_play_btn() -> void:
	_match_active = true
	menu_panel.visible = false
	gfx_panel.visible = false
	gameover_panel.visible = false
	hud.visible = true
	play_clicked.emit()

func _on_resume_btn() -> void:
	menu_panel.visible = false
	gfx_panel.visible = false
	hud.visible = true
	resume_clicked.emit()

func _on_pause_btn() -> void:
	hud.visible = false
	gfx_panel.visible = false
	menu_panel.visible = true
	refresh_labels()
	pause_clicked.emit()

func _on_title_btn() -> void:
	_match_active = false
	gameover_panel.visible = false
	gfx_panel.visible = false
	hud.visible = false
	menu_panel.visible = true
	refresh_labels()
	title_clicked.emit()

func _on_open_gfx() -> void:
	menu_panel.visible = false
	gfx_panel.visible = true

func _on_close_gfx() -> void:
	save_settings()
	gfx_panel.visible = false
	menu_panel.visible = true

func _on_toggle_autofire() -> void:
	auto_fire = not auto_fire
	emit_settings()

func _on_cycle_sens() -> void:
	sens_idx = (sens_idx + 1) % 3
	emit_settings()

func _on_toggle_audio() -> void:
	muted = not muted
	emit_settings()

func _on_toggle_shadows() -> void:
	shadows_on = not shadows_on
	emit_settings()

func _on_toggle_fog() -> void:
	fog_on = not fog_on
	emit_settings()

func _on_toggle_msaa() -> void:
	msaa_on = not msaa_on
	emit_settings()

func _on_toggle_fpscap() -> void:
	fps_cap = 30 if fps_cap == 60 else 60
	emit_settings()

func _on_toggle_showfps() -> void:
	show_fps = not show_fps
	emit_settings()

func _on_cycle_preset() -> void:
	gfx_preset = (gfx_preset + 1) % 3
	if gfx_preset == 0:
		shadows_on = false
		fog_on = false
		msaa_on = false
		fps_cap = 60
	elif gfx_preset == 1:
		shadows_on = true
		fog_on = true
		msaa_on = false
		fps_cap = 60
	else:
		shadows_on = true
		fog_on = true
		msaa_on = true
		fps_cap = 60
	emit_settings()

func emit_settings() -> void:
	refresh_labels()
	save_settings()
	settings_updated.emit(gfx_preset, shadows_on, fog_on, msaa_on, fps_cap, show_fps, muted, sens_idx, auto_fire)

func refresh_labels() -> void:
	if lbl_best == null:
		return
	lbl_best.text = "BEST WAVE: %d  •  TOP EARNINGS: $%d" % [best_wave, best_score]
	_btn_resume.visible = _match_active
	_btn_deploy.text = "RESTART MATCH" if _match_active else "PLAY"
	_btn_autofire.text = "AUTO-FIRE: " + ("ON" if auto_fire else "OFF")
	_btn_sens.text = "AIM SENS: " + ["LOW", "MED", "HIGH"][sens_idx]
	_btn_audio.text = "AUDIO: " + ("MUTED" if muted else "ON")
	_btn_preset.text = "PRESET: " + ["LOW (Max FPS)", "BALANCED (Redmi 13C)", "HIGH (Sharp + MSAA)"][gfx_preset]
	_btn_shadows.text = "SHADOWS: " + ("ON" if shadows_on else "OFF")
	_btn_fog.text = "SUNSET FOG: " + ("ON" if fog_on else "OFF")
	_btn_msaa.text = "ANTI-ALIAS: " + ("2X" if msaa_on else "OFF")
	_btn_fpscap.text = "FPS CAP: %d" % fps_cap
	_btn_showfps.text = "SHOW FPS COUNTER: " + ("ON" if show_fps else "OFF")
	lbl_fps.visible = show_fps

func show_banner(txt: String, dur: float) -> void:
	lbl_banner.text = txt
	lbl_banner.visible = true
	_banner_timer = dur

func show_hit(is_headshot: bool, is_kill: bool) -> void:
	hit_marker.visible = true
	_hit_timer = 0.12
	if is_headshot:
		lbl_crit.text = "HEADSHOT KILL!" if is_kill else "HEADSHOT!"
		lbl_crit.visible = true
		_crit_timer = 0.75

func flash_damage() -> void:
	_dmg_timer = 0.35

func show_gameover(wave: int, kills: int, score: int) -> void:
	_match_active = false
	hud.visible = false
	gameover_panel.visible = true
	if score > best_score:
		best_score = score
	if wave > best_wave:
		best_wave = wave
	save_settings()
	lbl_final.text = "WAVE REACHED: %d\nKILLS: %d\nEARNED: $%d" % [wave, kills, score]

func tick_timers(delta: float, fps: int) -> void:
	if lbl_fps != null:
		lbl_fps.text = "  %d FPS" % fps
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			lbl_banner.visible = false
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			hit_marker.visible = false
	if _crit_timer > 0.0:
		_crit_timer -= delta
		if _crit_timer <= 0.0:
			lbl_crit.visible = false
	if _dmg_timer > 0.0:
		_dmg_timer -= delta
		dmg_vignette.color.a = clampf(_dmg_timer * 1.4, 0.0, 0.45)
