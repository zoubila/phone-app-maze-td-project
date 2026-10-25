extends Control
## Cet écran prépare une partie, sans faire avancer le temps du jeu.
## Il ne crée pas les règles : le signal start_requested transmet la taille choisie à main.gd.

signal start_requested(grid_index: int)

const Controls = preload("res://ui/control_factory.gd")
const FOREST = preload("res://assets/terrain/foret.png")
const CAVE = preload("res://assets/terrain/caverne.png")
const CASTLE = preload("res://assets/terrain/chateau.png")

var card: Panel
var title: Label
var description: Label
var grid_label: Label
var grid_choice: OptionButton
var start_button: Button
var options_button: Button


## Construit le menu une fois. Options est volontairement présent sans action pour le moment.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	card = Panel.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f19f5")
	style.border_color = Color("bfa56b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color("00000088")
	style.shadow_size = 28
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	title = Controls.label(card, "LES MARCHES\nDU ROYAUME", Vector2.ZERO, Vector2.ZERO, 36, Color("f3dfaf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description = Controls.label(
		card,
		"Bâtissez votre labyrinthe et défendez le royaume contre 100 vagues de monstres.",
		Vector2.ZERO,
		Vector2.ZERO,
		19,
		Color("bdc8b1"),
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_label = Controls.label(card, "TAILLE DU TERRAIN", Vector2.ZERO, Vector2.ZERO, 15, Color("bfa56b"))

	grid_choice = OptionButton.new()
	grid_choice.add_theme_font_size_override("font_size", 20)

	for dimensions in preload("res://game.gd").GRID_SIZES:
		grid_choice.add_item("%d haut × %d long" % [dimensions.y, dimensions.x])
	card.add_child(grid_choice)

	start_button = Controls.button(
		card,
		"Commencer la partie",
		Vector2.ZERO,
		Vector2.ZERO,
		func(): start_requested.emit(grid_choice.selected),
	)

	var primary := style.duplicate() as StyleBoxFlat
	primary.bg_color = Color("bfa56b")
	primary.set_corner_radius_all(8)
	primary.shadow_size = 0
	start_button.add_theme_stylebox_override("normal", primary)

	var hover := primary.duplicate() as StyleBoxFlat
	hover.bg_color = Color("ddc58e")
	start_button.add_theme_stylebox_override("hover", hover)

	var pressed := primary.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("a88b52")
	start_button.add_theme_stylebox_override("pressed", pressed)
	start_button.add_theme_color_override("font_color", Color("15231b"))
	start_button.add_theme_color_override("font_hover_color", Color("15231b"))
	start_button.add_theme_color_override("font_pressed_color", Color("15231b"))
	start_button.add_theme_font_size_override("font_size", 22)
	options_button = Controls.button(card, "Options", Vector2.ZERO, Vector2.ZERO, func(): pass)
	options_button.tooltip_text = "Les options seront ajoutées prochainement."
	resized.connect(arrange)
	arrange()


## Centre le menu dans l'espace logique fourni par ui_layout.gd, y compris après une rotation.
func arrange() -> void:
	if not is_instance_valid(card):
		return

	var width := minf(600.0, size.x - 48.0)
	card.size = Vector2(width, 548)
	card.position = (size - card.size) / 2.0

	var content := width - 80.0
	title.position = Vector2(40, 28)
	title.size = Vector2(content, 108)
	description.position = Vector2(48, 152)
	description.size = Vector2(width - 96, 64)
	grid_label.position = Vector2(40, 246)
	grid_label.size = Vector2(content, 24)
	grid_choice.position = Vector2(40, 280)
	grid_choice.size = Vector2(content, 52)
	start_button.position = Vector2(40, 364)
	start_button.size = Vector2(content, 60)
	options_button.position = Vector2(40, 442)
	options_button.size = Vector2(content, 50)
	queue_redraw()


## Réutilise les illustrations du jeu comme décor du menu, sans déplacer la carte de la partie.
func _draw() -> void:
	draw_texture_rect(FOREST, Rect2(Vector2.ZERO, size), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("07130ec7"))
	draw_texture_rect(CAVE, Rect2(Vector2(12, size.y - 245), Vector2(330, 220)), false, Color(1, 1, 1, 0.58))
	draw_texture_rect(
		CASTLE,
		Rect2(Vector2(size.x - 310, size.y - 320), Vector2(300, 300)),
		false,
		Color(1, 1, 1, 0.7),
	)
