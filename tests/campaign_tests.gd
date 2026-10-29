extends RefCounted
## Parcourt les cent vagues, les récompenses, la victoire, puis une défaite et un redémarrage.
## Les monstres sont retirés artificiellement : ce scénario vérifie le déroulement, pas la difficulté de la campagne.


const Model = preload("res://game.gd")


## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> int:
	var game
	game = Model.new()
	game.reset(1)
	game.preparation = 0.0

	var kills = 0

	# Les ennemis sont éliminés artificiellement pour accélérer ce test du déroulement et des paiements.
	for expected_wave in range(1, 101):
		suite.check(game.start_wave(), "Start each campaign wave")

		var gold_before: int = game.gold
		var steps = 0

		while game.active and steps < 500:
			game.tick(0.65)

			for item in game.enemies:
				item.hp = 0
				kills += 1
			steps += 1
		suite.check(not game.active and game.best == expected_wave, "Every wave clears and updates record")
		suite.check(game.gold > gold_before, "Each wave pays rewards")

		var once: int = game.gold
		game.tick(0.1)
		suite.check(game.gold == once, "No duplicate clear bonus")
	suite.check(game.ended and game.won and game.wave == 100, "Victory exactly at wave 100")
	suite.check(not game.start_wave(), "No wave 101")
	game.reset(1)
	game.preparation = 0
	game.start_wave()
	game.lives = 1
	game.to_spawn = 1

	var leak: Dictionary = game.spawn_enemy()
	leak.portal_remaining = 0.0
	leak.cell = game.exit_cell - Vector2i.RIGHT
	leak.next = game.exit_cell
	leak.fraction = 0.95
	game.tick(0.1)
	suite.check(game.ended and not game.won and game.lives == 0, "Ground escape causes defeat")
	suite.check(game.gold == 600, "No gold for escaped enemy")
	game.reset(1)
	suite.check(
		not game.ended and game.wave == 0 and game.preparation == 60,
		"Replay restores first preparation",
	)
	return kills
