extends Node3D

var anim_player: AnimationPlayer
var muzzle_marker: Marker3D
var _clips: Dictionary = {}
var _current_locomotion: String = ""
var _action_timer: float = 0.0
var _is_dead: bool = false

static var _cached_ual2_lib: AnimationLibrary = null
static var _ual2_checked: bool = false

const UAL1_PATH := "res://assets/animations/UAL1_Standard.glb"
const UAL2_PATH := "res://assets/animations/UAL2_Standard.glb"
const BACKUP_PATH := "res://assets/models/Soldier.glb"

func build_soldier(uniform_col: Color, armor_col: Color, visor_col: Color, scale_mult: float = 1.0) -> void:
	var loaded := false
	var model_path := UAL1_PATH if ResourceLoader.exists(UAL1_PATH) else (BACKUP_PATH if ResourceLoader.exists(BACKUP_PATH) else "")

	if not model_path.is_empty():
		var packed := load(model_path)
		if packed is PackedScene:
			var model: Node3D = packed.instantiate()
			model.rotation.y = PI
			model.scale = Vector3.ONE * scale_mult
			add_child(model)
			_apply_tactical_skin(model, uniform_col)
			anim_player = _find_anim_player(model)
			var skel := _find_skeleton(model)
			if anim_player != null:
				_merge_ual2_library(skel)
				_index_animations()
			_attach_tactical_gear(skel, model, armor_col, visor_col)
			loaded = true

	if not loaded:
		_build_fallback(uniform_col, armor_col, visor_col, scale_mult)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var res := _find_anim_player(c)
		if res != null:
			return res
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var res := _find_skeleton(c)
		if res != null:
			return res
	return null

func _merge_ual2_library(target_skel: Skeleton3D) -> void:
	if _ual2_checked:
		if _cached_ual2_lib != null and not anim_player.has_animation_library("ual2"):
			anim_player.add_animation_library("ual2", _cached_ual2_lib)
		return
	_ual2_checked = true
	if not ResourceLoader.exists(UAL2_PATH) or target_skel == null:
		return
	var p2 := load(UAL2_PATH)
	if not (p2 is PackedScene):
		return
	var inst: Node3D = p2.instantiate()
	var ap2 := _find_anim_player(inst)
	if ap2 != null and ap2.has_animation_library(""):
		var root_node := anim_player.get_node(anim_player.root_node)
		var target_skel_path := String(root_node.get_path_to(target_skel))
		var lib := ap2.get_animation_library("").duplicate(true) as AnimationLibrary
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null:
				continue
			for t in range(anim.get_track_count()):
				var tp := String(anim.track_get_path(t))
				var colon := tp.find(":")
				if colon != -1:
					anim.track_set_path(t, NodePath(target_skel_path + tp.substr(colon)))
		_cached_ual2_lib = lib
		anim_player.add_animation_library("ual2", _cached_ual2_lib)
	inst.queue_free()

func _index_animations() -> void:
	var all_names := anim_player.get_animation_list()
	for full_name in all_names:
		var low := full_name.to_lower()
		var anim := anim_player.get_animation(full_name)
		if anim != null:
			if "loop" in low or low == "idle" or low == "walk" or low == "run" or "aim" in low:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE

	_pick_clip(all_names, "idle", ["pistol_idle_loop", "idle_loop", "idle"])
	_pick_clip(all_names, "aim_idle", ["pistol_aim", "pistol_idle_loop", "idle_loop"])
	_pick_clip(all_names, "walk", ["walk_loop", "walk"])
	_pick_clip(all_names, "jog", ["jog_fwd_loop", "walk_loop", "run"])
	_pick_clip(all_names, "sprint", ["sprint_loop", "jog_fwd_loop", "run"])
	_pick_clip(all_names, "crouch_idle", ["crouch_idle_loop", "crouch_idle", "idle_loop"])
	_pick_clip(all_names, "crouch_walk", ["crouch_fwd_loop", "crouch_walk", "walk_loop"])
	_pick_clip(all_names, "jump", ["jump_start", "jump_loop", "jump"])
	_pick_clip(all_names, "roll", ["roll", "slide", "sprint_loop"])
	_pick_clip(all_names, "shoot", ["pistol_shoot"])
	_pick_clip(all_names, "reload", ["pistol_reload"])
	_pick_clip(all_names, "hit_chest", ["hit_chest", "hit"])
	_pick_clip(all_names, "hit_head", ["hit_head", "hit_chest"])
	_pick_clip(all_names, "death", ["death01", "death"])

	set_locomotion("idle")

func _pick_clip(all_names: PackedStringArray, key: String, patterns: Array[String]) -> void:
	for pat in patterns:
		for full_name in all_names:
			var short := full_name.get_slice("/", 1) if "/" in full_name else full_name
			if short.to_lower() == pat:
				_clips[key] = full_name
				return
	for pat in patterns:
		for full_name in all_names:
			if pat in full_name.to_lower():
				_clips[key] = full_name
				return

func set_locomotion(state: String) -> void:
	if _is_dead or anim_player == null or _action_timer > 0.0 or _current_locomotion == state:
		return
	if _clips.has(state):
		_current_locomotion = state
		anim_player.play(_clips[state], 0.16)

func play_action(action_key: String, lock_time: float = 0.45, force_death: bool = false) -> void:
	if anim_player == null:
		return
	if _is_dead and not force_death:
		return
	if force_death:
		_is_dead = true
		_action_timer = 999.0
	else:
		_action_timer = lock_time
	_current_locomotion = ""
	if _clips.has(action_key):
		var cname: String = _clips[action_key]
		anim_player.stop()
		anim_player.play(cname, 0.08)

func _process(delta: float) -> void:
	if _action_timer > 0.0 and not _is_dead:
		_action_timer -= delta
		if _action_timer <= 0.0:
			set_locomotion("idle")

func _apply_tactical_skin(node: Node, uniform_col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var orig := mi.mesh.surface_get_material(s)
				var mat := StandardMaterial3D.new()
				if orig is StandardMaterial3D:
					mat = orig.duplicate() as StandardMaterial3D
				mat.albedo_color = uniform_col
				mat.roughness = 0.72
				mat.metallic = 0.12
				mi.set_surface_override_material(s, mat)
	for c in node.get_children():
		_apply_tactical_skin(c, uniform_col)

func _find_bone_name(skel: Skeleton3D, candidates: Array[String]) -> String:
	if skel == null:
		return ""
	for c in candidates:
		for i in range(skel.get_bone_count()):
			var bn := skel.get_bone_name(i)
			if bn.to_lower() == c.to_lower():
				return bn
	for c in candidates:
		for i in range(skel.get_bone_count()):
			var bn := skel.get_bone_name(i)
			if c.to_lower() in bn.to_lower():
				return bn
	return ""

func _attach_tactical_gear(skel: Skeleton3D, fallback_parent: Node3D, armor_col: Color, visor_col: Color) -> void:
	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = armor_col
	armor_mat.roughness = 0.55
	armor_mat.metallic = 0.25

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = visor_col
	visor_mat.emission_enabled = true
	visor_mat.emission = visor_col
	visor_mat.emission_energy_multiplier = 2.4

	var head_bone := _find_bone_name(skel, ["Head", "mixamorigHead"])
	if not head_bone.is_empty():
		var hb := BoneAttachment3D.new()
		hb.bone_name = head_bone
		skel.add_child(hb)
		var helmet := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.135
		hs.height = 0.18
		hs.radial_segments = 12
		hs.rings = 6
		helmet.mesh = hs
		helmet.position = Vector3(0, 0.08, 0)
		helmet.scale = Vector3(1.05, 0.85, 1.12)
		helmet.material_override = armor_mat
		hb.add_child(helmet)

		var visor := MeshInstance3D.new()
		var vb := BoxMesh.new()
		vb.size = Vector3(0.18, 0.045, 0.06)
		visor.mesh = vb
		visor.position = Vector3(0, 0.055, 0.115)
		visor.material_override = visor_mat
		hb.add_child(visor)

	var chest_bone := _find_bone_name(skel, ["spine_03", "spine_02", "mixamorigSpine2"])
	if not chest_bone.is_empty():
		var cb := BoneAttachment3D.new()
		cb.bone_name = chest_bone
		skel.add_child(cb)
		var vest := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.34, 0.34, 0.26)
		vest.mesh = vm
		vest.position = Vector3(0, 0.05, 0.01)
		vest.material_override = armor_mat
		cb.add_child(vest)

	var hand_bone := _find_bone_name(skel, ["hand_r", "righthand", "mixamorigRightHand"])
	var holder := Node3D.new()
	if not hand_bone.is_empty():
		var ba := BoneAttachment3D.new()
		ba.bone_name = hand_bone
		skel.add_child(ba)
		holder.position = Vector3(0.0, 0.07, 0.03)
		holder.rotation_degrees = Vector3(-88.0, 180.0, 0.0)
		ba.add_child(holder)
	else:
		holder.position = Vector3(0.24, 1.15, -0.32)
		fallback_parent.add_child(holder)

	holder.add_child(_build_carbine_mesh())
	muzzle_marker = Marker3D.new()
	muzzle_marker.position = Vector3(0.0, 0.02, -0.58)
	holder.add_child(muzzle_marker)

func _build_carbine_mesh() -> Node3D:
	var g := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.14, 0.15, 0.18)
	steel.metallic = 0.88
	steel.roughness = 0.26

	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.08, 0.08, 0.09)
	grip.roughness = 0.72

	var rec := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.052, 0.075, 0.32)
	rec.mesh = rm
	rec.material_override = steel
	g.add_child(rec)

	var brl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.017
	cm.height = 0.38
	cm.radial_segments = 8
	brl.mesh = cm
	brl.rotation_degrees.x = 90.0
	brl.position = Vector3(0, 0.014, -0.33)
	brl.material_override = steel
	g.add_child(brl)

	var mag := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.036, 0.13, 0.052)
	mag.mesh = mm
	mag.position = Vector3(0, -0.085, -0.05)
	mag.rotation_degrees.x = -12.0
	mag.material_override = grip
	g.add_child(mag)

	var stock := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.042, 0.085, 0.18)
	stock.mesh = sm
	stock.position = Vector3(0, -0.01, 0.22)
	stock.material_override = grip
	g.add_child(stock)
	return g

func _build_fallback(ucol: Color, acol: Color, _vcol: Color, scale_mult: float) -> void:
	var root := Node3D.new()
	root.scale = Vector3.ONE * scale_mult
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ucol
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.05
	torso.mesh = cap
	torso.position = Vector3(0, 0.95, 0)
	torso.material_override = mat
	root.add_child(torso)
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = acol
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.17
	sp.height = 0.34
	head.mesh = sp
	head.position = Vector3(0, 1.62, 0)
	head.material_override = mat2
	root.add_child(head)
	muzzle_marker = Marker3D.new()
	muzzle_marker.position = Vector3(0.22, 1.25, -0.6)
	root.add_child(muzzle_marker)
