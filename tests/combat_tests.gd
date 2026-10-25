extends RefCounted
## Vérifie les dégâts, les résistances, les poisons, les attaques de zone et les boss.
## Les monstres de test ont des points de vie connus, ce qui permet de comparer les dégâts à des valeurs attendues.


const Model = preload("res://game.gd")


## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> void:
	var game = Model.new()
	game.reset(1)

	# On commence par deux résistances différentes pour comparer les dégâts physiques et magiques.
	var armored = suite.enemy(game, false, "physical")
	var warded = suite.enemy(game, false, "magic")
	game.apply_hit(Vector2i.ZERO, suite.tower(0), armored)
	game.apply_hit(Vector2i.ZERO, suite.tower(0), warded)
	suite.near(armored.hp, 992.5, "Physical resistance halves physical damage")
	suite.near(warded.hp, 977.5, "Physical vulnerability multiplies physical damage")
	game.apply_hit(Vector2i.ZERO, suite.tower(2), armored)
	game.apply_hit(Vector2i.ZERO, suite.tower(2), warded)
	suite.near(armored.hp, 959.5, "Magic vulnerability")
	suite.near(warded.hp, 966.5, "Magic resistance")

	var flying = suite.enemy(game, true)

	for kind in range(8):
		if kind != 4:
			game.apply_hit(Vector2i.ZERO, suite.tower(kind), flying)
	suite.near(flying.hp, 1000.0, "Air immune to all ground damage towers")
	suite.check(flying.poison.is_empty() and flying.slow_time == 0, "Ground controls cannot affect air")
	game.apply_hit(Vector2i.ZERO, suite.tower(4), flying)
	suite.near(flying.hp, 976.0, "Beacon deals neutral physical damage to air")

	var ground = suite.enemy(game)
	game.apply_hit(Vector2i.ZERO, suite.tower(4), ground)
	suite.near(ground.hp, 1000.0, "Beacon never damages ground")

	for kind in [5, 6]:
		game.apply_hit(Vector2i.ZERO, suite.tower(kind, 7), ground)
		suite.near(ground.hp, 1000.0, "Slow towers do zero damage at every level")
		suite.check(ground.slow_time > 0 and ground.slow_factor < 1, "Slow applied")

	var strongest: float = ground.slow_factor
	game.apply_hit(Vector2i.ZERO, suite.tower(6), ground)
	suite.near(ground.slow_factor, strongest, "Weaker slow cannot replace stronger one")

	# On place deux ennemis proches pour vérifier qu'une seule attaque de zone les affecte tous les deux.
	for kind in [1, 3, 6]:
		game.reset(1)

		var first = suite.enemy(game)
		var second = suite.enemy(game)
		var source: Vector2i = game.entry + Vector2i(1, 1)
		game.fire_tower(source, suite.tower(kind))

		if kind == 6:
			suite.check(
				first.slow_time > 0 and second.slow_time > 0 and first.hp == 1000 and second.hp == 1000,
				"Seismic area control has no damage",
			)
		else:
			suite.check(first.hp < 1000 and second.hp < 1000, "Physical and magical area damage")
	game.reset(1)

	# On vérifie ensuite le renouvellement et le cumul des poisons, y compris leur expiration.
	ground = suite.enemy(game, false, "physical")
	game.apply_hit(Vector2i(1, 1), suite.tower(7), ground)
	suite.near(ground.hp, 1000.0, "Poison has no instant damage")
	game.apply_hit(Vector2i(1, 1), suite.tower(7), ground)
	suite.check(ground.poison.size() == 1, "Same poison source refreshes without stacking")
	game.poison_tick(ground, 1.0)
	suite.near(ground.hp, 989.5, "DoT deals magic damage with resistance multiplier")
	game.apply_hit(Vector2i(2, 1), suite.tower(7), ground)
	suite.check(ground.poison.size() == 2, "Distinct poison sources stack")
	game.poison_tick(ground, 10.0)
	suite.near(ground.hp, 905.5, "DoT expiry prevents excess damage on long frame")
	suite.check(ground.poison.is_empty(), "Expired poison removed")
	game.reset(1)
	game.gold = 10000

	# Le mur force un détour. Sa destruction doit raccourcir le trajet du boss sans le téléporter.
	for y in range(10, 15):
		game.build(Vector2i(3, y), 0)
	game.wave = 50
	game.to_spawn = 1

	var boss: Dictionary = game.spawn_enemy()
	suite.check(boss.boss == 2 and not boss.air, "Major boss remains ground on a flying wave")

	var before_path: int = game.flow[game.cell_id(boss.next)]
	var before_position: Vector2 = game.position_of(boss)
	var before_gold: int = game.gold
	suite.check(game.boss_attack(boss, true), "Major boss attacks a shortening construction")
	suite.check(game.destroyed == 1 and game.towers.size() == 4, "Construction destroyed")
	suite.check(game.flow[game.cell_id(boss.next)] < before_path, "Destruction strictly shortens boss path")
	suite.check(game.position_of(boss) == before_position, "Repath does not teleport boss")
	suite.check(game.gold == before_gold, "Destroyed tower gives no refund")
	game.move_enemy(boss, 0.1)
	suite.near(
		game.position_of(boss).distance_to(before_position),
		0.14,
		"Movement remains continuous after destruction",
	)

	var minor: Dictionary = suite.enemy(game)
	minor.boss = 1
	suite.check(not game.boss_attack(minor, true), "Mini boss cannot destroy towers")
	game.reset(1)
	game.wave = 50
	game.to_spawn = 1
	boss = game.spawn_enemy()
	game.gold = 1000
	game.active = false
	game.build(Vector2i(2, 2), 0)
	suite.check(not game.boss_attack(boss, true), "Boss ignores constructions that do not shorten path")
	game.reset(1)
	game.wave = 10
	game.to_spawn = 2

	var air: Dictionary = game.spawn_enemy()
	minor = game.spawn_enemy()
	suite.check(
		air.air and not minor.air and minor.boss == 1,
		"Tenth wave combines flying units and terrestrial mini boss",
	)

	var point: Vector2 = game.position_of(air)
	game.move_enemy(air, 1.0)
	suite.near(game.position_of(air).distance_to(point), 4.0, "Air follows direct route")
	game.wave = 1

	var reward_early: int = game.spawn_enemy().reward
	game.wave = 99
	suite.check(game.spawn_enemy().reward > reward_early, "Rewards increase with wave")
