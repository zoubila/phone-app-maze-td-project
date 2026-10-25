extends RefCounted
## DÉCOR DU PLATEAU : textures de forêt, caverne d'arrivée et château d'objectif.
## Les dessins restent en coordonnées du monde pour suivre le zoom, le déplacement et la rotation.
## Ce décor ne crée aucun obstacle : les règles de navigation restent dans game.gd.

const FOREST = preload("res://assets/terrain/foret.png")
const CAVE = preload("res://assets/terrain/caverne.png")
const CASTLE = preload("res://assets/terrain/chateau.png")
# Marge graphique hors grille : les repères ne recouvrent pas les cases constructibles.
const MARGIN := 260.0
const LANDMARK_INSET := 235.0

## Renvoie le rectangle de décor, en unités graphiques, avec de la place autour de la grille.
## Utilisé aussi par la caméra pour cadrer les bâtiments situés hors des cases de jeu.
static func world_bounds(game, cell_size: float) -> Rect2:
	return Rect2(Vector2.ONE * -MARGIN, Vector2(game.cols, game.rows) * cell_size + Vector2.ONE * MARGIN * 2.0)

## Pose le sol forestier en mosaïque, sans étirer l'image selon la taille de la grille.
## Sur la grille, réutilise uniquement la clairière centrale pour éviter des arbres sur les cases jouables.
## visible limite les tuiles dessinées à la portion affichée ; aucune copie d'image n'est créée.
func paint_ground(canvas: Node2D, game, cell_size: float, visible: Rect2) -> void:
	canvas.draw_texture_rect(FOREST, world_bounds(game, cell_size), true)

	var grid := Rect2(Vector2.ZERO, Vector2(game.cols, game.rows) * cell_size)
	var area := visible.intersection(grid)
	# On ne prélève que la clairière au centre de l'image, pour ne pas placer de grands arbres sur les cases jouables.
	# Les proportions 0,28 et 0,44 décrivent ce rectangle dans la texture, quelle que soit sa résolution.
	var source := Rect2(FOREST.get_size() * 0.28, FOREST.get_size() * 0.44)
	var tile_size := 512.0

	for y in range(floori(area.position.y / tile_size), ceili(area.end.y / tile_size)):
		for x in range(floori(area.position.x / tile_size), ceili(area.end.x / tile_size)):
			var tile := Rect2(Vector2(x, y) * tile_size, Vector2.ONE * tile_size).intersection(grid)
			canvas.draw_texture_rect_region(
				FOREST,
				tile,
				Rect2(source.position, source.size * tile.size / tile_size),
			)
	canvas.draw_rect(grid, Color("142a2238"))

## Dessine la caverne à gauche et le château à droite, avant les monstres et les tours.
## Les points d'ancrage placent la bouche et la porte près des cases d'entrée/sortie.
func paint_landmarks(canvas: Node2D, game, cell_size: float) -> void:
	var entrance := (Vector2(game.entry) + Vector2.ONE * 0.5) * cell_size
	var goal := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * cell_size
	canvas.draw_texture_rect(CAVE, Rect2(entrance - Vector2(225, 144), Vector2(288, 192)), false)
	canvas.draw_texture_rect(CASTLE, Rect2(goal - Vector2(68, 205), Vector2(260, 260)), false)
