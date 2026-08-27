extends Control

const PuzzleBook = preload("res://scripts/puzzles.gd")
const TWILIGHT_SHADER = preload("res://shaders/twilight.gdshader")
const MASCOT = preload("res://assets/art/catsweeper_mascot.png")
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
enum GameMode { PLAYING, WON, LOST }

@export_group("Feel")
@export_range(0.12, 0.45, 0.01) var double_tap_window := 0.28
@export_range(0.08, 0.35, 0.01) var mark_pop_duration := 0.14
@export_range(0.10, 0.45, 0.01) var cat_pop_duration := 0.24
@export_range(0.15, 0.60, 0.01) var rule_pulse_duration := 0.40
@export_range(0.12, 0.50, 0.01) var shake_duration := 0.24
@export_range(2.0, 18.0, 0.5) var shake_strength := 6.0
@export_range(0.25, 1.20, 0.05) var board_intro_duration := 0.55
@export_range(0.02, 0.12, 0.005) var celebration_stagger := 0.055
@export_range(0.6, 2.0, 0.05) var celebration_duration := 1.15
@export_range(250.0, 650.0, 10.0) var particle_gravity := 430.0
@export_range(6, 24, 1) var place_sparkle_count := 14
@export_range(36, 96, 2) var win_confetti_count := 64

@export_group("Atmosphere")
@export_range(0.0, 0.25, 0.005) var background_drift_speed := 0.045
@export_range(0.0, 1.5, 0.01) var background_glow_strength := 0.72
@export_range(0.0, 0.03, 0.001) var background_grain_strength := 0.006

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
var hearts := 3
var game_mode := GameMode.PLAYING
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
var intro_time := 0.0
var pulse_cell := -1
var pulse_time := 0.0
var error_cell := -1
var error_time := 0.0
var shake_time := 0.0
var win_time := 0.0
var loss_time := 0.0
var toast_text := ""
var toast_time := 0.0
var cat_pops: Dictionary = {}
var mark_pops: Dictionary = {}
var particles: Array[Dictionary] = []

var validation_solution_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ui_font = ThemeDB.fallback_font
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
	hearts = 3
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
	loss_time = 0.0
	cat_pops.clear()
	mark_pops.clear()
	particles.clear()
	if level_index == 0:
		toast_text = "One seat is found. Sweep the impossible seats first."
		toast_time = 5.0
	else:
		toast_text = ""
		toast_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	animation_clock += delta
	intro_time = minf(intro_time + delta, board_intro_duration)
	if game_mode == GameMode.PLAYING:
		elapsed_time += delta
	elif game_mode == GameMode.WON:
		win_time += delta
	else:
		loss_time += delta

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
		history.append({"changes": drag_changes.duplicate(true), "hearts": hearts})
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
	if game_mode == GameMode.LOST:
		if loss_time >= 0.35 and MODAL_BUTTON_RECT.has_point(base_position):
			_start_level(level_index)
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
	var eased_intro := 1.0 - pow(1.0 - intro_ratio, 3.0)
	return _scale_rect(BOARD_RECT, lerpf(0.94, 1.0, eased_intro))


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
	_push_history_change(cell, old_state, hearts)
	cell_states[cell] = new_state
	if new_state == CellState.MARKED:
		mark_pops[cell] = 0.0
		_play_sound(mark_player, randf_range(0.96, 1.06))
	else:
		_play_sound(mark_player, 0.88)


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


func _try_place_cat(cell: int) -> void:
	if game_mode != GameMode.PLAYING or given_cells.has(cell):
		return
	if cell_states[cell] == CellState.CAT:
		_push_history_change(cell, CellState.CAT, hearts)
		cell_states[cell] = CellState.EMPTY
		_play_sound(mark_player, 0.84)
		return

	var row := cell / grid_size
	var column := cell % grid_size
	var correct := int(puzzle["solution"][row]) == column
	var old_state := cell_states[cell]
	_push_history_change(cell, old_state, hearts)
	if correct:
		cell_states[cell] = CellState.CAT
		cat_pops[cell] = 0.0
		pulse_cell = cell
		pulse_time = rule_pulse_duration
		_spawn_place_sparkles(_cell_center(cell), region_colors[int(puzzle["regions"][cell]) % region_colors.size()])
		_play_sound(place_player, 0.96 + float(_cat_count()) * 0.035)
		if _cat_count() == grid_size:
			_complete_level()
	else:
		cell_states[cell] = CellState.MARKED
		mark_pops[cell] = 0.0
		hearts -= 1
		error_cell = cell
		error_time = shake_duration
		shake_time = shake_duration
		toast_text = _wrong_reason(cell)
		toast_time = 2.4
		_spawn_error_sparks(_cell_center(cell))
		_play_sound(error_player, randf_range(0.92, 1.02))
		if hearts <= 0:
			game_mode = GameMode.LOST
			loss_time = 0.0
			pending_cell = -1


func _wrong_reason(cell: int) -> String:
	var row := cell / grid_size
	var column := cell % grid_size
	var region := int(puzzle["regions"][cell])
	for other in range(cell_states.size()):
		if cell_states[other] != CellState.CAT:
			continue
		var other_row := other / grid_size
		var other_column := other % grid_size
		if other_row == row:
			return "That row already has a cat."
		if other_column == column:
			return "That column already has a cat."
		if abs(other_row - row) <= 1 and abs(other_column - column) <= 1:
			return "Too close—cats need a quiet seat around them."
		if int(puzzle["regions"][other]) == region:
			return "That color already has its cat."
	return "That choice leaves another cat without a seat."


func _push_history_change(cell: int, old_state: int, old_hearts: int) -> void:
	history.append({
		"changes": [{"cell": cell, "state": old_state}],
		"hearts": old_hearts
	})


func _undo() -> void:
	if history.is_empty() or game_mode == GameMode.WON:
		toast_text = "Nothing to sweep back yet."
		toast_time = 1.4
		return
	var action: Dictionary = history.pop_back()
	for change in action["changes"]:
		cell_states[int(change["cell"])] = int(change["state"])
	hearts = int(action["hearts"])
	if game_mode == GameMode.LOST:
		game_mode = GameMode.PLAYING
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
		particles.append({
			"kind": "place",
			"pos": origin,
			"vel": Vector2.from_angle(angle) * speed,
			"life": randf_range(0.38, 0.64),
			"max_life": 0.64,
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
		particles.append({
			"kind": "win",
			"pos": origin,
			"vel": Vector2(randf_range(-165.0, 165.0), randf_range(-480.0, -180.0)),
			"life": randf_range(1.45, 2.45),
			"max_life": 2.45,
			"color": palette[index % palette.size()],
			"size": randf_range(5.0, 9.0),
			"spin": randf_range(0.0, TAU),
			"spin_speed": randf_range(-7.0, 7.0)
		})


func _draw() -> void:
	_update_canvas_transform()
	var shake := Vector2.ZERO
	if shake_time > 0.0:
		var strength := shake_strength * (shake_time / maxf(shake_duration, 0.001))
		shake = Vector2(sin(animation_clock * 67.0), cos(animation_clock * 51.0) * 0.45) * strength
	draw_set_transform(canvas_offset, 0.0, Vector2.ONE * canvas_scale)
	_draw_header()
	_draw_rule_cards()
	draw_set_transform(canvas_offset + shake * canvas_scale, 0.0, Vector2.ONE * canvas_scale)
	_draw_board()
	draw_set_transform(canvas_offset, 0.0, Vector2.ONE * canvas_scale)
	_draw_footer()
	if game_mode == GameMode.WON:
		_draw_win_overlay()
	elif game_mode == GameMode.LOST:
		_draw_loss_overlay()
	_draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_header() -> void:
	_draw_panel(Rect2(43.0, 30.0, 118.0, 118.0), Color(0.01, 0.03, 0.09, 0.44), 38.0, _with_alpha(MINT, 0.24), 2.0)
	draw_texture_rect(MASCOT, Rect2(49.0, 36.0, 106.0, 106.0), false)
	_draw_text_left("CATSWEEPER", Vector2(181.0, 84.0), 43, CREAM)
	_draw_text_left("quiet logic for clever paws", Vector2(184.0, 124.0), 20, _with_alpha(CREAM, 0.72))

	var level_rect := Rect2(681.0, 54.0, 154.0, 68.0)
	_draw_panel(level_rect, _with_alpha(CREAM, 0.14), 34.0, _with_alpha(CREAM, 0.22), 2.0)
	_draw_text_center("ROOM %02d" % (level_index + 1), level_rect, 22, CREAM)

	var progress_rect := Rect2(75.0, 168.0, 365.0, 72.0)
	var hearts_rect := Rect2(462.0, 168.0, 363.0, 72.0)
	_draw_panel(progress_rect, CREAM, 36.0, _with_alpha(MINT, 0.44), 2.0)
	_draw_panel(hearts_rect, CREAM, 36.0, _with_alpha(CORAL, 0.38), 2.0)
	draw_circle(Vector2(118.0, 204.0), 28.0, _with_alpha(MINT, 0.20))
	_draw_cat(Vector2(118.0, 204.0), 22.0, 1.0, MINT)
	_draw_text_left("%d / %d  CATS SEATED" % [_cat_count(), grid_size], Vector2(158.0, 214.0), 24, INK)
	for index in range(3):
		var heart_radius := 19.0
		var heart_color := CORAL if index < hearts else Color("#DDD7CC")
		if error_time > 0.0 and index == hearts:
			var fade_phase := 1.0 - error_time / maxf(shake_duration, 0.001)
			heart_radius *= 1.0 + sin(fade_phase * PI) * 0.28
			heart_color = CORAL.lerp(Color("#DDD7CC"), fade_phase)
		_draw_heart(Vector2(565.0 + float(index) * 72.0, 204.0), heart_radius, heart_color)


func _draw_rule_cards() -> void:
	var labels := ["ONE PER COLOR", "ONE PER LINE", "GIVE THEM SPACE"]
	for index in range(3):
		var card := Rect2(75.0 + float(index) * 255.0, 263.0, 235.0, 68.0)
		_draw_panel(card, _with_alpha(CREAM, 0.97), 30.0, _with_alpha(CREAM, 0.48), 2.0)
		var icon_center := Vector2(card.position.x + 37.0, card.position.y + 34.0)
		if index == 0:
			_draw_color_icon(icon_center)
		elif index == 1:
			_draw_line_icon(icon_center)
		else:
			_draw_space_icon(icon_center)
		_draw_text_left(labels[index], Vector2(card.position.x + 70.0, card.position.y + 41.0), 18, INK_SOFT)


func _draw_board() -> void:
	var board_rect := _animated_board_rect()
	var tray := board_rect.grow(18.0)
	_rounded_rect(Rect2(tray.position + Vector2(0.0, 11.0), tray.size), Color(0.005, 0.012, 0.04, 0.24), 44.0)
	_draw_panel(tray, CREAM, 44.0, _with_alpha(CREAM, 0.52), 2.0)

	var slot := board_rect.size.x / float(grid_size)
	var gap := 9.0 if grid_size <= 6 else 8.0
	var tile_radius := minf(24.0, slot * 0.22)
	for cell in range(cell_states.size()):
		var row := cell / grid_size
		var column := cell % grid_size
		var tile_rect := Rect2(
			board_rect.position + Vector2(float(column) * slot + gap * 0.5, float(row) * slot + gap * 0.5),
			Vector2(slot - gap, slot - gap)
		)
		var region := int(puzzle["regions"][cell])
		var tile_color := region_colors[region % region_colors.size()]
		if cell == hover_cell and game_mode == GameMode.PLAYING:
			tile_color = tile_color.lightened(0.055)
		if cell == error_cell and error_time > 0.0:
			tile_color = tile_color.lerp(CORAL, 0.30 + 0.24 * sin(animation_clock * 34.0))
		_rounded_rect(tile_rect, tile_color, tile_radius)
		if cell == error_cell and error_time > 0.0:
			_draw_panel(tile_rect.grow(-2.0), tile_color, tile_radius - 2.0, _with_alpha(CORAL, 0.92), 4.0)

		if pulse_time > 0.0 and _shares_rule(cell, pulse_cell):
			var pulse_alpha := sin((pulse_time / maxf(rule_pulse_duration, 0.001)) * PI) * 0.17
			_rounded_rect(tile_rect.grow(-4.0), Color(1.0, 1.0, 1.0, pulse_alpha), maxf(8.0, tile_radius - 4.0))
		if cell == pulse_cell and pulse_time > 0.0:
			var ring_phase := 1.0 - pulse_time / maxf(rule_pulse_duration, 0.001)
			draw_arc(tile_rect.get_center(), slot * (0.28 + ring_phase * 0.15), 0.0, TAU, 40, _with_alpha(CREAM, (1.0 - ring_phase) * 0.78), 4.0, true)

		if cell_states[cell] == CellState.MARKED:
			var mark_scale := 1.0
			if mark_pops.has(cell):
				var mark_phase := clampf(float(mark_pops[cell]) / maxf(mark_pop_duration, 0.001), 0.0, 1.0)
				mark_scale = 0.72 + sin(mark_phase * PI) * 0.36 + mark_phase * 0.28
				draw_arc(tile_rect.get_center(), slot * (0.12 + mark_phase * 0.16), 0.0, TAU, 32, _with_alpha(CREAM, (1.0 - mark_phase) * 0.72), 3.0, true)
			_draw_whisker_mark(tile_rect.get_center(), slot * 0.23 * mark_scale, _with_alpha(INK, 0.70))
		elif cell_states[cell] == CellState.CAT:
			var pop_scale := 1.0
			var pop_phase := 1.0
			if cat_pops.has(cell):
				pop_phase = clampf(float(cat_pops[cell]) / maxf(cat_pop_duration, 0.001), 0.0, 1.0)
				pop_scale = 0.82 + pop_phase * 0.18 + sin(pop_phase * PI) * 0.20
				draw_circle(tile_rect.get_center(), slot * (0.18 + pop_phase * 0.09), _with_alpha(CREAM, (1.0 - pop_phase) * 0.18))
				draw_arc(tile_rect.get_center(), slot * (0.24 + pop_phase * 0.17), 0.0, TAU, 40, _with_alpha(CREAM, (1.0 - pop_phase) * 0.88), maxf(3.0, slot * 0.035), true)
			if game_mode == GameMode.WON:
				var row_delay := float(row) * celebration_stagger
				if win_time > row_delay:
					var bob_phase := clampf((win_time - row_delay) / maxf(celebration_duration, 0.001), 0.0, 1.0)
					pop_scale *= 1.0 + sin(bob_phase * PI * 2.0) * 0.07 * (1.0 - bob_phase)
					tile_rect.position.y -= sin(bob_phase * PI) * 9.0
			var accent := region_colors[region % region_colors.size()].darkened(0.10)
			_draw_cat(tile_rect.get_center(), slot * 0.31, pop_scale, accent)
			if given_cells.has(cell):
				draw_arc(tile_rect.get_center(), slot * 0.35, 0.0, TAU, 40, _with_alpha(GOLD, 0.92), 4.0, true)

	_draw_region_boundaries(board_rect, slot)

	if game_mode == GameMode.WON:
		var sweep_x := lerpf(board_rect.position.x - 120.0, board_rect.end.x + 120.0, clampf(win_time / maxf(celebration_duration, 0.001), 0.0, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(sweep_x - 75.0, board_rect.position.y),
			Vector2(sweep_x - 15.0, board_rect.position.y),
			Vector2(sweep_x + 75.0, board_rect.end.y),
			Vector2(sweep_x + 15.0, board_rect.end.y)
		]), Color(1.0, 0.96, 0.72, 0.14))


func _draw_region_boundaries(board_rect: Rect2, slot: float) -> void:
	var boundary_color := _with_alpha(INK, 0.22)
	for row in range(grid_size):
		for column in range(grid_size):
			var cell := row * grid_size + column
			var region := int(puzzle["regions"][cell])
			if column < grid_size - 1 and int(puzzle["regions"][cell + 1]) != region:
				var x := board_rect.position.x + float(column + 1) * slot
				draw_line(Vector2(x, board_rect.position.y + float(row) * slot + 7.0), Vector2(x, board_rect.position.y + float(row + 1) * slot - 7.0), boundary_color, 3.0, true)
			if row < grid_size - 1 and int(puzzle["regions"][cell + grid_size]) != region:
				var y := board_rect.position.y + float(row + 1) * slot
				draw_line(Vector2(board_rect.position.x + float(column) * slot + 7.0, y), Vector2(board_rect.position.x + float(column + 1) * slot - 7.0, y), boundary_color, 3.0, true)


func _draw_footer() -> void:
	var instruction := "TAP TO MARK  ·  DOUBLE-TAP OR RIGHT-CLICK TO PLACE"
	if toast_time > 0.0:
		instruction = toast_text
	var instruction_rect := Rect2(90.0, 1148.0, 720.0, 44.0)
	if toast_time > 0.0:
		_draw_panel(instruction_rect, _with_alpha(CREAM, 0.98), 22.0, _with_alpha(CORAL if error_time > 0.0 else MINT, 0.62), 2.0)
		_draw_text_center(instruction, instruction_rect, 18, INK)
	else:
		_draw_text_center(instruction, instruction_rect, 18, _with_alpha(CREAM, 0.82))

	_draw_button(UNDO_RECT, "UNDO", "undo", not history.is_empty())
	_draw_button(RESTART_RECT, "RESTART", "restart", true)
	_draw_text_center(_difficulty_label(), Rect2(250.0, 1326.0, 400.0, 32.0), 16, _with_alpha(CREAM, 0.60))


func _draw_button(rect: Rect2, label: String, icon: String, enabled: bool) -> void:
	var hovered := rect.has_point(pointer_base) and game_mode == GameMode.PLAYING
	var fill := _with_alpha(CREAM, 0.98 if enabled else 0.62)
	if hovered and enabled:
		fill = Color.WHITE
	_rounded_rect(Rect2(rect.position + Vector2(0.0, 7.0), rect.size), Color(0.0, 0.0, 0.0, 0.16), 40.0)
	_draw_panel(rect, fill, 40.0, _with_alpha(MINT if hovered else CREAM, 0.62), 2.0)
	var icon_center := Vector2(rect.position.x + 58.0, rect.get_center().y)
	draw_circle(icon_center, 25.0, _with_alpha(MINT if enabled else INK_SOFT, 0.20))
	if icon == "undo":
		draw_arc(icon_center, 17.0, -2.5, 2.15, 28, INK_SOFT, 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			icon_center + Vector2(-20.0, -8.0),
			icon_center + Vector2(-7.0, -15.0),
			icon_center + Vector2(-8.0, -1.0)
		]), INK_SOFT)
	else:
		draw_arc(icon_center, 17.0, -0.3, 5.15, 30, INK_SOFT, 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			icon_center + Vector2(17.0, -13.0),
			icon_center + Vector2(20.0, 2.0),
			icon_center + Vector2(8.0, -5.0)
		]), INK_SOFT)
	_draw_text_center(label, Rect2(rect.position.x + 74.0, rect.position.y, rect.size.x - 90.0, rect.size.y), 23, INK if enabled else _with_alpha(INK, 0.48))


func _draw_win_overlay() -> void:
	var alpha := clampf((win_time - 0.28) / 0.36, 0.0, 1.0)
	if alpha <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color(0.015, 0.035, 0.09, 0.62 * alpha))
	var modal := Rect2(110.0, 335.0, 680.0, 735.0)
	_rounded_rect(Rect2(modal.position + Vector2(0.0, 15.0), modal.size), Color(0.0, 0.0, 0.0, 0.24 * alpha), 50.0)
	_draw_panel(modal, _with_alpha(CREAM, alpha), 50.0, _with_alpha(GOLD, 0.72 * alpha), 4.0)
	var mascot_center := Vector2(450.0, 548.0)
	draw_circle(mascot_center, 180.0, _with_alpha(GOLD, 0.08 * alpha))
	for ray in range(18):
		var angle := TAU * float(ray) / 18.0 + win_time * 0.12
		draw_line(mascot_center + Vector2.from_angle(angle) * 135.0, mascot_center + Vector2.from_angle(angle) * 180.0, _with_alpha(GOLD, 0.34 * alpha), 5.0, true)
	var mascot_phase := clampf((win_time - 0.28) / 0.55, 0.0, 1.0)
	var mascot_scale := 0.88 + mascot_phase * 0.12 + sin(mascot_phase * PI) * 0.07
	var mascot_frame := _scale_rect(Rect2(310.0, 408.0, 280.0, 280.0), mascot_scale)
	var mascot_image := _scale_rect(Rect2(318.0, 416.0, 264.0, 264.0), mascot_scale)
	_rounded_rect(mascot_frame, _with_alpha(INK, alpha), 48.0)
	draw_texture_rect(MASCOT, mascot_image, false, _with_alpha(Color.WHITE, alpha))
	_draw_text_center("PURRFECT SWEEP!", Rect2(150.0, 708.0, 600.0, 72.0), 42, _with_alpha(INK, alpha))
	_draw_text_center("Room %02d cleared in %s" % [level_index + 1, _format_time(elapsed_time)], Rect2(160.0, 786.0, 580.0, 46.0), 21, _with_alpha(INK_SOFT, alpha))
	_draw_text_center("%d calm hearts left" % hearts, Rect2(220.0, 835.0, 460.0, 40.0), 18, _with_alpha(CORAL.darkened(0.18), alpha))
	var button_fill := CORAL.lightened(0.04) if MODAL_BUTTON_RECT.has_point(pointer_base) else CORAL
	_rounded_rect(Rect2(MODAL_BUTTON_RECT.position + Vector2(0.0, 8.0), MODAL_BUTTON_RECT.size), Color(0.28, 0.10, 0.08, 0.18 * alpha), 46.0)
	_rounded_rect(MODAL_BUTTON_RECT, _with_alpha(button_fill, alpha), 46.0)
	var button_text := "PLAY AGAIN" if level_index >= PuzzleBook.LEVELS.size() - 1 else "NEXT ROOM"
	_draw_text_center(button_text, MODAL_BUTTON_RECT, 28, _with_alpha(INK, alpha))


func _draw_loss_overlay() -> void:
	var alpha := clampf(loss_time / 0.32, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color(0.015, 0.035, 0.09, 0.64 * alpha))
	var modal := Rect2(110.0, 420.0, 680.0, 620.0)
	_rounded_rect(Rect2(modal.position + Vector2(0.0, 15.0), modal.size), Color(0.0, 0.0, 0.0, 0.24 * alpha), 50.0)
	_draw_panel(modal, _with_alpha(CREAM, alpha), 50.0, _with_alpha(CORAL, 0.68 * alpha), 4.0)
	_draw_cat(Vector2(450.0, 600.0), 98.0, 1.0, CORAL)
	_draw_text_center("PAWS. RESET.", Rect2(160.0, 720.0, 580.0, 70.0), 42, _with_alpha(INK, alpha))
	_draw_text_center("The cafe is still cozy. Try the sweep again.", Rect2(160.0, 798.0, 580.0, 48.0), 20, _with_alpha(INK_SOFT, alpha))
	_rounded_rect(Rect2(MODAL_BUTTON_RECT.position + Vector2(0.0, 8.0), MODAL_BUTTON_RECT.size), Color(0.28, 0.10, 0.08, 0.18 * alpha), 46.0)
	_rounded_rect(MODAL_BUTTON_RECT, _with_alpha(CORAL, alpha), 46.0)
	_draw_text_center("TRY AGAIN", MODAL_BUTTON_RECT, 28, _with_alpha(INK, alpha))


func _draw_particles() -> void:
	for particle in particles:
		var life_ratio := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		var color: Color = particle["color"]
		color.a *= minf(1.0, life_ratio * 2.2)
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


func _draw_cat(center: Vector2, radius: float, scale_value: float, accent: Color) -> void:
	var radius_scaled := radius * scale_value
	var shadow_center := center + Vector2(0.0, radius_scaled * 0.13)
	draw_circle(shadow_center, radius_scaled * 0.92, Color(0.04, 0.05, 0.09, 0.24))
	var ear_y := center.y - radius_scaled * 0.48
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius_scaled * 0.72, -radius_scaled * 0.12),
		center + Vector2(-radius_scaled * 0.50, -radius_scaled * 0.98),
		center + Vector2(-radius_scaled * 0.12, -radius_scaled * 0.48)
	]), CREAM)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(radius_scaled * 0.72, -radius_scaled * 0.12),
		center + Vector2(radius_scaled * 0.50, -radius_scaled * 0.98),
		center + Vector2(radius_scaled * 0.12, -radius_scaled * 0.48)
	]), CARAMEL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x - radius_scaled * 0.56, ear_y),
		Vector2(center.x - radius_scaled * 0.48, center.y - radius_scaled * 0.78),
		Vector2(center.x - radius_scaled * 0.28, center.y - radius_scaled * 0.47)
	]), _with_alpha(CORAL, 0.56))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x + radius_scaled * 0.56, ear_y),
		Vector2(center.x + radius_scaled * 0.48, center.y - radius_scaled * 0.78),
		Vector2(center.x + radius_scaled * 0.28, center.y - radius_scaled * 0.47)
	]), _with_alpha(CORAL, 0.56))
	draw_circle(center, radius_scaled * 0.74, CREAM)
	draw_circle(center + Vector2(radius_scaled * 0.30, -radius_scaled * 0.18), radius_scaled * 0.40, CARAMEL)
	draw_circle(center + Vector2(-radius_scaled * 0.27, -radius_scaled * 0.10), radius_scaled * 0.13, INK)
	draw_circle(center + Vector2(radius_scaled * 0.27, -radius_scaled * 0.10), radius_scaled * 0.13, INK)
	draw_circle(center + Vector2(-radius_scaled * 0.23, -radius_scaled * 0.15), radius_scaled * 0.04, Color.WHITE)
	draw_circle(center + Vector2(radius_scaled * 0.31, -radius_scaled * 0.15), radius_scaled * 0.04, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius_scaled * 0.09, radius_scaled * 0.09),
		center + Vector2(radius_scaled * 0.09, radius_scaled * 0.09),
		center + Vector2(0.0, radius_scaled * 0.19)
	]), CORAL)
	draw_arc(center + Vector2(-radius_scaled * 0.11, radius_scaled * 0.17), radius_scaled * 0.13, 0.2, 1.55, 10, INK_SOFT, maxf(1.5, radius_scaled * 0.035), true)
	draw_arc(center + Vector2(radius_scaled * 0.11, radius_scaled * 0.17), radius_scaled * 0.13, 1.58, 2.95, 10, INK_SOFT, maxf(1.5, radius_scaled * 0.035), true)
	for side in [-1.0, 1.0]:
		for whisker in range(2):
			var start := center + Vector2(side * radius_scaled * 0.42, radius_scaled * (0.12 + float(whisker) * 0.12))
			var finish := center + Vector2(side * radius_scaled * 0.88, radius_scaled * (0.05 + float(whisker) * 0.17))
			draw_line(start, finish, _with_alpha(INK_SOFT, 0.7), maxf(1.0, radius_scaled * 0.025), true)
	draw_arc(center + Vector2(0.0, radius_scaled * 0.50), radius_scaled * 0.35, 0.05, PI - 0.05, 20, accent, maxf(2.0, radius_scaled * 0.10), true)


func _draw_whisker_mark(center: Vector2, radius: float, color: Color) -> void:
	var width := maxf(3.0, radius * 0.17)
	var a_start := center + Vector2(-radius, -radius * 0.78)
	var a_end := center + Vector2(radius, radius * 0.78)
	var b_start := center + Vector2(radius, -radius * 0.78)
	var b_end := center + Vector2(-radius, radius * 0.78)
	draw_line(a_start, a_end, color, width, true)
	draw_line(b_start, b_end, color, width, true)
	for endpoint in [a_start, a_end, b_start, b_end]:
		draw_circle(endpoint, width * 0.5, color)
	draw_circle(center, maxf(2.0, radius * 0.15), _with_alpha(CREAM, 0.78))


func _draw_heart(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.36, -radius * 0.18), radius * 0.48, color)
	draw_circle(center + Vector2(radius * 0.36, -radius * 0.18), radius * 0.48, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.78, -radius * 0.08),
		center + Vector2(radius * 0.78, -radius * 0.08),
		center + Vector2(0.0, radius * 0.95)
	]), color)


func _draw_color_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.12))
	draw_circle(center, 21.0, PAPER)
	draw_circle(center + Vector2(-7.0, -5.0), 8.0, CORAL)
	draw_circle(center + Vector2(7.0, -5.0), 8.0, MINT)
	draw_circle(center + Vector2(0.0, 7.0), 8.0, GOLD)


func _draw_line_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.12))
	draw_circle(center, 21.0, PAPER)
	for index in range(3):
		var y := -11.0 + float(index) * 11.0
		draw_line(center + Vector2(-12.0, y), center + Vector2(12.0, y), _with_alpha(INK, 0.58), 4.0, true)
		draw_circle(center + Vector2(-12.0, y), 2.0, _with_alpha(INK, 0.58))
		draw_circle(center + Vector2(12.0, y), 2.0, _with_alpha(INK, 0.58))
	draw_circle(center, 5.5, MINT)


func _draw_space_icon(center: Vector2) -> void:
	draw_circle(center, 24.0, _with_alpha(INK, 0.12))
	draw_circle(center, 21.0, PAPER)
	draw_arc(center, 14.0, 0.0, TAU, 28, _with_alpha(INK, 0.50), 3.0, true)
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


func _draw_panel(rect: Rect2, fill: Color, radius: float, border: Color, border_width: float) -> void:
	if border_width > 0.0 and border.a > 0.0:
		_rounded_rect(rect, border, radius)
		_rounded_rect(rect.grow(-border_width), fill, maxf(1.0, radius - border_width))
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
