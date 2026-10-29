extends RefCounted
## Ce fichier contient le ciblage des tours, leurs attaques et les dégâts du poison.
## Les fonctions reçoivent game pour consulter les ennemis et le catalogue des tours.
## Les animations sont enregistrées dans game.shots, mais les dégâts sont décidés immédiatement ici.


## Renvoie le coefficient qui transforme les dégâts en fonction de la résistance.
## Une résistance au type school donne 0,5 ; l'autre type donne 1,5.
## Une unité sans résistance, notamment aérienne, reçoit le coefficient neutre de 1.
static func damage_multiplier(_game, enemy: Dictionary, school: String) -> float:
	if enemy.air or enemy.armor == "none":
		return 1.0
	return 0.5 if enemy.armor == school else 1.5


## Renvoie la portée du type de tour, exprimée en nombre de cases.
## Le niveau n'intervient pas dans ce calcul : améliorer une tour n'augmente pas sa portée.
static func tower_range(game, tower: Dictionary) -> float:
	return float(game.TYPES[int(tower.kind)].range)


## Vérifie qu'un monstre est vivant et appartient à la catégorie visée par la tour : sol ou air.
## Cette fonction ne mesure pas la distance ; fire_tower vérifiera aussi que la cible est à portée.
static func can_target(game, tower: Dictionary, enemy: Dictionary) -> bool:
	return enemy.hp > 0 and bool(game.TYPES[int(tower.kind)].air) == bool(enemy.air)


## Applique l'effet d'une attaque sur un ennemi compatible avec la tour.
## Selon le type, elle retire des points de vie, applique un ralentissement ou mémorise un poison.
## source est la case de la tour : elle distingue les poisons de tours différentes, qui peuvent se cumuler.
static func apply_hit(game, source: Vector2i, tower: Dictionary, enemy: Dictionary) -> void:
	if not game.can_target(tower, enemy):
		return

	var spec: Dictionary = game.TYPES[int(tower.kind)]
	var level = int(tower.level)

	if spec.mode == "slow" or spec.mode == "slow_aoe":
		var base_factor := 0.6
		if spec.mode == "slow_aoe":
			base_factor = 0.75

		var factor := maxf(0.35, base_factor - (level - 1) * 0.04)

		# Un facteur plus petit ralentit davantage. Le meilleur ralentissement est conservé ; on ne les multiplie pas.
		if enemy.slow_time <= 0 or factor <= enemy.slow_factor:
			enemy.slow_factor = factor
			enemy.slow_time = 2.0 + level * 0.2
	elif spec.mode == "dot":

		# La case de la tour sert de clé : un nouveau tir de cette tour renouvelle son poison.
		# Une autre tour possède une autre clé et ajoute donc un poison distinct.
		enemy.poison[source] = {
			"time": 4.0 + level * 0.5,
			"dps": float(spec.damage) * pow(1.55, level - 1),
		}
	else:
		enemy.hp -= float(spec.damage) * pow(1.55, level - 1) * game.damage_multiplier(enemy, spec.school)


## Cherche, parmi les ennemis à portée, celui qui a le moins de chemin restant jusqu'au château.
## Applique les dégâts ou le contrôle, à lui seul ou aux ennemis proches pour une attaque de zone.
## Si une cible est trouvée, prépare le délai avant le prochain tir et l'animation correspondante.
static func fire_tower(game, cell: Vector2i, tower: Dictionary) -> void:
	var target: Dictionary = {}

	# INF signifie l'infini : n'importe quelle première cible valide sera plus proche du château.
	var shortest = INF
	var radius = game.tower_range(tower)
	var origin = Vector2(cell) + Vector2.ONE * 0.5

	for enemy in game.enemies:
		if not game.can_target(tower, enemy):
			continue

		# Comparer les carrés des distances évite une racine carrée pour chaque ennemi examiné.
		var enemy_position: Vector2 = game.position_of(enemy)
		if origin.distance_squared_to(enemy_position) > radius * radius:
			continue

		# On compare le trajet restant, et non la distance directe au château : le labyrinthe compte dans ce choix.
		var remaining: float
		if enemy.air:
			remaining = game.cols - 1 - enemy.flight
		else:
			# La distance de la prochaine case est entière ; on y ajoute la portion de segment non parcourue.
			remaining = game.flow[game.cell_id(enemy.next)] + 1.0 - enemy.fraction
		remaining += float(enemy.get("portal_remaining", 0.0))

		if remaining < shortest:
			target = enemy
			shortest = remaining

	if target.is_empty():
		return

	var spec: Dictionary = game.TYPES[int(tower.kind)]
	var point = game.position_of(target)
	var splash: bool = spec.mode == "aoe" or spec.mode == "slow_aoe"

	# Une attaque de zone part de la cible choisie, puis touche les cibles compatibles proches de ce point.
	if splash:
		for enemy in game.enemies:
			if game.can_target(tower, enemy) and game.position_of(enemy).distance_squared_to(point) <= 2.25:
				game.apply_hit(cell, tower, enemy)
	else:
		game.apply_hit(cell, tower, target)
	tower.cooldown = float(spec.delay)

	# Cette durée sert seulement à animer le projectile. Les points de vie ont déjà été modifiés par apply_hit.
	var duration := 0.18
	if int(tower.kind) == 0:
		duration = clampf(origin.distance_to(point) / 12.0, 0.12, 0.32)
	game.shots.append({
		"kind": int(tower.kind),
		"from": origin,
		"to": point,
		"color": spec.color,
		"duration": duration,
		"life": duration,
		"splash": splash,
	})


## Applique les dégâts des poisons pendant dt secondes de jeu.
## Chaque tour empoisonneuse possède sa propre durée restante ; un effet expiré est retiré.
## Le dernier calcul de dégâts est limité au temps réellement restant, pour ne pas infliger de dégâts supplémentaires.
static func poison_tick(game, enemy: Dictionary, dt: float) -> void:
	for source in enemy.poison.keys():
		var effect: Dictionary = enemy.poison[source]

		# Si le poison expire avant la fin de dt, seule sa durée réellement restante produit des dégâts.
		var duration = minf(dt, float(effect.time))
		enemy.hp -= duration * effect.dps * game.damage_multiplier(enemy, "magic")
		effect.time -= dt

		if effect.time <= 0:
			enemy.poison.erase(source)
