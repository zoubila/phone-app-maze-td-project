extends RefCounted
## Ce fichier met les textes et les boutons en accord avec la partie.
## Il ne fait pas avancer les monstres et n'achète aucune tour.
## ui est la scène principale ; ui.game contient les données qui doivent être affichées.


## Actualise les zones de l'interface dans un ordre stable.
## La sélection est vérifiée avant d'être transmise au plateau et à la fiche.
static func refresh(ui) -> void:
	refresh_status(ui)
	refresh_wave_controls(ui)
	refresh_selected_tower(ui)
	refresh_board(ui)


## Affiche l'or, les vies, la vague et le chemin, puis colore le type de tour sélectionné.
## Le choix de grille est fermé après la première construction ou le début d'une vague.
static func refresh_status(ui) -> void:
	ui.status.text = "Or %d  •  Château %d  •  Vague %d/100" % [ui.game.gold, ui.game.lives, ui.game.wave]
	ui.message.text = ui.game.message
	ui.map_info.text = "Chemin : %d cases  •  Tours : %d  •  Record : %d" % [
		ui.game.route.size(),
		ui.game.towers.size(),
		ui.game.best,
	]
	ui.grid_choice.disabled = ui.game.wave > 0 or not ui.game.towers.is_empty()

	var highlighted_kind = int(ui.game.towers[ui.selected].kind) if ui.game.towers.has(ui.selected) else ui.selected_kind

	for i in range(ui.type_buttons.size()):
		ui.type_buttons[i].modulate = Color("f8d788") if i == highlighted_kind else Color.WHITE
		ui.type_buttons[i].disabled = ui.game.ended


## Adapte les boutons à la phase actuelle : attente, combat ou fin de partie.
## Le compte à rebours est arrondi au-dessus pour que le bouton n'affiche pas zéro trop tôt.
static func refresh_wave_controls(ui) -> void:
	if ui.game.ended:
		ui.wave_button.text = "Rejouer"
	elif ui.game.active:
		ui.wave_button.text = "Vague %d en cours" % ui.game.wave
	else:
		ui.wave_button.text = "Lancer vague %d • %d s" % [ui.game.wave + 1, int(ceil(ui.game.preparation))]
	ui.wave_button.disabled = ui.game.active or (not ui.game.ended and ui.game.paused)
	ui.wave_button.tooltip_text = "Démarrer la prochaine vague sans attendre la fin du compte à rebours."
	ui.pause_button.text = "Reprendre" if ui.game.paused else "Pause"
	ui.pause_button.disabled = ui.game.ended
	ui.speed_button.text = "Combat ×%d" % ui.game.speed_multiplier


## Met à jour les actions et le résumé de la tour sélectionnée, ou du type à construire.
## Une tour vendue ou détruite ne doit plus pouvoir être améliorée : son existence est revérifiée.
## Le prix manquant est affiché si le joueur ne possède pas assez d'or.
static func refresh_selected_tower(ui) -> void:
	ui.upgrade_button.disabled = true
	ui.sell_button.disabled = true
	ui.upgrade_button.tooltip_text = "Sélectionnez une tour construite sur la carte."

	var kind = ui.selected_kind
	var level = 1

	if ui.game.towers.has(ui.selected):
		var tower: Dictionary = ui.game.towers[ui.selected]
		kind = int(tower.kind)
		level = int(tower.level)

		var cost: int = ui.game.upgrade_cost(tower)
		ui.upgrade_button.text = "Niveau maximum" if level >= 7 else "Niveau %d • %d or" % [level + 1, cost]

		if level < 7 and ui.game.gold < cost:
			ui.upgrade_button.text = "N%d : manque %d or" % [level + 1, cost - ui.game.gold]
		ui.upgrade_button.tooltip_text = "Niveau maximum atteint." if level >= 7 else "Améliorer cette tour pour %d or." % cost
		ui.sell_button.text = "Vendre • %d or" % int(tower.spent * 0.7)
		ui.upgrade_button.disabled = ui.game.ended or level >= 7 or ui.game.gold < cost
		ui.sell_button.disabled = ui.game.ended
	else:
		ui.selected = Vector2i(-1, -1)
		ui.upgrade_button.text = "Améliorer"
		ui.sell_button.text = "Vendre"

	var spec: Dictionary = ui.game.TYPES[kind]
	var effect = ""

	match spec.mode:
		"slow":
			effect = "Ralentit une cible • aucun dégât"
		"slow_aoe":
			effect = "Ralentit en zone • aucun dégât"
		"dot":
			effect = "Poison magique • %.1f dégâts/s" % (float(spec.damage) * pow(1.55, level - 1))
		_:
			effect = "%s • %s • %.0f/tir • %.1f s" % [
				"Physique" if spec.school == "physical" else "Magie",
				"zone" if spec.mode == "aoe" else "cible unique",
				float(spec.damage) * pow(1.55, level - 1),
				float(spec.delay),
			]

	var level_text = "N%d/7" % level if ui.game.towers.has(ui.selected) else "à construire"
	ui.detail.text = "%s • %s • portée %.1f • %s\n%s" % [
		spec.name,
		level_text,
		float(spec.range),
		"air" if spec.air else "sol",
		effect,
	]


## Transmet la sélection au dessin, actualise la fiche ouverte et demande un nouveau dessin.
## Demander un dessin ne fait pas avancer le temps du jeu.
static func refresh_board(ui) -> void:
	ui.board.selected = ui.selected
	ui.refresh_inspection()
	ui.board.refresh()
