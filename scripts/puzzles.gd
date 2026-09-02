extends RefCounted

## Fifteen original, offline puzzle boards ordered from gentle to tricky.
## Each board has exactly one solution under Catsweeper's row, column,
## colored-territory, and no-touch rules.

const LEVELS: Array[Dictionary] = [
	{
		"size": 5,
		"regions": [0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 1, 1, 1, 2, 2, 3, 3, 2, 2, 2, 3, 3, 4, 4, 4],
		"solution": [0, 2, 4, 1, 3],
		"givens": [0]
	},
	{
		"size": 5,
		"regions": [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 3, 4, 2, 2, 4, 4, 4, 4, 2],
		"solution": [2, 0, 4, 1, 3],
		"givens": []
	},
	{
		"size": 5,
		"regions": [2, 2, 1, 0, 0, 2, 1, 1, 1, 1, 2, 2, 2, 2, 1, 2, 4, 3, 3, 1, 4, 4, 4, 3, 1],
		"solution": [4, 2, 0, 3, 1],
		"givens": []
	},
	{
		"size": 5,
		"regions": [2, 1, 1, 0, 0, 2, 1, 1, 1, 1, 2, 2, 2, 1, 3, 4, 4, 3, 3, 3, 4, 4, 4, 4, 4],
		"solution": [4, 2, 0, 3, 1],
		"givens": []
	},
	{
		"size": 6,
		"regions": [0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 2, 2, 2, 2, 3, 3, 3, 5, 2, 4, 3, 3, 5, 5, 5, 4, 3, 3, 5, 5, 5, 5],
		"solution": [0, 2, 4, 1, 5, 3],
		"givens": []
	},
	{
		"size": 6,
		"regions": [0, 0, 0, 1, 1, 1, 0, 2, 0, 3, 3, 1, 0, 2, 0, 3, 1, 1, 4, 2, 3, 3, 3, 5, 4, 4, 4, 3, 3, 5, 4, 4, 3, 3, 5, 5],
		"solution": [2, 5, 1, 3, 0, 4],
		"givens": []
	},
	{
		"size": 6,
		"regions": [1, 1, 1, 0, 0, 0, 1, 1, 1, 2, 0, 2, 1, 1, 3, 2, 2, 2, 1, 1, 3, 3, 2, 2, 4, 4, 3, 3, 3, 2, 5, 5, 5, 3, 3, 3],
		"solution": [4, 1, 5, 3, 0, 2],
		"givens": []
	},
	{
		"size": 6,
		"regions": [0, 2, 2, 1, 1, 1, 2, 2, 3, 1, 1, 1, 2, 2, 3, 3, 1, 1, 2, 3, 3, 3, 4, 4, 5, 5, 5, 5, 4, 4, 5, 5, 5, 4, 4, 4],
		"solution": [0, 4, 1, 3, 5, 2],
		"givens": []
	},
	{
		"size": 6,
		"regions": [1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 4, 1, 3, 3, 2, 4, 4, 4, 3, 3, 5, 4, 4, 4, 5, 5, 5, 4, 5, 5, 5, 5, 5],
		"solution": [4, 1, 5, 3, 0, 2],
		"givens": []
	},
	{
		"size": 6,
		"regions": [1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 2, 2, 1, 1, 1, 0, 2, 2, 3, 3, 3, 3, 2, 2, 4, 4, 3, 3, 3, 3, 5, 5, 5, 3, 3, 3],
		"solution": [4, 1, 5, 3, 0, 2],
		"givens": []
	},
	{
		"size": 7,
		"regions": [2, 1, 1, 1, 1, 0, 0, 2, 2, 2, 1, 1, 3, 3, 2, 2, 2, 2, 3, 3, 3, 2, 4, 2, 2, 2, 3, 3, 6, 4, 2, 5, 5, 3, 3, 6, 4, 5, 5, 5, 3, 5, 6, 6, 5, 5, 5, 5, 5],
		"solution": [6, 4, 2, 5, 1, 3, 0],
		"givens": []
	},
	{
		"size": 7,
		"regions": [4, 4, 0, 0, 3, 3, 1, 2, 4, 0, 4, 3, 3, 1, 2, 4, 4, 4, 5, 3, 3, 4, 4, 4, 5, 5, 3, 3, 4, 4, 5, 5, 5, 3, 3, 4, 4, 6, 5, 5, 5, 5, 4, 6, 6, 6, 5, 5, 5],
		"solution": [3, 6, 0, 5, 1, 4, 2],
		"givens": []
	},
	{
		"size": 7,
		"regions": [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 4, 2, 3, 0, 1, 1, 5, 4, 2, 3, 3, 5, 5, 5, 4, 4, 4, 3, 5, 5, 5, 4, 4, 4, 5, 5, 5, 5, 4, 4, 4, 5, 5, 5, 6],
		"solution": [2, 5, 1, 3, 0, 4, 6],
		"givens": []
	},
	{
		"size": 7,
		"regions": [0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 1, 0, 4, 2, 2, 2, 0, 4, 4, 4, 5, 5, 2, 3, 3, 4, 4, 5, 5, 2, 3, 4, 4, 4, 5, 5, 5, 5, 4, 4, 4, 6, 5, 5, 5, 4, 4, 4],
		"solution": [6, 4, 1, 3, 5, 2, 0],
		"givens": []
	},
	{
		"size": 7,
		"regions": [2, 1, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 0, 0, 2, 2, 1, 1, 3, 0, 3, 2, 5, 1, 1, 3, 3, 3, 5, 5, 1, 4, 4, 4, 3, 5, 5, 5, 4, 4, 4, 3, 6, 6, 5, 5, 4, 4, 3],
		"solution": [5, 3, 1, 6, 4, 2, 0],
		"givens": []
	}
]


## How many random boards to try before falling back to a handmade room.
const GENERATE_ATTEMPTS := 400


## Builds the room at `index` on demand, so the rooms never run out. The same
## index always rebuilds the same room, keeping progress and restarts stable.
static func generate(index: int, size: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	for attempt in range(GENERATE_ATTEMPTS):
		rng.seed = index * 1013 + attempt
		var solution := _random_solution(rng, size)
		if solution.is_empty():
			continue
		var level := {
			"size": size,
			"regions": _grow_regions(rng, size, solution),
			"solution": solution,
			"givens": []
		}
		if count_solutions(level) == 1:
			return level
	return LEVELS[index % LEVELS.size()]


## Counts up to two solutions. Exactly one means the room is fair to solve.
static func count_solutions(level: Dictionary) -> int:
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
	return _search_solution(0, n, level["regions"], used_columns, used_regions, columns)


static func _search_solution(row: int, n: int, regions: Array, used_columns: Array[bool], used_regions: Array[bool], columns: Array[int]) -> int:
	if row == n:
		return 1
	var found := 0
	for column in range(n):
		var region := int(regions[row * n + column])
		if used_columns[column] or used_regions[region]:
			continue
		if row > 0 and abs(column - columns[row - 1]) <= 1:
			continue
		used_columns[column] = true
		used_regions[region] = true
		columns[row] = column
		found += _search_solution(row + 1, n, regions, used_columns, used_regions, columns)
		used_columns[column] = false
		used_regions[region] = false
		if found >= 2:
			return found
	return found


## One cat per row, never sharing a column, never touching the row above.
static func _random_solution(rng: RandomNumberGenerator, n: int) -> Array[int]:
	var columns: Array[int] = []
	var used: Array[bool] = []
	used.resize(n)
	used.fill(false)
	if _place_row(rng, 0, n, used, columns):
		return columns
	return []


static func _place_row(rng: RandomNumberGenerator, row: int, n: int, used: Array[bool], columns: Array[int]) -> bool:
	if row == n:
		return true
	for column in _shuffled(rng, n):
		if used[column]:
			continue
		if row > 0 and abs(column - columns[row - 1]) <= 1:
			continue
		used[column] = true
		columns.append(column)
		if _place_row(rng, row + 1, n, used, columns):
			return true
		columns.resize(row)
		used[column] = false
	return false


## Every territory grows out from one cat's seat, so each colour holds exactly
## one cat and stays a single connected shape.
static func _grow_regions(rng: RandomNumberGenerator, n: int, solution: Array[int]) -> Array[int]:
	var regions: Array[int] = []
	var frontier: Array[int] = []
	regions.resize(n * n)
	regions.fill(-1)
	for row in range(n):
		var seat := row * n + solution[row]
		regions[seat] = row
		frontier.append(seat)
	while not frontier.is_empty():
		var pick := rng.randi_range(0, frontier.size() - 1)
		var cell: int = frontier[pick]
		var grown := false
		for direction in _shuffled(rng, 4):
			var next := _neighbour(cell, direction, n)
			if next < 0 or regions[next] >= 0:
				continue
			regions[next] = regions[cell]
			frontier.append(next)
			grown = true
			break
		if not grown:
			frontier.remove_at(pick)
	return regions


static func _neighbour(cell: int, direction: int, n: int) -> int:
	var row := cell / n
	var column := cell % n
	if direction == 0:
		return cell - n if row > 0 else -1
	if direction == 1:
		return cell + n if row < n - 1 else -1
	if direction == 2:
		return cell - 1 if column > 0 else -1
	return cell + 1 if column < n - 1 else -1


## Fisher-Yates on the seeded generator, so shuffles stay reproducible.
static func _shuffled(rng: RandomNumberGenerator, n: int) -> Array[int]:
	var order: Array[int] = []
	for value in range(n):
		order.append(value)
	for index in range(n - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var kept := order[index]
		order[index] = order[swap]
		order[swap] = kept
	return order
