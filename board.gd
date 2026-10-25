extends Control
## PLATEAU : dessin provisoire, caméra, zoom et identification des éléments touchés.
## Control reçoit les événements et découpe le dessin à son rectangle visible.
## Conversion : position écran locale = position en cases × CELL × zoom + pan.
## Le modèle game reste indépendant de ces déplacements de caméra et de la résolution.
# Une case vaut 42 unités graphiques avant zoom ; la simulation ne dépend pas de cette taille.
const CELL := 42.0
# Décor séparé du modèle : changer ses textures ne change ni les cases ni le chemin des monstres.
var scenery = preload("res://scenery.gd").new()
# Les tirs sont dessinés à part pour pouvoir remplacer leurs sprites sans toucher au combat.
var projectiles = preload("res://projectiles.gd").new()
var game
# Les gestes tactiles sont séparés des règles de jeu et des commandes de souris.
var touch_gestures = preload("res://input/board_touch.gd").new()
# CAMÉRA ET SÉLECTION : selected sert à dessiner portée et contour ; pan/zoom cadrent la carte.
var selected := Vector2i(-1, -1)
var zoom := 1.0
var pan := Vector2.ZERO
# GESTE EN COURS : start/pan_start gardent l'état de départ ; moved distingue glissement et toucher.
var dragging := false
var moved := false
var start := Vector2.ZERO
var pan_start := Vector2.ZERO
# CACHE DU CHEMIN : recalcul graphique seulement quand game.revision change.
var route_revision := -1
var route_points := PackedVector2Array()
var painter: Node2D
# SIGNAUX envoyés à main : case touchée, unité touchée/survolée et début d'un glissement.
# Les points d'unité sont locaux au plateau ; leur target indique type et cell ou id.
signal cell_tapped(cell: Vector2i)
signal item_tapped(target: Dictionary, point: Vector2)
signal item_hovered(target: Dictionary, point: Vector2)
signal view_dragged

var hovering := false
var hover_point := Vector2.ZERO

# Dessinateur enfant : Node2D accepte les transformations de caméra ; le Control parent découpe son image.
class MapPainter extends Node2D:
	var view
	## Rappel de dessin du nœud enfant : délègue tout le contenu du monde à view.paint(self).
	## Le parent peut ainsi zoomer/déplacer ce contenu sans déplacer le cadre du plateau.
	func _draw() -> void:
		view.paint(self)

## Active le découpage au rectangle du plateau et crée son dessinateur enfant.
## Connecte la sortie du pointeur pour fermer les aperçus, puis cadre l'entrée.
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	painter = MapPainter.new()
	painter.view = self
	add_child(painter)
	# Fonction anonyme appelée à la sortie du pointeur : efface le survol sans toucher à la sélection fixée.
	mouse_exited.connect(func():
		hovering = false
		item_hovered.emit({}, Vector2.ZERO))
	entry_view()

## Applique le décalage pan et le zoom au dessinateur, puis demande un nouveau dessin.
## Les positions du modèle restent en cases : seules les transformations graphiques changent.
func refresh() -> void:
	if painter != null:
		painter.position = pan
		painter.scale = Vector2.ONE * zoom
		painter.queue_redraw()
	queue_redraw()

## Renvoie le zoom permettant de voir toute la carte avec une marge de 5 %.
## Utilise la taille disponible du plateau et les dimensions de la grille.
func minimum_zoom() -> float:
	var bounds: Rect2 = scenery.world_bounds(game, CELL)
	return minf(size.x / bounds.size.x, size.y / bounds.size.y) * 0.95

## Change la taille du plateau en conservant la position du monde au centre de la vue.
## Si la vue montrait toute la carte, réajuste plutôt la vue d'ensemble au nouvel écran.
## Interrompt un glissement commencé avant la rotation et limite la caméra à la carte.
func resize_view(new_size: Vector2) -> void:
	if size.is_equal_approx(new_size):
		return

	var was_overview := is_equal_approx(zoom, minimum_zoom())
	# Annule la caméra pour retrouver le point du monde au centre AVANT de changer la taille.
	var focus := (size / 2.0 - pan) / zoom
	size = new_size
	dragging = false
	touch_gestures.reset()

	if was_overview:
		overview()
	else:
		zoom = clampf(zoom, minimum_zoom(), 2.0)
		pan = size / 2.0 - focus * zoom
		clamp_pan()
		refresh()

## Change le zoom en gardant le point anchor du plateau au même endroit du monde.
## Borne value entre la vue complète et ×2 ; les limites de caméra peuvent ajuster le cadrage.
func set_zoom(value: float, anchor: Vector2) -> void:
	# Mémorise le point du monde sous le doigt/pointeur avant de modifier le facteur de zoom.
	var world := (anchor - pan) / zoom
	zoom = clampf(value, minimum_zoom(), 2.0)
	pan = anchor - world * zoom
	clamp_pan()
	if dragging:
		# La molette peut être utilisée pendant que la souris est tenue : le zoom ne doit pas acheter une tour.
		# Le prochain déplacement repart de la caméra actuelle pour éviter un saut vers l'ancien cadrage.
		pan_start = pan
		start = anchor
		moved = true
	refresh()

## Limite le décalage de la carte pour éviter de la perdre entièrement hors du plateau.
## Autorise une marge de 24 unités graphiques autour de ses bords.
func clamp_pan() -> void:
	var bounds: Rect2 = scenery.world_bounds(game, CELL)
	# Les marges autorisent à voir les silhouettes complètes, même hors de la grille logique.
	var minimum := size - bounds.end * zoom - Vector2.ONE * 24.0
	var maximum := -bounds.position * zoom + Vector2.ONE * 24.0
	pan.x = clampf(pan.x, minf(minimum.x, maximum.x), maxf(minimum.x, maximum.x))
	pan.y = clampf(pan.y, minf(minimum.y, maximum.y), maxf(minimum.y, maximum.y))

## Revient au zoom ×1 et cadre la caverne entière à gauche, à mi-hauteur du plateau.
func entry_view() -> void:
	zoom = 1.0
	pan = Vector2(
		scenery.LANDMARK_INSET,
		size.y / 2.0,
	) - (Vector2(game.entry) + Vector2.ONE * 0.5) * CELL * zoom
	clamp_pan()
	refresh()

## Revient au zoom ×1 et cadre le château entier à droite, à mi-hauteur du plateau.
func castle_view() -> void:
	zoom = 1.0
	pan = Vector2(
		size.x - scenery.LANDMARK_INSET,
		size.y / 2.0,
	) - (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * CELL * zoom
	clamp_pan()
	refresh()

## Cadre la grille entière et la centre dans le plateau avec le zoom minimum.
func overview() -> void:
	zoom = minimum_zoom()
	pan = (size - Vector2(game.cols, game.rows) * CELL * zoom) / 2.0
	refresh()

## Convertit point, local au plateau, en case entière (x, y) en annulant pan et zoom.
## Ne vérifie pas les limites : game.inside permet ensuite de valider la case.
func cell_at(point: Vector2) -> Vector2i:
	var local := (point - pan) / (zoom * CELL)
	return Vector2i(floori(local.x), floori(local.y))

## Identifie l'unité dessinée sous point : monstre en priorité, sinon tour la plus proche.
## point est local au plateau. Les zones de sélection incluent les toits hors de leur case.
## Renvoie un dictionnaire type+id pour un monstre, type+cell pour une tour, ou {} sans cible.
func pick_item(point: Vector2) -> Dictionary:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return {}

	var world := (point - pan) / zoom
	# Les monstres sont dessinés au-dessus des tours : ils ont donc priorité pour être inspectés.
	var nearest: Dictionary = {}
	var best_distance := INF
	# On teste d'abord les monstres, car ils sont dessinés par-dessus les tours.
	# Ici, on identifie la cible touchée : aucun dessin ni dégât n'est produit par cette boucle.
	for enemy in game.enemies:
		if enemy.hp <= 0:
			continue

		var p: Vector2 = game.position_of(enemy) * CELL
		var radius := 22.0 if enemy.boss == 2 else (18.0 if enemy.boss == 1 else (22.0 if enemy.air else 14.0))
		var distance := world.distance_squared_to(p)

		if distance <= radius * radius and distance < best_distance:
			nearest = {"type": "enemy", "id": enemy.id}
			best_distance = distance

	if not nearest.is_empty():
		return nearest

	var cell := cell_at(point)
	# Teste neuf cases proches pour inclure le toit d'une tour qui dépasse dans la case voisine.
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var candidate := Vector2i(x, y)

			if not game.towers.has(candidate):
				continue

			var center := (Vector2(candidate) + Vector2.ONE * 0.5) * CELL

			if Rect2(center - Vector2(22, 27), Vector2(44, 49)).has_point(world):
				var distance := world.distance_squared_to(center)

				if distance < best_distance:
					nearest = {"type": "tower", "cell": candidate}
					best_distance = distance
	return nearest

## Reçoit les événements du plateau : clic, déplacement, molette et geste de zoom.
## Distingue un toucher d'un glissement par un seuil de 10 unités ; émet ensuite les signaux.
## Le tactile utilise l'émulation souris de Godot pour ces mêmes commandes.
func _gui_input(event: InputEvent) -> void:
	if touch_gestures.handle(self, event):
		accept_event()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(zoom * 1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(zoom / 1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				moved = false
				start = event.position
				pan_start = pan
			else:
				if dragging and not moved and Rect2(Vector2.ZERO, size).has_point(event.position):
					var target := pick_item(event.position)
					var cell := cell_at(event.position)

					if not target.is_empty():
						item_tapped.emit(target, event.position)
					elif game.inside(cell):
						# En vue d'ensemble, agrandit d'abord au lieu d'acheter une tour sur une case trop petite.
						if zoom * CELL < 20:
							set_zoom(1.0, event.position)
						else:
							cell_tapped.emit(cell)
					else:
						# Le décor hors grille peut aussi fermer une fiche ; game.build refuse cette case sans achat.
						cell_tapped.emit(cell)
				dragging = false
	elif event is InputEventMouseMotion:
		hover_point = event.position
		hovering = Rect2(Vector2.ZERO, size).has_point(event.position)

		if dragging:
			# Une fois le seuil franchi, le geste reste un déplacement jusqu'au relâchement.
			if not moved and event.position.distance_to(start) > 10:
				moved = true
				view_dragged.emit()

			if moved:
				pan = pan_start + event.position - start
				clamp_pan()
				refresh()
		else:
			item_hovered.emit(pick_item(event.position), event.position)
	elif event is InputEventMagnifyGesture:
		# Un pincement ne doit jamais se terminer par un clic qui achète une tour.
		dragging = false
		moved = true
		view_dragged.emit()
		set_zoom(zoom * event.factor, event.position)
	# Marque l'événement comme traité pour éviter qu'un autre contrôle l'utilise aussi.
	accept_event()

## Dessine le fond et le contour du Control, fixes à l'écran malgré le zoom du contenu.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17271d"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("89744c"), false, 3)

## Demande au dessinateur de représenter la partie avec la caméra actuelle.
## Le détail des couches est dans rendering/board_renderer.gd ; ce fichier garde les interactions avec la carte.
func paint(canvas: Node2D) -> void:
	preload("res://rendering/board_renderer.gd").paint(self, canvas)
