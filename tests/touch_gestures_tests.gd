extends RefCounted
## Simule deux doigts et les événements souris associés, sans dépendre d'un appareil physique.


## Envoie l'appui ou le relâchement d'un doigt identifié par son index.
static func finger(board, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	board._input(event.xformed_by(board.get_global_transform_with_canvas()))


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


## Envoie un contact réel au moteur, sans inventer de clic souris ni attendre entre les deux doigts.
static func raw_finger(suite, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	# parse_input_event attend les pixels de fenêtre ; le moteur les reconvertit ensuite vers le viewport.
	event.position = suite.root.get_final_transform() * point
	event.pressed = pressed
	event.canceled = canceled
	event.window_id = suite.root.get_window_id()
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Le déplacement utilise les coordonnées du viewport, afin de tester aussi l'échelle de l'interface mobile.
static func raw_drag(suite, index: int, point: Vector2, previous: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	var transform: Transform2D = suite.root.get_final_transform()
	event.position = transform * point
	event.relative = transform.basis_xform(point - previous)
	event.window_id = suite.root.get_window_id()
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Répète des pincements immédiats et inversés ; aucun appui long ni événement de souris manuel n'est utilisé.
static func immediate_pinch(suite, ui) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(2400, 1080)]:
		suite.root.size = dimensions
		await suite.process_frame
		ui.apply_layout(true)
		for identifiers in [[0, 1], [1, 0], [8, 2], [2, 8]]:
			var board = ui.board
			board.entry_view()
			var transform: Transform2D = board.get_global_transform_with_canvas()
			var center: Vector2 = board.size / 2
			var left: Vector2 = transform * (center - Vector2(60, 0))
			var right: Vector2 = transform * (center + Vector2(60, 0))
			var farther: Vector2 = transform * (center + Vector2(100, 0))
			var first: int = identifiers[0]
			var second: int = identifiers[1]
			var gold: int = ui.game.gold
			var zoom: float = board.zoom
			# Même image, aucune pause : c'est précisément le geste signalé comme défaillant sur téléphone.
			raw_finger(suite, first, left, true)
			raw_finger(suite, second, right, true)
			suite.check(board.touch_gestures.points.size() == 2, "Two simultaneous raw touches are tracked without holding the first finger")
			raw_drag(suite, second, farther, right)
			suite.check(board.zoom > zoom, "Immediate two-finger separation zooms through the actual input pipeline")
			var enlarged: float = board.zoom
			raw_drag(suite, second, right, farther)
			suite.check(board.zoom < enlarged, "Immediate two-finger pinch also zooms out")
			raw_finger(suite, first, left, false)
			# Le doigt restant ne doit pas reprendre la construction après avoir servi au zoom.
			raw_drag(suite, second, farther, right)
			raw_finger(suite, second, farther, false)
			await suite.process_frame
			suite.check(ui.game.towers.is_empty() and ui.game.gold == gold, "Immediate pinch and remaining-finger motion never purchase a tower")
			suite.check(board.touch_gestures.points.is_empty() and not board.touch_gestures.pinched, "All contacts are released before the next pinch")

	# Une annulation système doit terminer le geste ; le prochain pincement doit fonctionner normalement.
	var board = ui.board
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var left: Vector2 = transform * (board.size / 2 - Vector2(60, 0))
	var right: Vector2 = transform * (board.size / 2 + Vector2(60, 0))
	raw_finger(suite, 0, left, true)
	raw_finger(suite, 1, right, true)
	raw_finger(suite, 0, left, false, true)
	raw_finger(suite, 1, right, false, true)
	suite.check(board.touch_gestures.points.is_empty() and not board.dragging, "Canceled gesture leaves no stuck fingers or construction press")
	suite.check(ui.game.towers.is_empty(), "Canceled pinch never ends as a purchase")

	# Un doigt sur une commande et un doigt sur la carte ne constituent pas un pincement de la carte.
	var zoom: float = board.zoom
	var pause_point: Vector2 = ui.pause_button.get_global_rect().get_center()
	raw_finger(suite, 0, pause_point, true)
	raw_finger(suite, 1, right, true)
	suite.check(board.touch_gestures.points.size() == 1, "Floating HUD button cannot become a camera gesture contact")
	raw_drag(suite, 1, right + Vector2(50, 0), right)
	suite.near(board.zoom, zoom, "A HUD touch plus one map finger does not zoom")
	raw_finger(suite, 0, pause_point, false)
	raw_finger(suite, 1, right + Vector2(50, 0), false)
	ui.open_settings()
	raw_finger(suite, 0, left, true)
	raw_finger(suite, 1, right, true)
	suite.check(board.touch_gestures.points.is_empty(), "Settings modal blocks new camera contacts")
	raw_finger(suite, 0, left, false)
	raw_finger(suite, 1, right, false)
	ui.settings_screen.hide()


## Vérifie le zoom direct à deux doigts, l'absence de double zoom natif et l'absence d'achat au relâchement.
static func run(suite) -> void:
	suite.root.size = Vector2i(1280, 720)
	await suite.process_frame
	var original_emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	var ui = load("res://main.tscn").instantiate()
	ui.developer_mode = true
	suite.root.add_child(ui)
	ui.set_process(false)
	await suite.process_frame
	await tap(suite, ui.menu_screen.start_button.get_global_rect().get_center())
	suite.check(not ui.in_menu, "Touch input starts gameplay from menu")
	await tap(suite, ui.type_buttons[2].get_global_rect().get_center())
	suite.check(ui.selected_kind == 2, "Touch input selects a tower type")
	var landmark_gold: int = ui.game.gold
	for landmark_index in [1]:
		var reserved_cell: Vector2i = ui.game.entry + Vector2i(1, -1)
		if landmark_index == 1:
			ui.board.castle_view()
			reserved_cell = ui.game.exit_cell + Vector2i(0, -1)
		var reserved_point: Vector2 = ui.board.pan + (Vector2(reserved_cell) + Vector2.ONE * 0.5) * ui.board.CELL * ui.board.zoom
		await tap(suite, ui.board.get_global_transform_with_canvas() * reserved_point)
		suite.check(ui.game.towers.is_empty() and ui.game.gold == landmark_gold, "Touching the castle never purchases a tower")
	ui.board.entry_view()
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
	board._input(drag.xformed_by(board.get_global_transform_with_canvas()))
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
	await immediate_pinch(suite, ui)
	Input.emulate_mouse_from_touch = original_emulation
	ui.queue_free()
	await suite.process_frame
