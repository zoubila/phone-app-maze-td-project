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
var map_info: Label
var detail: Label
var grid_choice: OptionButton
var wave_button: Button
var pause_button: Button
var speed_button: Button
var upgrade_button: Button
var sell_button: Button
var type_buttons: Array[Button] = []
# saved_best garde le dernier record écrit sur disque pour éviter les sauvegardes inutiles.
# ui_clock mesure l'attente avant la prochaine actualisation des textes, effectuée dix fois par seconde.
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


## Sélectionne la grille index avant toute construction et avant la première vague.
## Réinitialise la partie et la vue sur l'entrée ; ignore un changement après le début du jeu.
func change_grid(index: int) -> void:
	if game.wave != 0 or not game.towers.is_empty():
		return
	grid_index = index
	game.reset(index)
	close_inspection()
	selected = Vector2i(-1, -1)
	board.entry_view()
	refresh_ui()


## Choisit le type index pour les prochaines constructions et affiche sa fiche de catalogue.
## Désélectionne la tour placée afin de ne pas la vendre ou l'améliorer par confusion.
func select_kind(index: int) -> void:
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
	inspector.fit_inside(Rect2(board.position, board.size))


## Action du bouton de vague : lance la suivante, ou recommence après victoire/défaite.
## Un redémarrage garde la taille de grille choisie et replace la vue sur l'entrée.
func start_or_reset() -> void:
	if game.ended:
		game.reset(grid_index)
		close_inspection()
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
	preload("res://ui/update_interface.gd").refresh(self)


## Appelée à chaque image par Godot : fait avancer le modèle avec delta secondes réelles.
## Limite un saut de temps à 0,25 seconde, redessine le plateau et actualise les textes dix fois par seconde.
## Sauvegarde localement le record uniquement lorsqu'il change, jamais la partie en cours.
func _process(delta: float) -> void:
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
