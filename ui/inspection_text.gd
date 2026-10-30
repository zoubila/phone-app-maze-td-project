extends RefCounted
## Ce fichier prépare le texte des fiches sans créer de boutons ni modifier la partie.
## Il reçoit des données, les traduit en phrases lisibles, puis renvoie du texte.
## Les retours à la ligne sont construits explicitement pour éviter une seule instruction démesurée.


## Choisit le nom à afficher en donnant la priorité aux deux catégories de boss.
static func enemy_title(enemy: Dictionary) -> String:
	if enemy.boss == 2:
		return "Gros boss"

	if enemy.boss == 1:
		return "Mini boss"

	if enemy.air:
		return "Unité aérienne"

	return "Monstre terrestre"


## Décrit la résistance du monstre avec les mêmes mots que les deux catégories de dégâts.
## Le cas aérien est traité avant l'armure, car les volants reçoivent des dégâts physiques neutres.
static func enemy_resistance(enemy: Dictionary) -> String:
	if enemy.air:
		return "Aucune faiblesse physique"

	if enemy.armor == "none":
		return "Aucune résistance"

	if enemy.armor == "physical":
		return "Résiste au physique • faible à la magie"

	return "Résiste à la magie • faible au physique"


## Prépare les lignes de statistiques du monstre qui est actuellement inspecté.
## pinned indique que le joueur a gardé la fiche ouverte par clic ou toucher.
## La vitesse affichée tient compte du givre tant que sa durée restante est positive.
static func enemy_body(enemy: Dictionary, pinned: bool) -> String:
	var speed: float = enemy.speed

	if enemy.slow_time > 0:
		speed *= enemy.slow_factor

	var hint := "Cliquer / toucher pour garder la fiche"

	if pinned:
		hint = "Toucher ailleurs pour fermer"

	if enemy.boss == 2:
		hint = "Brise les tours • Givre max 40 %"
	elif enemy.boss == 1:
		hint = "Givre limité à 45 %"

	var targets := "tours terrestres"

	if enemy.air:
		targets = "Ballistes uniquement"

	var frost := "non"

	if enemy.slow_time > 0:
		frost = "actif"

	var lines: Array[String] = [
		"PV : %.0f / %.0f" % [maxf(0, enemy.hp), enemy.max_hp],
		enemy_resistance(enemy),
		"Vitesse : %.2f cases/s" % speed,
		"Récompense : %d or" % enemy.reward,
		"Ciblage : %s" % targets,
		"Givre : %s • Poison : %d" % [frost, enemy.poison.size()],
		hint,
	]

	# join place un retour à la ligne entre les phrases, sans en ajouter après la dernière.
	return "\n".join(lines)


## Décrit ce que produit une attaque de la tour au niveau demandé.
## Les dégâts progressent avec le niveau ; la cadence et la portée restent celles du type de tour.
static func tower_effect(game, spec: Dictionary, level: int) -> String:
	var damage: float = float(spec.damage) * game.tower_power(level)
	var scope := "une cible"

	if spec.mode == "aoe" or spec.mode == "slow_aoe":
		scope = "en zone"

	match spec.mode:
		"slow", "slow_aoe":
			# Le facteur indique la part de vitesse conservée : 0,6 correspond à 40 % de ralentissement.
			var base_factor := 0.6

			if spec.mode == "slow_aoe":
				base_factor = 0.75

			var factor := maxf(0.35, base_factor - (level - 1) * 0.04)
			var percentage := (1.0 - factor) * 100.0
			var duration := 2.0 + level * 0.2
			return "Ralentit de %.0f %% • zéro dégât\nDurée : %.1f s • %s" % [percentage, duration, scope]

		"dot":
			return "Poison magique : %.1f dégâts/s\nDurée : %.1f s par application" % [
				damage,
				4.0 + level * 0.5,
			]

		_:
			var school := "magiques"

			if spec.school == "physical":
				school = "physiques"

			if spec.mode == "aoe":
				scope = "zone"
			return "%.1f dégâts %s / tir\n%.1f s entre tirs • %s" % [damage, school, spec.delay, scope]


## Compose le texte d'une tour construite ou de son aperçu dans le catalogue.
## Dans le catalogue, on affiche le prix d'achat ; sur une tour existante, on affiche le prochain niveau et la revente.
static func tower_body(game, tower: Dictionary, catalog: bool) -> String:
	var spec: Dictionary = game.TYPES[int(tower.kind)]
	var level := int(tower.level)
	var targets := "sol uniquement"

	if spec.air:
		targets = "air uniquement"

	var price := "Niveau maximum atteint"

	if catalog:
		price = "Prix : %d or" % spec.cost
	elif level < 7:
		price = "Amélioration : %d or" % game.upgrade_cost(tower)

	var last_line := "Choisir une case pour construire"

	if not catalog:
		last_line = "Vente : %d or (70 %%)" % int(tower.spent * 0.7)

	var lines: Array[String] = [
		"Cibles : %s" % targets,
		tower_effect(game, spec, level),
		"Portée fixe : %.1f cases" % game.tower_range(tower),
		"PV : %.0f / %.0f" % [tower.hp, 120.0 + (level - 1) * 60],
		price,
		last_line,
	]
	return "\n".join(lines)
