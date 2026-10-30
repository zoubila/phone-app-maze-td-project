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

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2369a9")
	style.border_color = Color("#102e50")
	style.set_border_width_all(4)
	style.border_width_bottom = 10
	style.set_corner_radius_all(26)
	style.shadow_color = Color("#031727b0")
	style.shadow_size = 24
	card.add_theme_stylebox_override("panel", style)
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
	style_grid_popup()
	grid_choice.item_selected.connect(func(_index): update_grid_hint())
	grid_hint = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 15, Color("#e5f4ff"))
	grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_grid_information()

	start_button = Controls.button(
		card,
		"COMMENCER",
		Vector2.ZERO,
		Vector2.ZERO,
		func(): start_requested.emit(grid_choice.selected),
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102e50fa")
	style.border_color = Color("#81cef4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color("#03172790")
	style.shadow_size = 10
	grid_info_panel.add_theme_stylebox_override("panel", style)
	add_child(grid_info_panel)
	Controls.label(grid_info_panel, "Débloquer les terrains", Vector2(18, 12), Vector2(480, 28), 20, Color("#ffe184"))
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
func style_grid_popup() -> void:
	var popup := grid_choice.get_popup()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#163e65")
	panel.border_color = Color("#81cef4")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
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


## Actualise les verrous et leurs conditions, sans effacer un choix encore accessible.
## Les identifiants des grilles restent ceux du modèle, même si leur libellé change.
func configure_grids(progress, developer: bool) -> void:
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
	title.position = Vector2(28, 16)
	title.size = Vector2(width - 56, 136)
	hero.position = Vector2(width / 2.0 - 135, 146)
	hero.size = Vector2(270, 140)
	description.position = Vector2(32, 286)
	description.size = Vector2(width - 64, 52)
	description.add_theme_font_size_override("font_size", 17)
	grid_label.position = Vector2(40, 346)
	grid_label.size = Vector2(content, 24)
	grid_info_button.position = Vector2(width - 84, 332)
	grid_info_button.size = Vector2(44, 44)
	grid_info_panel.position = card.position + Vector2(40, 60)
	grid_info_panel.size = Vector2(content, 270)
	grid_info_text.size = Vector2(content - 36, 206)
	grid_choice.position = Vector2(40, 380)
	grid_choice.size = Vector2(content, 58)
	grid_hint.position = Vector2(42, 444)
	grid_hint.size = Vector2(content - 4, 40)
	start_button.position = Vector2(40, 494)
	start_button.size = Vector2(content, 66)
	options_button.position = Vector2(40, 574)
	options_button.size = Vector2(content, 46)
	footer.position = Vector2(24, 642)
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
