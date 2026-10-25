extends RefCounted
## Vérifie la position des flèches, leur orientation, leur durée et leur réaction à la pause.
## Les tests de dégâts et de cadence servent à s'assurer que l'animation ne change pas les règles de l'archer.


const Model = preload("res://game.gd")


## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> void:
	var renderer = preload("res://projectiles.gd")

	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var shot = {"from": Vector2(4, 4), "to": Vector2(4, 4) + direction * 2.0, "duration": 0.3, "life": 0.3}

		for progress in [0.0, 0.5, 1.0]:
			shot.life = shot.duration * (1.0 - progress)

			var transform: Transform2D = renderer.arrow_transform(shot, 42.0)
			suite.check(
				transform.origin.is_equal_approx(shot.from.lerp(shot.to, progress) * 42.0),
				"Arrow moves from tower to target without overshoot",
			)
			suite.check(
				transform.x.is_equal_approx(direction),
				"Arrow sprite points towards target in all four directions",
			)

	var game = Model.new()
	game.reset(1)
	game.start_wave()

	var dummy: Dictionary = suite.enemy(game)
	var archer = suite.tower(0)
	game.fire_tower(game.entry + Vector2i(1, -1), archer)
	suite.check(
		game.shots.size() == 1 and game.shots[0].kind == 0,
		"Archer shot is identified for sprite rendering",
	)
	suite.near(dummy.hp, 985.0, "Arrow animation preserves existing archer damage")
	suite.near(archer.cooldown, 1.2, "Arrow sprite does not change archer cadence")

	var life: float = game.shots[0].life
	game.paused = true
	game.tick(0.2)
	suite.near(game.shots[0].life, life, "Pause freezes arrow flight")
	game.paused = false
	game.speed_multiplier = 5
	game.tick(0.1)
	suite.check(game.shots.is_empty(), "Arrow expires with accelerated combat time")
	game.fire_tower(game.entry + Vector2i(1, -1), suite.tower(2))
	suite.check(
		game.shots.size() == 1 and game.shots[0].kind == 2,
		"Other towers remain distinguishable from arrows",
	)
	suite.near(game.shots[0].life, 0.18, "Other tower visual duration stays unchanged")
