extends RefCounted
## Ce fichier prépare les vagues et les monstres qui vont apparaître.
## Les positions et vitesses sont exprimées en cases ; les points de vie et l'or sont des valeurs de jeu.
## Le paramètre game est la partie à modifier, et non une nouvelle partie créée pour cet appel.


## Décrit la composition de la vague number, sans la démarrer.
## Le résultat indique son effectif, la présence de volants, la résistance des terrestres et le type de boss.
## Pour boss, 0 signifie aucun boss, 1 un mini boss et 2 un gros boss.
static func wave_plan(_game, number: int) -> Dictionary:
	# Le reste d'une division par dix vaut zéro pour les vagues 10, 20, 30, etc.
	var boss_kind := 0
	if number == 50 or number == 100:
		boss_kind = 2
	elif number % 10 == 0:
		boss_kind = 1

	return {
		"air": number % 10 == 0,
		"boss": boss_kind,
		"armor": "physical" if number % 2 == 1 else "magic",
		"count": 8 + number * 2,
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
	game.message = "Vague %d : %s%s" % [
		game.wave,
		"sol + air" if plan.air else "résistance " + armor_label,
		" + GROS BOSS" if plan.boss == 2 else (" + mini boss" if plan.boss == 1 else ""),
	]
	game.wave_started.emit(game.wave)
	return true


## Calcule les points de vie initiaux d'un ennemi de la vague number.
## Les points de vie progressent de 6 % par vague ; les volants ont un coefficient de 0,6.
## Le coefficient du mini boss est 16 et celui du gros boss est 75, avant application de la difficulté.
static func enemy_health(game, number: int, flying: bool = false, boss: int = 0) -> float:
	# La vague 1 applique une puissance de zéro : 50 PV de base, puis le coefficient de difficulté.
	var health := 50.0 * pow(1.06, maxi(0, number - 1))
	if flying:
		health *= 0.6

	if boss == 2:
		health *= 75.0
	elif boss == 1:
		health *= 16.0

	# La même difficulté s'applique aux terrestres, volants et boss, après leurs coefficients propres.
	return health * game.Difficulty.health_multiplier(game.difficulty_index, number)


## Crée le prochain monstre et l'ajoute à la liste des ennemis de la partie.
## Les vagues mixtes alternent volants et terrestres ; le boss prévu apparaît en dernier.
## Le dictionnaire renvoyé est le monstre lui-même : modifier ses champs modifie donc ce monstre dans le jeu.
static func spawn_enemy(game) -> Dictionary:
	var plan = game.wave_plan(game.wave)

	# Le dernier monstre reçoit le rôle de boss prévu. Les autres apparitions restent des unités ordinaires.
	var boss = int(plan.boss) if game.to_spawn == 1 else 0
	var flying: bool = plan.air and boss == 0 and game.spawned % 2 == 0
	var hp = game.enemy_health(game.wave, flying, boss)
	var reward: int = (8 + game.wave * 2) * (30 if boss == 2 else (8 if boss == 1 else 1))
	reward = game.combat_income(reward)

	# La fiche suivante contient tout l'état d'un monstre : position, combat, effets et récompense.
	var enemy = {
		# Catégorie et résistance : ces champs décident quelles tours peuvent attaquer et avec quelle efficacité.
		"air": flying,
		"boss": boss,
		"armor": "none" if flying else plan.armor,
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
