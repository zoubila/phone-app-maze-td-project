extends RefCounted
## Ce fichier s'occupe des positions des monstres et de leur arrivée au château.
## Un ennemi est un dictionnaire : par exemple enemy.hp est sa valeur de points de vie.
## Les images et la caméra ne sont pas utilisées ici ; le déplacement doit fonctionner sans affichage.


## Calcule la position précise du monstre entre les centres de ses cases.
## Le résultat est exprimé en cases, avec des décimales pour obtenir un déplacement fluide.
## Le dessin multiplie ensuite cette position par la taille graphique d'une case.
static func position_of(game, enemy: Dictionary) -> Vector2:
	if enemy.air:
		return Vector2(game.entry).lerp(
			Vector2(game.exit_cell),
			float(enemy.flight) / maxf(1.0, game.cols - 1),
		) + Vector2.ONE * 0.5
	return Vector2(enemy.cell).lerp(Vector2(enemy.next), float(enemy.fraction)) + Vector2.ONE * 0.5


## Déplace un ennemi pendant dt secondes de jeu, à sa vitesse éventuellement ralentie.
## Un terrestre termine chaque segment avant de choisir la case suivante ; un volant suit la ligne directe.
## Si le monstre arrive au château, escape retire les vies correspondantes.
static func move_enemy(game, enemy: Dictionary, dt: float) -> void:
	var distance: float = enemy.speed * dt * (enemy.slow_factor if enemy.slow_time > 0 else 1.0)

	if enemy.air:
		enemy.flight += distance

		if enemy.flight >= game.cols - 1:
			game.escape(enemy)
		return

	# Un intervalle peut traverser plusieurs cases. On consomme la distance segment par segment pour garder les virages.
	while distance > 0 and not enemy.escaped:
		var step = minf(distance, 1.0 - float(enemy.fraction))
		enemy.fraction += step
		distance -= step

		# La petite tolérance évite de rester bloqué à une valeur comme 0,999999 à cause des arrondis numériques.
		if enemy.fraction >= 0.999999:
			enemy.cell = enemy.next
			enemy.fraction = 0.0

			if enemy.cell == game.exit_cell:
				game.escape(enemy)
				break
			enemy.next = game.next_cell(enemy.cell, game.flow)


## Enregistre une arrivée au château une seule fois et met les points de vie du monstre à zéro.
## Le joueur perd une vie pour une unité, trois pour un mini boss et cinq pour un gros boss.
## Le champ escaped permettra de retirer ce monstre sans donner d'or.
static func escape(game, enemy: Dictionary) -> void:
	if enemy.escaped:
		return
	enemy.escaped = true
	enemy.hp = 0.0
	game.lives = maxi(0, game.lives - (5 if enemy.boss == 2 else (3 if enemy.boss == 1 else 1)))
