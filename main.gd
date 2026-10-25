extends Node2D
## POINT D'ENTRÉE : relie les commandes, le modèle game et le rendu board.
## Node2D est le nœud racine de main.tscn ; Godot appelle _ready puis _process à chaque image.
## Les signaux (pressed, item_tapped…) déclenchent les méthodes connectées par connect.
## ui_layout.gd place les contrôles ; inspection.gd gère les fiches des tours et monstres.

# OBJETS PRINCIPAUX : preload charge un script ; new crée son instance.
# game possède les règles, board les dessine. Les contrôles ci-dessous affichent ces données.
var game = preload("res://game.gd").new()
var board: Control
# selected est la case de la tour sélectionnée ; (-1, -1) signifie aucune sélection.
# selected_kind est le type à construire (0 à 7) ; grid_index désigne l'une des trois grilles.
var selected := Vector2i(-1, -1)
var selected_kind := 0
var grid_index := 0
# RÉFÉRENCES D'INTERFACE : Label = texte, Button = bouton, OptionButton = liste de choix.
# Conserver ces objets permet à refresh_ui et ui_layout de modifier les mêmes contrôles.
var status: Label
var message: Label
var map_info: Label
var detail: Label
var grid_choice: OptionButton
var wave_button: Button
var pause_button: Button
var speed_button: Button
var upgrade_button: Button
var sell_button: Button
var type_buttons: Array[Button] = []
# MÉMOIRE D'AFFICHAGE : saved_best évite les sauvegardes répétées ; ui_clock cadence les textes à 10 Hz.
var saved_best := 0
var ui_clock := 0.0
var title_label: Label
var subtitle_label: Label
var footer_label: Label
var entry_button: Button
var castle_button: Button
var overview_button: Button
var zoom_out_button: Button
var zoom_in_button: Button
# DISPOSITION : zone sûre, taille logique et orientation ; inspector référence la fiche d'informations.
var layout_area := Rect2()
var layout_size := Vector2.ZERO
var landscape := true
var inspector: Panel

## Appelée par Godot quand la scène entre dans l'arbre : charge le record puis crée l'interface.
## Connecte les changements de taille de fenêtre à la disposition mobile et affiche l'état initial.
func _ready() -> void:
	# user:// est le dossier de données local propre à l'application, accessible sur ordinateur et mobile.
	var save := ConfigFile.new()
	if save.load("user://progress.cfg") == OK:
		game.best = int(save.get_value("progress", "best_wave", 0))
	saved_best = game.best
	make_ui()
	get_viewport().size_changed.connect(apply_layout)
	apply_layout(true)
	refresh_ui()

## Crée un texte avec position, dimensions, taille de police et couleur, puis le renvoie.
## Le texte ignore les clics pour laisser fonctionner les commandes ou le plateau en dessous.
func label(text_value: String, pos: Vector2, dimensions: Vector2, font_size: int, color := Color("e9e1c8")) -> Label:
	var item := Label.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.clip_text = true
	add_child(item)
	return item

## Crée un bouton aux dimensions demandées et lui applique les styles normal, survol et désactivé.
## action est la fonction à appeler lors de pressed. Renvoie le bouton ajouté à la scène.
func button(text_value: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", 19)
	item.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("24372a")
	normal.border_color = Color("60704c")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	item.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("374d35")
	item.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("1a281e")
	disabled.border_color = Color("394434")
	item.add_theme_stylebox_override("disabled", disabled)
	# connect enregistre la fonction à appeler plus tard au clic ; il ne l'exécute pas maintenant.
	item.pressed.connect(action)
	add_child(item)
	return item

## Construit les contrôles de la scène et relie leurs signaux aux actions du jeu.
## Les coordonnées initiales sont réorganisées ensuite par ui_layout.gd selon l'écran.
## Crée la fiche d'inspection en dernier pour qu'elle s'affiche au-dessus du plateau.
func make_ui() -> void:
	title_label = label("LES MARCHES DU ROYAUME", Vector2(32, 30), Vector2(656, 42), 31)
	subtitle_label = label("MAZE TD  /  PROTOTYPE 09", Vector2(32, 76), Vector2(656, 28), 18, Color("a7b596"))
	status = label("", Vector2(32, 112), Vector2(656, 32), 22)
	message = label("", Vector2(32, 150), Vector2(656, 30), 18, Color("ebcc84"))
	grid_choice = OptionButton.new()
	grid_choice.position = Vector2(32, 188)
	grid_choice.size = Vector2(296, 48)
	grid_choice.add_theme_font_size_override("font_size", 18)
	for dimensions in game.GRID_SIZES:
		grid_choice.add_item("%d haut × %d long" % [dimensions.y, dimensions.x])
	grid_choice.item_selected.connect(change_grid)
	add_child(grid_choice)
	board = preload("res://board.gd").new()
	board.game = game
	board.position = Vector2(32, 248)
	board.size = Vector2(656, 600)
	# Le plateau émet une intention ; main décide de l'action, puis game valide les règles et les prix.
	board.cell_tapped.connect(interact)
	board.item_tapped.connect(inspect_item)
	board.item_hovered.connect(hover_item)
	board.view_dragged.connect(close_inspection)
	add_child(board)
	entry_button = button("Entrée", Vector2(340, 188), Vector2(108, 48), board.entry_view)
	castle_button = button("Château", Vector2(460, 188), Vector2(108, 48), board.castle_view)
	overview_button = button("Vue", Vector2(580, 188), Vector2(108, 48), board.overview)
	map_info = label("", Vector2(32, 860), Vector2(496, 40), 18, Color("c9c7ac"))
	# Les petites fonctions anonymes func() adaptent un clic sans argument à un zoom centré sur le plateau.
	zoom_out_button = button("−", Vector2(544, 858), Vector2(64, 44), func(): board.set_zoom(board.zoom / 1.3, board.size / 2))
	zoom_in_button = button("+", Vector2(624, 858), Vector2(64, 44), func(): board.set_zoom(board.zoom * 1.3, board.size / 2))
	detail = label("", Vector2(32, 907), Vector2(656, 48), 18)
	for i in range(game.TYPES.size()):
		# Capture l'index propre à ce bouton pour ses fonctions anonymes de sélection et de survol.
		var index := i
		type_buttons.append(button("%s\n%d or" % [game.TYPES[i].name, game.TYPES[i].cost], Vector2(32 + (i % 4) * 166, 963 + (i / 4) * 61), Vector2(158, 56), func(): select_kind(index)))
		type_buttons[i].mouse_entered.connect(func(): preview_kind(index))
		type_buttons[i].mouse_exited.connect(hide_hover)
	upgrade_button = button("Améliorer", Vector2(32, 1096), Vector2(320, 52), upgrade_selected)
	sell_button = button("Vendre", Vector2(368, 1096), Vector2(320, 52), sell_selected)
	wave_button = button("", Vector2(32, 1162), Vector2(320, 60), start_or_reset)
	pause_button = button("Pause", Vector2(368, 1162), Vector2(154, 60), toggle_pause)
	speed_button = button("×1", Vector2(538, 1162), Vector2(150, 60), toggle_speed)
	footer_label = label("Toucher : bâtir / sélectionner  •  Glisser : déplacer la carte", Vector2(32, 1232), Vector2(656, 25), 16, Color("a7b596"))
	inspector = preload("res://inspection.gd").new()
	add_child(inspector)
	inspector.sell_requested.connect(sell_tower)
	inspector.upgrade_requested.connect(upgrade_tower)
	inspector.dismiss_requested.connect(close_inspection)

## Adapte les contrôles à la zone sûre disponible et à l'orientation actuelle.
## force impose le calcul même si la zone n'a pas changé ; la partie n'est pas réinitialisée.
## Replace aussi la fiche ouverte après une rotation ou un redimensionnement.
func apply_layout(force: bool = false) -> void:
	if not is_instance_valid(speed_button):
		return
	var area: Rect2 = preload("res://ui_layout.gd").safe_viewport_area(get_viewport_rect().size)
	if not force and area.is_equal_approx(layout_area):
		return
	layout_area = area
	preload("res://ui_layout.gd").arrange(self, area)
	refresh_inspection(true)

## Sélectionne la grille index avant toute construction et avant la première vague.
## Réinitialise la partie et la vue sur l'entrée ; ignore un changement après le début du jeu.
func change_grid(index: int) -> void:
	if game.wave != 0 or not game.towers.is_empty():
		return
	grid_index = index
	game.reset(index)
	close_inspection()
	# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
	selected = Vector2i(-1, -1)
	board.entry_view()
	refresh_ui()

## Choisit le type index pour les prochaines constructions et affiche sa fiche de catalogue.
## Désélectionne la tour placée afin de ne pas la vendre ou l'améliorer par confusion.
func select_kind(index: int) -> void:
	selected_kind = index
	# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
	selected = Vector2i(-1, -1)
	open_inspection({"type": "catalog", "kind": index}, type_buttons[index].position + type_buttons[index].size / 2.0, true)
	refresh_ui()

## Traite un toucher sur une case : sélection de tour, fermeture de fiche ou construction.
## cell est une coordonnée de grille. Le premier toucher hors d'une fiche d'unité ferme sans achat.
## Le modèle valide et facture une construction ; l'interface se met ensuite à jour.
func interact(cell: Vector2i) -> void:
	if game.towers.has(cell):
		selected = cell
		inspect_item({"type": "tower", "cell": cell}, (Vector2(cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom + board.pan)
		return
	# Évite l'achat accidentel quand le joueur voulait seulement fermer la fiche d'une unité.
	elif inspector.visible and inspector.pinned and inspector.target.get("type") != "catalog":
		# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
		selected = Vector2i(-1, -1)
		close_inspection()
	elif game.build(cell, selected_kind):
		selected = cell
		close_inspection()
	refresh_ui()

## Action du bouton principal Améliorer : transmet la case actuellement sélectionnée.
func upgrade_selected() -> void:
	upgrade_tower(selected)

## Demande l'amélioration de la tour en cell puis actualise textes, boutons et fiche.
## Le modèle décide si l'amélioration est possible et fournit le message à afficher.
func upgrade_tower(cell: Vector2i) -> void:
	game.upgrade(cell)
	refresh_ui()

## Action du bouton principal Vendre : transmet la case actuellement sélectionnée.
func sell_selected() -> void:
	sell_tower(selected)

## Demande la vente de la tour en cell, depuis le panneau principal ou sa fiche.
## Après une vente réussie, retire la sélection correspondante et ferme la fiche périmée.
func sell_tower(cell: Vector2i) -> void:
	if game.sell(cell):
		if selected == cell:
			# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
			selected = Vector2i(-1, -1)
		close_inspection()
	refresh_ui()

## Ouvre une fiche pour target à partir de point, exprimé dans les coordonnées de main.
## pin=true garde la fiche ouverte après un clic ; false crée un aperçu passif au survol.
## Actualise aussitôt les données et garde la fiche dans le plateau.
func open_inspection(target: Dictionary, point: Vector2, pin: bool) -> void:
	if not is_instance_valid(inspector):
		return
	inspector.show_card(target, point, pin)
	refresh_inspection()

## Réagit au clic/toucher sur une tour ou un monstre identifié par target.
## point est local au plateau : ajoute sa position pour ouvrir la fiche dans main.
## Une tour devient la cible des actions ; un monstre efface la sélection de vente.
func inspect_item(target: Dictionary, point: Vector2) -> void:
	selected = target.cell if target.type == "tower" else Vector2i(-1, -1)
	open_inspection(target, board.position + point, true)
	refresh_ui()

## Réagit au survol d'une unité sans modifier la sélection de vente.
## Affiche une fiche passive, sauf si une fiche est déjà fixée par clic/toucher.
func hover_item(target: Dictionary, point: Vector2) -> void:
	if inspector.pinned:
		return
	if target.is_empty():
		hide_hover()
	else:
		open_inspection(target, board.position + point, false)

## Affiche les statistiques du type kind au survol d'un bouton du catalogue.
## Préserve une fiche déjà fixée et ne change pas le type choisi pour construire.
func preview_kind(kind: int) -> void:
	if not is_instance_valid(inspector) or inspector.pinned:
		return
	open_inspection({"type": "catalog", "kind": kind}, type_buttons[kind].position + type_buttons[kind].size / 2.0, false)

## Masque uniquement un aperçu passif quand le pointeur quitte sa cible.
## Une fiche fixée par clic/toucher reste ouverte.
func hide_hover() -> void:
	if is_instance_valid(inspector) and not inspector.pinned:
		inspector.hide_card()

## Ferme la fiche, passive ou fixée ; conserve la sélection de tour du panneau principal.
func close_inspection() -> void:
	if is_instance_valid(inspector):
		inspector.hide_card()

## Rafraîchit PV, effets et actions ; ferme la fiche si sa cible a disparu.
## Un aperçu suit ce qui passe sous le pointeur. Une fiche fixée reste immobile pour le tactile.
## reanchor=true recalcule son ancrage après rotation ; limite ensuite sa position au plateau.
func refresh_inspection(reanchor: bool = false) -> void:
	if not is_instance_valid(inspector) or not inspector.visible:
		return
	# Réévalue l'unité sous un pointeur immobile : un monstre peut entrer ou sortir du survol en marchant.
	if not inspector.pinned and board.hovering and not board.dragging:
		var hovered: Dictionary = board.pick_item(board.hover_point)
		if hovered.is_empty():
			hide_hover()
			return
		inspector.show_card(hovered, board.position + board.hover_point, false)
	if not inspector.update_card(game):
		close_inspection()
		return
	# Une fiche tactile ne suit pas continuellement le monstre : ses boutons doivent rester stables.
	# On recalcule sa position seulement quand la disposition de l'écran change.
	if inspector.pinned and reanchor:
		var target: Dictionary = inspector.target
		if target.type == "tower":
			inspector.anchor = board.position + board.pan + (Vector2(target.cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom
		elif target.type == "catalog":
			inspector.anchor = type_buttons[int(target.kind)].position + type_buttons[int(target.kind)].size / 2.0
		else:
			for enemy in game.enemies:
				if enemy.id == target.id:
					inspector.anchor = board.position + board.pan + game.position_of(enemy) * board.CELL * board.zoom
	inspector.fit_inside(Rect2(board.position, board.size))

## Action du bouton de vague : lance la suivante, ou recommence après victoire/défaite.
## Un redémarrage garde la taille de grille choisie et replace la vue sur l'entrée.
func start_or_reset() -> void:
	if game.ended:
		game.reset(grid_index)
		close_inspection()
		# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
		selected = Vector2i(-1, -1)
		board.entry_view()
	else:
		game.start_wave()
	refresh_ui()

## Inverse l'état de pause et met à jour le bouton ; les achats restent utilisables.
func toggle_pause() -> void:
	game.paused = not game.paused
	refresh_ui()

## Parcourt les vitesses de combat 1 → 2 → 3 → 5 → 1, puis actualise leur affichage.
func toggle_speed() -> void:
	var index: int = game.COMBAT_SPEEDS.find(game.speed_multiplier)
	game.speed_multiplier = game.COMBAT_SPEEDS[(index + 1) % game.COMBAT_SPEEDS.size()]
	refresh_ui()

## Reçoit les notifications système de Godot ; met le jeu en pause au passage en arrière-plan.
## what identifie l'événement reçu, notamment lors d'un changement d'application sur mobile.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(pause_button):
		game.paused = true
		refresh_ui()

## Recopie l'état du modèle dans les textes, boutons, sélection et fiche.
## Calcule les libellés d'achat, amélioration et vente et désactive les actions impossibles.
## Ne fait pas avancer la simulation ; demande seulement un nouveau dessin du plateau.
func refresh_ui() -> void:
	status.text = "Or %d  •  Château %d  •  Vague %d/100" % [game.gold, game.lives, game.wave]
	message.text = game.message
	map_info.text = "Chemin : %d cases  •  Tours : %d  •  Record : %d" % [game.route.size(), game.towers.size(), game.best]
	grid_choice.disabled = game.wave > 0 or not game.towers.is_empty()
	var highlighted_kind := int(game.towers[selected].kind) if game.towers.has(selected) else selected_kind
	for i in range(type_buttons.size()):
		type_buttons[i].modulate = Color("f8d788") if i == highlighted_kind else Color.WHITE
		type_buttons[i].disabled = game.ended
	if game.ended:
		wave_button.text = "Rejouer"
	elif game.active:
		wave_button.text = "Vague %d en cours" % game.wave
	else:
		wave_button.text = "Lancer vague %d • %d s" % [game.wave + 1, int(ceil(game.preparation))]
	wave_button.disabled = game.active or (not game.ended and game.paused)
	wave_button.tooltip_text = "Démarrer la prochaine vague sans attendre la fin du compte à rebours."
	pause_button.text = "Reprendre" if game.paused else "Pause"
	pause_button.disabled = game.ended
	speed_button.text = "Combat ×%d" % game.speed_multiplier
	upgrade_button.disabled = true
	sell_button.disabled = true
	upgrade_button.tooltip_text = "Sélectionnez une tour construite sur la carte."
	var kind := selected_kind
	var level := 1
	# La tour sélectionnée peut avoir été vendue ou détruite ; vérifie son existence avant de lire ses données.
	if game.towers.has(selected):
		var tower: Dictionary = game.towers[selected]
		kind = int(tower.kind)
		level = int(tower.level)
		var cost: int = game.upgrade_cost(tower)
		upgrade_button.text = "Niveau maximum" if level >= 7 else "Niveau %d • %d or" % [level + 1, cost]
		if level < 7 and game.gold < cost:
			upgrade_button.text = "N%d : manque %d or" % [level + 1, cost - game.gold]
		upgrade_button.tooltip_text = "Niveau maximum atteint." if level >= 7 else "Améliorer cette tour pour %d or." % cost
		sell_button.text = "Vendre • %d or" % int(tower.spent * 0.7)
		upgrade_button.disabled = game.ended or level >= 7 or game.gold < cost
		sell_button.disabled = game.ended
	else:
		# Efface la case sélectionnée ; cette valeur hors grille signifie « aucune tour ».
		selected = Vector2i(-1, -1)
		upgrade_button.text = "Améliorer"
		sell_button.text = "Vendre"
	# spec est la fiche de base du type ; level fournit les statistiques du niveau actuel.
	var spec: Dictionary = game.TYPES[kind]
	var effect := ""
	match spec.mode:
		"slow": effect = "Ralentit une cible • aucun dégât"
		"slow_aoe": effect = "Ralentit en zone • aucun dégât"
		"dot": effect = "Poison magique • %.1f dégâts/s" % (float(spec.damage) * pow(1.55, level - 1))
		_: effect = "%s • %s • %.0f/tir • %.1f s" % ["Physique" if spec.school == "physical" else "Magie", "zone" if spec.mode == "aoe" else "cible unique", float(spec.damage) * pow(1.55, level - 1), float(spec.delay)]
	var level_text := "N%d/7" % level if game.towers.has(selected) else "à construire"
	detail.text = "%s • %s • portée %.1f • %s\n%s" % [spec.name, level_text, float(spec.range), "air" if spec.air else "sol", effect]
	board.selected = selected
	refresh_inspection()
	board.refresh()

## Appelée à chaque image par Godot : fait avancer le modèle avec delta secondes réelles.
## Limite un saut de temps à 0,25 s, redessine le plateau et rafraîchit les textes à 10 Hz.
## Sauvegarde localement le record uniquement lorsqu'il change, jamais la partie en cours.
func _process(delta: float) -> void:
	# Ne rattrape pas une longue absence d'un coup ; une notification système met aussi le jeu en pause.
	game.tick(minf(delta, 0.25))
	ui_clock += delta
	# Les textes et fiches se rafraîchissent au maximum dix fois par seconde ; le dessin reste à chaque image.
	if ui_clock >= 0.1:
		ui_clock = 0.0
		apply_layout()
		refresh_ui()
	else:
		board.refresh()
	# Écrit uniquement un nouveau record. saved_best ne change que si la sauvegarde réussit.
	if game.best != saved_best:
		# user:// est le dossier de données local propre à l'application, accessible sur ordinateur et mobile.
		var save := ConfigFile.new()
		save.set_value("progress", "best_wave", game.best)
		if save.save("user://progress.cfg") == OK:
			saved_best = game.best
