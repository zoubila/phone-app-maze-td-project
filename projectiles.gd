extends RefCounted
## RENDU DES TIRS : flèche texturée de l'archer et effets provisoires des autres tours.
## Les dégâts sont calculés par game.gd au tir ; le vol est une animation visuelle.

const ARROW = preload("res://assets/projectiles/fleche.png")
const ARROW_WIDTH := 48.0

## Calcule la position et la rotation d'une flèche à partir de son temps de vie restant.
## Renvoie une transformation dans le monde ; pan et zoom sont appliqués par le plateau parent.
## Le point d'arrivée est mémorisé au tir, même si le monstre disparaît entre-temps.
static func arrow_transform(shot: Dictionary, cell_size: float) -> Transform2D:
	var origin: Vector2 = shot.from * cell_size
	var target: Vector2 = shot.to * cell_size
	# life diminue jusqu'à zéro, tandis que duration garde la durée initiale.
	# Leur rapport passe de 1 à 0 : le soustraire de 1 donne une progression qui va du départ à l'arrivée.
	# clampf empêche une petite erreur d'arrondi de placer la flèche avant ou après sa trajectoire.
	var progress := clampf(1.0 - float(shot.life) / maxf(0.001, float(shot.duration)), 0.0, 1.0)
	# lerp calcule le point situé à cette proportion entre origin et target.
	return Transform2D((target - origin).angle(), origin.lerp(target, progress))

## Dessine une flèche de taille constante dans le monde, tournée vers sa cible.
## Conserve les proportions du PNG et rétablit la transformation avant les autres dessins.
func paint_arrow(canvas: Node2D, shot: Dictionary, cell_size: float) -> void:
	var transform := arrow_transform(shot, cell_size)
	var dimensions := Vector2(ARROW_WIDTH, ARROW_WIDTH * ARROW.get_height() / ARROW.get_width())
	canvas.draw_set_transform(transform.origin, transform.get_rotation())
	canvas.draw_texture_rect(ARROW, Rect2(-dimensions / 2.0, dimensions), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0)

## Dessine tous les tirs encore actifs. kind=0 désigne l'archer : aucun segment rouge n'est dessiné.
## Les boss, dont les tirs n'ont pas de kind, et les autres tours gardent leurs effets actuels.
func paint(canvas: Node2D, shots: Array, cell_size: float) -> void:
	for shot in shots:
		if shot.get("kind", -1) == 0:
			paint_arrow(canvas, shot, cell_size)
			continue

		var color: Color = shot.color
		color.a = minf(1.0, shot.life / 0.18)
		canvas.draw_line(shot.from * cell_size, shot.to * cell_size, color, 3, true)

		if shot.splash:
			canvas.draw_arc(shot.to * cell_size, cell_size * 1.5 * (1.0 - color.a), 0, TAU, 24, color, 2, true)
