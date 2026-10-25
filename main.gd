extends Node2D
## Ce fichier est le point de départ de l'application et le lien entre les boutons et la partie.
## Godot crée ce nœud à partir de main.tscn, appelle _ready une fois, puis _process à chaque image.
## La création des boutons est dans ui/build_interface.gd ; leur actualisation est dans ui/update_interface.gd.
## Les règles ne sont pas recopiées ici : les actions du joueur sont transmises à l'objet game.

# preload trouve le script avant le démarrage ; new crée la partie que l'on va utiliser.
# game garde les règles et les données. board est le contrôle qui affiche la carte et reçoit les touchers.
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
var wave_button: Button
var pause_button: Button
var speed_button: Button
var settings_button: Button
var settings_screen: Panel
var type_buttons: Array[Button] = []
# saved_best garde le dernier record écrit sur disque pour éviter les sauvegardes inutiles.
# ui_clock mesure l'attente avant la prochaine actualisation des textes, effectuée dix fois par seconde.
var saved_best := 0
var ui_clock := 0.0
# DISPOSITION : zone sûre, taille logique et orientation ; inspector référence la fiche d'informations.
var layout_area := Rect2()
var layout_size := Vector2.ZERO
var landscape := true
var inspector: Panel
var hud_panel: Panel
var menu_screen: Control
var end_screen: Panel
# La préparation et les combats ne commencent qu’après le clic du menu.
var in_menu := true

## Appelée par Godot quand la scène entre dans l'arbre : charge le record puis crée l'interface.
## Connecte les changements de taille de fenêtre à la disposition mobile et affiche l'état initial.
func _ready() -> void:
	var save := ConfigFile.new()

	if save.load("user://progress.cfg") == OK:
		game.best = int(save.get_value("progress", "best_wave", 0))
	saved_best = game.best
	make_ui()
	get_viewport().size_changed.connect(apply_layout)
	apply_layout(true)
	refresh_ui()


## Construit les contrôles de la scène et relie leurs signaux aux actions du jeu.
## Les coordonnées initiales sont réorganisées ensuite par ui_layout.gd selon l'écran.
## Crée la fiche d'inspection en dernier pour qu'elle s'affiche au-dessus du plateau.
func make_ui() -> void:
	preload("res://ui/build_interface.gd").create(self)


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



## Choisit le type index pour les prochaines constructions et affiche sa fiche de catalogue.
## Désélectionne la tour placée afin de ne pas la vendre ou l'améliorer par confusion.
func select_kind(index: int) -> void:
	if in_menu or game.ended:
		return

	selected_kind = index
	selected = Vector2i(-1, -1)
	open_inspection(
		{"type": "catalog", "kind": index},
		type_buttons[index].position + type_buttons[index].size / 2.0,
		true,
	)
	refresh_ui()


## Traite un toucher sur une case : sélection de tour, fermeture de fiche ou construction.
## cell est une coordonnée de grille. Le premier toucher hors d'une fiche d'unité ferme sans achat.
## Le modèle valide et facture une construction ; l'interface se met ensuite à jour.
func interact(cell: Vector2i) -> void:
	if in_menu or game.ended:
		return

	if game.towers.has(cell):
		selected = cell
		inspect_item(
			{"type": "tower", "cell": cell},
			(Vector2(cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom + board.pan,
		)
		return
	elif inspector.visible and inspector.pinned and inspector.target.get("type") != "catalog":
		selected = Vector2i(-1, -1)
		close_inspection()
	elif game.build(cell, selected_kind):
		selected = cell
		close_inspection()
	refresh_ui()



## Demande l'amélioration de la tour en cell puis actualise textes, boutons et fiche.
## Le modèle décide si l'amélioration est possible et fournit le message à afficher.
func upgrade_tower(cell: Vector2i) -> void:
	game.upgrade(cell)
	refresh_ui()



## Demande la vente de la tour en cell depuis le bouton de sa fiche d'informations.
## Après une vente réussie, retire la sélection correspondante et ferme la fiche périmée.
func sell_tower(cell: Vector2i) -> void:
	if game.sell(cell):
		if selected == cell:
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
	if in_menu or game.ended:
		return

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
	open_inspection(
		{"type": "catalog", "kind": kind},
		type_buttons[kind].position + type_buttons[kind].size / 2.0,
		false,
	)


## Masque uniquement un aperçu passif quand le pointeur quitte sa cible.
## Une fiche fixée par clic/toucher reste ouverte.
func hide_hover() -> void:
	if is_instance_valid(inspector) and not inspector.pinned:
		inspector.hide_card()


## Ferme la fiche et conserve la tour sélectionnée pour son cercle de portée et une inspection ultérieure.
func close_inspection() -> void:
	if is_instance_valid(inspector):
		inspector.hide_card()


## Rafraîchit PV, effets et actions ; ferme la fiche si sa cible a disparu.
## Un aperçu suit ce qui passe sous le pointeur. Une fiche fixée reste immobile pour le tactile.
## reanchor=true recalcule son ancrage après rotation ; limite ensuite sa position au plateau.
func refresh_inspection(reanchor: bool = false) -> void:
	if not is_instance_valid(inspector) or not inspector.visible:
		return

	if not inspector.pinned and board.hovering and not board.dragging:
		var hovered: Dictionary = board.pick_item(board.hover_point)

		if hovered.is_empty():
			hide_hover()
			return
		inspector.show_card(hovered, board.position + board.hover_point, false)

	if not inspector.update_card(game):
		close_inspection()
		return

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
	inspector.fit_inside(inspection_bounds())



## Démarre une nouvelle partie après le choix du menu. L'attente d'une minute commence ici, pas dans le menu.
func start_game(index: int = 0) -> void:
	settings_screen.hide()
	grid_index = index
	game.reset(index)
	in_menu = false
	selected = Vector2i(-1, -1)
	selected_kind = 0
	close_inspection()
	# Une fin de partie peut avoir interrompu un glissement avant le relâchement du doigt.
	board.dragging = false
	board.moved = false
	board.touch_gestures.reset()
	apply_layout(true)
	board.entry_view()
	refresh_ui()


## Recommence avec la même taille de grille depuis le bouton central du résultat.
func restart_game() -> void:
	if game.ended:
		start_game(grid_index)


## Revient au menu ; Commencer créera ensuite une nouvelle partie avec la grille choisie.
## Ferme les fenêtres et annule les gestes pour éviter un clic involontaire au prochain lancement.
func return_home() -> void:
	in_menu = true
	settings_screen.hide()
	close_inspection()
	selected = Vector2i(-1, -1)
	board.dragging = false
	board.moved = false
	board.touch_gestures.reset()
	refresh_ui()


## Ouvre les paramètres et suspend le temps sans modifier la pause choisie par le joueur.
func open_settings() -> void:
	if in_menu or game.ended:
		return
	close_inspection()
	board.dragging = false
	board.touch_gestures.reset()
	settings_screen.show()


## Le bouton flottant permet seulement d'écourter la préparation de la prochaine vague.
func launch_wave() -> void:
	if not in_menu and not game.ended:
		game.start_wave()
	refresh_ui()


## Réserve les bandes des commandes flottantes pour qu'une fiche ne masque pas Pause ou le lancement de vague.
func inspection_bounds() -> Rect2:
	return Rect2(board.position + Vector2(0, 72), board.size - Vector2(0, 144))


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
	preload("res://ui/update_interface.gd").refresh(self)


## Appelée à chaque image par Godot : fait avancer le modèle avec delta secondes réelles.
## Limite un saut de temps à 0,25 seconde, redessine le plateau et actualise les textes dix fois par seconde.
## Sauvegarde localement le record uniquement lorsqu'il change, jamais la partie en cours.
func _process(delta: float) -> void:
	if in_menu or settings_screen.visible:
		return

	# Après un ralentissement important de l'application, on ne simule pas tout le retard d'un seul coup.
	game.tick(minf(delta, 0.25))
	ui_clock += delta

	if ui_clock >= 0.1:
		ui_clock = 0.0
		apply_layout()
		refresh_ui()
	else:
		board.refresh()

	if game.best != saved_best:
		# user:// est le dossier de données privé du jeu sur l'appareil, et non le dossier du code source.
		var save := ConfigFile.new()
		save.set_value("progress", "best_wave", game.best)

		if save.save("user://progress.cfg") == OK:
			saved_best = game.best
