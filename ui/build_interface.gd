extends RefCounted
## Ce fichier assemble l'interface une seule fois au lancement de la scène.
## Les fonctions sont séparées par zone visible : en-tête, carte, catalogue, actions et fiche.
## ui est le nœud main.gd ; les contrôles sont conservés dans ses variables pour être actualisés ensuite.


const Controls = preload("res://ui/control_factory.gd")


## Construit les différentes zones dans leur ordre d'affichage.
## Cette fonction ne lance pas de vague et ne remet pas la partie à zéro.
static func create(ui) -> void:
	create_header(ui)
	create_map_controls(ui)
	create_tower_catalog(ui)
	create_action_buttons(ui)
	create_inspector(ui)


## Crée le titre, les ressources visibles et la zone qui explique la dernière action au joueur.
static func create_header(ui) -> void:
	ui.title_label = Controls.label(ui, "LES MARCHES DU ROYAUME", Vector2(32, 30), Vector2(656, 42), 31)
	ui.subtitle_label = Controls.label(
		ui,
		"MAZE TD  /  PROTOTYPE 10",
		Vector2(32, 76),
		Vector2(656, 28),
		18,
		Color("a7b596"),
	)
	ui.status = Controls.label(ui, "", Vector2(32, 112), Vector2(656, 32), 22)
	ui.message = Controls.label(ui, "", Vector2(32, 150), Vector2(656, 30), 18, Color("ebcc84"))


## Crée la carte et les commandes pour choisir sa taille, déplacer la vue et zoomer.
## Les signaux du plateau appellent les actions de main.gd lorsqu'une case ou une unité est touchée.
static func create_map_controls(ui) -> void:
	ui.grid_choice = OptionButton.new()
	ui.grid_choice.position = Vector2(32, 188)
	ui.grid_choice.size = Vector2(296, 48)
	ui.grid_choice.add_theme_font_size_override("font_size", 18)

	for dimensions in ui.game.GRID_SIZES:
		ui.grid_choice.add_item("%d haut × %d long" % [dimensions.y, dimensions.x])
	ui.grid_choice.item_selected.connect(ui.change_grid)
	ui.add_child(ui.grid_choice)
	ui.board = preload("res://board.gd").new()
	ui.board.game = ui.game
	ui.board.position = Vector2(32, 248)
	ui.board.size = Vector2(656, 600)
	ui.board.cell_tapped.connect(ui.interact)
	ui.board.item_tapped.connect(ui.inspect_item)
	ui.board.item_hovered.connect(ui.hover_item)
	ui.board.view_dragged.connect(ui.close_inspection)
	ui.add_child(ui.board)
	ui.entry_button = Controls.button(ui, "Entrée", Vector2(340, 188), Vector2(108, 48), ui.board.entry_view)
	ui.castle_button = Controls.button(ui, "Château", Vector2(460, 188), Vector2(108, 48), ui.board.castle_view)
	ui.overview_button = Controls.button(ui, "Vue", Vector2(580, 188), Vector2(108, 48), ui.board.overview)
	ui.map_info = Controls.label(ui, "", Vector2(32, 860), Vector2(496, 40), 18, Color("c9c7ac"))
	ui.zoom_out_button = Controls.button(
		ui,
		"−",
		Vector2(544, 858),
		Vector2(64, 44),
		func(): ui.board.set_zoom(ui.board.zoom / 1.3, ui.board.size / 2),
	)
	ui.zoom_in_button = Controls.button(
		ui,
		"+",
		Vector2(624, 858),
		Vector2(64, 44),
		func(): ui.board.set_zoom(ui.board.zoom * 1.3, ui.board.size / 2),
	)
	ui.detail = Controls.label(ui, "", Vector2(32, 907), Vector2(656, 48), 18)


## Crée un bouton par type de tour, puis prépare les réactions au clic et au survol.
## Chaque bouton garde son propre index afin que tous ne finissent pas par sélectionner la dernière tour.
static func create_tower_catalog(ui) -> void:
	for i in range(ui.game.TYPES.size()):
		var index = i
		ui.type_buttons.append(Controls.button(
			ui,
			"%s\n%d or" % [ui.game.TYPES[i].name, ui.game.TYPES[i].cost],
			Vector2(32 + (i % 4) * 166, 963 + (i / 4) * 61),
			Vector2(158, 56),
			func(): ui.select_kind(index),
		))
		ui.type_buttons[i].mouse_entered.connect(func(): ui.preview_kind(index))
		ui.type_buttons[i].mouse_exited.connect(ui.hide_hover)


## Crée les actions de jeu : amélioration, vente, lancement, pause et vitesse.
## Les positions indiquées ici sont des valeurs de départ ; ui_layout.gd les adaptera à l'écran.
static func create_action_buttons(ui) -> void:
	ui.upgrade_button = Controls.button(
		ui,
		"Améliorer",
		Vector2(32, 1096),
		Vector2(320, 52),
		ui.upgrade_selected,
	)
	ui.sell_button = Controls.button(ui, "Vendre", Vector2(368, 1096), Vector2(320, 52), ui.sell_selected)
	ui.wave_button = Controls.button(ui, "", Vector2(32, 1162), Vector2(320, 60), ui.start_or_reset)
	ui.pause_button = Controls.button(ui, "Pause", Vector2(368, 1162), Vector2(154, 60), ui.toggle_pause)
	ui.speed_button = Controls.button(ui, "×1", Vector2(538, 1162), Vector2(150, 60), ui.toggle_speed)
	ui.footer_label = Controls.label(
		ui,
		"Toucher : bâtir / sélectionner  •  Glisser : déplacer la carte",
		Vector2(32, 1232),
		Vector2(656, 25),
		16,
		Color("a7b596"),
	)


## Crée la fiche d'informations après les autres contrôles pour la dessiner au-dessus du plateau.
## La fiche envoie des demandes de vente et d'amélioration ; main.gd les transmet aux règles du jeu.
static func create_inspector(ui) -> void:
	ui.inspector = preload("res://inspection.gd").new()
	ui.add_child(ui.inspector)
	ui.inspector.sell_requested.connect(ui.sell_tower)
	ui.inspector.upgrade_requested.connect(ui.upgrade_tower)
	ui.inspector.dismiss_requested.connect(ui.close_inspection)
