extends RefCounted
## Ce fichier dessine le contenu du plateau, couche après couche.
## view désigne board.gd : il fournit la caméra et la partie à représenter.
## canvas est le nœud Godot sur lequel les formes et images sont dessinées. Aucune règle de combat n'est modifiée.

const Art = preload("res://rendering/unit_art.gd")


## Dessine les couches dans cet ordre : terrain, chemin, quadrillage, bâtiments, portée, unités, tirs, pause.
## Changer cet ordre peut masquer les unités sous le décor ; il doit donc rester explicite.
static func paint(view, canvas: Node2D) -> void:
	if view.game == null:
		return

	var visible = Rect2(-view.pan / view.zoom, view.size / view.zoom).grow(view.CELL)
	paint_ground(view, canvas, visible)
	paint_route(view, canvas, visible)
	paint_grid(view, canvas, visible)
	view.scenery.paint_landmarks(canvas, view.game, view.CELL)
	paint_range(view, canvas)
	paint_towers(view, canvas, visible)
	paint_enemies(view, canvas, visible)
	paint_shots(view, canvas)
	paint_pause(view, canvas)


## Dessine le terrain et les emprises réservées aux bâtiments, avant le chemin et le quadrillage.
static func paint_ground(view, canvas: Node2D, visible: Rect2) -> void:
	view.scenery.paint_ground(canvas, view.game, view.CELL, visible)
	# Atténue le contraste du fond pour laisser ressortir les silhouettes des unités.
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(view.game.cols, view.game.rows) * view.CELL), Color("#17393b0a"))
	view.scenery.paint_reserved_areas(canvas, view.game, view.CELL)


## Pose le quadrillage sur le terrain ET sur le chemin afin de distinguer toutes les cases.
## Le trait garde une épaisseur d'un pixel à chaque zoom ; seules les lignes visibles sont dessinées.
## Les bâtiments et les unités sont dessinés ensuite pour ne pas être striés par cette surcouche.
static func paint_grid(view, canvas: Node2D, visible: Rect2) -> void:

	var x0 = maxi(0, floori(visible.position.x / view.CELL))
	var x1 = mini(view.game.cols, ceili(visible.end.x / view.CELL))
	var y0 = maxi(0, floori(visible.position.y / view.CELL))
	var y1 = mini(view.game.rows, ceili(visible.end.y / view.CELL))

	for x in range(x0, x1 + 1):
		canvas.draw_line(
			Vector2(x * view.CELL, y0 * view.CELL),
			Vector2(x * view.CELL, y1 * view.CELL),
			Color("#2e67252e"),
			1.0 / view.zoom,
		)

	for y in range(y0, y1 + 1):
		canvas.draw_line(
			Vector2(x0 * view.CELL, y * view.CELL),
			Vector2(x1 * view.CELL, y * view.CELL),
			Color("#2e67252e"),
			1.0 / view.zoom,
		)


## Dessine le chemin minimal actuellement disponible depuis l'arrivée des monstres.
## Ses points sont recalculés seulement quand les constructions changent, puis réutilisés entre les images.
static func paint_route(view, canvas: Node2D, visible: Rect2) -> void:

	# Réutiliser les mêmes points évite de reconstruire le tracé à chaque image si aucune tour n'a changé.
	if view.route_revision != view.game.revision:
		view.route_points.clear()
		if not view.game.route.is_empty():
			view.route_points.append(view.scenery.portal_origin(view.game, view.CELL))

		# Garder seulement les virages évite de redessiner des disques sur chaque case d'une ligne droite.
		for index in range(view.game.route.size()):
			var cell: Vector2i = view.game.route[index]
			if index > 0 and index < view.game.route.size() - 1:
				var before: Vector2i = view.game.route[index - 1]
				var after: Vector2i = view.game.route[index + 1]
				if cell - before == after - cell:
					continue
			view.route_points.append((Vector2(cell) + Vector2.ONE * 0.5) * view.CELL)
		if not view.game.route.is_empty():
			var goal: Vector2 = (Vector2(view.game.exit_cell) + Vector2.ONE * 0.5) * view.CELL
			view.route_points.append(goal + Vector2(130, 10))
		view.route_revision = view.game.revision

	view.scenery.paint_path(canvas, view.route_points, view.game.route, view.CELL, visible, view.zoom)


## Dessine un cercle indiquant la portée de la tour sélectionnée, si elle existe encore.
## La distance du modèle est en cases ; CELL la transforme en unités graphiques.
static func paint_range(view, canvas: Node2D) -> void:
	if view.game.towers.has(view.selected):
		var point = (Vector2(view.selected) + Vector2.ONE * 0.5) * view.CELL
		var radius: float = view.game.tower_range(view.game.towers[view.selected]) * view.CELL
		canvas.draw_circle(point, radius, Color("#efd58a12"))
		canvas.draw_arc(point, radius, 0, TAU, 64, Color("#efd58a88"), 2, true)


## Dessine les illustrations des tours, leur niveau, leur sélection et leurs éventuelles blessures.
## Une tour hors du rectangle visible est ignorée pour éviter du travail inutile.
static func paint_towers(view, canvas: Node2D, visible: Rect2) -> void:
	for cell in view.game.towers:
		var p = (Vector2(cell) + Vector2.ONE * 0.5) * view.CELL

		if not visible.has_point(p):
			continue

		var tower: Dictionary = view.game.towers[cell]
		# Assombrit uniquement le sol de la case, avant de dessiner la tour pour garder son illustration lumineuse.
		if cell == view.selected:
			canvas.draw_rect(Rect2(Vector2(cell) * view.CELL, Vector2.ONE * view.CELL), Color("#00000030"))
		canvas.draw_texture_rect(Art.tower_icon(int(tower.kind)), Rect2(p - Vector2(22, 29), Vector2(44, 51)), false)

		# Les détails fins sont masqués quand la carte est très éloignée, car ils deviendraient illisibles.
		if view.zoom > 0.4:
			canvas.draw_circle(p + Vector2(14, 13), 7, Color("#173b49"))
			canvas.draw_arc(p + Vector2(14, 13), 7, 0, TAU, 16, Color("#e7c17a"), 1.0, true)
			canvas.draw_string(
				ThemeDB.fallback_font,
				p + Vector2(11, 17),
				str(tower.level),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color("#fff0be"),
			)

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

		var radius := 19.0 if enemy.boss == 2 else (15.0 if enemy.boss == 1 else 10.0)
		var bob := 0.0 if view.game.paused else sin(float(Time.get_ticks_msec()) / 145.0 + float(enemy.id)) * 1.1
		var tint := Color("#9ae4ff") if enemy.slow_time > 0 else Color("#ffffff")
		# Une apparition progressive accompagne le trajet réel depuis le portail hors grille.
		var emergence := clampf(float(enemy.get("portal_age", 1.0)) / 0.32, 0.0, 1.0)
		tint.a *= emergence
		canvas.draw_set_transform(p + Vector2(0, 8), 0.0, Vector2(1.0, 0.35))
		canvas.draw_circle(Vector2.ZERO, radius, Color("#172f3b70"))
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_texture_rect(
			Art.enemy_icon(enemy),
			Art.enemy_bounds(enemy, p, bob),
			false,
			tint,
		)

		if not enemy.poison.is_empty():
			canvas.draw_arc(p, radius + 4, 0, TAU, 18, Color("#96d768"), 2)

		# Les détails fins sont masqués quand la carte est très éloignée, car ils deviendraient illisibles.
		if view.zoom > 0.4 and enemy.hp < enemy.max_hp:
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
