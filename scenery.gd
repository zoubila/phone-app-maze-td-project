extends RefCounted
## DÉCOR DU PLATEAU : terrain cartoon, portail des monstres et bourg à protéger.
## Les dessins restent en coordonnées du monde pour suivre le zoom, le déplacement et la rotation.
## Le portail est hors grille. Seule l'emprise du château garde une réservation dans la grille.
## Ces réservations sont définies dans game.gd ; le dessin réutilise leurs coordonnées.

const GROUND = preload("res://assets/terrain/sol_toon_v2.png")
const TREE = preload("res://assets/terrain/chene_toon_v2.png")
const PORTAL = preload("res://assets/terrain/portail_cartoon.png")
const TOWN = preload("res://assets/terrain/bourg_cartoon.png")
# Marge graphique hors grille : les repères ne recouvrent pas les cases constructibles.
const MARGIN := 370.0
const LANDMARK_INSET := 340.0


## Le point d'apparition est partagé avec le modèle : le monstre sort bien de la bouche du portail.
static func portal_origin(game, cell_size: float) -> Vector2:
	return (Vector2(game.entry) + Vector2.ONE * 0.5) * cell_size - Vector2(game.PORTAL_APPROACH_CELLS * cell_size, 0)

## Renvoie le rectangle de décor, en unités graphiques, avec de la place autour de la grille.
## Utilisé aussi par la caméra pour cadrer les bâtiments situés hors des cases de jeu.
static func world_bounds(game, cell_size: float) -> Rect2:
	return Rect2(Vector2.ONE * -MARGIN, Vector2(game.cols, game.rows) * cell_size + Vector2.ONE * MARGIN * 2.0)

## Répète le mélange de terre, pavés anciens et végétation à une échelle constante.
## Seules les tuiles visibles sont dessinées. Les arbres restent hors des cases constructibles.
func paint_ground(canvas: Node2D, game, cell_size: float, visible: Rect2) -> void:
	var grid := Rect2(Vector2.ZERO, Vector2(game.cols, game.rows) * cell_size)
	var bounds := world_bounds(game, cell_size)
	var area := visible.intersection(bounds)
	var tile_size := 512.0

	for y in range(floori(area.position.y / tile_size), ceili(area.end.y / tile_size)):
		for x in range(floori(area.position.x / tile_size), ceili(area.end.x / tile_size)):
			var origin := Vector2(x, y) * tile_size
			var tile := Rect2(origin, Vector2.ONE * tile_size).intersection(bounds)
			canvas.draw_texture_rect_region(
				GROUND,
				tile,
				Rect2((tile.position - origin) / tile_size * GROUND.get_size(), tile.size / tile_size * GROUND.get_size()),
			)
	paint_forest_edge(canvas, game, cell_size, visible, grid)
	paint_landmark_ground(canvas, game, cell_size, visible)


## Signale les emprises non constructibles après le quadrillage et avant le chemin et les bâtiments.
## Les limites proviennent du modèle : elles ne changent pas avec le zoom ou l'orientation de l'écran.
func paint_reserved_areas(canvas: Node2D, game, cell_size: float) -> void:
	var areas: Array[Rect2i] = game.landmark_areas()
	for index in range(areas.size()):
		var area := Rect2(Vector2(areas[index].position) * cell_size, Vector2(areas[index].size) * cell_size)
		var edge := Color("#e0c48c91")
		# Quatre petits repères remplacent le rectangle technique qui encombrait le décor.
		for corner in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
			var point: Vector2 = area.position + corner * area.size
			var direction: Vector2 = Vector2.ONE - corner * 2.0
			canvas.draw_line(point, point + Vector2(direction.x * 9.0, 0), edge, 1.5, true)
			canvas.draw_line(point, point + Vector2(0, direction.y * 9.0), edge, 1.5, true)


## Dessine une dalle basse avec une tranche sombre et un dessus clair, pour suggérer le relief.
func paint_flat_stone(canvas: Node2D, point: Vector2, half_size: Vector2, color: Color) -> void:
	var shape := PackedVector2Array([
		point + Vector2(-half_size.x, -half_size.y * 0.4),
		point + Vector2(-half_size.x * 0.45, -half_size.y),
		point + Vector2(half_size.x * 0.7, -half_size.y * 0.85),
		point + Vector2(half_size.x, half_size.y * 0.25),
		point + Vector2(half_size.x * 0.3, half_size.y),
		point + Vector2(-half_size.x * 0.8, half_size.y * 0.8),
	])
	canvas.draw_set_transform(Vector2(0, 2))
	canvas.draw_colored_polygon(shape, Color("#6e7356"))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_colored_polygon(shape, color)
	canvas.draw_line(shape[1], shape[2], color.lightened(0.2), 1.5, true)


## Distingue les deux pôles : terre cendrée et cercle magique à gauche, parvis pavé à droite.
## Les coordonnées des portes restent rattachées aux cases d'entrée et de sortie du modèle.
func paint_landmark_ground(canvas: Node2D, game, cell_size: float, visible: Rect2) -> void:
	var goal := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * cell_size
	var portal_base := portal_origin(game, cell_size) + Vector2(0, 7)
	var town_base := goal + Vector2(130, 10)
	if visible.grow(200.0).has_point(portal_base):
		canvas.draw_set_transform(portal_base, 0.0, Vector2(1.0, 0.6))
		canvas.draw_circle(Vector2.ZERO, 146.0, Color("#716c5666"))
		canvas.draw_circle(Vector2.ZERO, 112.0, Color("#605e6370"))
		canvas.draw_arc(Vector2.ZERO, 94.0, 0.0, TAU, 48, Color("#a897c0a0"), 3.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
		for index in range(8):
			var angle := float(index) / 8.0 * TAU
			var point := portal_base + Vector2(cos(angle) * 126.0, sin(angle) * 66.0)
			paint_flat_stone(canvas, point, Vector2(13, 9), Color("#88878c"))

	if visible.grow(230.0).has_point(town_base):
		canvas.draw_set_transform(town_base, 0.0, Vector2(1.0, 0.55))
		canvas.draw_circle(Vector2.ZERO, 170.0, Color("#9c8b617d"))
		canvas.draw_set_transform(Vector2.ZERO)
		for y in range(-3, 4):
			for x in range(-6, 7):
				var offset := Vector2(x * 23 + (y % 2) * 10, y * 17)
				if Vector2(offset.x, offset.y * 1.8).length() < 152.0:
					paint_flat_stone(canvas, town_base + offset, Vector2(10, 7), Color("#c2b58e"))


## Ajoute des arbres aux cimes arrondies dans les marges, avec une lumière venant du haut gauche.
## Le placement dépend des coordonnées : les arbres ne bougent pas au zoom ou au redessin.
## Les abords des deux bâtiments et toutes les cases de jeu restent dégagés.
func paint_forest_edge(canvas: Node2D, game, cell_size: float, visible: Rect2, grid: Rect2) -> void:
	var bounds := world_bounds(game, cell_size)
	var area := visible.grow(70.0).intersection(bounds)
	var goal := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * cell_size
	var cave_area := Rect2(portal_origin(game, cell_size) - Vector2(165, 240), Vector2(330, 350))
	var castle_area := Rect2(goal - Vector2(80, 250), Vector2(430, 370))

	for y in range(floori(area.position.y / 100.0), ceili(area.end.y / 100.0)):
		for x in range(floori(area.position.x / 100.0), ceili(area.end.x / 100.0)):
			var seed_value := absi(x * 73 + y * 137)
			var point := Vector2(x * 100 + 45, y * 100 + 45)
			point += Vector2(seed_value % 23 - 11, seed_value % 17 - 8)

			if not bounds.has_point(point) or grid.grow(55.0).has_point(point):
				continue
			if cave_area.has_point(point) or castle_area.has_point(point):
				continue

			canvas.draw_texture_rect(TREE, Rect2(point - Vector2(56, 98), Vector2(112, 118)), false)


## Superpose ombre, bord de terre et surface claire pour donner du volume au chemin.
## points contient seulement les extrémités et virages ; route conserve les cases pour les petits cailloux.
## Le dessin suit le chemin du modèle sans modifier les déplacements ni les droits de construction.
func paint_path(canvas: Node2D, points: PackedVector2Array, route: Array, cell_size: float, visible: Rect2, zoom: float) -> void:
	if points.size() < 2:
		return

	canvas.draw_set_transform(Vector2(0, 3))
	paint_path_stroke(canvas, points, Color("#31492e55"), 38.0)
	canvas.draw_set_transform(Vector2.ZERO)
	paint_path_stroke(canvas, points, Color("#8b592f"), 34.0)
	paint_path_stroke(canvas, points, Color("#d79d57"), 31.0)
	paint_path_stroke(canvas, points, Color("#f0ca8c"), 26.0)
	paint_path_stroke(canvas, points, Color("#f8db9e"), 18.0)

	# Les petits détails disparaissent en vue éloignée pour conserver une lecture claire sur mobile.
	if zoom < 0.45:
		return

	for cell in route:
		var point := (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
		if not visible.has_point(point):
			continue
		var variation := absi(cell.x * 17 + cell.y * 31)
		if variation % 3 != 0:
			continue

		point += Vector2(variation % 9 - 4, variation % 13 - 6)
		var pebble := PackedVector2Array([
			point + Vector2(-4, 0), point + Vector2(-2, -3),
			point + Vector2(3, -2), point + Vector2(5, 1), point + Vector2(0, 3),
		])
		canvas.draw_colored_polygon(pebble, Color("#b89160"))
		canvas.draw_line(point + Vector2(-2, -2), point + Vector2(2, -2), Color("#f7dca5"), 1.5, true)


## Arrondit les extrémités et les virages d'un trait épais avec des disques de même couleur.
## Les longs segments droits n'ont pas de points intermédiaires : leur coût reste faible.
func paint_path_stroke(canvas: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	# Des segments indépendants évitent les pointes carrées des jointures d'une polyligne épaisse.
	for index in range(points.size() - 1):
		canvas.draw_line(points[index], points[index + 1], color, width, true)
	for point in points:
		canvas.draw_circle(point, width * 0.5, color)

## Dessine le portail d'apparition à gauche et le bourg fortifié à droite, au bout du chemin.
## Le portail et son socle restent à gauche de la grille ; le château garde son emprise réservée.
func paint_landmarks(canvas: Node2D, game, cell_size: float) -> void:
	var goal := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * cell_size
	var mouth := portal_origin(game, cell_size)
	canvas.draw_texture_rect(PORTAL, Rect2(mouth - Vector2(132, 205), Vector2(255, 233)), false)
	canvas.draw_texture_rect(TOWN, Rect2(goal - Vector2(40, 205), Vector2(360, 240)), false)
	paint_portal_glow(canvas, game, mouth)


## Ajoute un halo respirant et quelques étincelles au moment d'une apparition.
## Les temps viennent de la simulation : une pause fige aussi l'effet et la sortie du monstre.
func paint_portal_glow(canvas: Node2D, game, mouth: Vector2) -> void:
	var phase: float = game.presentation_time
	var pulse := 0.5 + sin(phase * 3.0) * 0.5
	canvas.draw_set_transform(mouth - Vector2(4, 64), 0.0, Vector2(0.62, 1.0))
	canvas.draw_arc(Vector2.ZERO, 39.0 + pulse * 4.0, -2.6, 2.6, 36, Color("#93ddff55"), 1.5, true)
	canvas.draw_set_transform(Vector2.ZERO)
	var youngest := 1.0
	for enemy in game.enemies:
		youngest = minf(youngest, float(enemy.get("portal_age", 1.0)))
	if youngest >= 0.7:
		return
	for index in range(10):
		var angle := float(index) * TAU / 10.0
		var point := mouth - Vector2(4, 34) + Vector2(cos(angle), sin(angle)) * (14.0 + youngest * 55.0)
		var spark := Color("#a6d9ff")
		spark.a = (1.0 - youngest / 0.7) * 0.7
		canvas.draw_circle(point, 1.5 + pulse, spark)
