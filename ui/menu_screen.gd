extends Control
## Cet écran prépare une partie, sans faire avancer le temps du jeu.
## Il ne crée pas les règles : le signal start_requested transmet la taille choisie à main.gd.

signal start_requested(grid_index: int)

const Controls = preload("res://ui/control_factory.gd")
const PORTAL = preload("res://assets/terrain/portail_cartoon.png")
const TOWN = preload("res://assets/terrain/bourg_cartoon.png")

var card: Panel
var title: Label
var description: Label
var grid_label: Label
var grid_choice: OptionButton
var grid_hint: Label
var difficulty_label: Label
var difficulty_choice: OptionButton
var difficulty_hint: Label
var dev_wave_label: Label
var dev_wave: SpinBox
var dev_wave_less: Button
var dev_wave_more: Button
var grid_info_button: Button
var grid_info_panel: Panel
var grid_info_text: Label
var grid_info_pinned := false
var start_button: Button
var options_button: Button
var hero: TextureRect
var footer: Label
var backdrop: GradientTexture2D


## Construit le menu une fois. Options est volontairement présent sans action pour le moment.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	# Le dégradé est calculé une fois ; le fond reste doux quelle que soit la taille de l'écran.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#3388c6"), Color("#16396d")])
	backdrop = GradientTexture2D.new()
	backdrop.gradient = gradient
	backdrop.width = 2
	backdrop.height = 512
	backdrop.fill_from = Vector2.ZERO
	backdrop.fill_to = Vector2(0, 1)
	card = Panel.new()

	Controls.style_panel(card)
	var style := Controls.panel_style()
	add_child(card)

	title = Controls.label(card, "LES MARCHES\nDU ROYAUME", Vector2.ZERO, Vector2.ZERO, 36, Color("#f3dfaf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Controls.headline(title, 54, Color("#ffe184"))
	title.add_theme_color_override("font_shadow_color", Color("#071b2d"))
	title.add_theme_constant_override("shadow_offset_y", 4)
	hero = TextureRect.new()
	hero.texture = TOWN
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hero)
	description = Controls.label(
		card,
		"Votre royaume. Vos tours. Votre labyrinthe.\nRepoussez les monstres jusqu'à la dernière vague !",
		Vector2.ZERO,
		Vector2.ZERO,
		19,
		Color("#e5f4ff"),
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_label = Controls.label(card, "TAILLE DU TERRAIN", Vector2.ZERO, Vector2.ZERO, 15, Color("#bfa56b"))
	Controls.headline(grid_label, 15, Color("#fff1bf"))

	grid_choice = OptionButton.new()
	grid_choice.fit_to_longest_item = false
	grid_choice.add_theme_font_size_override("font_size", 23)
	grid_choice.add_theme_font_override("font", Controls.DISPLAY_FONT)
	var choice_style := style.duplicate() as StyleBoxFlat
	choice_style.bg_color = Color("#fff0c9")
	choice_style.border_color = Color("#102e50")
	choice_style.set_corner_radius_all(12)
	choice_style.shadow_size = 0
	choice_style.border_width_bottom = 3
	choice_style.content_margin_left = 20
	choice_style.content_margin_right = 40
	grid_choice.add_theme_stylebox_override("normal", choice_style)
	var choice_hover := choice_style.duplicate() as StyleBoxFlat
	choice_hover.bg_color = Color("#fff8e6")
	choice_hover.border_color = Color("#68c9f3")
	grid_choice.add_theme_stylebox_override("hover", choice_hover)
	grid_choice.add_theme_stylebox_override("pressed", choice_hover)
	grid_choice.add_theme_stylebox_override("focus", choice_hover)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		grid_choice.add_theme_color_override(state, Color("#16334d"))
	grid_choice.add_theme_color_override("arrow", Color("#16334d"))
	grid_choice.add_theme_constant_override("arrow_margin", 18)
	grid_choice.add_theme_constant_override("modulate_arrow", 1)
	grid_choice.focus_mode = Control.FOCUS_ALL

	for dimensions in preload("res://game.gd").GRID_SIZES:
		grid_choice.add_item("%d × %d" % [dimensions.y, dimensions.x])
	card.add_child(grid_choice)
	style_choice_popup(grid_choice)
	grid_choice.item_selected.connect(func(_index): update_grid_hint())
	grid_hint = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 15, Color("#e5f4ff"))
	grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_grid_information()
	create_difficulty_choice()
	create_developer_controls()

	start_button = Controls.button(
		card,
		"COMMENCER",
		Vector2.ZERO,
		Vector2.ZERO,
		func():
			# Valide aussi un nombre saisi au clavier sans avoir appuyé sur Entrée.
			dev_wave.apply()
			start_requested.emit(grid_choice.selected),
	)

	Controls.play_style(start_button)
	start_button.add_theme_font_size_override("font_size", 32)
	options_button = Controls.button(card, "OPTIONS", Vector2.ZERO, Vector2.ZERO, func(): pass)
	options_button.tooltip_text = "Les options seront ajoutées prochainement."
	footer = Controls.label(card, "8 TOURS  ·  100 VAGUES  ·  UN ROYAUME", Vector2.ZERO, Vector2.ZERO, 13, Color("#94b8bc"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Controls.headline(footer, 14, Color("#c2e2ff"))
	resized.connect(arrange)
	arrange()
	configure_grids(preload("res://progression.gd").new(), false)


## Le bouton d'aide fonctionne aussi au toucher, contrairement à une infobulle qui exige un survol.
## Un clic fixe l'explication ; un second clic ou un toucher ailleurs la ferme.
func create_grid_information() -> void:
	grid_info_button = Controls.button(card, "?", Vector2.ZERO, Vector2(44, 44), toggle_grid_information)
	grid_info_button.tooltip_text = "Pourquoi certaines grilles sont-elles verrouillées ?"
	grid_info_button.mouse_entered.connect(func(): grid_info_panel.show())
	grid_info_button.mouse_exited.connect(func():
		if not grid_info_pinned:
			grid_info_panel.hide()
	)
	grid_info_panel = Panel.new()
	grid_info_panel.z_index = 10
	grid_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	Controls.style_panel(grid_info_panel, true)
	add_child(grid_info_panel)
	var heading := Controls.label(grid_info_panel, "Débloquer les terrains", Vector2(18, 12), Vector2(480, 28), 20)
	Controls.headline(heading, 22, Controls.GOLD)
	grid_info_text = Controls.label(grid_info_panel, "", Vector2(18, 48), Vector2(480, 140), 17, Color("#e5f4ff"))
	grid_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_info_panel.hide()


## Fixe l'aide ouverte par survol, ou ferme celle qui était déjà fixée par un toucher.
func toggle_grid_information() -> void:
	grid_info_pinned = not grid_info_pinned
	grid_info_panel.visible = grid_info_pinned


## Ferme l'aide au toucher extérieur, sans empêcher le bouton visé de recevoir ce même toucher.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_instance_valid(grid_info_panel) or not grid_info_panel.visible:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if not grid_info_panel.get_global_rect().has_point(event.position) and not grid_info_button.get_global_rect().has_point(event.position):
			grid_info_pinned = false
			grid_info_panel.hide()


## Donne à la liste déroulante les mêmes couleurs et de grandes lignes lisibles au doigt.
func style_choice_popup(choice: OptionButton) -> void:
	var popup := choice.get_popup()
	var panel := Controls.panel_style(true)
	panel.bg_color = Color("#163e65")
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#2f7db6")
	hover.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_font_override("font", Controls.DISPLAY_FONT)
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_constant_override("v_separation", 24)
	popup.add_theme_color_override("font_color", Color("#fff0c9"))
	popup.add_theme_color_override("font_hover_color", Color("#ffffff"))
	popup.add_theme_color_override("font_disabled_color", Color("#92a9bd"))


## Prépare un second sélecteur à côté de la grille et explique immédiatement les effets du choix.
func create_difficulty_choice() -> void:
	difficulty_label = Controls.label(card, "DIFFICULTÉ", Vector2.ZERO, Vector2.ZERO, 15)
	Controls.headline(difficulty_label, 15, Color("#fff1bf"))
	difficulty_choice = OptionButton.new()
	difficulty_choice.fit_to_longest_item = false
	difficulty_choice.add_theme_font_override("font", Controls.DISPLAY_FONT)
	difficulty_choice.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		difficulty_choice.add_theme_stylebox_override(state, grid_choice.get_theme_stylebox(state))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "arrow"]:
		difficulty_choice.add_theme_color_override(state, grid_choice.get_theme_color(state))
	difficulty_choice.add_theme_constant_override("arrow_margin", 18)
	difficulty_choice.add_theme_constant_override("modulate_arrow", 1)
	for settings in preload("res://gameplay/difficulty.gd").PROFILES:
		difficulty_choice.add_item(settings.name)
		difficulty_choice.set_item_tooltip(difficulty_choice.item_count - 1, settings.description)
	difficulty_choice.select(1)
	card.add_child(difficulty_choice)
	style_choice_popup(difficulty_choice)
	difficulty_hint = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 15, Color("#ffe184"))
	difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_choice.item_selected.connect(func(_index): update_difficulty_hint())
	update_difficulty_hint()


## Les pourcentages affichés viennent du catalogue qui calcule réellement les PV et les revenus.
func update_difficulty_hint() -> void:
	var settings: Dictionary = preload("res://gameplay/difficulty.gd").profile(difficulty_choice.selected)
	difficulty_hint.text = "%s : %s" % [settings.name, settings.description]
	difficulty_choice.tooltip_text = settings.description


## Ce choix existe uniquement pour les essais : saisir une vague ou utiliser les boutons moins et plus.
## Les boutons gardent une surface tactile confortable ; le champ est borné entre 1 et 100.
func create_developer_controls() -> void:
	dev_wave_label = Controls.label(card, "VAGUE DE DÉPART", Vector2.ZERO, Vector2.ZERO, 17, Color("#ffe184"))
	dev_wave = SpinBox.new()
	dev_wave.min_value = 1
	dev_wave.max_value = 100
	dev_wave.step = 1
	dev_wave.value = 1
	dev_wave.tooltip_text = "Préparer directement cette vague, sans jouer les précédentes."
	card.add_child(dev_wave)
	var editor := dev_wave.get_line_edit()
	editor.add_theme_font_size_override("font_size", 21)
	editor.add_theme_color_override("font_color", Color("#16334d"))
	for state in ["normal", "focus"]:
		var input_style := grid_choice.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		input_style.content_margin_left = 12
		input_style.content_margin_right = 8
		editor.add_theme_stylebox_override(state, input_style)
	editor.alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor.add_theme_color_override("caret_color", Color("#16334d"))
	editor.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	dev_wave_less = Controls.button(card, "−", Vector2.ZERO, Vector2(44, 44), func(): dev_wave.value -= 1)
	dev_wave_more = Controls.button(card, "+", Vector2.ZERO, Vector2(44, 44), func(): dev_wave.value += 1)


## Actualise les verrous et leurs conditions, sans effacer un choix encore accessible.
## Les identifiants des grilles restent ceux du modèle, même si leur libellé change.
func configure_grids(progress, developer: bool) -> void:
	for control in [dev_wave_label, dev_wave, dev_wave_less, dev_wave_more]:
		control.visible = developer
	footer.text = "MODE DEV · CHÂTEAU INVULNÉRABLE" if developer else "8 TOURS  ·  100 VAGUES  ·  UN ROYAUME"
	grid_info_pinned = false
	grid_info_panel.hide()
	var explanations: Array[String] = []
	for index in range(grid_choice.item_count):
		var dimensions: Vector2i = preload("res://game.gd").GRID_SIZES[index]
		var unlocked: bool = progress.is_unlocked(index, developer)
		var label := "%d × %d" % [dimensions.y, dimensions.x]
		grid_choice.set_item_text(index, label if unlocked else label + " · Verrouillé")
		grid_choice.set_item_disabled(index, not unlocked)
		var requirement := "Toujours accessible"
		if index == 0:
			requirement = "Atteindre la vague 25 sur 25 × 50 · Record : %d/25" % progress.reached[1]
		elif index == 2:
			requirement = "Atteindre la vague 50 sur 50 × 100 · Record : %d/50" % progress.reached[0]
		grid_choice.set_item_tooltip(index, requirement)
		if index != 1:
			var state := "Accessible" if unlocked else "Verrouillée"
			var detail := requirement.replace(" · Record : ", "\nVotre record : ")
			if developer:
				detail = "Accessible en mode développeur, sans condition."
			explanations.append("%s — %s\n%s" % [label, state, detail])
	grid_info_text.text = "\n\n".join(explanations)
	if not progress.is_unlocked(grid_choice.selected, developer):
		grid_choice.select(1)
	grid_choice.set_meta("developer_mode", developer)
	var next_unlock := "50 × 100 : vague %d/25 sur 25 × 50" % mini(progress.reached[1], 25)
	if progress.is_unlocked(0):
		next_unlock = "100 × 200 : vague %d/50 sur 50 × 100" % mini(progress.reached[0], 50)
	grid_choice.set_meta("next_unlock", next_unlock)
	grid_choice.set_meta("all_unlocked", progress.is_unlocked(2))
	update_grid_hint()
	arrange()


## Explique le prochain objectif sous le champ, sans exiger un survol indisponible sur téléphone.
func update_grid_hint() -> void:
	if bool(grid_choice.get_meta("developer_mode", false)):
		grid_hint.text = "MODE DÉVELOPPEUR · Toutes les grilles accessibles"
	elif bool(grid_choice.get_meta("all_unlocked", false)):
		grid_hint.text = "Toutes les grilles sont débloquées · Hauteur × longueur"
	else:
		grid_hint.text = "Débloquer " + str(grid_choice.get_meta("next_unlock", ""))


## Centre le menu dans l'espace logique fourni par ui_layout.gd, y compris après une rotation.
func arrange() -> void:
	if not is_instance_valid(card):
		return

	var width := minf(600.0, size.x - 48.0)
	card.size = Vector2(width, 688)
	card.position = (size - card.size) / 2.0

	var content := width - 80.0
	var column := (content - 16.0) / 2.0
	title.position = Vector2(28, 16)
	title.size = Vector2(width - 56, 136)
	hero.position = Vector2(width / 2.0 - 135, 146)
	hero.size = Vector2(270, 94 if dev_wave.visible else 140)
	dev_wave_label.position = Vector2(40, 242)
	dev_wave_label.size = Vector2(content - 300, 44)
	dev_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dev_wave_less.position = Vector2(width - 320, 242)
	dev_wave.position = Vector2(width - 270, 242)
	dev_wave.size = Vector2(180, 44)
	dev_wave_more.position = Vector2(width - 84, 242)
	description.position = Vector2(32, 286)
	description.size = Vector2(width - 64, 52)
	description.add_theme_font_size_override("font_size", 17)
	grid_label.position = Vector2(40, 350)
	grid_label.size = Vector2(column - 48, 24)
	grid_info_button.position = Vector2(40 + column - 44, 338)
	grid_info_button.size = Vector2(44, 44)
	grid_info_panel.position = card.position + Vector2(40, 60)
	grid_info_panel.size = Vector2(content, 270)
	grid_info_text.size = Vector2(content - 36, 206)
	grid_choice.position = Vector2(40, 390)
	grid_choice.size = Vector2(column, 58)
	difficulty_label.position = Vector2(56 + column, 350)
	difficulty_label.size = Vector2(column, 24)
	difficulty_choice.position = Vector2(56 + column, 390)
	difficulty_choice.size = Vector2(column, 58)
	grid_hint.position = Vector2(42, 454)
	grid_hint.size = Vector2(content - 4, 24)
	difficulty_hint.position = Vector2(42, 480)
	difficulty_hint.size = Vector2(content - 4, 40)
	start_button.position = Vector2(40, 526)
	start_button.size = Vector2(content, 62)
	options_button.position = Vector2(40, 600)
	options_button.size = Vector2(content, 46)
	footer.position = Vector2(24, 654)
	footer.size = Vector2(width - 48, 20)
	queue_redraw()


## Réutilise les illustrations du jeu comme décor du menu, sans déplacer la carte de la partie.
func _draw() -> void:
	# Un fond calme à grands losanges met les titres et les boutons en avant sur petit écran.
	if backdrop != null:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, size), false)
	for y in range(-1, ceili(size.y / 144.0) + 1):
		for x in range(-1, ceili(size.x / 144.0) + 1):
			var center := Vector2(x * 144 + (y % 2) * 72, y * 144)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -68), center + Vector2(68, 0),
				center + Vector2(0, 68), center + Vector2(-68, 0),
			]), Color("#75c5ed13"))
	if size.x > size.y:
		draw_texture_rect(PORTAL, Rect2(Vector2(22, size.y * 0.35), Vector2(290, 265)), false)
		draw_texture_rect(TOWN, Rect2(Vector2(size.x - 338, size.y * 0.38), Vector2(320, 213)), false)
