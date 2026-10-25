extends RefCounted
## Ces fonctions créent les textes et les boutons avec une apparence commune.
## parent est le nœud auquel le contrôle sera ajouté. Le contrôle renvoyé reste modifiable ensuite.
## Elles ne décident ni du prix des tours ni du déroulement du combat.


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
	item.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#24372a")
	normal.border_color = Color("#60704c")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	item.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#374d35")
	item.add_theme_stylebox_override("hover", hover)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#1a281e")
	disabled.border_color = Color("#394434")
	item.add_theme_stylebox_override("disabled", disabled)

	# On enregistre la fonction à appeler plus tard. Connecter le bouton n'exécute pas immédiatement l'action.
	item.pressed.connect(action)
	parent.add_child(item)
	return item
