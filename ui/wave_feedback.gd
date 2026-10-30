extends Control
## Célébration et annonce des vagues, en secondes réelles et sans bloquer les commandes.
## Le modèle déclenche l'événement ; ce contrôle ne verse pas d'or et ne change aucun ennemi.

const Controls = preload("res://ui/control_factory.gd")
var card: Panel
var heading: Label
var reward: Label
var detail: Label
var decoration: Control
var age := 0.0
var duration := 3.8
var celebrating := true
var displayed_wave := 0


## La médaille et les étincelles sont des enfants du panneau, comme les textes.
## Elles héritent ainsi exactement de son zoom, de sa transparence et de sa visibilité.
class Decoration extends Control:
	var feedback

	## Godot redessine les ornements dans les coordonnées locales du panneau animé.
	func _draw() -> void:
		feedback.paint_decoration(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 18
	card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Controls.style_panel(card, true)
	add_child(card)
	decoration = Decoration.new()
	decoration.feedback = self
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(decoration)
	heading = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 28, Color("#fff1b9"))
	Controls.headline(heading, 28, Color("#fff1b9"))
	heading.add_theme_color_override("font_shadow_color", Color("#071b2d"))
	heading.add_theme_constant_override("shadow_offset_y", 3)
	reward = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 23, Color("#ffe398"))
	detail = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 17, Controls.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(arrange)
	clear()


## Affiche le bonus réellement versé et la composition de la prochaine vague.
func show_repelled(number: int, bonus: int, plan: Dictionary) -> void:
	celebrating = true
	displayed_wave = number
	age = 0.0
	duration = 3.8
	heading.text = "VAGUE %d REPOUSSÉE !" % number
	reward.text = "+%d or  ·  Le royaume tient bon !" % bonus
	var threat := "ennemis résistants au physique" if plan.armor == "physical" else "ennemis résistants à la magie"
	if plan.air:
		threat = "unités volantes et terrestres"
	if plan.boss > 0:
		threat += " + un boss"
	detail.text = "Préparez la vague %d : %s." % [number + 1, threat]
	start_animation()


## Annonce également le départ, pour relier la préparation à l'action.
func show_incoming(number: int) -> void:
	celebrating = false
	displayed_wave = number
	age = 0.0
	duration = 1.8
	heading.text = "LA VAGUE %d ARRIVE !" % number
	reward.text = "Aux remparts !"
	detail.text = "Vos tours défendent le royaume."
	start_animation()


## Prépare l'état invisible AVANT d'afficher le groupe, pour ne pas réutiliser une image de l'annonce précédente.
func start_animation() -> void:
	arrange()
	update_animation()
	show()
	set_process(true)


## Efface une animation lors d'un retour au menu ou d'une nouvelle partie.
func clear() -> void:
	hide()
	set_process(false)
	displayed_wave = 0
	age = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * 0.82
	decoration.queue_redraw()


## Conserve un bandeau compact au-dessus du plateau, aussi en portrait.
func arrange() -> void:
	if not is_instance_valid(card):
		return
	var width := minf(600.0, size.x - 40.0)
	card.size = Vector2(width, 166)
	decoration.size = card.size
	card.pivot_offset = card.size / 2.0
	card.position = Vector2((size.x - width) / 2.0, maxf(84.0, size.y * 0.14))
	heading.position = Vector2(86, 18)
	heading.size = Vector2(width - 106, 40)
	heading.add_theme_font_size_override("font_size", 25 if width < 550 else 28)
	reward.position = Vector2(86, 62)
	reward.size = Vector2(width - 106, 32)
	reward.add_theme_font_size_override("font_size", 19 if width < 550 else 23)
	detail.position = Vector2(24, 108)
	detail.size = Vector2(width - 48, 46)


## Une entrée élastique, puis un fondu court : la fête ne retarde jamais la vague suivante.
func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		clear()
		return
	update_animation()


## Anime uniquement le panneau parent : fond, étoile, étincelles et textes suivent un seul état visuel.
func update_animation() -> void:
	var entrance := clampf(age / 0.38, 0.0, 1.0)
	var pop := 1.0 + sin(entrance * PI) * 0.055
	card.scale = Vector2.ONE * lerpf(0.82, pop, entrance)
	card.modulate.a = minf(clampf(age / 0.16, 0.0, 1.0), clampf((duration - age) / 0.45, 0.0, 1.0))
	decoration.queue_redraw()


## Dessine médaille, étoile et pluie d'étincelles sans textures ni particules physiques.
func paint_decoration(canvas: Control) -> void:
	if not visible or not is_instance_valid(card):
		return
	var center := Vector2(46, 54)
	canvas.draw_circle(center + Vector2(0, 4), 33, Color("#724e31"))
	canvas.draw_circle(center, 33, Color("#f1c05e"))
	canvas.draw_circle(center - Vector2(0, 2), 26, Color("#ffe59a"))
	draw_star(canvas, center, 19.0, Color("#aa6a30"))
	if not celebrating:
		return
	var colors := [Color("#ffe49a"), Color("#78dac0"), Color("#e3abf4"), Color("#fff6d9")]
	for index in range(32):
		var angle := float(index) * 2.39996
		var speed := 55.0 + float(index % 7) * 14.0
		# Les étincelles partent des bords, pour ne pas brouiller le titre et les informations utiles.
		var side := -1.0 if index % 2 == 0 else 1.0
		var origin := Vector2(18 if side < 0 else card.size.x - 18, 62)
		var point := origin + Vector2(side * absf(cos(angle)), sin(angle)) * speed * age
		point.y += 36.0 * age * age
		var radius := (3.0 + float(index % 3)) * clampf((duration - age) / 1.4, 0.0, 1.0)
		draw_star(canvas, point, radius, colors[index % colors.size()])


## Dessine une étoile sur le contrôle enfant, pour qu'elle partage les transformations du panneau.
func draw_star(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	if radius < 0.5:
		return
	var points := PackedVector2Array()
	for index in range(10):
		var angle := -PI / 2.0 + float(index) * TAU / 10.0
		var length := radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	canvas.draw_colored_polygon(points, color)
