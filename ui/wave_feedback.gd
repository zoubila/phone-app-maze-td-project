extends Control
## Célébration et annonce des vagues, en secondes réelles et sans bloquer les commandes.
## Le modèle déclenche l'événement ; ce contrôle ne verse pas d'or et ne change aucun ennemi.

const Controls = preload("res://ui/control_factory.gd")
var card: Panel
var heading: Label
var reward: Label
var detail: Label
var age := 0.0
var duration := 3.8
var celebrating := true
var displayed_wave := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 18
	card = Panel.new()
	card.z_index = -1
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#153d4af5")
	style.border_color = Color("#f4ca6a")
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(0)
	style.shadow_color = Color("#061a2aa0")
	style.shadow_size = 18
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	heading = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 28, Color("#fff1b9"))
	Controls.headline(heading, 28, Color("#fff1b9"))
	heading.add_theme_color_override("font_shadow_color", Color("#071b2d"))
	heading.add_theme_constant_override("shadow_offset_y", 3)
	reward = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 23, Color("#ffe398"))
	detail = Controls.label(card, "", Vector2.ZERO, Vector2.ZERO, 17, Color("#cee9de"))
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
	show()
	set_process(true)
	arrange()


## Annonce également le départ, pour relier la préparation à l'action.
func show_incoming(number: int) -> void:
	celebrating = false
	displayed_wave = number
	age = 0.0
	duration = 1.8
	heading.text = "LA VAGUE %d ARRIVE !" % number
	reward.text = "Aux remparts !"
	detail.text = "Vos tours défendent le royaume."
	show()
	set_process(true)
	arrange()


## Efface une animation lors d'un retour au menu ou d'une nouvelle partie.
func clear() -> void:
	hide()
	set_process(false)
	displayed_wave = 0
	modulate.a = 1.0


## Conserve un bandeau compact au-dessus du plateau, aussi en portrait.
func arrange() -> void:
	if not is_instance_valid(card):
		return
	var width := minf(600.0, size.x - 40.0)
	card.size = Vector2(width, 166)
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
	var entrance := clampf(age / 0.38, 0.0, 1.0)
	var pop := 1.0 + sin(entrance * PI) * 0.055
	card.scale = Vector2.ONE * lerpf(0.82, pop, entrance)
	modulate.a = minf(clampf(age / 0.16, 0.0, 1.0), clampf((duration - age) / 0.45, 0.0, 1.0))
	queue_redraw()
	card.queue_redraw()
	if age >= duration:
		clear()


## Dessine médaille, étoile et pluie d'étincelles sans textures ni particules physiques.
func _draw() -> void:
	if not visible or not is_instance_valid(card):
		return
	var center := card.position + Vector2(46, 54)
	draw_circle(center + Vector2(0, 4), 33, Color("#724e31"))
	draw_circle(center, 33, Color("#f1c05e"))
	draw_circle(center - Vector2(0, 2), 26, Color("#ffe59a"))
	draw_star(center, 19.0, Color("#aa6a30"))
	if not celebrating:
		return
	var colors := [Color("#ffe49a"), Color("#78dac0"), Color("#e3abf4"), Color("#fff6d9")]
	for index in range(32):
		var angle := float(index) * 2.39996
		var speed := 55.0 + float(index % 7) * 14.0
		# Les étincelles partent des bords, pour ne pas brouiller le titre et les informations utiles.
		var side := -1.0 if index % 2 == 0 else 1.0
		var origin := card.position + Vector2(18 if side < 0 else card.size.x - 18, 62)
		var point := origin + Vector2(side * absf(cos(angle)), sin(angle)) * speed * age
		point.y += 36.0 * age * age
		var radius := (3.0 + float(index % 3)) * clampf((duration - age) / 1.4, 0.0, 1.0)
		draw_star(point, radius, colors[index % colors.size()])


func draw_star(center: Vector2, radius: float, color: Color) -> void:
	if radius < 0.5:
		return
	var points := PackedVector2Array()
	for index in range(10):
		var angle := -PI / 2.0 + float(index) * TAU / 10.0
		var length := radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	draw_colored_polygon(points, color)
