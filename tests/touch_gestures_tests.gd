extends RefCounted
## Simule deux doigts et les événements souris associés, sans dépendre d'un appareil physique.


## Envoie l'appui ou le relâchement d'un doigt identifié par son index.
static func finger(board, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	board._gui_input(event)


## Passe par l'entrée tactile de Godot, qui génère elle-même les clics destinés aux boutons et au plateau.
static func tap(suite, point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		event.window_id = suite.root.get_window_id()
		Input.parse_input_event(event)
	await suite.process_frame


## Vérifie le zoom direct à deux doigts, l'absence de double zoom natif et l'absence d'achat au relâchement.
static func run(suite) -> void:
	suite.root.size = Vector2i(1280, 720)
	await suite.process_frame
	var original_emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	var ui = load("res://main.tscn").instantiate()
	suite.root.add_child(ui)
	ui.set_process(false)
	await suite.process_frame
	await tap(suite, ui.menu_screen.start_button.get_global_rect().get_center())
	suite.check(not ui.in_menu, "Touch input starts gameplay from menu")
	await tap(suite, ui.type_buttons[2].get_global_rect().get_center())
	suite.check(ui.selected_kind == 2, "Touch input selects a tower type")
	var cell: Vector2i = ui.game.entry + Vector2i(3, -1)
	var point: Vector2 = ui.board.pan + (Vector2(cell) + Vector2.ONE * 0.5) * ui.board.CELL
	await tap(suite, ui.board.get_global_transform_with_canvas() * point)
	suite.check(ui.game.towers.has(cell), "Single finger still places a tower through mouse emulation")
	await tap(suite, ui.board.get_global_transform_with_canvas() * point)
	suite.check(ui.inspector.pinned, "Single finger opens the tower card")
	await tap(suite, ui.inspector.sell_button.get_global_rect().get_center())
	suite.check(ui.game.towers.is_empty(), "Touch input sells through the tower card")
	var board: Control = ui.board
	var center := board.size / 2.0
	var original_zoom: float = board.zoom
	var world: Vector2 = (center - board.pan) / board.zoom
	finger(board, 0, center - Vector2(60, 0), true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = center - Vector2(60, 0)
	board._gui_input(mouse)
	finger(board, 1, center + Vector2(60, 0), true)
	suite.check(not board.dragging, "Second finger cancels a possible construction click")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = center + Vector2(100, 0)
	board._gui_input(drag)
	suite.check(board.zoom > original_zoom, "Two touch points zoom without a native magnify event")
	var new_center := center + Vector2(20, 0)
	suite.check(((new_center - board.pan) / board.zoom).distance_to(world) < 0.01, "Pinch follows the moving midpoint of the fingers")
	var zoom: float = board.zoom
	var native := InputEventMagnifyGesture.new()
	native.position = center
	native.factor = 1.5
	board._gui_input(native)
	suite.near(board.zoom, zoom, "Native gesture is not applied twice while touch points are tracked")
	finger(board, 1, drag.position, false)
	finger(board, 0, mouse.position, false)
	mouse.pressed = false
	board._gui_input(mouse)
	suite.check(ui.game.towers.is_empty() and board.touch_gestures.points.is_empty(), "Releasing both fingers does not build a tower")
	Input.emulate_mouse_from_touch = original_emulation
	ui.queue_free()
	await suite.process_frame
