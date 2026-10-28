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
	grid_choice.add_theme_font_size_override("font_size", 20)
	grid_choice.add_theme_font_override("font", Controls.DISPLAY_FONT)
	var choice_style := style.duplicate() as StyleBoxFlat
	choice_style.bg_color = Color("#164b82")
	choice_style.set_corner_radius_all(12)
	choice_style.shadow_size = 0
	choice_style.border_width_bottom = 3
	grid_choice.add_theme_stylebox_override("normal", choice_style)
	grid_choice.add_theme_stylebox_override("hover", choice_style)
	grid_choice.add_theme_color_override("font_color", Color("#fff0c9"))

	for dimensions in preload("res://game.gd").GRID_SIZES:
		grid_choice.add_item("%d haut × %d long" % [dimensions.y, dimensions.x])
	card.add_child(grid_choice)

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


## Centre le menu dans l'espace logique fourni par ui_layout.gd, y compris après une rotation.
func arrange() -> void:
	if not is_instance_valid(card):
		return

	var width := minf(600.0, size.x - 48.0)
	card.size = Vector2(width, 650)
	card.position = (size - card.size) / 2.0

	var content := width - 80.0
	title.position = Vector2(28, 16)
	title.size = Vector2(width - 56, 136)
	hero.position = Vector2(width / 2.0 - 135, 152)
	hero.size = Vector2(270, 166)
	description.position = Vector2(32, 322)
	description.size = Vector2(width - 64, 52)
	description.add_theme_font_size_override("font_size", 17)
	grid_label.position = Vector2(40, 380)
	grid_label.size = Vector2(content, 24)
	grid_choice.position = Vector2(40, 414)
	grid_choice.size = Vector2(content, 52)
	start_button.position = Vector2(40, 488)
	start_button.size = Vector2(content, 66)
	options_button.position = Vector2(40, 568)
	options_button.size = Vector2(content, 46)
	footer.position = Vector2(24, 622)
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
