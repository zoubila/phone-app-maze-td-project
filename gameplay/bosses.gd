extends RefCounted
## Ce fichier regroupe les attaques des gros boss contre les constructions.
## Avant d'attaquer, il teste des retraits fictifs de tours pour chercher un raccourci utile.
## Un mini boss n'a pas cette capacité de destruction.


## Cherche les tours dont le retrait pourrait raccourcir le chemin restant du gros boss.
## Au maximum seize tours sont examinées pour limiter le temps de calcul sur les grandes cartes.
## La liste renvoyée contient des cases candidates ; aucune tour n'est encore attaquée.
static func shortening_targets(game, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var anchor: Vector2i = enemy.next
	var current = game.flow[game.cell_id(anchor)]
	var candidates: Array = game.towers.keys()
	var tested = 0

	# Les tours sont tirées sans remise : retirer une candidate évite de la tester plusieurs fois dans la même recherche.
	while not candidates.is_empty() and tested < 16:
		var index = game.rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		tested += 1

		# On simule la disparition de cette tour, puis on compare la distance depuis la prochaine case du boss.
		var alternate = game.field_without(cell)

		if alternate[game.cell_id(anchor)] >= 0 and alternate[game.cell_id(anchor)] < current:
			result.append(cell)
	return result


## Fait tenter au gros boss une attaque sur une tour dont la disparition lui serait utile.
## force supprime le tirage de probabilité, ce qui rend ce scénario vérifiable dans les tests.
## Si les points de vie de la tour tombent à zéro, elle est retirée sans remboursement et le chemin change.
static func boss_attack(game, enemy: Dictionary, force := false) -> bool:
	if enemy.boss != 2 or enemy.hp <= 0 or (not force and game.rng.randf() > 0.65):
		return false

	var candidates = game.shortening_targets(enemy)

	if candidates.is_empty():
		return false

	var cell: Vector2i = candidates[game.rng.randi_range(0, candidates.size() - 1)]
	game.towers[cell].hp -= 60.0 + game.wave * 3.0
	game.shots.append({
		"from": game.position_of(enemy),
		"to": Vector2(cell) + Vector2.ONE * 0.5,
		"color": Color("f16b54"),
		"life": 0.45,
		"splash": true,
	})

	if game.towers[cell].hp <= 0:
		game.towers.erase(cell)
		game.destroyed += 1
		game.rebuild_flow()
		game.message = "Le boss a détruit une tour et raccourci son chemin !"
	return true
