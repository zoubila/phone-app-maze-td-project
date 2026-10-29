extends RefCounted
## Le portail ne prend aucune case de jeu. Son sas est un déplacement réel, continu et testable sans dessin.

const Model = preload("res://game.gd")
const Scenery = preload("res://scenery.gd")


static func run(suite) -> void:
	var game = Model.new()
	for grid_index in range(Model.GRID_SIZES.size()):
		game.reset(grid_index)
		var mouth: Vector2 = Scenery.portal_origin(game, 42.0)
		suite.check(mouth.x + 123.0 < 0.0, "Entire portal illustration stays outside the grid")
		suite.check(mouth.x + 146.0 < 0.0, "Portal ground apron also stays outside the grid")
		for offset in [Vector2i(1, -1), Vector2i(2, 0), Vector2i(0, -4)]:
			suite.check(game.build(game.entry + offset, 0), "Former portal footprint is constructible")
		suite.check(not game.build(game.entry, 0), "Only the actual entrance cell remains protected")
		suite.check(not game.build(game.exit_cell + Vector2i(-1, -1), 0), "Castle reservation is preserved")
		var astar := AStarGrid2D.new()
		astar.region = Rect2i(Vector2i.ZERO, Vector2i(game.cols, game.rows))
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.update()
		for cell in game.towers:
			astar.set_point_solid(cell)
		suite.check(astar.get_id_path(game.entry, game.exit_cell).size() == game.route.size(), "Maze beside portal agrees with independent pathfinding")

	game.reset(1)
	game.start_wave()
	game.to_spawn = 1
	var enemy: Dictionary = game.spawn_enemy()
	var origin: Vector2 = game.position_of(enemy)
	suite.near(origin.x, float(game.entry.x) + 0.5 - Model.PORTAL_APPROACH_CELLS, "Enemy appears at the portal mouth outside the map")
	suite.near(enemy.portal_age, 0.0, "Emergence starts with a fresh appearance animation")
	# Un monstre encore hors grille ne doit pas réserver artificiellement la case suivante.
	suite.check(game.build(game.entry + Vector2i.RIGHT, 0), "Can place a tower near entry while an enemy is still outside")
	suite.check(enemy.next != game.entry + Vector2i.RIGHT, "Placing that tower updates the entrance route")
	game.move_enemy(enemy, (Model.PORTAL_APPROACH_CELLS + 0.3) / float(enemy.speed))
	suite.near(enemy.portal_remaining, 0.0, "Approach is fully consumed on entering the map")
	var expected: Vector2 = (Vector2(game.entry) + Vector2.ONE * 0.5).lerp(Vector2(enemy.next) + Vector2.ONE * 0.5, 0.3)
	suite.check(game.position_of(enemy).distance_to(expected) < 0.001, "Crossing portal approach into a maze turn never teleports or crosses the tower")

	game.reset(1)
	game.start_wave()
	game.to_spawn = 1
	enemy = game.spawn_enemy()
	game.paused = true
	var age: float = enemy.portal_age
	var phase: float = game.presentation_time
	game.tick(0.5)
	suite.check(enemy.portal_age == age and enemy.portal_remaining == Model.PORTAL_APPROACH_CELLS, "Pause freezes emergence and outside movement")
	suite.check(game.presentation_time == phase, "Pause freezes portal light effects")
	game.paused = false
	game.speed_multiplier = 5
	game.tick(0.1)
	suite.near(enemy.portal_remaining, Model.PORTAL_APPROACH_CELLS - float(enemy.speed) * 0.5, "Approach follows the chosen combat speed")
	suite.check(enemy.portal_age > 0.0, "Emergence progresses during actual simulation")

	game.reset(1)
	game.wave = 10
	game.to_spawn = 2
	var flying: Dictionary = game.spawn_enemy()
	var start: Vector2 = game.position_of(flying)
	game.move_enemy(flying, 1.1)
	suite.check(flying.air and flying.portal_remaining == 0.0 and flying.flight > 0.0, "Flying units leave the same portal before their direct flight")
	suite.near(game.position_of(flying).distance_to(start), 4.4, "Flying emergence remains continuous across the map boundary")
