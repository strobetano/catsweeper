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
	_run_gameplay_checks(game)
	await process_frame
	await process_frame
	game.free()
	game = null
	packed = null
	await process_frame
	_finish()



func _run_gameplay_checks(game: Node) -> void:
	var saved_unlock: int = game.unlocked_level
	game._start_level(0)
	_expect(game.grid_size == 5, "first room is 5x5")
	_expect(game._count_solutions(game.puzzle) == 1, "first room has one solution")
	_expect(game._cat_count() == 1, "tutorial starts with one locked cat")

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
	_expect(game.hearts == 2, "wrong cat costs one heart")
	_expect(game.cell_states[wrong_cell] == 1, "wrong cat becomes a mark")
	game._undo()
	_expect(game.hearts == 3 and game.cell_states[wrong_cell] == 0, "undo restores a mistake")

	for row in range(game.grid_size):
		var solution_cell: int = row * game.grid_size + int(game.puzzle["solution"][row])
		if not game.given_cells.has(solution_cell):
			game._try_place_cat(solution_cell)
	_expect(game.game_mode == 1, "placing every cat wins the room")
	_expect(game._cat_count() == game.grid_size, "win keeps every cat visible")
	_expect(game.unlocked_level == 1, "win unlocks the next room")

	for level in game.PuzzleBook.LEVELS:
		_expect(game._count_solutions(level) == 1, "puzzle pack remains uniquely solvable")

	var final_level: int = game.PuzzleBook.LEVELS.size() - 1
	game.level_index = final_level
	game.game_mode = 1
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
