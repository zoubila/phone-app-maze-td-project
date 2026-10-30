extends RefCounted
## Assemble les écrans et les commandes une seule fois. Le plateau est créé avant ses commandes flottantes.
## Le catalogue ne contient que les huit tours ; le menu et le résultat sont des écrans séparés.

const Controls = preload("res://ui/control_factory.gd")
const Art = preload("res://rendering/unit_art.gd")


## Prépare le plateau, le catalogue, les informations flottantes, les fiches et les deux écrans.
static func create(ui) -> void:
	ui.board = preload("res://board.gd").new()
	ui.board.game = ui.game
	ui.board.size = Vector2(1000, 696)
	ui.board.cell_tapped.connect(ui.interact)
	ui.board.item_tapped.connect(ui.inspect_item)
	ui.board.item_hovered.connect(ui.hover_item)
	ui.board.view_dragged.connect(ui.close_inspection)
	ui.add_child(ui.board)
	create_tower_catalog(ui)
	create_overlay_controls(ui)
	create_screens(ui)


## Le panneau de construction reste limité aux huit types, avec un prix visible et une fiche au survol/toucher.
static func create_tower_catalog(ui) -> void:
	for kind in range(ui.game.TYPES.size()):
		var index = kind
		var button: Button = Controls.button(
			ui, "%s\n%d or" % [ui.game.TYPES[kind].name, ui.game.TYPES[kind].cost],
			Vector2.ZERO, Vector2(144, 72), func(): ui.select_kind(index)
		)
		button.mouse_entered.connect(func(): ui.preview_kind(index))
		button.set_meta("tower_kind", kind)
		button.icon = Art.tower_icon(kind)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 48)
		button.add_theme_constant_override("h_separation", 5)
		button.add_theme_font_size_override("font_size", 19)
		Controls.catalog_style(button, false)
		button.mouse_exited.connect(ui.hide_hover)
		ui.type_buttons.append(button)


## Pose les ressources et les commandes sur la carte, sans réserver une grande zone au-dessus d'elle.
## La transparence concerne le fond des boutons : le texte reste opaque pour conserver sa lisibilité.
static func create_overlay_controls(ui) -> void:
	ui.hud_panel = Panel.new()
	ui.hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := Controls.panel_style(true)
	background.bg_color = Color("#164b82c7")
	background.shadow_size = 3
	background.border_width_bottom = 4
	ui.hud_panel.add_theme_stylebox_override("panel", background)
	ui.add_child(ui.hud_panel)
	ui.status = Controls.label(ui, "", Vector2.ZERO, Vector2.ZERO, 20)
	ui.message = Controls.label(ui, "", Vector2.ZERO, Vector2.ZERO, 17, Color("#ebd5a2"))
	ui.message.add_theme_constant_override("outline_size", 4)
	ui.message.add_theme_color_override("font_outline_color", Color("#07130ed9"))
	ui.pause_button = Controls.button(ui, "Pause", Vector2.ZERO, Vector2(100, 44), ui.toggle_pause)
	ui.speed_button = Controls.button(ui, "Vitesse ×1", Vector2.ZERO, Vector2(120, 44), ui.toggle_speed)
	ui.settings_button = Controls.button(ui, "⚙", Vector2.ZERO, Vector2(44, 44), ui.open_settings)
	ui.settings_button.add_theme_font_size_override("font_size", 28)
	ui.settings_button.tooltip_text = "Paramètres"
	ui.wave_button = Controls.button(ui, "", Vector2.ZERO, Vector2(272, 44), ui.launch_wave)
	ui.preparation_hint = Controls.label(ui, "", Vector2.ZERO, Vector2.ZERO, 15, Color("#fff0c4"))
	ui.preparation_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.preparation_hint.add_theme_constant_override("outline_size", 4)
	ui.preparation_hint.add_theme_color_override("font_outline_color", Color("#102f3ee0"))

	for button in [ui.pause_button, ui.speed_button, ui.settings_button]:
		Controls.floating_style(button)
	Controls.play_style(ui.wave_button)


## Les fiches gèrent seules la vente et l'amélioration. La fin de partie reçoit son propre bouton Rejouer.
static func create_screens(ui) -> void:
	ui.wave_feedback = preload("res://ui/wave_feedback.gd").new()
	ui.add_child(ui.wave_feedback)
	ui.inspector = preload("res://inspection.gd").new()
	ui.add_child(ui.inspector)
	ui.inspector.sell_requested.connect(ui.sell_tower)
	ui.inspector.upgrade_requested.connect(ui.upgrade_tower)
	ui.inspector.dismiss_requested.connect(ui.close_inspection)

	ui.end_screen = preload("res://ui/end_screen.gd").new()
	ui.add_child(ui.end_screen)
	ui.end_screen.replay_requested.connect(ui.restart_game)
	ui.end_screen.home_requested.connect(ui.return_home)

	ui.settings_screen = preload("res://ui/settings_screen.gd").new()
	ui.add_child(ui.settings_screen)
	ui.settings_screen.home_requested.connect(ui.return_home)

	ui.menu_screen = preload("res://ui/menu_screen.gd").new()
	ui.add_child(ui.menu_screen)
	ui.menu_screen.start_requested.connect(ui.start_game)
