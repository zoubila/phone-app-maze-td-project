extends RefCounted
## Ce fichier dessine le contenu du plateau, couche après couche.
## view désigne board.gd : il fournit la caméra et la partie à représenter.
## canvas est le nœud Godot sur lequel les formes et images sont dessinées. Aucune règle de combat n'est modifiée.


## Dessine les couches dans cet ordre : terrain, chemin, portée, tours, monstres, tirs, pause.
## Changer cet ordre peut masquer les unités sous le décor ; il doit donc rester explicite.
static func paint(view, canvas: Node2D) -> void:
	if view.game == null:
		return

	var visible = Rect2(-view.pan / view.zoom, view.size / view.zoom).grow(view.CELL)
	paint_ground(view, canvas, visible)
	paint_route(view, canvas)
	paint_range(view, canvas)
	paint_towers(view, canvas, visible)
	paint_enemies(view, canvas, visible)
	paint_shots(view, canvas)
	paint_pause(view, canvas)


## Dessine la forêt et le quadrillage seulement dans la portion visible de la carte.
## Le quadrillage reste fin à chaque zoom pour ne pas masquer les unités.
static func paint_ground(view, canvas: Node2D, visible: Rect2) -> void:
	view.scenery.paint_ground(canvas, view.game, view.CELL, visible)

	var x0 = maxi(0, floori(visible.position.x / view.CELL))
	var x1 = mini(view.game.cols, ceili(visible.end.x / view.CELL))
	var y0 = maxi(0, floori(visible.position.y / view.CELL))
	var y1 = mini(view.game.rows, ceili(visible.end.y / view.CELL))

	for x in range(x0, x1 + 1):
		canvas.draw_line(
			Vector2(x * view.CELL, y0 * view.CELL),
			Vector2(x * view.CELL, y1 * view.CELL),
			Color("#cad8a33b"),
			1.0 / view.zoom,
		)

	for y in range(y0, y1 + 1):
		canvas.draw_line(
			Vector2(x0 * view.CELL, y * view.CELL),
			Vector2(x1 * view.CELL, y * view.CELL),
			Color("#cad8a33b"),
			1.0 / view.zoom,
		)


## Dessine le chemin minimal actuellement disponible depuis l'arrivée des monstres.
## Ses points sont recalculés seulement quand les constructions changent, puis réutilisés entre les images.
static func paint_route(view, canvas: Node2D) -> void:

	# Réutiliser les mêmes points évite de reconstruire le tracé à chaque image si aucune tour n'a changé.
	if view.route_revision != view.game.revision:
		view.route_points.clear()

		for cell in view.game.route:
			view.route_points.append((Vector2(cell) + Vector2.ONE * 0.5) * view.CELL)
		view.route_revision = view.game.revision

	if view.route_points.size() > 1:
		canvas.draw_polyline(view.route_points, Color("#d5bc7766"), 10, true)
	view.scenery.paint_landmarks(canvas, view.game, view.CELL)


## Dessine un cercle indiquant la portée de la tour sélectionnée, si elle existe encore.
## La distance du modèle est en cases ; CELL la transforme en unités graphiques.
static func paint_range(view, canvas: Node2D) -> void:
	if view.game.towers.has(view.selected):
		var point = (Vector2(view.selected) + Vector2.ONE * 0.5) * view.CELL
		var radius: float = view.game.tower_range(view.game.towers[view.selected]) * view.CELL
		canvas.draw_circle(point, radius, Color("#efd58a12"))
		canvas.draw_arc(point, radius, 0, TAU, 64, Color("#efd58a88"), 2, true)


## Dessine les tours provisoires, leur niveau, leur sélection et leurs éventuelles blessures.
## Une tour hors du rectangle visible est ignorée pour éviter du travail inutile.
static func paint_towers(view, canvas: Node2D, visible: Rect2) -> void:
	for cell in view.game.towers:
		var p = (Vector2(cell) + Vector2.ONE * 0.5) * view.CELL

		if not visible.has_point(p):
			continue

		var tower: Dictionary = view.game.towers[cell]
		var color: Color = view.game.TYPES[int(tower.kind)].color
		canvas.draw_circle(p + Vector2(2, 3), 18, Color("#15251b"))
		canvas.draw_rect(Rect2(p - Vector2(14, 13), Vector2(28, 30)), Color("#b8af96"))

		if tower.kind <= 1:
			canvas.draw_colored_polygon(
				PackedVector2Array([p + Vector2(-18, -9), p + Vector2(0, -24), p + Vector2(18, -9)]),
				color,
			)
		else:
			canvas.draw_colored_polygon(
				PackedVector2Array([
					p + Vector2(0, -25),
					p + Vector2(10, -14),
					p + Vector2(0, -4),
					p + Vector2(-10, -14),
				]),
				color,
			)

		# Les détails fins sont masqués quand la carte est très éloignée, car ils deviendraient illisibles.
		if view.zoom > 0.4:
			canvas.draw_string(
				ThemeDB.fallback_font,
				p + Vector2(-5, 12),
				str(tower.level),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color("#263325"),
			)

		if cell == view.selected:
			canvas.draw_rect(Rect2(p - Vector2(20, 20), Vector2(40, 40)), Color("#f8dc8b"), false, 2)

		if tower.hp < 120.0 + (tower.level - 1) * 60:
			canvas.draw_line(
				p + Vector2(-16, 20),
				p + Vector2(-16 + 32 * tower.hp / (120.0 + (tower.level - 1) * 60), 20),
				Color("#d67762"),
				3,
			)


## Dessine les monstres avec leur couleur et leurs états : givre, poison et points de vie.
## Le modèle donne une position précise entre deux cases afin que leur mouvement soit fluide.
static func paint_enemies(view, canvas: Node2D, visible: Rect2) -> void:
	for enemy in view.game.enemies:
		var p: Vector2 = view.game.position_of(enemy) * view.CELL

		if not visible.has_point(p):
			continue

		var color = Color("#c6b88a") if enemy.armor == "physical" else Color("#bd91ce")

		if enemy.air:
			color = Color("#edc96a")

		if enemy.boss > 0:
			color = Color("#e47755")

		if enemy.slow_time > 0:
			color = Color("#8ad8ea")

		var radius = 19.0 if enemy.boss == 2 else (15.0 if enemy.boss == 1 else 10.0)
		canvas.draw_circle(p, radius, color)

		if enemy.air:
			canvas.draw_line(p - Vector2(22, 10), p, color, 5)
			canvas.draw_line(p, p + Vector2(22, -10), color, 5)

		if not enemy.poison.is_empty():
			canvas.draw_arc(p, radius + 4, 0, TAU, 18, Color("#96d768"), 2)

		# Les détails fins sont masqués quand la carte est très éloignée, car ils deviendraient illisibles.
		if view.zoom > 0.4:
			canvas.draw_circle(p + Vector2(-3, -2), 2, Color("#263325"))
			canvas.draw_circle(p + Vector2(3, -2), 2, Color("#263325"))
			canvas.draw_line(p + Vector2(-15, -radius - 7), p + Vector2(15, -radius - 7), Color("#492c26"), 3)
			canvas.draw_line(
				p + Vector2(-15, -radius - 7),
				p + Vector2(-15 + 30 * maxf(0, enemy.hp / enemy.max_hp), -radius - 7),
				Color("#b2d078"),
				3,
			)


## Confie les animations de tir à projectiles.gd, qui sait notamment dessiner et tourner les flèches.
static func paint_shots(view, canvas: Node2D) -> void:
	view.projectiles.paint(canvas, view.game.shots, view.CELL)


## Ajoute un voile et le mot PAUSE par-dessus le monde quand la partie est arrêtée.
## On annule ici le décalage et le zoom pour couvrir exactement la zone visible du plateau.
static func paint_pause(view, canvas: Node2D) -> void:
	if view.game.paused:
		canvas.draw_rect(Rect2(-view.pan / view.zoom, view.size / view.zoom), Color("#000000aa"))
		canvas.draw_string(
			ThemeDB.fallback_font,
			(view.size / 2.0 - view.pan) / view.zoom,
			"PAUSE",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			int(32 / view.zoom),
			Color("#f8e2b1"),
		)
