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


	_expect(game.tutorial_step == game.TutorialStep.MARK_SEAT, "first room starts the two-step tutorial")
	_expect(game._tutorial_target_cell() == game.TUTORIAL_MARK_CELL, "tutorial first highlights its mark seat")
	_expect(game.given_cells.has(game.TUTORIAL_GIVEN_CELL), "tutorial reuses the locked opening cat")
	_expect(game._shares_rule(game.TUTORIAL_MARK_CELL, game.TUTORIAL_GIVEN_CELL), "tutorial mark seat is visibly impossible")
	_expect(int(game.puzzle["solution"][1]) == game.TUTORIAL_CAT_CELL % game.grid_size, "tutorial cat seat matches the real solution")

	game.intro_time = game.board_intro_duration
	var tutorial_mark_position: Vector2 = game._cell_center(game.TUTORIAL_MARK_CELL)
	game._begin_pointer(tutorial_mark_position, false)
	_expect(game.pending_cell == game.TUTORIAL_MARK_CELL and game.cell_states[game.TUTORIAL_MARK_CELL] == game.CellState.EMPTY, "tutorial single tap waits for double-tap window")
	game._process(game.double_tap_window + 0.01)
	_expect(game.cell_states[game.TUTORIAL_MARK_CELL] == game.CellState.MARKED and game.tutorial_step == game.TutorialStep.PLACE_CAT, "tutorial single tap marks and advances")
	_expect(game._tutorial_target_cell() == game.TUTORIAL_CAT_CELL, "tutorial then highlights its cat seat")

	var tutorial_cat_position: Vector2 = game._cell_center(game.TUTORIAL_CAT_CELL)
	game._begin_pointer(tutorial_cat_position, false)
	game._begin_pointer(tutorial_cat_position, false)
	_expect(game.cell_states[game.TUTORIAL_CAT_CELL] == game.CellState.CAT and game.tutorial_step == game.TutorialStep.OFF, "tutorial double-tap places the cat and finishes")
	_expect(game.toast_time == game.tutorial_success_duration, "tutorial finishes with praise")

	game._start_level(1)
	_expect(game.tutorial_step == game.TutorialStep.OFF and game._tutorial_target_cell() == -1, "later rooms do not repeat the tutorial")
	game._start_level(0)
	game._paint_mark(game.TUTORIAL_MARK_CELL)
	_expect(game.tutorial_step == game.TutorialStep.PLACE_CAT, "drag marking also advances the tutorial")
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
	var modal_point: Vector2 = game.MODAL_BUTTON_RECT.position + game.MODAL_BUTTON_RECT.size * 0.5
	game._handle_ui_press(modal_point)
	_expect(game.level_index == 0 and game.unlocked_level == 0, "play again resets saved progression")

	game.unlocked_level = saved_unlock
	game._save_progress()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	requested_exit_code = 0 if failures == 0 else 1
	if failures == 0:
		print("CATSWEEPER TESTS PASSED")
	else:
		print("CATSWEEPER TESTS FAILED: ", failures)
	call_deferred("_quit_cleanly")


func _quit_cleanly() -> void:
	quit(requested_exit_code)
