extends RefCounted
## Ces fonctions créent les textes et les boutons avec une apparence commune.
## parent est le nœud auquel le contrôle sera ajouté. Le contrôle renvoyé reste modifiable ensuite.
## Elles ne décident ni du prix des tours ni du déroulement du combat.

const DISPLAY_FONT = preload("res://assets/polices/LilitaOne-Regular.ttf")
const TOWER_COLORS := [
	Color("#328a52"), Color("#ae6535"), Color("#7650ad"), Color("#a7439c"),
	Color("#397cb1"), Color("#258dba"), Color("#a56c36"), Color("#669439"),
]


## Réserve la police épaisse aux titres et aux commandes ; les descriptions gardent leur police de lecture.
static func headline(item: Label, font_size: int, color := Color("#fff5d7")) -> void:
	item.add_theme_font_override("font", DISPLAY_FONT)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color("#153047"))
	item.add_theme_constant_override("outline_size", 4)
	item.add_theme_color_override("font_shadow_color", Color("#0b203a"))
	item.add_theme_constant_override("shadow_offset_y", 3)


## Crée un texte et le renvoie pour pouvoir changer son contenu plus tard.
## pos et dimensions indiquent sa place et sa taille dans l'interface.
## Le texte laisse passer les clics : il ne doit pas empêcher de toucher le plateau en dessous.
static func label(
	parent,
	text_value: String,
	pos: Vector2,
	dimensions: Vector2,
	font_size: int,
	color := Color("#e9e1c8"),
) -> Label:
	var item := Label.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.clip_text = true
	parent.add_child(item)
	return item


## Crée un bouton, applique ses trois apparences et le relie à l'action demandée.
## action est une fonction à exécuter quand le bouton sera pressé ; connect prépare ce lien sans l'exécuter.
## Le bouton renvoyé pourra ensuite être déplacé ou désactivé par l'interface.
static func button(parent, text_value: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", 19)
	item.add_theme_font_override("font", DISPLAY_FONT)
	item.add_theme_color_override("font_outline_color", Color("#16334d"))
	item.add_theme_constant_override("outline_size", 3)
	item.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#347fbd")
	normal.border_color = Color("#133552")
	normal.set_border_width_all(3)
	normal.border_width_bottom = 7
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color("#04192780")
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	item.add_theme_color_override("font_color", Color("#fff0c9"))
	item.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#4899d5")
	hover.border_color = Color("#9edcfc")
	item.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#24679f")
	pressed.border_color = Color("#153047")
	pressed.border_width_bottom = 2
	item.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#293e48")
	disabled.border_color = Color("#52616a")
	item.add_theme_stylebox_override("disabled", disabled)

	# On enregistre la fonction à appeler plus tard. Connecter le bouton n'exécute pas immédiatement l'action.
	item.pressed.connect(action)
	parent.add_child(item)
	return item


## Le bouton d'action principal ressemble à une pièce de bois dorée, avec un bord inférieur en relief.
static func primary_style(item: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#ffc548")
	normal.border_color = Color("#7b4823")
	normal.set_border_width_all(3)
	normal.border_width_bottom = 8
	normal.set_corner_radius_all(14)
	normal.shadow_color = Color("#071b2880")
	normal.shadow_size = 7
	normal.shadow_offset = Vector2(0, 3)
	item.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#ffdf75")
	item.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#eaaa2c")
	pressed.border_width_bottom = 2
	item.add_theme_stylebox_override("pressed", pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		item.add_theme_color_override(state, Color("#fff7dc"))
	item.add_theme_color_override("font_outline_color", Color("#805027"))
	item.add_theme_font_size_override("font_size", 19)


## Les cartes de tours associent une illustration à une surface claire, lisible sur téléphone.
## Le style est reconstruit seulement quand la sélection change, pas à chaque actualisation du HUD.
static func catalog_style(item: Button, selected: bool) -> void:
	if item.has_meta("catalog_selected") and bool(item.get_meta("catalog_selected")) == selected:
		return
	item.set_meta("catalog_selected", selected)
	var normal := StyleBoxFlat.new()
	var kind: int = clampi(int(item.get_meta("tower_kind", 0)), 0, 7)
	var color: Color = TOWER_COLORS[kind]
	normal.bg_color = color.lightened(0.10) if selected else color
	normal.border_color = Color("#ffe080") if selected else Color("#18334c")
	normal.set_border_width_all(3)
	normal.border_width_bottom = 7
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 7
	normal.content_margin_right = 7
	normal.shadow_color = Color("#061c2870")
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	item.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.16)
	hover.border_color = Color("#ffe080")
	item.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	pressed.border_width_bottom = 2
	item.add_theme_stylebox_override("pressed", pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		item.add_theme_color_override(state, Color("#fff7e1"))
	item.add_theme_color_override("font_outline_color", Color("#1a2c3b"))
	item.add_theme_constant_override("outline_size", 3)


## Le bouton du menu utilise un grand volume vert, distinct des commandes secondaires bleues.
static func play_style(item: Button) -> void:
	primary_style(item)
	var normal: StyleBoxFlat = item.get_theme_stylebox("normal").duplicate()
	normal.bg_color = Color("#76cd40")
	normal.border_color = Color("#2d6b2c")
	item.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#99e361")
	item.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#5bb530")
	pressed.border_width_bottom = 3
	item.add_theme_stylebox_override("pressed", pressed)
	item.add_theme_color_override("font_outline_color", Color("#2d5c26"))
