extends Control
## PLATEAU : dessin provisoire, caméra, zoom et identification des éléments touchés.
## Control reçoit les événements et découpe le dessin à son rectangle visible.
## Conversion : position écran locale = position en cases × CELL × zoom + pan.
## Le modèle game reste indépendant de ces déplacements de caméra et de la résolution.
# Une case vaut 42 unités graphiques avant zoom ; la simulation ne dépend pas de cette taille.
const CELL := 42.0
var game
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
	return minf(size.x / (game.cols * CELL), size.y / (game.rows * CELL)) * 0.95

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
	refresh()

## Limite le décalage de la carte pour éviter de la perdre entièrement hors du plateau.
## Autorise une marge de 24 unités graphiques autour de ses bords.
func clamp_pan() -> void:
	var world := Vector2(game.cols, game.rows) * CELL * zoom
	pan.x = clampf(pan.x, minf(24.0, size.x - world.x - 24.0), maxf(24.0, size.x - world.x - 24.0))
	pan.y = clampf(pan.y, minf(24.0, size.y - world.y - 24.0), maxf(24.0, size.y - world.y - 24.0))

## Revient au zoom ×1 et place l'entrée près du bord gauche, à mi-hauteur du plateau.
func entry_view() -> void:
	zoom = 1.0
	pan = Vector2(35, size.y / 2.0) - (Vector2(game.entry) + Vector2.ONE * 0.5) * CELL * zoom
	clamp_pan()
	refresh()

## Revient au zoom ×1 et place le château près du bord droit, à mi-hauteur du plateau.
func castle_view() -> void:
	zoom = 1.0
	pan = Vector2(size.x - 35, size.y / 2.0) - (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * CELL * zoom
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
	# MONSTRES : couleur de résistance/type, teinte de givre, anneau de poison et barre de vie.
	# Les détails fins sont masqués à faible zoom pour garder une vue lisible.
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
		set_zoom(zoom * event.factor, event.position)
	# Marque l'événement comme traité pour éviter qu'un autre contrôle l'utilise aussi.
	accept_event()

## Dessine le fond et le contour du Control, fixes à l'écran malgré le zoom du contenu.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17271d"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("89744c"), false, 3)

## Dessine sur canvas les éléments du monde, transformés par pan et zoom.
## Ordre des couches : grille, chemin, portée, tours, entrée/château, monstres, tirs puis pause.
## Les graphismes sont provisoires ; cette méthode accueillera les textures et animations.
func paint(canvas: Node2D) -> void:
	if game == null:
		return
	# Calcule la portion du monde visible ; la marge d'une case inclut les dessins débordants.
	# Limiter le quadrillage et les unités dessinées économise du travail sur les grandes cartes.
	var visible := Rect2(-pan / zoom, size / zoom).grow(CELL)
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(game.cols, game.rows) * CELL), Color("304632"))
	var x0 := maxi(0, floori(visible.position.x / CELL))
	var x1 := mini(game.cols, ceili(visible.end.x / CELL))
	var y0 := maxi(0, floori(visible.position.y / CELL))
	var y1 := mini(game.rows, ceili(visible.end.y / CELL))
	for x in range(x0, x1 + 1):
		canvas.draw_line(Vector2(x * CELL, y0 * CELL), Vector2(x * CELL, y1 * CELL), Color("5b6548"), 1.0 / zoom)
	for y in range(y0, y1 + 1):
		canvas.draw_line(Vector2(x0 * CELL, y * CELL), Vector2(x1 * CELL, y * CELL), Color("5b6548"), 1.0 / zoom)
	# Reconstruit les points de la ligne seulement si les obstacles ont changé, pas à chaque image.
	if route_revision != game.revision:
		route_points.clear()
		for cell in game.route:
			route_points.append((Vector2(cell) + Vector2.ONE * 0.5) * CELL)
		route_revision = game.revision
	if route_points.size() > 1:
		canvas.draw_polyline(route_points, Color("d5bc7766"), 10, true)
	# COUVERTURE : cercle de portée fixe de la tour choisie, derrière les constructions.
	if game.towers.has(selected):
		var point := (Vector2(selected) + Vector2.ONE * 0.5) * CELL
		var radius: float = game.tower_range(game.towers[selected]) * CELL
		canvas.draw_circle(point, radius, Color("efd58a12"))
		canvas.draw_arc(point, radius, 0, TAU, 64, Color("efd58a88"), 2, true)
	# TOURS PROVISOIRES : ombre, corps, toit ou cristal coloré, numéro de niveau et état de santé.
	for cell in game.towers:
		var p := (Vector2(cell) + Vector2.ONE * 0.5) * CELL
		if not visible.has_point(p):
			continue
		var tower: Dictionary = game.towers[cell]
		var color: Color = game.TYPES[int(tower.kind)].color
		canvas.draw_circle(p + Vector2(2, 3), 18, Color("15251b"))
		canvas.draw_rect(Rect2(p - Vector2(14, 13), Vector2(28, 30)), Color("b8af96"))
		if tower.kind <= 1:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -9), p + Vector2(0, -24), p + Vector2(18, -9)]), color)
		else:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -25), p + Vector2(10, -14), p + Vector2(0, -4), p + Vector2(-10, -14)]), color)
		if zoom > 0.4:
			canvas.draw_string(ThemeDB.fallback_font, p + Vector2(-5, 12), str(tower.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("263325"))
		if cell == selected:
			canvas.draw_rect(Rect2(p - Vector2(20, 20), Vector2(40, 40)), Color("f8dc8b"), false, 2)
		if tower.hp < 120.0 + (tower.level - 1) * 60:
			canvas.draw_line(p + Vector2(-16, 20), p + Vector2(-16 + 32 * tower.hp / (120.0 + (tower.level - 1) * 60), 20), Color("d67762"), 3)
	# REPÈRES : entrée et château restent identifiables même à faible zoom.
	var entry_point := (Vector2(game.entry) + Vector2.ONE * 0.5) * CELL
	canvas.draw_circle(entry_point, maxf(15.0, 5 / zoom), Color("c98644"))
	var castle := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * CELL
	if zoom < 0.3:
		canvas.draw_circle(castle, 5 / zoom, Color("ddd0ae"))
	canvas.draw_rect(Rect2(castle - Vector2(16, 18), Vector2(32, 36)), Color("ddd0ae"))
	canvas.draw_rect(Rect2(castle + Vector2(-5, 3), Vector2(10, 15)), Color("51422f"))
	# MONSTRES : couleur de résistance/type, teinte de givre, anneau de poison et barre de vie.
	# Les détails fins sont masqués à faible zoom pour garder une vue lisible.
	for enemy in game.enemies:
		var p: Vector2 = game.position_of(enemy) * CELL
		if not visible.has_point(p):
			continue
		var color := Color("c6b88a") if enemy.armor == "physical" else Color("bd91ce")
		if enemy.air:
			color = Color("edc96a")
		if enemy.boss > 0:
			color = Color("e47755")
		if enemy.slow_time > 0:
			color = Color("8ad8ea")
		var radius := 19.0 if enemy.boss == 2 else (15.0 if enemy.boss == 1 else 10.0)
		canvas.draw_circle(p, radius, color)
		if enemy.air:
			canvas.draw_line(p - Vector2(22, 10), p, color, 5)
			canvas.draw_line(p, p + Vector2(22, -10), color, 5)
		if not enemy.poison.is_empty():
			canvas.draw_arc(p, radius + 4, 0, TAU, 18, Color("96d768"), 2)
		if zoom > 0.4:
			canvas.draw_circle(p + Vector2(-3, -2), 2, Color("263325"))
			canvas.draw_circle(p + Vector2(3, -2), 2, Color("263325"))
			canvas.draw_line(p + Vector2(-15, -radius - 7), p + Vector2(15, -radius - 7), Color("492c26"), 3)
			canvas.draw_line(p + Vector2(-15, -radius - 7), p + Vector2(-15 + 30 * maxf(0, enemy.hp / enemy.max_hp), -radius - 7), Color("b2d078"), 3)
	# EFFETS DE TIR : segments et anneaux temporaires ; les dégâts ont déjà été appliqués par le modèle.
	for shot in game.shots:
		var color: Color = shot.color
		color.a = minf(1.0, shot.life / 0.18)
		canvas.draw_line(shot.from * CELL, shot.to * CELL, color, 3, true)
		if shot.splash:
			canvas.draw_arc(shot.to * CELL, CELL * 1.5 * (1.0 - color.a), 0, TAU, 24, color, 2, true)
	# VOILE DE PAUSE : convertit le rectangle d'écran en coordonnées du dessinateur transformé.
	if game.paused:
		canvas.draw_rect(Rect2(-pan / zoom, size / zoom), Color("000000aa"))
		canvas.draw_string(ThemeDB.fallback_font, (size / 2.0 - pan) / zoom, "PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 / zoom), Color("f8e2b1"))
