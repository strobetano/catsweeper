extends Control

const PuzzleBook = preload("res://scripts/puzzles.gd")
const TWILIGHT_SHADER = preload("res://shaders/twilight.gdshader")
const CAT_ATLAS = preload("res://assets/art/catsweeper_chibi_states.png")
const UI_FONT = preload("res://assets/fonts/Fredoka-SemiBold.ttf")
const WALLPAPER_SETS := [
	[
		preload("res://assets/art/backgrounds/rooftop_far.png"),
		preload("res://assets/art/backgrounds/rooftop_mid.png"),
		preload("res://assets/art/backgrounds/rooftop_near.png")
	],
	[
		preload("res://assets/art/backgrounds/garden_far.png"),
		preload("res://assets/art/backgrounds/garden_mid.png"),
		preload("res://assets/art/backgrounds/garden_near.png")
	],
	[
		preload("res://assets/art/backgrounds/library_far.png"),
		preload("res://assets/art/backgrounds/library_mid.png"),
		preload("res://assets/art/backgrounds/library_near.png")
	]
]
const MARK_SOUND_PATH := "res://assets/audio/mark.ogg"
const PLACE_SOUND_PATH := "res://assets/audio/place.ogg"
const ERROR_SOUND_PATH := "res://assets/audio/error.ogg"
const WIN_SOUND_PATH := "res://assets/audio/win.ogg"

const BASE_SIZE := Vector2(900.0, 1400.0)
const BOARD_RECT := Rect2(75.0, 365.0, 750.0, 750.0)
const UNDO_RECT := Rect2(75.0, 1210.0, 355.0, 88.0)
const RESTART_RECT := Rect2(470.0, 1210.0, 355.0, 88.0)
const MODAL_BUTTON_RECT := Rect2(210.0, 930.0, 480.0, 102.0)
const SAVE_PATH := "user://catsweeper.cfg"
const TUTORIAL_GIVEN_CELL := 0
const TUTORIAL_MARK_CELL := 1
const TUTORIAL_CAT_CELL := 7

const INK := Color("#1D2942")
const INK_SOFT := Color("#46516A")
const CREAM := Color("#FFF9F0")
const PAPER := Color("#F3EBDD")
const MINT := Color("#A8DCCB")
const CORAL := Color("#F2A59E")
const GOLD := Color("#F5D98E")
const CARAMEL := Color("#DEB991")
const SKY := Color("#AFCEE8")
const PLUM := Color("#C9B9E5")

enum CellState { EMPTY, MARKED, CAT }
enum GameMode { PLAYING, WON }
enum CatPose { IDLE, HAPPY, SLEEPY, WORRIED }
enum TutorialStep { OFF, MARK_SEAT, PLACE_CAT }

@export_group("Feel")
@export_range(0.12, 0.45, 0.01) var double_tap_window := 0.28
@export_range(0.08, 0.35, 0.01) var mark_pop_duration := 0.20
@export_range(0.10, 0.45, 0.01) var cat_pop_duration := 0.32
@export_range(0.15, 0.60, 0.01) var rule_pulse_duration := 0.50
@export_range(0.12, 0.50, 0.01) var shake_duration := 0.30
@export_range(2.0, 18.0, 0.5) var shake_strength := 6.0
@export_range(0.25, 1.20, 0.05) var board_intro_duration := 0.72
@export_range(0.8, 3.0, 0.05) var cartoon_overshoot := 1.65
@export_range(0.18, 0.55, 0.01) var ui_fade_duration := 0.32
@export_range(0.4, 3.0, 0.05) var tutorial_pulse_speed := 1.35
@export_range(1.0, 4.0, 0.1) var tutorial_success_duration := 2.6
@export_range(0.02, 0.12, 0.005) var celebration_stagger := 0.055
@export_range(0.6, 2.0, 0.05) var celebration_duration := 1.30
@export_range(0.1, 1.5, 0.05) var cat_idle_speed := 0.65
@export_range(0.0, 0.08, 0.005) var cat_breathe_amount := 0.040
@export_range(0.0, 6.0, 0.25) var cat_bob_height := 3.0
@export_range(250.0, 650.0, 10.0) var particle_gravity := 430.0
@export_range(6, 24, 1) var place_sparkle_count := 14
@export_range(36, 96, 2) var win_confetti_count := 64

@export_group("Style")
@export_range(1.0, 1.6, 0.05) var border_weight := 1.25

@export_group("Atmosphere")
@export_range(0.0, 0.25, 0.005) var background_drift_speed := 0.065
@export_range(0.0, 1.5, 0.01) var background_glow_strength := 1.0
@export_range(0.0, 1.0, 0.01) var background_mote_strength := 0.44
@export_range(0.0, 0.03, 0.001) var background_grain_strength := 0.005
@export_range(0.0, 36.0, 1.0) var wallpaper_parallax_strength := 18.0
@export_range(1.0, 12.0, 0.25) var wallpaper_follow_speed := 5.0
@export_range(0.0, 12.0, 0.5) var wallpaper_idle_sway := 5.0

@export_group("Audio")
@export_range(-30.0, 0.0, 0.5) var sfx_volume_db := -8.0

var region_colors: Array[Color] = [
	Color("#F5C8C5"),
	Color("#C6E5D8"),
	Color("#C9DDF0"),
	Color("#F5E3AD"),
	Color("#DCCFF0"),
	Color("#F1D0B8"),
	Color("#C8E2E0")
]

var ui_font: Font
var mark_player: AudioStreamPlayer
var place_player: AudioStreamPlayer
var error_player: AudioStreamPlayer
var win_player: AudioStreamPlayer

var level_index := 0
var unlocked_level := 0
var puzzle: Dictionary
var grid_size := 5
var cell_states: Array[int] = []
var given_cells: Dictionary = {}
var game_mode := GameMode.PLAYING
var tutorial_step := TutorialStep.OFF
var history: Array[Dictionary] = []
var elapsed_time := 0.0

var canvas_scale := 1.0
var canvas_offset := Vector2.ZERO
var pointer_base := Vector2(-1000.0, -1000.0)
var hover_cell := -1
var pending_cell := -1
var pending_time := 0.0
var press_cell := -1
var drag_active := false
var drag_changes: Array[Dictionary] = []
var drag_seen: Dictionary = {}

var animation_clock := 0.0
var wallpaper_parallax := Vector2.ZERO
var intro_time := 0.0
var pulse_cell := -1
var pulse_time := 0.0
var error_cell := -1
var error_time := 0.0
var shake_time := 0.0
var win_time := 0.0
var toast_text := ""
var toast_time := 0.0
var cat_pops: Dictionary = {}
var mark_pops: Dictionary = {}
var particles: Array[Dictionary] = []

var validation_solution_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ui_font = UI_FONT
	_create_background()
	_create_audio_players()
	_load_progress()
	_validate_puzzle_pack()
	_start_level(unlocked_level)
	set_process(true)


func _create_background() -> void:
	var background := ColorRect.new()
	background.name = "TwilightShader"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = TWILIGHT_SHADER
	shader_material.set_shader_parameter("drift_speed", background_drift_speed)
	shader_material.set_shader_parameter("glow_strength", background_glow_strength)
	shader_material.set_shader_parameter("mote_strength", background_mote_strength)
	shader_material.set_shader_parameter("grain_strength", background_grain_strength)
	background.material = shader_material
	add_child(background)
	move_child(background, 0)


func _create_audio_players() -> void:
	mark_player = _make_player(load(MARK_SOUND_PATH) as AudioStream)
	place_player = _make_player(load(PLACE_SOUND_PATH) as AudioStream)
	error_player = _make_player(load(ERROR_SOUND_PATH) as AudioStream)
	win_player = _make_player(load(WIN_SOUND_PATH) as AudioStream)


func _make_player(audio_stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = audio_stream
	player.volume_db = sfx_volume_db
	add_child(player)
	return player


func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		unlocked_level = clampi(int(save.get_value("progress", "unlocked_level", 0)), 0, PuzzleBook.LEVELS.size() - 1)


func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "unlocked_level", unlocked_level)
	save.save(SAVE_PATH)


func _start_level(index: int) -> void:
	level_index = clampi(index, 0, PuzzleBook.LEVELS.size() - 1)
	puzzle = PuzzleBook.LEVELS[level_index]
	grid_size = int(puzzle["size"])
	cell_states.clear()
	cell_states.resize(grid_size * grid_size)
	cell_states.fill(CellState.EMPTY)
	given_cells.clear()
	for given_cell in puzzle["givens"]:
		var cell := int(given_cell)
		given_cells[cell] = true
		cell_states[cell] = CellState.CAT
	game_mode = GameMode.PLAYING
	history.clear()
	elapsed_time = 0.0
	pending_cell = -1
	press_cell = -1
	drag_active = false
	hover_cell = -1
	intro_time = 0.0
	pulse_cell = -1
	pulse_time = 0.0
	error_cell = -1
	error_time = 0.0
	shake_time = 0.0
	win_time = 0.0
	cat_pops.clear()
	mark_pops.clear()
	particles.clear()
	tutorial_step = TutorialStep.MARK_SEAT if level_index == 0 else TutorialStep.OFF
	toast_text = ""
	toast_time = 0.0
	if tutorial_step == TutorialStep.MARK_SEAT:
		pulse_cell = TUTORIAL_GIVEN_CELL
		pulse_time = rule_pulse_duration
	queue_redraw()


func _process(delta: float) -> void:
	animation_clock += delta
	var pointer_ratio := Vector2.ZERO
	if Rect2(Vector2.ZERO, BASE_SIZE).has_point(pointer_base):
		pointer_ratio = pointer_base / BASE_SIZE * 2.0 - Vector2.ONE
	var target_parallax := Vector2(
		clampf(pointer_ratio.x, -1.0, 1.0),
		clampf(pointer_ratio.y, -1.0, 1.0)
	)
	var follow_amount := 1.0 - exp(-wallpaper_follow_speed * delta)
	wallpaper_parallax += (target_parallax - wallpaper_parallax) * follow_amount
	intro_time = minf(intro_time + delta, board_intro_duration)
	self_modulate = Color(1.0, 1.0, 1.0, _smooth_fade(intro_time / maxf(board_intro_duration, 0.001)))
	if game_mode == GameMode.PLAYING:
		elapsed_time += delta
	else:
		win_time += delta

	if pending_cell >= 0:
		pending_time -= delta
		if pending_time <= 0.0:
			var cell := pending_cell
			pending_cell = -1
			_toggle_mark(cell)

	pulse_time = maxf(0.0, pulse_time - delta)
	error_time = maxf(0.0, error_time - delta)
	shake_time = maxf(0.0, shake_time - delta)
	toast_time = maxf(0.0, toast_time - delta)

	for key in cat_pops.keys():
		cat_pops[key] = float(cat_pops[key]) + delta
		if float(cat_pops[key]) >= cat_pop_duration:
			cat_pops.erase(key)
	for key in mark_pops.keys():
		mark_pops[key] = float(mark_pops[key]) + delta
		if float(mark_pops[key]) >= mark_pop_duration:
			mark_pops.erase(key)

	var particle_index := particles.size() - 1
	while particle_index >= 0:
		var particle := particles[particle_index]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			particles.remove_at(particle_index)
		else:
			particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["vel"]) * delta
			particle["vel"] = Vector2(particle["vel"]) + Vector2(0.0, particle_gravity) * delta
			particle["spin"] = float(particle["spin"]) + delta * float(particle["spin_speed"])
			particles[particle_index] = particle
		particle_index -= 1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_base = _screen_to_base(event.position)
		hover_cell = _cell_at(pointer_base)
		if int(event.button_mask) & MOUSE_BUTTON_MASK_LEFT and press_cell >= 0:
			var current_cell := _cell_at(pointer_base)
			if current_cell >= 0 and current_cell != press_cell:
				if not drag_active:
					drag_active = true
					pending_cell = -1
					drag_changes.clear()
					drag_seen.clear()
					_paint_mark(press_cell)
				_paint_mark(current_cell)
		accept_event()
	elif event is InputEventMouseButton:
		pointer_base = _screen_to_base(event.position)
		hover_cell = _cell_at(pointer_base)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _handle_ui_press(pointer_base):
					pending_cell = -1
					accept_event()
					return
				_begin_pointer(pointer_base, event.double_click)
			else:
				_finish_pointer()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var cell := _cell_at(pointer_base)
			if cell >= 0 and game_mode == GameMode.PLAYING:
				pending_cell = -1
				_try_place_cat(cell)
			accept_event()


func _begin_pointer(base_position: Vector2, system_double_click: bool) -> void:
	if game_mode != GameMode.PLAYING:
		return
	var cell := _cell_at(base_position)
	if cell < 0:
		return
	if system_double_click or (pending_cell == cell and pending_time > 0.0):
		pending_cell = -1
		press_cell = -1
		_try_place_cat(cell)
		return
	if pending_cell >= 0 and pending_cell != cell:
		var previous := pending_cell
		pending_cell = -1
		_toggle_mark(previous)
	pending_cell = cell
	pending_time = double_tap_window
	press_cell = cell
	drag_active = false
	drag_changes.clear()
	drag_seen.clear()


func _finish_pointer() -> void:
	if drag_active and not drag_changes.is_empty():
		history.append({"changes": drag_changes.duplicate(true)})
	drag_active = false
	drag_changes.clear()
	drag_seen.clear()
	press_cell = -1


func _handle_ui_press(base_position: Vector2) -> bool:
	if game_mode == GameMode.WON:
		if win_time >= 0.55 and MODAL_BUTTON_RECT.has_point(base_position):
			if level_index >= PuzzleBook.LEVELS.size() - 1:
				unlocked_level = 0
				_save_progress()
				_start_level(0)
			else:
				_start_level(level_index + 1)
			return true
		return false
	if UNDO_RECT.has_point(base_position):
		_undo()
		return true
	if RESTART_RECT.has_point(base_position):
		_start_level(level_index)
		return true
	return false


func _screen_to_base(screen_position: Vector2) -> Vector2:
	_update_canvas_transform()
	return (screen_position - canvas_offset) / maxf(canvas_scale, 0.001)


func _update_canvas_transform() -> void:
	var view_size := size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = BASE_SIZE
	canvas_scale = minf(view_size.x / BASE_SIZE.x, view_size.y / BASE_SIZE.y)
	canvas_offset = (view_size - BASE_SIZE * canvas_scale) * 0.5


func _animated_board_rect() -> Rect2:
	var intro_ratio := clampf(intro_time / maxf(board_intro_duration, 0.001), 0.0, 1.0)
	return _scale_rect(BOARD_RECT, lerpf(0.86, 1.0, _cartoon_settle(intro_ratio)))


func _cell_at(base_position: Vector2) -> int:
	var board_rect := _animated_board_rect()
	if not board_rect.has_point(base_position):
		return -1
	var slot := board_rect.size.x / float(grid_size)
	var column := clampi(int((base_position.x - board_rect.position.x) / slot), 0, grid_size - 1)
	var row := clampi(int((base_position.y - board_rect.position.y) / slot), 0, grid_size - 1)
	return row * grid_size + column


func _toggle_mark(cell: int) -> void:
	if game_mode != GameMode.PLAYING or given_cells.has(cell):
		return
	var old_state := cell_states[cell]
	var new_state := CellState.MARKED
	if old_state == CellState.MARKED or old_state == CellState.CAT:
		new_state = CellState.EMPTY
	_push_history_change(cell, old_state)
	cell_states[cell] = new_state
	if old_state == CellState.CAT:
		error_cell = -1
		error_time = 0.0
		shake_time = 0.0
	if new_state == CellState.MARKED:
		mark_pops[cell] = 0.0
		_play_sound(mark_player, randf_range(0.96, 1.06))
	else:
		_play_sound(mark_player, 0.88)
	if new_state == CellState.MARKED:
		_update_tutorial_progress(cell, false)


func _paint_mark(cell: int) -> void:
	if cell < 0 or cell >= cell_states.size() or given_cells.has(cell) or drag_seen.has(cell):
		return
	drag_seen[cell] = true
	if cell_states[cell] != CellState.EMPTY:
		return
	drag_changes.append({"cell": cell, "state": cell_states[cell]})
	cell_states[cell] = CellState.MARKED
	mark_pops[cell] = 0.0
	_play_sound(mark_player, randf_range(0.94, 1.08))
	_update_tutorial_progress(cell, false)


func _try_place_cat(cell: int) -> void:
	if game_mode != GameMode.PLAYING or given_cells.has(cell):
		return
	if cell_states[cell] == CellState.CAT:
		_push_history_change(cell, CellState.CAT)
		cell_states[cell] = CellState.EMPTY
		error_cell = -1
		error_time = 0.0
		shake_time = 0.0
		_play_sound(mark_player, 0.84)
		return

	if _cat_count() >= grid_size:
		error_cell = cell
		error_time = shake_duration
		shake_time = shake_duration
		toast_text = "All cats are seated. Move one before adding another."
		toast_time = 2.4
		_spawn_error_sparks(_cell_center(cell))
		_play_sound(error_player, randf_range(0.92, 1.02))
		return

	var old_state := cell_states[cell]
	_push_history_change(cell, old_state)
	cell_states[cell] = CellState.CAT
	error_cell = -1
	cat_pops[cell] = 0.0
	pulse_cell = cell
	pulse_time = rule_pulse_duration
	_spawn_place_sparkles(_cell_center(cell), region_colors[int(puzzle["regions"][cell]) % region_colors.size()])
	_play_sound(place_player, 0.96 + float(_cat_count()) * 0.035)
	_update_tutorial_progress(cell, true)
	if _cat_count() == grid_size:
		_validate_full_layout(cell)


func _validate_full_layout(preferred_cell: int) -> void:
	var cells_to_check: Array[int] = []
	if preferred_cell >= 0 and cell_states[preferred_cell] == CellState.CAT:
		cells_to_check.append(preferred_cell)
	for cell in range(cell_states.size()):
		if cell_states[cell] == CellState.CAT and cell != preferred_cell:
			cells_to_check.append(cell)
	for cell in cells_to_check:
		var reason := _wrong_reason(cell)
		if reason.is_empty():
			continue
		error_cell = cell
		error_time = shake_duration
		shake_time = shake_duration
		toast_text = reason
		toast_time = 2.4
		_spawn_error_sparks(_cell_center(cell))
		_play_sound(error_player, randf_range(0.92, 1.02))
		return
	_complete_level()


func _update_tutorial_progress(action_cell: int, placed_cat: bool) -> void:
	if level_index != 0 or game_mode != GameMode.PLAYING or tutorial_step == TutorialStep.OFF:
		return
	if tutorial_step == TutorialStep.MARK_SEAT and not placed_cat and action_cell == TUTORIAL_MARK_CELL and cell_states[action_cell] == CellState.MARKED:
		tutorial_step = TutorialStep.PLACE_CAT
		pulse_cell = TUTORIAL_CAT_CELL
		pulse_time = rule_pulse_duration
	if tutorial_step == TutorialStep.PLACE_CAT and cell_states[TUTORIAL_CAT_CELL] == CellState.CAT:
		tutorial_step = TutorialStep.OFF
		toast_text = "PURRFECT! USE THE THREE RULES TO FINISH THE ROOM."
		toast_time = tutorial_success_duration


func _tutorial_target_cell() -> int:
	if level_index != 0 or game_mode != GameMode.PLAYING:
		return -1
	if tutorial_step == TutorialStep.MARK_SEAT:
		return TUTORIAL_MARK_CELL
	if tutorial_step == TutorialStep.PLACE_CAT:
		return TUTORIAL_CAT_CELL
	return -1


func _wrong_reason(cell: int) -> String:
	var row := cell / grid_size
	var column := cell % grid_size
	var region := int(puzzle["regions"][cell])
	for other in range(cell_states.size()):
		if other == cell or cell_states[other] != CellState.CAT:
			continue
		var other_row := other / grid_size
		var other_column := other % grid_size
		if abs(other_row - row) <= 1 and abs(other_column - column) <= 1:
			return "Cats cannot touch, even diagonally."
		if other_row == row:
			return "That row already has a cat."
		if other_column == column:
			return "That column already has a cat."
		if int(puzzle["regions"][other]) == region:
			return "That color already has its cat."
	return ""


func _push_history_change(cell: int, old_state: int) -> void:
	history.append({"changes": [{"cell": cell, "state": old_state}]})


func _undo() -> void:
	if history.is_empty() or game_mode == GameMode.WON:
		toast_text = "Nothing to sweep back yet."
		toast_time = 1.4
		return
	var action: Dictionary = history.pop_back()
	for change in action["changes"]:
		cell_states[int(change["cell"])] = int(change["state"])
	error_cell = -1
	error_time = 0.0
	shake_time = 0.0
	toast_text = "Last sweep restored."
	toast_time = 1.25
	_play_sound(mark_player, 0.78)


func _complete_level() -> void:
	game_mode = GameMode.WON
	win_time = 0.0
	pending_cell = -1
	unlocked_level = maxi(unlocked_level, mini(level_index + 1, PuzzleBook.LEVELS.size() - 1))
	_save_progress()
	_spawn_win_confetti()
	_play_sound(win_player, 1.0)


func _cat_count() -> int:
	var count := 0
	for state in cell_states:
		if state == CellState.CAT:
			count += 1
	return count


func _play_sound(player: AudioStreamPlayer, pitch: float) -> void:
	player.pitch_scale = clampf(pitch, 0.65, 1.45)
	player.play()


func _cell_center(cell: int) -> Vector2:
	var slot := BOARD_RECT.size.x / float(grid_size)
	var row := cell / grid_size
	var column := cell % grid_size
	return BOARD_RECT.position + Vector2((float(column) + 0.5) * slot, (float(row) + 0.5) * slot)


func _spawn_place_sparkles(origin: Vector2, color: Color) -> void:
	for index in range(place_sparkle_count):
		var angle := TAU * float(index) / float(place_sparkle_count) + randf_range(-0.14, 0.14)
		var speed := randf_range(80.0, 165.0)
		var lifetime := randf_range(0.38, 0.64)
		particles.append({
			"kind": "place",
			"pos": origin,
			"vel": Vector2.from_angle(angle) * speed,
			"life": lifetime,
			"max_life": lifetime,
			"color": color.lightened(0.16),
			"size": randf_range(4.0, 7.5),
			"spin": randf_range(0.0, TAU),
			"spin_speed": randf_range(-6.0, 6.0)
		})


func _spawn_error_sparks(origin: Vector2) -> void:
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		particles.append({
			"kind": "error",
			"pos": origin,
			"vel": Vector2.from_angle(angle) * randf_range(55.0, 105.0),
			"life": 0.34,
			"max_life": 0.34,
			"color": CORAL,
			"size": 5.0,
			"spin": angle,
			"spin_speed": 3.0
		})


func _spawn_win_confetti() -> void:
	var palette := [MINT, CORAL, GOLD, SKY, PLUM, CREAM]
	for index in range(win_confetti_count):
		var origin := Vector2(randf_range(80.0, 820.0), randf_range(300.0, 570.0))
		var lifetime := randf_range(1.45, 2.45)
		particles.append({
			"kind": "win",
			"pos": origin,
			"vel": Vector2(randf_range(-165.0, 165.0), randf_range(-480.0, -180.0)),
			"life": lifetime,
			"max_life": lifetime,
			"color": palette[index % palette.size()],
			"size": randf_range(5.0, 9.0),
			"spin": randf_range(0.0, TAU),
			"spin_speed": randf_range(-7.0, 7.0)
		})


func _draw() -> void:
	_update_canvas_transform()
	var shake := Vector2.ZERO
	if shake_time > 0.0:
		var shake_phase := 1.0 - shake_time / maxf(shake_duration, 0.001)
		var strength := shake_strength * _smooth_pulse(shake_phase)
		shake = Vector2(sin(animation_clock * 67.0), cos(animation_clock * 51.0) * 0.45) * strength
	draw_set_transform(canvas_offset, 0.0, Vector2.ONE * canvas_scale)
	_draw_wallpaper()
	_draw_header()
	_draw_rule_cards()
	draw_set_transform(canvas_offset + shake * canvas_scale, 0.0, Vector2.ONE * canvas_scale)
	_draw_board()
	draw_set_transform(canvas_offset, 0.0, Vector2.ONE * canvas_scale)
	_draw_footer()
	if game_mode == GameMode.WON:
		_draw_win_overlay()
	_draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wallpaper() -> void:
	var wallpaper_set: Array = WALLPAPER_SETS[_wallpaper_set_index()]
	var intro_ratio := _smooth_fade(intro_time / maxf(board_intro_duration, 0.001))
	var scene_phase := animation_clock * background_drift_speed * TAU + float(level_index) * 0.73
	var idle_motion := Vector2(
		sin(scene_phase),
		cos(scene_phase * 0.73)
	) * wallpaper_idle_sway
	var camera_motion := -wallpaper_parallax * wallpaper_parallax_strength + idle_motion
	var reveal_motion := Vector2(0.0, (1.0 - intro_ratio) * 18.0)
	_draw_wallpaper_layer(wallpaper_set[0] as Texture2D, camera_motion + reveal_motion, 0.20, 0.72)
	_draw_wallpaper_layer(wallpaper_set[1] as Texture2D, camera_motion + reveal_motion, 0.52, 0.78)
	_draw_wallpaper_layer(wallpaper_set[2] as Texture2D, camera_motion + reveal_motion, 1.0, 0.86)


func _wallpaper_set_index() -> int:
	if level_index < 4:
		return 0
	if level_index < 10:
		return 1
	return 2


func _draw_wallpaper_layer(texture: Texture2D, motion: Vector2, depth: float, opacity: float) -> void:
	var texture_size := texture.get_size()
	var cover_scale := maxf(BASE_SIZE.x / texture_size.x, BASE_SIZE.y / texture_size.y) * 1.06
	var draw_size := texture_size * cover_scale
	var draw_position := (BASE_SIZE - draw_size) * 0.5 + motion * depth
	draw_texture_rect(texture, Rect2(draw_position, draw_size), false, _with_alpha(Color.WHITE, opacity))


func _draw_header() -> void:
	var title_panel := Rect2(28.0, 20.0, 638.0, 138.0)
	_rounded_rect(Rect2(title_panel.position + Vector2(0.0, 7.0), title_panel.size), _with_alpha(INK, 0.18), 44.0)
	_draw_panel(title_panel, _with_alpha(INK, 0.58), 44.0, _with_alpha(CREAM, 0.28), 4.0)
	_draw_panel(Rect2(43.0, 30.0, 118.0, 118.0), _with_alpha(INK, 0.82), 38.0, _with_alpha(PLUM, 0.42), 5.0)
	_draw_cat(Vector2(102.0, 92.0), 48.0, 1.0, _cat_pose())
	_draw_text_left("CATSWEEPER", Vector2(181.0, 84.0), 43, CREAM)
	_draw_text_left("quiet logic for clever paws", Vector2(184.0, 124.0), 20, _with_alpha(CREAM, 0.72))

	var level_rect := Rect2(681.0, 54.0, 154.0, 68.0)
	_rounded_rect(Rect2(level_rect.position + Vector2(0.0, 5.0), level_rect.size), _with_alpha(INK, 0.16), 34.0)
	_draw_panel(level_rect, _with_alpha(PLUM, 0.88), 34.0, _with_alpha(CREAM, 0.64), 4.0)
	_draw_text_center("ROOM %02d" % (level_index + 1), level_rect, 22, INK)

	var progress_rect := Rect2(75.0, 168.0, 365.0, 72.0)
	var guidance_rect := Rect2(462.0, 168.0, 363.0, 72.0)
	_rounded_rect(Rect2(progress_rect.position + Vector2(0.0, 5.0), progress_rect.size), _with_alpha(INK, 0.12), 36.0)
	_rounded_rect(Rect2(guidance_rect.position + Vector2(0.0, 5.0), guidance_rect.size), _with_alpha(INK, 0.12), 36.0)
	_draw_panel(progress_rect, CREAM, 36.0, _with_alpha(MINT, 0.48), 4.0)
	_draw_panel(guidance_rect, CREAM, 36.0, _with_alpha(CORAL, 0.44), 4.0)
	draw_circle(Vector2(118.0, 204.0), 28.0, _with_alpha(MINT, 0.20))
	_draw_cat(Vector2(118.0, 204.0), 22.0, 1.0, _cat_pose())
	_draw_text_left("%d / %d  CATS SEATED" % [_cat_count(), grid_size], Vector2(158.0, 214.0), 24, INK)
	draw_circle(Vector2(505.0, 204.0), 28.0, _with_alpha(CORAL, 0.18))
	_draw_space_icon(Vector2(505.0, 204.0))
	var guidance := "MOVE ONE CAT TO FIX" if _cat_count() == grid_size and error_cell >= 0 else "PLACE ALL CATS FIRST"
	_draw_text_left(guidance, Vector2(543.0, 212.0), 20, INK)


func _draw_rule_cards() -> void:
	var labels := ["ONE PER COLOR", "ONE PER LINE", "NO CATS TOUCHING"]
	var accents := [MINT, SKY, CORAL]
	var pulse := 0.0
	if pulse_time > 0.0:
		var pulse_phase := 1.0 - pulse_time / maxf(rule_pulse_duration, 0.001)
		pulse = _smooth_pulse(pulse_phase)
	for index in range(3):
		var card := Rect2(75.0 + float(index) * 255.0, 263.0, 235.0, 68.0)
		var accent: Color = accents[index]
		var card_fill := CREAM.lerp(accent, pulse * 0.12)
		_rounded_rect(Rect2(card.position + Vector2(0.0, 5.0), card.size), _with_alpha(INK, 0.10), 30.0)
		_draw_panel(card, _with_alpha(card_fill, 0.98), 30.0, _with_alpha(accent, 0.44 + pulse * 0.30), 4.0)
		var icon_center := Vector2(card.position.x + 37.0, card.position.y + 34.0)
		if index == 0:
			_draw_color_icon(icon_center)
		elif index == 1:
			_draw_line_icon(icon_center)
		else:
			_draw_space_icon(icon_center)
		_draw_text_left(labels[index], Vector2(card.position.x + 70.0, card.position.y + 42.0), 19, INK_SOFT)


func _draw_board() -> void:
	var board_rect := _animated_board_rect()
	var tray := board_rect.grow(18.0)
	_rounded_rect(Rect2(tray.position + Vector2(0.0, 11.0), tray.size), Color(0.005, 0.012, 0.04, 0.24), 44.0)
	_draw_panel(tray, CREAM, 44.0, _with_alpha(INK, 0.24), 5.0)

	var slot := board_rect.size.x / float(grid_size)
	var gap := 9.0 if grid_size <= 6 else 8.0
	var tile_radius := minf(24.0, slot * 0.22)
	var tutorial_target := _tutorial_target_cell()
	for cell in range(cell_states.size()):
		var row := cell / grid_size
		var column := cell % grid_size
		var tile_rect := Rect2(
			board_rect.position + Vector2(float(column) * slot + gap * 0.5, float(row) * slot + gap * 0.5),
			Vector2(slot - gap, slot - gap)
		)
		var region := int(puzzle["regions"][cell])
		var tile_color := region_colors[region % region_colors.size()]
		var error_envelope := 0.0
		if cell == hover_cell and game_mode == GameMode.PLAYING:
			tile_color = tile_color.lightened(0.075)
		if cell == error_cell and error_time > 0.0:
			var error_phase := 1.0 - error_time / maxf(shake_duration, 0.001)
			error_envelope = _smooth_pulse(error_phase)
			tile_color = tile_color.lerp(CORAL, (0.30 + 0.12 * sin(animation_clock * 34.0)) * error_envelope)
		_rounded_rect(tile_rect, tile_color, tile_radius)
		if cell == hover_cell and game_mode == GameMode.PLAYING and cell != error_cell:
			_draw_panel(tile_rect.grow(-2.0), tile_color, tile_radius - 2.0, _with_alpha(CREAM, 0.84), 5.0)
		if cell == error_cell and error_time > 0.0:
			_draw_panel(tile_rect.grow(-2.0), tile_color, tile_radius - 2.0, _with_alpha(CORAL, 0.92 * error_envelope), 6.0)

		if cell == tutorial_target:
			var tutorial_wave := 0.5 + 0.5 * sin(animation_clock * tutorial_pulse_speed * TAU)
			var tutorial_accent := MINT if tutorial_step == TutorialStep.MARK_SEAT else GOLD
			var tutorial_rect := tile_rect.grow(-3.0 - tutorial_wave * 1.5)
			_draw_panel(tutorial_rect, _with_alpha(CREAM, 0.10 + tutorial_wave * 0.08), maxf(8.0, tile_radius - 3.0), _with_alpha(tutorial_accent, 0.74 + tutorial_wave * 0.22), 6.0)
			draw_arc(tile_rect.get_center(), slot * (0.31 + tutorial_wave * 0.025), 0.0, TAU, 40, _with_alpha(CREAM, 0.34 + tutorial_wave * 0.24), 3.0, true)

		if pulse_time > 0.0 and _shares_rule(cell, pulse_cell):
			var pulse_phase := 1.0 - pulse_time / maxf(rule_pulse_duration, 0.001)
			var pulse_alpha := _smooth_pulse(pulse_phase) * 0.17
			_rounded_rect(tile_rect.grow(-4.0), Color(1.0, 1.0, 1.0, pulse_alpha), maxf(8.0, tile_radius - 4.0))
		if cell == pulse_cell and pulse_time > 0.0:
			var ring_phase := 1.0 - pulse_time / maxf(rule_pulse_duration, 0.001)
			var ring_motion := _smooth_fade(ring_phase)
			draw_arc(tile_rect.get_center(), slot * (0.28 + ring_motion * 0.15), 0.0, TAU, 40, _with_alpha(CREAM, _smooth_pulse(ring_phase) * 0.78), 5.0, true)
			if ring_phase > 0.16:
				var echo_phase := (ring_phase - 0.16) / 0.84
				var echo_motion := _smooth_fade(echo_phase)
				draw_arc(tile_rect.get_center(), slot * (0.18 + echo_motion * 0.30), 0.0, TAU, 40, _with_alpha(GOLD, _smooth_pulse(echo_phase) * 0.54), 4.0, true)

		if cell == pending_cell and game_mode == GameMode.PLAYING:
			var pending_ratio := clampf(pending_time / maxf(double_tap_window, 0.001), 0.0, 1.0)
			var pending_phase := 1.0 - pending_ratio
			var pending_motion := _smooth_fade(pending_phase)
			var pending_alpha := _smooth_pulse(pending_phase) * 0.80
			draw_arc(tile_rect.get_center(), slot * (0.32 + pending_motion * 0.035), 0.0, TAU, 40, _with_alpha(CREAM, pending_alpha), 5.0, true)
			draw_circle(tile_rect.get_center(), slot * 0.035, _with_alpha(MINT, pending_alpha * 0.72))

		if cell_states[cell] == CellState.MARKED:
			var mark_scale := 1.0
			var mark_alpha := 1.0
			if mark_pops.has(cell):
				var mark_phase := clampf(float(mark_pops[cell]) / maxf(mark_pop_duration, 0.001), 0.0, 1.0)
				var mark_motion := _smooth_fade(mark_phase)
				mark_scale = lerpf(0.46, 1.0, _cartoon_settle(mark_phase))
				mark_alpha = mark_motion
				draw_arc(tile_rect.get_center(), slot * (0.12 + mark_motion * 0.16), 0.0, TAU, 32, _with_alpha(CREAM, _smooth_pulse(mark_phase) * 0.72), 4.5, true)
			_draw_whisker_mark(tile_rect.get_center(), slot * 0.23 * mark_scale, _with_alpha(INK, 0.80 * mark_alpha))
		elif cell_states[cell] == CellState.CAT:
			var pop_scale := 1.0
			var pop_phase := 1.0
			var cat_alpha := 1.0
			if cat_pops.has(cell):
				pop_phase = clampf(float(cat_pops[cell]) / maxf(cat_pop_duration, 0.001), 0.0, 1.0)
				var pop_motion := _smooth_fade(pop_phase)
				var pop_envelope := _smooth_pulse(pop_phase)
				pop_scale = lerpf(0.55, 1.0, _cartoon_settle(pop_phase))
				cat_alpha = pop_motion
				draw_circle(tile_rect.get_center(), slot * (0.18 + pop_motion * 0.09), _with_alpha(CREAM, pop_envelope * 0.18))
				draw_arc(tile_rect.get_center(), slot * (0.24 + pop_motion * 0.17), 0.0, TAU, 40, _with_alpha(CREAM, pop_envelope * 0.88), maxf(5.0, slot * 0.045), true)
			if game_mode == GameMode.WON:
				var row_delay := float(row) * celebration_stagger
				if win_time > row_delay:
					var bob_phase := clampf((win_time - row_delay) / maxf(celebration_duration, 0.001), 0.0, 1.0)
					var bob_envelope := _smooth_pulse(bob_phase)
					pop_scale *= 1.0 + sin(bob_phase * PI * 2.0) * 0.07 * bob_envelope
					tile_rect.position.y -= bob_envelope * 9.0
			_draw_cat(tile_rect.get_center(), slot * 0.31, pop_scale, _cat_pose(cell), cat_alpha, float(cell) * 0.47)
			if given_cells.has(cell):
				draw_arc(tile_rect.get_center(), slot * 0.35, 0.0, TAU, 40, _with_alpha(GOLD, 0.92), 5.5, true)

	_draw_region_boundaries(board_rect, slot)

	if game_mode == GameMode.WON:
		var sweep_phase := _smooth_fade(win_time / maxf(celebration_duration, 0.001))
		var sweep_x := lerpf(board_rect.position.x - 120.0, board_rect.end.x + 120.0, sweep_phase)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sweep_x - 75.0, board_rect.position.y),
			Vector2(sweep_x - 15.0, board_rect.position.y),
			Vector2(sweep_x + 75.0, board_rect.end.y),
			Vector2(sweep_x + 15.0, board_rect.end.y)
		]), Color(1.0, 0.96, 0.72, 0.14))


func _draw_region_boundaries(board_rect: Rect2, slot: float) -> void:
	var boundary_color := _with_alpha(INK, 0.50)
	var boundary_width := clampf(slot * 0.050, 5.5, 7.5)
	for row in range(grid_size):
		for column in range(grid_size):
			var cell := row * grid_size + column
			var region := int(puzzle["regions"][cell])
			if column < grid_size - 1 and int(puzzle["regions"][cell + 1]) != region:
				var x := board_rect.position.x + float(column + 1) * slot
				var vertical_start := Vector2(x, board_rect.position.y + float(row) * slot + 7.0)
				var vertical_finish := Vector2(x, board_rect.position.y + float(row + 1) * slot - 7.0)
				draw_line(vertical_start, vertical_finish, boundary_color, boundary_width, true)
				draw_circle(vertical_start, boundary_width * 0.5, boundary_color)
				draw_circle(vertical_finish, boundary_width * 0.5, boundary_color)
			if row < grid_size - 1 and int(puzzle["regions"][cell + grid_size]) != region:
				var y := board_rect.position.y + float(row + 1) * slot
				var horizontal_start := Vector2(board_rect.position.x + float(column) * slot + 7.0, y)
				var horizontal_finish := Vector2(board_rect.position.x + float(column + 1) * slot - 7.0, y)
				draw_line(horizontal_start, horizontal_finish, boundary_color, boundary_width, true)
				draw_circle(horizontal_start, boundary_width * 0.5, boundary_color)
				draw_circle(horizontal_finish, boundary_width * 0.5, boundary_color)

func _draw_footer() -> void:
	if toast_time <= 0.0 and _tutorial_target_cell() >= 0:
		_draw_tutorial_prompt()
	else:
		var base_instruction := "TAP TO MARK  ·  DOUBLE-TAP OR RIGHT-CLICK TO PLACE"
		var instruction_rect := Rect2(90.0, 1148.0, 720.0, 44.0)
		var toast_alpha := 0.0
		if toast_time > 0.0:
			toast_alpha = _smooth_fade(toast_time / maxf(ui_fade_duration, 0.001))
		var border_color := MINT
		if error_time > 0.0:
			border_color = MINT.lerp(CORAL, toast_alpha)
		_rounded_rect(Rect2(instruction_rect.position + Vector2(0.0, 4.0), instruction_rect.size), _with_alpha(INK, 0.12), 22.0)
		_draw_panel(instruction_rect, _with_alpha(CREAM, 0.97), 22.0, _with_alpha(border_color, 0.62), 4.0)
		if toast_alpha < 1.0:
			_draw_text_center(base_instruction, instruction_rect, 18, _with_alpha(INK, 1.0 - toast_alpha))
		if toast_alpha > 0.0:
			_draw_text_center(toast_text, instruction_rect, 18, _with_alpha(INK, toast_alpha))

	_draw_button(UNDO_RECT, "UNDO", "undo", not history.is_empty())
	_draw_button(RESTART_RECT, "RESTART", "restart", true)
	var difficulty_rect := Rect2(250.0, 1321.0, 400.0, 42.0)
	_draw_panel(difficulty_rect, _with_alpha(INK, 0.48), 21.0, _with_alpha(CREAM, 0.22), 3.0)
	_draw_text_center(_difficulty_label(), difficulty_rect, 16, _with_alpha(CREAM, 0.88))


func _draw_tutorial_prompt() -> void:
	var prompt_rect := Rect2(75.0, 1137.0, 750.0, 60.0)
	var accent := MINT if tutorial_step == TutorialStep.MARK_SEAT else GOLD
	var step_label := "1 / 2" if tutorial_step == TutorialStep.MARK_SEAT else "2 / 2"
	var message := "TAP THE GLOWING SEAT TO MARK IT IMPOSSIBLE"
	if tutorial_step == TutorialStep.PLACE_CAT:
		message = "NICE! DOUBLE-TAP THE GLOWING SEAT FOR A CAT"
	_rounded_rect(Rect2(prompt_rect.position + Vector2(0.0, 5.0), prompt_rect.size), _with_alpha(INK, 0.16), 28.0)
	_draw_panel(prompt_rect, _with_alpha(CREAM, 0.98), 28.0, _with_alpha(accent, 0.78), 5.0)
	var badge_rect := Rect2(prompt_rect.position + Vector2(12.0, 10.0), Vector2(96.0, 40.0))
	_draw_panel(badge_rect, accent, 20.0, _with_alpha(INK, 0.16), 3.0)
	_draw_text_center(step_label, badge_rect, 17, INK)
	_draw_text_center(message, Rect2(prompt_rect.position.x + 116.0, prompt_rect.position.y, prompt_rect.size.x - 128.0, prompt_rect.size.y), 19, INK)


func _draw_button(rect: Rect2, label: String, icon: String, enabled: bool) -> void:
	var hovered := rect.has_point(pointer_base) and game_mode == GameMode.PLAYING
	var fill := _with_alpha(CREAM, 0.98 if enabled else 0.52)
	if hovered and enabled:
		fill = Color.WHITE
	var shadow_alpha := 0.16 if enabled else 0.07
	var border_color := MINT if hovered and enabled else (CREAM if enabled else INK_SOFT)
	var border_alpha := 0.62 if enabled else 0.16
	_rounded_rect(Rect2(rect.position + Vector2(0.0, 7.0), rect.size), Color(0.0, 0.0, 0.0, shadow_alpha), 40.0)
	_draw_panel(rect, fill, 40.0, _with_alpha(border_color, border_alpha), 4.0)
	var icon_center := Vector2(rect.position.x + 58.0, rect.get_center().y)
	draw_circle(icon_center, 25.0, _with_alpha(MINT if enabled else INK_SOFT, 0.20 if enabled else 0.10))
	if icon == "undo":
		draw_arc(icon_center, 17.0, -2.5, 2.15, 28, INK_SOFT, 6.0, true)
		draw_colored_polygon(PackedVector2Array([
			icon_center + Vector2(-20.0, -8.0),
			icon_center + Vector2(-7.0, -15.0),
			icon_center + Vector2(-8.0, -1.0)
		]), INK_SOFT)
	else:
		draw_arc(icon_center, 17.0, -0.3, 5.15, 30, INK_SOFT, 6.0, true)
		draw_colored_polygon(PackedVector2Array([
			icon_center + Vector2(17.0, -13.0),
			icon_center + Vector2(20.0, 2.0),
			icon_center + Vector2(8.0, -5.0)
		]), INK_SOFT)
	_draw_text_center(label, Rect2(rect.position.x + 74.0, rect.position.y, rect.size.x - 90.0, rect.size.y), 23, INK if enabled else _with_alpha(INK, 0.48))


func _draw_win_overlay() -> void:
	var alpha := _smooth_fade((win_time - celebration_stagger * 4.0) / maxf(ui_fade_duration, 0.001))
	if alpha <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color(0.015, 0.035, 0.09, 0.62 * alpha))
	var modal := Rect2(110.0, 335.0, 680.0, 735.0)
	_rounded_rect(Rect2(modal.position + Vector2(0.0, 15.0), modal.size), Color(0.0, 0.0, 0.0, 0.24 * alpha), 50.0)
	_draw_panel(modal, _with_alpha(CREAM, alpha), 50.0, _with_alpha(GOLD, 0.72 * alpha), 6.0)
	var mascot_center := Vector2(450.0, 548.0)
	draw_circle(mascot_center, 180.0, _with_alpha(GOLD, 0.08 * alpha))
	for ray in range(18):
		var angle := TAU * float(ray) / 18.0 + win_time * 0.12
		draw_line(mascot_center + Vector2.from_angle(angle) * 135.0, mascot_center + Vector2.from_angle(angle) * 180.0, _with_alpha(GOLD, 0.34 * alpha), 6.0, true)
	var mascot_delay := celebration_stagger * 4.0
	var mascot_duration := celebration_duration * 0.42
	var mascot_phase := clampf((win_time - mascot_delay) / maxf(mascot_duration, 0.001), 0.0, 1.0)
	var mascot_scale := lerpf(0.68, 1.0, _cartoon_settle(mascot_phase))
	_draw_cat(mascot_center, 118.0, mascot_scale, CatPose.HAPPY, alpha)
	_draw_text_center("PURRFECT SWEEP!", Rect2(150.0, 708.0, 600.0, 72.0), 42, _with_alpha(INK, alpha))
	_draw_text_center("Room %02d cleared in %s" % [level_index + 1, _format_time(elapsed_time)], Rect2(160.0, 786.0, 580.0, 46.0), 21, _with_alpha(INK_SOFT, alpha))
	_draw_text_center("Every cat follows all three rules", Rect2(220.0, 835.0, 460.0, 40.0), 18, _with_alpha(CORAL.darkened(0.18), alpha))
	var button_fill := CORAL.lightened(0.04) if MODAL_BUTTON_RECT.has_point(pointer_base) else CORAL
	_rounded_rect(Rect2(MODAL_BUTTON_RECT.position + Vector2(0.0, 8.0), MODAL_BUTTON_RECT.size), Color(0.28, 0.10, 0.08, 0.18 * alpha), 46.0)
	_draw_panel(MODAL_BUTTON_RECT, _with_alpha(button_fill, alpha), 46.0, _with_alpha(CREAM, 0.48 * alpha), 5.0)
	var button_text := "PLAY AGAIN" if level_index >= PuzzleBook.LEVELS.size() - 1 else "NEXT ROOM"
	_draw_text_center(button_text, MODAL_BUTTON_RECT, 28, _with_alpha(INK, alpha))


func _draw_particles() -> void:
	for particle in particles:
		var life_ratio := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		var particle_progress := 1.0 - life_ratio
		var color: Color = particle["color"]
		color.a *= _smooth_pulse(particle_progress)
		var pos: Vector2 = particle["pos"]
		var particle_size := float(particle["size"])
		var direction := Vector2.from_angle(float(particle["spin"]))
		var side := Vector2(-direction.y, direction.x)
		var kind := String(particle["kind"])
		if kind == "place":
			draw_colored_polygon(PackedVector2Array([
				pos + direction * particle_size,
				pos + side * particle_size * 0.62,
				pos - direction * particle_size,
				pos - side * particle_size * 0.62
			]), color)
			draw_circle(pos, maxf(1.4, particle_size * 0.24), _with_alpha(CREAM, color.a))
		elif kind == "error":
			var error_width := maxf(2.5, particle_size * 0.62)
			draw_line(pos - direction * particle_size, pos + direction * particle_size, color, error_width, true)
			draw_circle(pos - direction * particle_size, error_width * 0.5, color)
			draw_circle(pos + direction * particle_size, error_width * 0.5, color)
		else:
			var confetti_width := maxf(3.0, particle_size * 0.58)
			var confetti_half := particle_size * 0.82
			draw_line(pos - direction * confetti_half, pos + direction * confetti_half, color, confetti_width, true)
			draw_circle(pos - direction * confetti_half, confetti_width * 0.5, color)
			draw_circle(pos + direction * confetti_half, confetti_width * 0.5, color)


func _cat_pose(cell: int = -1) -> int:
	if game_mode == GameMode.WON:
		return CatPose.HAPPY
	if error_time > 0.0:
		return CatPose.WORRIED
	if cell >= 0 and given_cells.has(cell):
		return CatPose.SLEEPY
	if cell >= 0 and cat_pops.has(cell):
		return CatPose.HAPPY
	return CatPose.IDLE


func _draw_cat(center: Vector2, radius: float, scale_value: float, pose: int = CatPose.IDLE, opacity: float = 1.0, phase_offset: float = 0.0) -> void:
	var frame_size := CAT_ATLAS.get_size() * 0.5
	var frame_column := int(pose) % 2
	var frame_row := int(int(pose) / 2)
	var source_rect := Rect2(Vector2(float(frame_column), float(frame_row)) * frame_size, frame_size)
	var idle_phase := animation_clock * cat_idle_speed * TAU + phase_offset
	var breathe := sin(idle_phase)
	var animated_center := center + Vector2(0.0, cos(idle_phase) * cat_bob_height)
	var visual_size := Vector2.ONE * radius * 2.75 * scale_value
	visual_size *= Vector2(
		1.0 + breathe * cat_breathe_amount,
		1.0 - breathe * cat_breathe_amount * 0.62
	)
	var destination := Rect2(animated_center - visual_size * 0.5, visual_size)
	var shadow_size := visual_size * Vector2(0.74, 0.18)
	var shadow_rect := Rect2(
		Vector2(animated_center.x - shadow_size.x * 0.5, animated_center.y + visual_size.y * 0.34),
		shadow_size
	)
	_rounded_rect(shadow_rect, Color(0.03, 0.04, 0.08, 0.18 * opacity), shadow_size.y * 0.38)

	var outline_width := clampf(radius * 0.055 * border_weight, 1.5, 5.5)
	var outline_color := _with_alpha(INK, 0.92 * opacity)
	var outline_directions: Array[Vector2] = [
		Vector2(-1.0, -1.0),
		Vector2(0.0, -1.0),
		Vector2(1.0, -1.0),
		Vector2(-1.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(-1.0, 1.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0)
	]
	for direction in outline_directions:
		var outline_rect := Rect2(destination.position + direction * outline_width, destination.size)
		draw_texture_rect_region(CAT_ATLAS, outline_rect, source_rect, outline_color, false, true)
	draw_texture_rect_region(CAT_ATLAS, destination, source_rect, _with_alpha(Color.WHITE, opacity), false, true)


func _draw_whisker_mark(center: Vector2, radius: float, color: Color) -> void:
	var width := clampf(radius * 0.23, 5.5, 8.5)
	var a_start := center + Vector2(-radius, -radius * 0.78)
	var a_end := center + Vector2(radius, radius * 0.78)
	var b_start := center + Vector2(radius, -radius * 0.78)
	var b_end := center + Vector2(-radius, radius * 0.78)
	draw_line(a_start, a_end, color, width, true)
	draw_line(b_start, b_end, color, width, true)
	for endpoint in [a_start, a_end, b_start, b_end]:
		draw_circle(endpoint, width * 0.5, color)
	draw_circle(center, maxf(2.0, radius * 0.15), _with_alpha(CREAM, 0.78))


func _draw_color_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.18))
	draw_circle(center, 20.0, PAPER)
	draw_circle(center + Vector2(-7.0, -5.0), 8.0, CORAL)
	draw_circle(center + Vector2(7.0, -5.0), 8.0, MINT)
	draw_circle(center + Vector2(0.0, 7.0), 8.0, GOLD)


func _draw_line_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.18))
	draw_circle(center, 20.0, PAPER)
	for index in range(3):
		var y := -11.0 + float(index) * 11.0
		draw_line(center + Vector2(-12.0, y), center + Vector2(12.0, y), _with_alpha(INK, 0.64), 5.5, true)
		draw_circle(center + Vector2(-12.0, y), 2.75, _with_alpha(INK, 0.64))
		draw_circle(center + Vector2(12.0, y), 2.75, _with_alpha(INK, 0.64))
	draw_circle(center, 5.5, MINT)


func _draw_space_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.18))
	draw_circle(center, 20.0, PAPER)
	draw_arc(center, 14.0, 0.0, TAU, 28, _with_alpha(INK, 0.58), 5.0, true)
	draw_circle(center, 6.0, CORAL)
	draw_circle(center + Vector2(0.0, -14.0), 2.2, MINT)
	draw_circle(center + Vector2(0.0, 14.0), 2.2, MINT)


func _shares_rule(cell: int, source: int) -> bool:
	if source < 0:
		return false
	var row := cell / grid_size
	var column := cell % grid_size
	var source_row := source / grid_size
	var source_column := source % grid_size
	return row == source_row or column == source_column or int(puzzle["regions"][cell]) == int(puzzle["regions"][source]) or (abs(row - source_row) <= 1 and abs(column - source_column) <= 1)


func _difficulty_label() -> String:
	if grid_size == 5:
		return "COZY SHIFT  ·  5 × 5"
	if grid_size == 6:
		return "CLEVER SHIFT  ·  6 × 6"
	return "MOONLIT SHIFT  ·  7 × 7"


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _scale_rect(rect: Rect2, amount: float) -> Rect2:
	var scaled_size := rect.size * amount
	return Rect2(rect.get_center() - scaled_size * 0.5, scaled_size)


func _smooth_fade(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _smooth_pulse(progress: float) -> float:
	var t := _smooth_fade(progress)
	return 4.0 * t * (1.0 - t)


func _cartoon_settle(progress: float) -> float:
	var t := _smooth_fade(progress) - 1.0
	return 1.0 + (cartoon_overshoot + 1.0) * t * t * t + cartoon_overshoot * t * t


func _draw_panel(rect: Rect2, fill: Color, radius: float, border: Color, border_width: float) -> void:
	var weighted_width := border_width * border_weight
	if weighted_width > 0.0 and border.a > 0.0:
		_rounded_rect(rect, border, radius)
		_rounded_rect(rect.grow(-weighted_width), fill, maxf(1.0, radius - weighted_width))
	else:
		_rounded_rect(rect, fill, radius)


func _rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	if color.a <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var rounded := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if rounded <= 0.5:
		draw_rect(rect, color)
		return
	var k := 0.382683432
	var d := 0.707106781
	var e := 0.923879533
	var top_left := rect.position + Vector2(rounded, rounded)
	var top_right := Vector2(rect.end.x - rounded, rect.position.y + rounded)
	var bottom_right := rect.end - Vector2(rounded, rounded)
	var bottom_left := Vector2(rect.position.x + rounded, rect.end.y - rounded)
	draw_colored_polygon(PackedVector2Array([
		top_left + Vector2(-rounded, 0.0),
		top_left + Vector2(-e * rounded, -k * rounded),
		top_left + Vector2(-d * rounded, -d * rounded),
		top_left + Vector2(-k * rounded, -e * rounded),
		top_left + Vector2(0.0, -rounded),
		top_right + Vector2(0.0, -rounded),
		top_right + Vector2(k * rounded, -e * rounded),
		top_right + Vector2(d * rounded, -d * rounded),
		top_right + Vector2(e * rounded, -k * rounded),
		top_right + Vector2(rounded, 0.0),
		bottom_right + Vector2(rounded, 0.0),
		bottom_right + Vector2(e * rounded, k * rounded),
		bottom_right + Vector2(d * rounded, d * rounded),
		bottom_right + Vector2(k * rounded, e * rounded),
		bottom_right + Vector2(0.0, rounded),
		bottom_left + Vector2(0.0, rounded),
		bottom_left + Vector2(-k * rounded, e * rounded),
		bottom_left + Vector2(-d * rounded, d * rounded),
		bottom_left + Vector2(-e * rounded, k * rounded),
		bottom_left + Vector2(-rounded, 0.0)
	]), color)


func _draw_text_center(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var baseline := rect.position.y + (rect.size.y - ui_font.get_height(font_size)) * 0.5 + ui_font.get_height(font_size) * 0.82
	draw_string(ui_font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


func _draw_text_left(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	draw_string(ui_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _with_alpha(color: Color, multiplier: float) -> Color:
	var result := color
	result.a *= multiplier
	return result


func _validate_puzzle_pack() -> void:
	for index in range(PuzzleBook.LEVELS.size()):
		var level: Dictionary = PuzzleBook.LEVELS[index]
		var n := int(level["size"])
		if level["regions"].size() != n * n or level["solution"].size() != n:
			push_error("Catsweeper puzzle %d has invalid dimensions." % (index + 1))
			continue
		var solution_count := _count_solutions(level)
		if solution_count != 1:
			push_error("Catsweeper puzzle %d must have exactly one solution, found %d." % [index + 1, solution_count])


func _count_solutions(level: Dictionary) -> int:
	var n := int(level["size"])
	var used_columns: Array[bool] = []
	var used_regions: Array[bool] = []
	var columns: Array[int] = []
	used_columns.resize(n)
	used_columns.fill(false)
	used_regions.resize(n)
	used_regions.fill(false)
	columns.resize(n)
	columns.fill(-1)
	validation_solution_count = 0
	_search_solution(0, n, level["regions"], used_columns, used_regions, columns)
	return validation_solution_count


func _search_solution(row: int, n: int, regions: Array, used_columns: Array[bool], used_regions: Array[bool], columns: Array[int]) -> void:
	if validation_solution_count >= 2:
		return
	if row == n:
		validation_solution_count += 1
		return
	for column in range(n):
		var region := int(regions[row * n + column])
		if used_columns[column] or used_regions[region]:
			continue
		if row > 0 and abs(column - columns[row - 1]) <= 1:
			continue
		used_columns[column] = true
		used_regions[region] = true
		columns[row] = column
		_search_solution(row + 1, n, regions, used_columns, used_regions, columns)
		used_columns[column] = false
		used_regions[region] = false
