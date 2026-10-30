extends RefCounted
## Ce fichier prépare les vagues et les monstres qui vont apparaître.
## Les positions et vitesses sont exprimées en cases ; les points de vie et l'or sont des valeurs de jeu.
## Le paramètre game est la partie à modifier, et non une nouvelle partie créée pour cet appel.


## Décrit la composition de la vague number, sans la démarrer.
## Le résultat indique son effectif, la présence de volants, la résistance des terrestres et le type de boss.
## Pour boss, 0 signifie aucun boss, 1 un mini boss et 2 un gros boss.
static func wave_plan(game, number: int) -> Dictionary:
	# Le reste d'une division par dix vaut zéro pour les vagues 10, 20, 30, etc.
	var boss_kind := 0
	if number == 50 or number == 100:
		boss_kind = 2
	elif number % 10 == 0:
		boss_kind = 1

	var count := 8 + number * 2
	return {
		"air": number % 10 == 0,
		"boss": boss_kind,
		"armor": "physical" if number % 2 == 1 else "magic",
		"mixed_armor": number >= 7,
		"count": count,
		"income": preload("res://gameplay/economy.gd").distribution(number, count, boss_kind, game.difficulty_index),
	}


## Lance la vague suivante sans attendre la fin du compte à rebours.
## Elle prépare le nombre d'apparitions, remet leur minuterie à zéro et annonce la composition au joueur.
## Renvoie false si une vague est déjà active, si le jeu est en pause ou si la campagne est terminée.
static func start_wave(game) -> bool:
	if game.active or game.ended or game.paused or game.wave >= game.LAST_WAVE:
		return false
	game.preparation = 0.0
	game.wave += 1
	game.active = true
	game.spawned = 0
	game.to_spawn = int(game.wave_plan(game.wave).count)
	game.spawn_clock = 0.0

	var plan = game.wave_plan(game.wave)
	var armor_label := "physique" if plan.armor == "physical" else "magique"
	var ground_label := "résistance " + armor_label
	if plan.mixed_armor:
		ground_label = "résistances mixtes, dominante " + armor_label
	game.message = "Vague %d : %s%s" % [
		game.wave,
		"sol + air" if plan.air else ground_label,
		" + GROS BOSS" if plan.boss == 2 else (" + mini boss" if plan.boss == 1 else ""),
	]
	game.wave_started.emit(game.wave)
	return true


## Calcule les points de vie initiaux d'un ennemi de la vague number.
## Les PV suivent la courbe de base_health ; les volants ont un coefficient de 0,6.
## Le coefficient du mini boss est 16 et celui du gros boss est 75, avant application de la difficulté.
static func enemy_health(game, number: int, flying: bool = false, boss: int = 0) -> float:
	var health := base_health(number)
	if flying:
		health *= 0.6

	if boss == 2:
		health *= 75.0
	elif boss == 1:
		health *= 16.0

	# La même difficulté s'applique aux terrestres, volants et boss, après leurs coefficients propres.
	return health * game.Difficulty.health_multiplier(game.difficulty_index, number)


## Préserve les six premières vagues et relie des points de contrôle par une croissance continue.
## Le milieu de partie résiste aux améliorations ; la fin n'exige plus l'explosion des revenus de l'ancienne courbe.
## Les points de contrôle sont des PV terrestres ordinaires en Normal, avant résistance et difficulté.
static func base_health(number: int) -> float:
	var wave := clampi(number, 1, 100)
	if wave <= 6:
		return 50.0 * pow(1.06, wave - 1)
	var previous_wave := 6
	var previous_health := 50.0 * pow(1.06, 5)
	for checkpoint in [Vector2(10, 96), Vector2(20, 350), Vector2(30, 900), Vector2(50, 2200), Vector2(100, 6000)]:
		if wave <= checkpoint.x:
			var progress: float = float(wave - previous_wave) / (checkpoint.x - previous_wave)
			return previous_health * pow(checkpoint.y / previous_health, progress)
		previous_wave = int(checkpoint.x)
		previous_health = checkpoint.y
	return previous_health


## Crée le prochain monstre et l'ajoute à la liste des ennemis de la partie.
## Les vagues mixtes alternent volants et terrestres ; le boss prévu apparaît en dernier.
## Le dictionnaire renvoyé est le monstre lui-même : modifier ses champs modifie donc ce monstre dans le jeu.
static func spawn_enemy(game) -> Dictionary:
	var plan = game.wave_plan(game.wave)

	# Le dernier monstre reçoit le rôle de boss prévu. Les autres apparitions restent des unités ordinaires.
	var boss = int(plan.boss) if game.to_spawn == 1 else 0
	var flying: bool = plan.air and boss == 0 and game.spawned % 2 == 0
	# La dominante continue d'alterner. Une minorité opposée demande de conserver les deux types de dégâts.
	var armor: String = plan.armor
	var mix_interval := 4 if game.wave < 25 else 3
	var ground_ordinal: int = game.spawned / 2 if plan.air else game.spawned
	if plan.mixed_armor and not flying and boss == 0 and ground_ordinal % mix_interval == mix_interval - 1:
		armor = "magic" if armor == "physical" else "physical"
	var hp = game.enemy_health(game.wave, flying, boss)
	var reward: int = preload("res://gameplay/economy.gd").enemy_reward(plan.income, game.spawned, boss > 0)

	# La fiche suivante contient tout l'état d'un monstre : position, combat, effets et récompense.
	var enemy = {
		# Catégorie et résistance : ces champs décident quelles tours peuvent attaquer et avec quelle efficacité.
		"air": flying,
		"boss": boss,
		"armor": "none" if flying else armor,
		"hp": hp,
		"max_hp": hp,
		# Déplacement terrestre : case actuelle, prochaine case, puis progression de 0 à 1 entre les deux.
		"cell": game.entry,
		"next": game.next_cell(game.entry, game.flow),
		"fraction": 0.0,
		# Le sas du portail est hors grille ; ces valeurs animent l'apparition avant l'entrée.
		"portal_remaining": game.PORTAL_APPROACH_CELLS,
		"portal_age": 0.0,
		# flight mesure la distance parcourue par un volant ; speed est une vitesse en cases par seconde.
		"flight": 0.0,
		"speed": 4.0 if flying else (1.4 if boss > 0 else 2.5),
		# Effets en cours : durée du givre, part de vitesse conservée et poisons rangés par tour d'origine.
		"slow_time": 0.0,
		"slow_factor": 1.0,
		"poison": {},
		# La fuite interdit la récompense. attack_clock mesure l'attente avant une nouvelle tentative du boss.
		"reward": reward,
		"attack_clock": 6.0,
		"escaped": false,
	}

	# Cet identifiant distingue deux monstres visuellement identiques, notamment pour leur fiche d'informations.
	enemy.id = game.next_enemy_id
	game.next_enemy_id += 1
	game.enemies.append(enemy)
	game.spawned += 1
	game.to_spawn -= 1
	return enemy
