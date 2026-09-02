extends SceneTree

var failures := 0
var requested_exit_code := 0


func _initialize() -> void:
	_run_deferred()


func _run_deferred() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn")
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	for player in [game.mark_player, game.place_player, game.error_player, game.win_player]:
		player.stop()
		player.stream = null
	await _run_gameplay_checks(game)
	_run_language_checks(game)
	await process_frame
	await process_frame
	game.free()
	game = null
	packed = null
	await process_frame
	_finish()



func _run_gameplay_checks(game: Node) -> void:
	var saved_unlock: int = game.unlocked_level
	game.unlocked_level = 0
	game._start_level(0)
	_expect(game.grid_size == 5, "first room is 5x5")
	_expect(game._count_solutions(game.puzzle) == 1, "first room has one solution")
	_expect(game._cat_count() == 1, "tutorial starts with one locked cat")
	var wallpaper_sets_valid: bool = game.WALLPAPER_SETS.size() == 3
	for wallpaper_set in game.WALLPAPER_SETS:
		wallpaper_sets_valid = wallpaper_sets_valid and wallpaper_set.size() == 3
		for layer in wallpaper_set:
			wallpaper_sets_valid = wallpaper_sets_valid and layer is Texture2D and layer.get_size().x > 0.0 and layer.get_size().y > 0.0
	_expect(wallpaper_sets_valid, "three complete wallpaper sets are imported")
	for band in [[0, 0], [3, 0], [4, 1], [9, 1], [10, 2], [14, 2]]:
		game.level_index = int(band[0])
		_expect(game._wallpaper_set_index() == int(band[1]), "room %d uses wallpaper set %d" % [int(band[0]) + 1, int(band[1]) + 1])
	game._start_level(0)


	var mark_step_cell: int = int(game.TUTORIAL_STEPS[0]["cell"])
	var first_cause_cell: int = int(game.TUTORIAL_STEPS[0]["cause"])
	_expect(game.tutorial_step == 0, "first room starts the guided tutorial")
	_expect(game.rules_card, "room 1 opens on the three rules")
	game._process(game.tutorial_reason_duration + 0.01)
	_expect(game.tutorial_reason_time > 0.0, "the first reason waits behind the rules card")
	_expect(game._handle_ui_press(game.BOARD_RECT.get_center()), "a tap answers the rules card")
	_expect(not game.rules_card, "the rules card steps aside after a tap")
	_expect(game._tutorial_target_cell() == mark_step_cell, "tutorial first highlights its mark seat")
	_expect(game.given_cells.has(first_cause_cell), "tutorial reuses the locked opening cat")
	_expect(game._shares_rule(mark_step_cell, first_cause_cell), "tutorial mark seat is visibly impossible")
	var causes_are_cats := true
	for step in game.TUTORIAL_STEPS:
		var cause_cell: int = int(step["cause"])
		causes_are_cats = causes_are_cats and (cause_cell == first_cause_cell or int(game.puzzle["solution"][cause_cell / game.grid_size]) == cause_cell % game.grid_size)
	_expect(causes_are_cats, "every step blames a cat that is really seated by then")
	var guided_seats := 0
	var tutorial_seats_valid := true
	for step in game.TUTORIAL_STEPS:
		if not bool(step["place_cat"]):
			continue
		guided_seats += 1
		var step_cell: int = int(step["cell"])
		tutorial_seats_valid = tutorial_seats_valid and int(game.puzzle["solution"][step_cell / game.grid_size]) == step_cell % game.grid_size
	_expect(tutorial_seats_valid, "every tutorial cat seat matches the real solution")
	_expect(guided_seats == game.grid_size - game.given_cells.size(), "the tutorial guides every seat the room still needs")
	var step_pictures: Dictionary = {}
	for step in game.TUTORIAL_STEPS:
		step_pictures[String(step["icon"])] = true
	_expect(step_pictures.size() == game.TUTORIAL_STEPS.size(), "every tutorial step shows its own picture")

	game.intro_time = game.board_intro_duration
	_expect(game.tutorial_reason_time > 0.0 and game.pulse_cell == first_cause_cell, "a step opens by pulsing the cat that explains it")
	game._process(game.tutorial_reason_duration + 0.01)
	_expect(game.tutorial_reason_time == 0.0, "the reason then gives way to the tap to make")
	game._begin_pointer(game._cell_center(mark_step_cell), false)
	_expect(game.pending_cell == mark_step_cell and game.cell_states[mark_step_cell] == game.CellState.EMPTY, "tutorial single tap waits for double-tap window")
	game._process(game.double_tap_window + 0.01)
	_expect(game.cell_states[mark_step_cell] == game.CellState.MARKED and game.tutorial_step == 1, "tutorial single tap marks and advances")
	_expect(game.tutorial_reason_time > 0.0 and game.pulse_cell == int(game.TUTORIAL_STEPS[1]["cause"]), "the next step explains itself too")

	for index in range(1, game.TUTORIAL_STEPS.size()):
		var seat_cell: int = int(game.TUTORIAL_STEPS[index]["cell"])
		_expect(game._tutorial_target_cell() == seat_cell, "tutorial highlights step %d" % (index + 1))
		var seat_position: Vector2 = game._cell_center(seat_cell)
		game._begin_pointer(seat_position, false)
		game._begin_pointer(seat_position, false)
		_expect(game.cell_states[seat_cell] == game.CellState.CAT, "tutorial double-tap seats the cat of step %d" % (index + 1))
	_expect(game.tutorial_step == -1, "following every step finishes the tutorial")
	_expect(game.toast_time == game.tutorial_success_duration, "tutorial finishes with praise")
	_expect(game.game_mode == game.GameMode.WON, "the guided tutorial clears the first room")

	game.unlocked_level = 0
	game._start_level(1)
	_expect(game.tutorial_step == -1 and game._tutorial_target_cell() == -1, "later rooms do not repeat the tutorial")

	var first_hint_cell: int = game._next_solution_cell()
	_expect(first_hint_cell == int(game.puzzle["solution"][0]), "the first hint aims at the opening row")
	_expect(game._handle_ui_press(game.HINT_RECT.get_center()), "the hint button answers a tap")
	_expect(game.hint_cell == first_hint_cell and game.hint_time > 0.0, "a hint glows the next correct seat")
	_expect(game._highlight_cell() == first_hint_cell, "a hinted seat gets the guiding glow")
	var misplaced_cell: int = game.grid_size + (int(game.puzzle["solution"][1]) + 2) % game.grid_size
	game._try_place_cat(misplaced_cell)
	game._use_hint()
	_expect(game.hint_cell == misplaced_cell, "a hint points at a misplaced cat first")
	game._process(game.hint_highlight_duration + 0.01)
	_expect(game.hint_time == 0.0 and game._highlight_cell() == -1, "the hint glow fades on its own")

	game._start_level(1)
	game._try_place_cat(2)
	_expect(game.clash_time == 0.0 and game.error_cell == -1, "a cat that breaks nothing is left alone")
	game._try_place_cat(17)
	_expect(game.error_cell == 17 and game.clash_cell == 2, "a clashing cat is shown next to the cat it clashes with")
	_expect(game.clash_kind == "column" and not game.toast_text.is_empty(), "the clash names the rule that broke")
	var clash_column_lit := true
	for row in range(game.grid_size):
		clash_column_lit = clash_column_lit and game._in_clash_group(row * game.grid_size + 2)
	_expect(clash_column_lit, "the whole clashing column lights up")
	_expect(not game._in_clash_group(3), "seats outside the clash stay calm")
	game._process(game.clash_highlight_duration + 0.01)
	_expect(not game._in_clash_group(2), "the clash highlight fades on its own")
	game._try_place_cat(17)
	_expect(game.error_cell == -1 and game.clash_time == 0.0, "moving the clashing cat clears the mistake")

	game._start_level(0)
	game._paint_mark(mark_step_cell)
	_expect(game.tutorial_step == 1, "drag marking also advances the tutorial")
	game.tutorial_reason_time = 0.0
	game._use_hint()
	_expect(game.hint_cell == -1 and game.tutorial_reason_time > 0.0 and game.pulse_cell == int(game.TUTORIAL_STEPS[game.tutorial_step]["cause"]), "a hint during the tutorial replays the reason")
	game._start_level(0)

	game.intro_time = 0.0
	var opening_rect: Rect2 = game._animated_board_rect()
	_expect(game._cell_at(opening_rect.position + Vector2(1.0, 1.0)) == 0, "opening board hit-test follows its animation")
	_expect(game._cell_at(game.BOARD_RECT.position + Vector2(1.0, 1.0)) == -1, "hidden opening edge is not interactive")
	game.intro_time = game.board_intro_duration

	var mark_cell := 1
	if game.given_cells.has(mark_cell):
		mark_cell = 2
	game._toggle_mark(mark_cell)
	_expect(game.cell_states[mark_cell] == 1, "single action marks a cell")
	game._undo()
	_expect(game.cell_states[mark_cell] == 0, "undo restores a mark")

	var wrong_row := 1
	var wrong_column: int = (int(game.puzzle["solution"][wrong_row]) + 1) % game.grid_size
	var wrong_cell: int = wrong_row * game.grid_size + wrong_column
	game._try_place_cat(wrong_cell)
	_expect(game.cell_states[wrong_cell] == game.CellState.CAT, "a wrong cat stays seated before the board is full")
	_expect(game.game_mode == game.GameMode.PLAYING and game.unlocked_level == 0, "an incomplete board does not advance")
	game._undo()
	_expect(game.cell_states[wrong_cell] == game.CellState.EMPTY, "undo removes the freely placed cat")

	for row in range(game.grid_size):
		var placement_cell: int = row * game.grid_size + int(game.puzzle["solution"][row])
		if row == wrong_row:
			placement_cell = wrong_cell
		if not game.given_cells.has(placement_cell):
			game._try_place_cat(placement_cell)
	_expect(game.game_mode == game.GameMode.PLAYING, "a full wrong board stays playable")
	_expect(game._cat_count() == game.grid_size and game.unlocked_level == 0, "a full wrong board keeps every cat and does not unlock the next room")
	_expect(game.error_cell >= 0 and not game.toast_text.is_empty(), "a full wrong board explains what to fix")
	_expect(game.full_board_feedback_time > 0.0, "a full wrong board starts playful correction feedback")
	var correction_cell: int = game.error_cell
	_expect(game.cell_states[correction_cell] == game.CellState.CAT, "correction feedback targets a seated cat")
	_expect(not game.given_cells.has(correction_cell), "correction feedback targets a movable cat")
	_expect(game._correction_glow_strength(correction_cell) > 0.0, "correction feedback gives its target a visible glow")
	_expect(game._cat_pose(correction_cell) == game.CatPose.WORRIED, "only the correction target uses its worried pose")
	var full_board_error_particles := 0
	for particle in game.particles:
		if String(particle["kind"]) == "error":
			full_board_error_particles += 1
	_expect(full_board_error_particles >= 18, "a full wrong board creates a strong error burst")
	game._process(game.shake_duration + 0.05)
	_expect(game.error_time == 0.0 and game.full_board_feedback_time > 0.0, "correction card outlasts the short error shake")
	_expect(game._correction_glow_strength(correction_cell) > 0.0, "target glow remains visible after the error shake")
	game._process(game.full_board_feedback_duration)
	_expect(game.full_board_feedback_time == 0.0 and game._correction_glow_strength(correction_cell) > 0.0, "target keeps glowing until it is moved")
	game.queue_redraw()
	await process_frame

	game._try_place_cat(correction_cell)
	_expect(game.cell_states[correction_cell] == game.CellState.EMPTY and game.error_cell == -1 and game._correction_glow_strength(correction_cell) == 0.0, "moving the glowing cat clears its feedback")
	game._try_place_cat(correction_cell)
	_expect(game.cell_states[correction_cell] == game.CellState.CAT, "correction target can be restored")
	game._try_place_cat(wrong_cell)
	_expect(game.full_board_feedback_time == 0.0, "moving the wrong cat clears the correction card")
	var correct_cell: int = wrong_row * game.grid_size + int(game.puzzle["solution"][wrong_row])
	game._try_place_cat(correct_cell)
	_expect(game.game_mode == game.GameMode.WON, "correcting the full board wins the room")
	_expect(game._cat_count() == game.grid_size, "win keeps every cat visible")
	_expect(game.unlocked_level == 1, "win unlocks the next room")
	var win_particle_count := 0
	var left_cannon_seen := false
	var right_cannon_seen := false
	var win_launches_valid := true
	var win_shapes: Dictionary = {}
	for particle in game.particles:
		if String(particle["kind"]) != "win":
			continue
		win_particle_count += 1
		var particle_position: Vector2 = particle["pos"]
		var particle_velocity: Vector2 = particle["vel"]
		if particle_position.x < game.BASE_SIZE.x * 0.5:
			left_cannon_seen = true
			win_launches_valid = win_launches_valid and particle_velocity.x > 0.0
		else:
			right_cannon_seen = true
			win_launches_valid = win_launches_valid and particle_velocity.x < 0.0
		win_launches_valid = win_launches_valid and particle_velocity.y < 0.0
		win_launches_valid = win_launches_valid and float(particle["life"]) == float(particle["max_life"])
		win_shapes[int(particle["shape"])] = true
	_expect(win_particle_count == game.win_confetti_count, "a win launches the configured confetti count")
	_expect(left_cannon_seen and right_cannon_seen and win_launches_valid, "win confetti launches inward from both sides")
	_expect(win_shapes.size() == 3, "win confetti mixes three playful shapes")
	game._process(game.celebration_stagger * 4.0 + game.ui_fade_duration * 0.55)
	game.queue_redraw()
	await process_frame

	for level in game.PuzzleBook.LEVELS:
		_expect(game._count_solutions(level) == 1, "puzzle pack remains uniquely solvable")

	var final_level: int = game.PuzzleBook.LEVELS.size() - 1
	game.level_index = final_level
	game.game_mode = game.GameMode.WON
	game.win_time = 0.55
	game.unlocked_level = final_level
	game.rules_card = false
	var modal_point: Vector2 = game.MODAL_BUTTON_RECT.position + game.MODAL_BUTTON_RECT.size * 0.5
	game._handle_ui_press(modal_point)
	_expect(game.level_index == 0 and game.unlocked_level == 0, "play again resets saved progression")

	game.unlocked_level = saved_unlock
	game._save_progress()


## Each entry is one drawing box: how wide the text may be and the size it is drawn at.
const TEXT_LIMITS: Array[Dictionary] = [
	{"width": 482.0, "size": 28, "keys": ["TITLE_SUBTITLE"]},
	{"width": 154.0, "size": 28, "keys": ["ROOM_LABEL"]},
	{"width": 282.0, "size": 30, "keys": ["CATS_COUNT", "GUIDANCE_SEAT", "GUIDANCE_MOVE"]},
	{"width": 157.0, "size": 28, "keys": ["RULE_COLOR", "RULE_LINE", "RULE_TOUCH"]},
	{"width": 146.0, "size": 30, "keys": ["BUTTON_UNDO", "BUTTON_HINT", "BUTTON_RESTART"]},
	{"width": 460.0, "size": 26, "keys": ["DIFFICULTY_5", "DIFFICULTY_6", "DIFFICULTY_7"]},
	{"width": 720.0, "size": 30, "keys": [
		"FOOTER_HOWTO", "TOAST_ALL_SEATED", "TOAST_NOTHING_TO_UNDO", "TOAST_UNDONE",
		"TOAST_TUTORIAL_DONE", "TOAST_ALL_PLACED",
		"REASON_ROW", "REASON_COLUMN", "REASON_COLOR"
	]},
	{"width": 420.0, "size": 28, "keys": ["MOVE_GLOWING_CAT"]},
	{"width": 564.0, "size": 28, "keys": [
		"TUTORIAL_MARK", "TUTORIAL_FIRST_CAT", "HINT_SEAT_HERE",
		"TUTORIAL_WHY_TOUCH", "TUTORIAL_WHY_BLOCKED", "TUTORIAL_WHY_ROW",
		"TUTORIAL_WHY_COLUMN", "TUTORIAL_WHY_COLOR"
	]},
	{"width": 550.0, "size": 28, "keys": ["RULES_COLOR", "RULES_LINE", "REASON_TOUCH"]},
	{"width": 640.0, "size": 42, "keys": ["RULES_TITLE"]},
	{"width": 640.0, "size": 30, "keys": ["RULES_START"]},
	{"width": 385.0, "size": 42, "keys": ["FEEDBACK_SO_CLOSE"]},
	{"width": 600.0, "size": 46, "keys": ["WIN_TITLE"]},
	{"width": 580.0, "size": 28, "keys": ["WIN_TIME"]},
	{"width": 540.0, "size": 28, "keys": ["WIN_SUBTITLE"]},
	{"width": 480.0, "size": 30, "keys": ["WIN_NEXT", "WIN_AGAIN"]}
]


func _run_language_checks(game: Node) -> void:
	var saved_language: int = game.language_index
	var english: Translation = load("res://assets/i18n/ui.en.translation")
	_expect(english != null, "the translation table is imported")
	if english == null:
		return
	var keys := english.get_message_list()
	_expect(keys.size() >= 30, "the translation table covers the whole interface")

	for language in game.LANGUAGES:
		var locale: String = String(language["locale"])
		game.language_index = game._language_index(locale)
		game._apply_language()
		_expect(TranslationServer.compare_locales(TranslationServer.get_locale(), locale) > 0, "%s becomes the live language" % locale)
		var untranslated := PackedStringArray()
		for key in keys:
			var line: String = game.tr(key)
			if line.is_empty() or (locale != "en" and line == String(key)):
				untranslated.append(String(key))
		_expect(untranslated.is_empty(), _listed("%s translates every line" % locale, untranslated))
		var overflowing := PackedStringArray()
		for limit in TEXT_LIMITS:
			for key in limit["keys"]:
				var line: String = game.tr(String(key)).replace("%02d", "01").replace("%d", "5").replace("%s", "00:00")
				if game.ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(limit["size"])).x > float(limit["width"]):
					overflowing.append(String(key))
		_expect(overflowing.is_empty(), _listed("%s text fits every panel" % locale, overflowing))

	var chips_fit := true
	for language in game.LANGUAGES:
		var chip_width: float = game.ui_font.get_string_size(String(language["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x
		chips_fit = chips_fit and chip_width <= game.LANGUAGE_RECT.size.x - 76.0
	_expect(chips_fit, "every language name fits the language pill")
	_expect(game.ui_font.get_string_size("日本語", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x > 0.0, "japanese and chinese letters have glyphs to draw")

	game.language_index = 0
	game._apply_language()
	game.rules_card = false
	_expect(game._handle_ui_press(game.LANGUAGE_RECT.get_center()), "the language pill answers a tap")
	_expect(game.language_index == 1, "tapping the pill moves to the next language")
	_expect(TranslationServer.compare_locales(TranslationServer.get_locale(), String(game.LANGUAGES[1]["locale"])) > 0, "the pill changes the live language")

	game.language_index = saved_language
	game._apply_language()
	game._save_progress()


func _listed(label: String, offenders: PackedStringArray) -> String:
	if offenders.is_empty():
		return label
	return "%s (%s)" % [label, ", ".join(offenders)]


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	requested_exit_code = 0 if failures == 0 else 1
	if failures == 0:
		print("NEKODOKU TESTS PASSED")
	else:
		print("NEKODOKU TESTS FAILED: ", failures)
	call_deferred("_quit_cleanly")


func _quit_cleanly() -> void:
	quit(requested_exit_code)
