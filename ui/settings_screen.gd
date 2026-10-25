extends Panel
## Fenêtre des paramètres en cours de partie. Son voile bloque les commandes situées derrière elle.
## Le temps est suspendu tant qu'elle est ouverte, sans modifier la pause choisie par le joueur.

signal home_requested

const Controls = preload("res://ui/control_factory.gd")

var card: Panel
var options_button: Button
var home_button: Button
var close_button: Button


## Crée la fenêtre et ses commandes. Options reste volontairement sans effet pour le moment.
func _ready() -> void:
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := StyleBoxFlat.new()
	veil.bg_color = Color("09150dd9")
	add_theme_stylebox_override("panel", veil)

	card = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18291ff5")
	style.border_color = Color("bfa56b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	Controls.label(card, "Paramètres", Vector2(28, 22), Vector2(320, 50), 30, Color("f3dfaf"))
	close_button = Controls.button(card, "×", Vector2(370, 22), Vector2(44, 44), hide)
	close_button.tooltip_text = "Fermer les paramètres"
	options_button = Controls.button(card, "Options", Vector2(64, 106), Vector2(312, 56), func(): pass)
	options_button.tooltip_text = "Les options seront ajoutées prochainement."
	home_button = Controls.button(
		card, "Retour accueil", Vector2(64, 180), Vector2(312, 56),
		func(): home_requested.emit(),
	)
	resized.connect(arrange)
	arrange()
	hide()


## Centre les commandes dans la zone sûre, y compris après une rotation du téléphone.
func arrange() -> void:
	if is_instance_valid(card):
		card.size = Vector2(440, 268)
		card.position = (size - card.size) / 2.0
