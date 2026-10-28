extends RefCounted
## Vérifie les cartes, l'économie, les vagues et les vitesses de simulation.
## Chaque scénario commence avec une réinitialisation de la partie pour contrôler ses conditions de départ.


const Model = preload("res://game.gd")


## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> void:
	var game = Model.new()
	landmark_reservations(suite, game)

	# Première étape : on compare les trois grilles avec le calcul de chemin indépendant fourni par Godot.
	for index in range(3):
		game.reset(index)
		suite.check(
			game.cols == Model.GRID_SIZES[index].x and game.rows == Model.GRID_SIZES[index].y,
			"Selected dimensions",
		)
		suite.check(game.route.size() == game.cols, "Unobstructed shortest path")
		game.gold = 100000

		for y in range(game.rows):
			game.build(Vector2i(3, y), 0)
		suite.check(game.towers.size() == game.rows - 1, "Final blocking placement refused")
		suite.check(game.gold == 100000 - (game.rows - 1) * 50, "Refused construction never charged")

		var astar = AStarGrid2D.new()
		astar.region = Rect2i(0, 0, game.cols, game.rows)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.update()

		for cell in game.towers:
			astar.set_point_solid(cell)

		var reference = astar.get_id_path(game.entry, game.exit_cell)
		suite.check(reference.size() == game.route.size(), "Shortest path agrees with independent AStarGrid2D")

		for i in range(1, game.route.size()):
			var difference: Vector2i = game.route[i] - game.route[i - 1]
			suite.check(
				absi(difference.x) + absi(difference.y) == 1 and not game.towers.has(game.route[i]),
				"Path continuity and obstacle avoidance",
			)
	game.reset(1)
	suite.check(not game.build(game.entry, 0) and not game.build(game.exit_cell, 0), "Protect entry and exit")
	suite.check(
		not game.build(Vector2i(-1, 2), 0) and not game.build(Vector2i(game.cols, 2), 0),
		"Reject out-of-bounds coordinates",
	)
	suite.check(
		not game.build(Vector2i(1, 1), -1) and not game.build(Vector2i(1, 1), 8),
		"Reject invalid tower types",
	)
	game.gold = 0
	suite.check(not game.build(Vector2i(1, 1), 0), "Reject unaffordable purchase")

	# Deuxième étape : chaque type est acheté, amélioré jusqu'au niveau 7, puis revendu.
	for kind in range(8):
		game.reset(1)
		game.gold = 100000

		var cell = Vector2i(1, 1)
		suite.check(game.build(cell, kind), "Build each of eight tower classes")

		var previous_damage: float = float(Model.TYPES[kind].damage)

		for level in range(2, 8):
			var price: int = game.upgrade_cost(game.towers[cell])
			var previous_gold: int = game.gold
			suite.check(game.upgrade(cell), "Upgrade succeeds through level seven")
			suite.check(
				game.towers[cell].level == level and game.gold == previous_gold - price,
				"Upgrade price and level",
			)
			suite.near(
				game.tower_range(game.towers[cell]),
				float(Model.TYPES[kind].range),
				"Range stays fixed at every upgrade level",
			)
		suite.check(not game.upgrade(cell) and game.towers[cell].level == 7, "Level seven cap")

		var refund = int(game.towers[cell].spent * 0.7)
		var before: int = game.gold
		suite.check(game.sell(cell) and game.gold == before + refund, "Refund all investment at 70 percent")
	game.reset(1)
	game.speed_multiplier = 2
	suite.check(game.start_wave(), "Can launch the first wave immediately")
	suite.check(
		game.active and game.wave == 1 and game.preparation == 0,
		"Manual launch clears preparation countdown",
	)
	suite.check(not game.start_wave() and game.wave == 1, "Repeated launch cannot create a second active wave")
	game.reset(1)
	game.speed_multiplier = 2
	game.tick(59.9)
	suite.check(not game.active and game.wave == 0, "No wave before 60 seconds even in double speed")
	game.paused = true
	game.tick(2.0)
	suite.near(game.preparation, 0.1, "Pause freezes preparation")
	game.paused = false
	game.tick(0.1)
	suite.check(game.active and game.wave == 1, "Automatic start at one minute")
	suite.check(game.build(Vector2i(1, 1), 0), "Can build during wave")
	suite.check(game.upgrade(Vector2i(1, 1)), "Can upgrade during wave")
	game.paused = true
	suite.check(game.upgrade(Vector2i(1, 1)), "Can upgrade while paused")
	suite.check(game.sell(Vector2i(1, 1)), "Can sell while paused during wave")
	suite.check(game.build(Vector2i(1, 1), 4), "Can place antiair ballista while paused during wave")
	suite.check(game.sell(Vector2i(1, 1)), "Can sell antiair tower")
	game.paused = false
	game.tick(0.1)
	suite.check(game.enemies.size() == 1, "Automatic spawning")

	var original: Vector2 = game.position_of(game.enemies[0])
	game.paused = true
	game.tick(0.1)
	suite.check(game.position_of(game.enemies[0]) == original, "Pause freezes enemies")
	game.paused = false
	game.tick(0.1)
	suite.near(game.position_of(game.enemies[0]).distance_to(original), 0.5, "Double combat speed")

	# On vérifie le calendrier des boss, la présence des volants et la croissance des points de vie.
	for wave in range(1, 101):
		var plan: Dictionary = game.wave_plan(wave)
		suite.check(bool(plan.air) == (wave % 10 == 0), "Flying units every tenth wave")
		suite.check(
			plan.boss == (2 if wave == 50 or wave == 100 else (1 if wave % 10 == 0 else 0)),
			"Mini and major boss schedule",
		)
		suite.check(plan.armor == ("physical" if wave % 2 == 1 else "magic"), "Alternating ground resistances")

		if wave > 1:
			suite.near(
				game.enemy_health(wave) / game.enemy_health(wave - 1),
				1.06,
				"Enemy health increases by six percent each wave",
			)

	for wave in range(10, 101, 10):
		game.reset(1)
		game.wave = wave
		game.to_spawn = game.wave_plan(wave).count

		var air_count = 0
		var ground_count = 0

		while game.to_spawn > 0:
			var mixed: Dictionary = game.spawn_enemy()

			if mixed.air:
				air_count += 1
				suite.near(
					mixed.max_hp,
					game.enemy_health(wave) * 0.6,
					"Flying HP reduced to 60 percent of ground HP",
				)
			elif mixed.boss == 0:
				ground_count += 1
		suite.check(air_count > 0 and ground_count > 0, "Every flying wave includes regular ground enemies")
	suite.check(game.enemy_health(10, true) < 60.0, "First flying wave no longer has 224 HP per flyer")
	suite.near(
		game.enemy_health(10, false, 1),
		game.enemy_health(10) * 16.0,
		"Mini boss durability doubled from prototype 03",
	)

	for boss_wave in [50, 100]:
		suite.near(
			game.enemy_health(boss_wave, false, 2),
			game.enemy_health(boss_wave) * 75.0,
			"Major boss durability tripled from prototype 03",
		)

	# On mesure les moments des tirs de l'archer : améliorer ses dégâts ne doit pas accélérer ses flèches.
	for level in [1, 7]:
		game.reset(1)
		game.gold = 100000

		# La première position libre est à trois colonnes de l'entrée, hors du portail.
		var archer_cell: Vector2i = game.entry + Vector2i(3, -1)
		suite.check(game.build(archer_cell, 0), "Cadence archer is built outside the portal")

		for upgrade_index in range(level - 1):
			game.upgrade(archer_cell)
		game.preparation = 0
		game.start_wave()

		var dummy: Dictionary = suite.enemy(game)
		# Déplacer aussi la cible conserve la distance du scénario de cadence initial.
		dummy.cell += Vector2i(2, 0)
		dummy.next += Vector2i(2, 0)
		dummy.hp = 100000.0
		dummy.speed = 0.0
		game.to_spawn = 0

		var previous_hp: float = dummy.hp
		var arrow_times: Array[float] = []

		for frame in range(300):
			game.tick(1.0 / 60.0)

			if dummy.hp < previous_hp:
				arrow_times.append((frame + 1) / 60.0)
				previous_hp = dummy.hp
		suite.check(arrow_times.size() == 5, "Archer fires five arrows in five seconds at levels one and seven")

		for index in range(1, arrow_times.size()):
			suite.check(
				arrow_times[index] - arrow_times[index - 1] >= 1.2 - 0.000001,
				"Archer animation has 1.2 simulated seconds between arrows",
			)
		game.enemies.clear()
		dummy = suite.enemy(game)

		var untouched: float = dummy.hp
		game.fire_tower(game.entry + Vector2i(4, 0), game.towers[archer_cell])
		suite.near(dummy.hp, untouched, "Upgraded archer cannot hit outside its base range")
	game.reset(1)
	suite.check(game.build(game.entry + Vector2i(3, -1), 0), "TTK archer is built outside the portal")
	game.preparation = 0
	game.start_wave()

	var ttk_dummy: Dictionary = suite.enemy(game)
	ttk_dummy.cell += Vector2i(2, 0)
	ttk_dummy.next += Vector2i(2, 0)
	ttk_dummy.hp = 300.0
	ttk_dummy.speed = 0.0
	game.to_spawn = 0

	var measured_ttk = 0.0

	while ttk_dummy.hp > 0 and measured_ttk < 60.0:
		game.tick(1.0 / 60.0)
		measured_ttk += 1.0 / 60.0
	suite.check(
		measured_ttk >= 22.8 and measured_ttk < 22.9,
		"Archer TTK is 22.8 seconds against neutral stationary 300 HP target",
	)
	game.reset(1)
	suite.check(game.build(game.entry + Vector2i(3, -1), 4), "First ballista is built outside the portal")
	game.build(game.entry + Vector2i(7, -1), 4)
	game.wave = 9
	game.preparation = 0
	game.start_wave()

	for frame in range(1000):
		game.tick(0.1)

		for item in game.enemies:
			if not item.air:
				item.hp = 0

		if not game.active:
			break
	suite.check(
		not game.active and game.lives == 20,
		"Two level-one ballistas can defeat the first flying contingent",
	)
	game.reset(1)
	game.gold = 100000

	for cell in [Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 5), Vector2i(5, 3), Vector2i(5, 5)]:
		game.build(cell, 0)
	game.preparation = 0.0
	game.start_wave()

	var trapped: Dictionary = game.spawn_enemy()
	trapped.portal_remaining = 0.0
	trapped.cell = Vector2i(4, 4)
	trapped.next = Vector2i(5, 4)
	trapped.fraction = 0.5

	var trap_gold: int = game.gold
	suite.check(not game.build(Vector2i(6, 4), 0), "Cannot trap a ground unit away from the entrance route")
	suite.check(
		game.gold == trap_gold and not game.towers.has(Vector2i(6, 4)),
		"Trapping placement is rolled back without charge",
	)
	suite.check(
		not game.build(trapped.cell, 0) and not game.build(trapped.next, 0),
		"Cannot build under a moving ground enemy",
	)

	var moving_position: Vector2 = game.position_of(trapped)
	suite.check(game.sell(Vector2i(4, 3)), "Selling works in live combat")
	suite.check(game.position_of(trapped) == moving_position, "Live sale and repath do not teleport units")

	var reference: Dictionary = {}

	# On compare une même durée DE JEU aux quatre vitesses. Les résultats doivent rester identiques.
	for speed in Model.COMBAT_SPEEDS:
		game.reset(1)
		game.gold = 10000
		suite.check(game.build(game.entry + Vector2i(3, -1), 0), "Speed test archer is built outside the portal")
		game.build(game.entry + Vector2i(4, 1), 7)
		game.build(game.entry + Vector2i(6, -1), 4)
		game.wave = 9
		game.preparation = 0
		game.start_wave()
		game.speed_multiplier = speed

		for frame in range(600 / speed):
			game.tick(0.02)

		var health = 0.0
		var positions = 0.0

		for item in game.enemies:
			health += item.hp
			positions += game.position_of(item).x

		var result = {
			"gold": game.gold,
			"lives": game.lives,
			"spawned": game.spawned,
			"health": health,
			"positions": positions,
		}

		if reference.is_empty():
			reference = result
		else:
			suite.check(
				result.gold == reference.gold and result.lives == reference.lives and result.spawned == reference.spawned,
				"Speed does not alter outcomes or spawn timing",
			)
			suite.near(result.health, reference.health, "Speed preserves damage and poison")
			suite.near(result.positions, reference.positions, "Speed preserves movement")


## Reproduit les achats sur le château, pour chaque carte et état de pause/combat.
## Un refus ne doit modifier ni l'or, ni les tours, ni le chemin. Les cases voisines restent libres.
static func landmark_reservations(suite, game) -> void:
	for grid_index in range(Model.GRID_SIZES.size()):
		for state in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
			game.reset(grid_index)
			game.active = bool(state.x)
			game.paused = bool(state.y)
			var original_gold: int = game.gold
			var original_revision: int = game.revision
			var original_route: Array[Vector2i] = game.route.duplicate()

			for area in game.landmark_areas():
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						suite.check(not game.build(Vector2i(x, y), 0), "No tower anywhere on a landmark footprint")
				# La réservation doit s'appliquer aux huit types de tours, pas seulement à l'archer.
				for kind in range(Model.TYPES.size()):
					suite.check(not game.build(area.position, kind), "Every tower type respects landmark reservations")

			suite.check(game.gold == original_gold and game.towers.is_empty(), "Reserved placement never charges or creates a tower")
			suite.check(game.revision == original_revision and game.route == original_route, "Reserved placement leaves navigation unchanged")
			suite.check(game.flow[game.cell_id(game.entry)] >= 0, "Portal and castle remain traversable")
			suite.check(game.build(game.entry + Vector2i(3, -1), 0), "Can build immediately outside portal footprint")
			suite.check(game.build(game.exit_cell + Vector2i(-2, -1), 0), "Can build immediately outside castle footprint")
