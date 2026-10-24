extends Control
## Clipped, pannable and zoomable board; positions are independent of gameplay.
const CELL := 42.0
var game
var selected := Vector2i(-1, -1)
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var moved := false
var start := Vector2.ZERO
var pan_start := Vector2.ZERO
var route_revision := -1
var route_points := PackedVector2Array()
var painter: Node2D
signal cell_tapped(cell: Vector2i)

class MapPainter extends Node2D:
	var view
	func _draw() -> void:
		view.paint(self)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	painter = MapPainter.new()
	painter.view = self
	add_child(painter)
	entry_view()

func refresh() -> void:
	if painter != null:
		painter.position = pan
		painter.scale = Vector2.ONE * zoom
		painter.queue_redraw()
	queue_redraw()

func minimum_zoom() -> float:
	return minf(size.x / (game.cols * CELL), size.y / (game.rows * CELL)) * 0.95

func set_zoom(value: float, anchor: Vector2) -> void:
	var world := (anchor - pan) / zoom
	zoom = clampf(value, minimum_zoom(), 2.0)
	pan = anchor - world * zoom
	clamp_pan()
	refresh()

func clamp_pan() -> void:
	var world := Vector2(game.cols, game.rows) * CELL * zoom
	pan.x = clampf(pan.x, minf(24.0, size.x - world.x - 24.0), maxf(24.0, size.x - world.x - 24.0))
	pan.y = clampf(pan.y, minf(24.0, size.y - world.y - 24.0), maxf(24.0, size.y - world.y - 24.0))

func entry_view() -> void:
	zoom = 1.0
	pan = Vector2(35, size.y / 2.0) - (Vector2(game.entry) + Vector2.ONE * 0.5) * CELL * zoom
	clamp_pan()
	refresh()

func castle_view() -> void:
	zoom = 1.0
	pan = Vector2(size.x - 35, size.y / 2.0) - (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * CELL * zoom
	clamp_pan()
	refresh()

func overview() -> void:
	zoom = minimum_zoom()
	pan = (size - Vector2(game.cols, game.rows) * CELL * zoom) / 2.0
	refresh()

func cell_at(point: Vector2) -> Vector2i:
	var local := (point - pan) / (zoom * CELL)
	return Vector2i(floori(local.x), floori(local.y))

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
					var cell := cell_at(event.position)
					if game.inside(cell):
						if zoom * CELL < 20:
							set_zoom(1.0, event.position)
						else:
							cell_tapped.emit(cell)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(start) > 10:
			moved = true
		if moved:
			pan = pan_start + event.position - start
			clamp_pan()
			refresh()
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * event.factor, event.position)
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17271d"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("89744c"), false, 3)

func paint(canvas: Node2D) -> void:
	if game == null:
		return
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
	if route_revision != game.revision:
		route_points.clear()
		for cell in game.route:
			route_points.append((Vector2(cell) + Vector2.ONE * 0.5) * CELL)
		route_revision = game.revision
	if route_points.size() > 1:
		canvas.draw_polyline(route_points, Color("d5bc7766"), 10, true)
	if game.towers.has(selected):
		var point := (Vector2(selected) + Vector2.ONE * 0.5) * CELL
		var radius: float = game.tower_range(game.towers[selected]) * CELL
		canvas.draw_circle(point, radius, Color("efd58a12"))
		canvas.draw_arc(point, radius, 0, TAU, 64, Color("efd58a88"), 2, true)
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
	var entry_point := (Vector2(game.entry) + Vector2.ONE * 0.5) * CELL
	canvas.draw_circle(entry_point, maxf(15.0, 5 / zoom), Color("c98644"))
	var castle := (Vector2(game.exit_cell) + Vector2.ONE * 0.5) * CELL
	if zoom < 0.3:
		canvas.draw_circle(castle, 5 / zoom, Color("ddd0ae"))
	canvas.draw_rect(Rect2(castle - Vector2(16, 18), Vector2(32, 36)), Color("ddd0ae"))
	canvas.draw_rect(Rect2(castle + Vector2(-5, 3), Vector2(10, 15)), Color("51422f"))
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
	for shot in game.shots:
		var color: Color = shot.color
		color.a = minf(1.0, shot.life / 0.18)
		canvas.draw_line(shot.from * CELL, shot.to * CELL, color, 3, true)
		if shot.splash:
			canvas.draw_arc(shot.to * CELL, CELL * 1.5 * (1.0 - color.a), 0, TAU, 24, color, 2, true)
	if game.paused:
		canvas.draw_rect(Rect2(-pan / zoom, size / zoom), Color("000000aa"))
		canvas.draw_string(ThemeDB.fallback_font, (size / 2.0 - pan) / zoom, "PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 / zoom), Color("f8e2b1"))
