extends Panel
## Ce panneau couvre seulement le plateau à la fin de la partie.
## Il bloque les constructions derrière lui et propose de rejouer ou de revenir à l'accueil.

signal replay_requested
signal home_requested

const Controls = preload("res://ui/control_factory.gd")

var card: Panel
var title: Label
var description: Label
var replay_button: Button
var home_button: Button


## Prépare le panneau, qui restera caché tant que la partie n'est ni gagnée ni perdue.
func _ready() -> void:
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP

	var veil := StyleBoxFlat.new()
	veil.bg_color = Color("#09150dd9")
	add_theme_stylebox_override("panel", veil)
	card = Panel.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18291ff5")
	style.border_color = Color("#bfa56b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	title = Controls.label(card, "", Vector2(24, 24), Vector2(392, 54), 34, Color("#f3dfaf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description = Controls.label(card, "", Vector2(24, 90), Vector2(392, 56), 19)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	replay_button = Controls.button(
		card,
		"Rejouer",
		Vector2(64, 174),
		Vector2(312, 56),
		func(): replay_requested.emit(),
	)
	home_button = Controls.button(
		card, "Retour accueil", Vector2(64, 242), Vector2(312, 56),
		func(): home_requested.emit(),
	)
	resized.connect(arrange)
	arrange()
	hide()


## Garde le résultat et son bouton au milieu du plateau, même si le téléphone est tourné après la défaite.
func arrange() -> void:
	if is_instance_valid(card):
		card.size = Vector2(440, 326)
		card.position = (size - card.size) / 2.0


## Met à jour le texte sans remettre à zéro la partie ; seul un clic sur Rejouer le fera.
func refresh(game) -> void:
	visible = game.ended

	if not visible:
		return
	title.text = "Victoire !" if game.won else "Défaite"
	description.text = "Les 100 vagues ont été repoussées." if game.won else "Le château est tombé à la vague %d." % game.wave
