extends RefCounted
## Ce fichier organise le passage du temps et l'ordre des événements du combat.
## delta est le temps réel écoulé ; dt est une petite durée de jeu, après application de la vitesse.
## Les fonctions statiques s'appellent directement sur le script, sans fabriquer un nouvel objet.


## Fait avancer la partie à partir de delta secondes réellement écoulées.
## La pause arrête cette progression. La préparation avance normalement, sans accélération de combat.
## Pendant le combat, le temps accéléré est découpé en petits pas identiques pour conserver les mêmes résultats.
static func tick(game, delta: float) -> void:
	if game.paused or game.ended:
		return
	# Le halo du portail respire en temps réel et se fige avec la pause.
	game.presentation_time += delta

	if not game.active:
		advance_shots(game, delta)
		game.preparation = maxf(0.0, game.preparation - delta)

		if game.preparation <= 0.0001:
			game.start_wave()
		return

	# À vitesse 5, une seconde réelle ajoute cinq secondes à simuler. Le reste sera gardé jusqu'à sa consommation.
	game.combat_accumulator += delta * game.speed_multiplier

	while game.combat_accumulator + 0.0000001 >= game.SIMULATION_STEP and game.active and not game.ended:
		game.combat_accumulator -= game.SIMULATION_STEP
		game.combat_step(game.SIMULATION_STEP)

	if not game.active:
		game.combat_accumulator = 0.0


## Exécute un petit intervalle dt de combat, exprimé en secondes de jeu.
## L'ordre est important : apparitions, poison et mouvement, attaques des boss, tirs des tours, puis récompenses.
## Les dernières étapes déterminent si le château tombe ou si la vague et la campagne sont terminées.
static func combat_step(game, dt: float) -> void:
	advance_shots(game, dt)
	spawn_waiting_enemies(game, dt)
	advance_enemies(game, dt)
	fire_ready_towers(game, dt)
	remove_and_pay_enemies(game)
	finish_wave_if_needed(game)


## Diminue la durée des animations, puis conserve seulement les tirs encore visibles.
## filter construit une nouvelle liste à partir des tirs pour lesquels la petite fonction renvoie true.
static func advance_shots(game, dt: float) -> void:
	for shot in game.shots:
		shot.life -= dt
	game.shots = game.shots.filter(func(shot): return shot.life > 0)


## Fait apparaître les monstres attendus toutes les 0,65 seconde de jeu.
## La boucle permet de traiter plusieurs apparitions si la durée reçue est assez grande.
static func spawn_waiting_enemies(game, dt: float) -> void:
	game.spawn_clock -= dt

	while game.to_spawn > 0 and game.spawn_clock <= 0:
		game.spawn_enemy()
		game.spawn_clock += 0.65


## Applique les poisons, déplace les survivants et fait attaquer les gros boss qui sont prêts.
## Un monstre tué par le poison est ignoré pour la suite de cet intervalle.
static func advance_enemies(game, dt: float) -> void:
	for enemy in game.enemies:
		if enemy.hp <= 0:
			continue
		game.poison_tick(enemy, dt)

		if enemy.hp <= 0:
			continue

		# Si le givre expire au milieu de dt, la première portion est ralentie et la seconde retrouve sa vitesse normale.
		var slowed = minf(dt, float(enemy.slow_time))

		if slowed > 0:
			game.move_enemy(enemy, slowed)
			enemy.slow_time = maxf(0.0, enemy.slow_time - slowed)

		if dt > slowed and not enemy.escaped:
			game.move_enemy(enemy, dt - slowed)

		if enemy.boss == 2 and not enemy.escaped:
			enemy.attack_clock -= dt

			if enemy.attack_clock <= 0:
				enemy.attack_clock += 6.0
				game.boss_attack(enemy)


## Diminue le délai de tir des tours et laisse attaquer celles qui sont prêtes.
## Sans cible à portée, la tour reste prête pour le prochain intervalle.
static func fire_ready_towers(game, dt: float) -> void:
	for cell in game.towers:
		var tower: Dictionary = game.towers[cell]
		tower.cooldown = maxf(0.0, tower.cooldown - dt)

		if tower.cooldown <= 0.0000001:
			game.fire_tower(cell, tower)


## Retire les morts et verse leurs récompenses, sauf s'ils ont atteint le château.
## Le retrait empêche de verser à nouveau de l'or pour les mêmes monstres à l'intervalle suivant.
static func remove_and_pay_enemies(game) -> void:
	var survivors: Array = []

	for enemy in game.enemies:
		if enemy.hp > 0:
			survivors.append(enemy)
		elif not enemy.escaped:
			game.gold += int(enemy.reward)
			game.enemy_defeated.emit(enemy)
	game.enemies = survivors


## Vérifie la défaite avant la réussite de la vague et la victoire de campagne.
## Une vague terminée paie son bonus une seule fois et prépare l'attente de quinze secondes.
static func finish_wave_if_needed(game) -> void:
	if not game.active or game.ended:
		return
	if game.lives <= 0 and not game.developer_mode:
		game.active = false
		game.ended = true
		game.message = "Le château est tombé. Recomposez votre labyrinthe."
	elif game.to_spawn == 0 and game.enemies.is_empty():
		game.active = false
		var bonus: int = game.wave_plan(game.wave).income.clear_bonus
		game.gold += bonus
		game.best = maxi(game.best, game.wave)
		game.preparation = 15.0
		game.message = "Vague repoussée. Préparez la suivante."

		if game.wave == game.LAST_WAVE:
			game.ended = true
			game.won = true
			game.message = "Victoire ! Les 100 vagues ont été repoussées."
		game.wave_repelled.emit(game.wave, bonus)
