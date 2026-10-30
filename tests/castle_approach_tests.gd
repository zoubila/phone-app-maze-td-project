extends RefCounted
## Reproduit les achats refusés à tort au-dessus du château, où son image est transparente.

const Model = preload("res://game.gd")


## Les cases vides doivent rester constructibles sur chaque grille, en préparation, combat et pause.
static func run(suite) -> void:
	var game = Model.new()
	for grid in range(3):
		for state in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			for offset in [Vector2i(0, -5), Vector2i(-1, -5), Vector2i(0, -3), Vector2i(-1, -1), Vector2i(0, 1)]:
				game.reset(grid)
				game.active = bool(state.x)
				game.paused = bool(state.y)
				var cell: Vector2i = game.exit_cell + offset
				suite.check(not game.is_landmark_area(cell), "Empty cells around castle are no longer reserved")
				suite.check(game.build(cell, 0) and game.gold == 550, "Tower purchase above or beside castle succeeds and charges once")
				suite.check(game.flow[game.cell_id(game.entry)] >= 0, "New castle-adjacent tower preserves a path to the exit")
		game.reset(grid)
		suite.check(not game.build(game.exit_cell, 0), "Castle exit itself remains protected")
		for offset in [Vector2i(0, -2), Vector2i(0, -1)]:
			suite.check(not game.build(game.exit_cell + offset, 0), "Cells actually occupied by castle remain protected")

	# Vérifie aussi les vrais clics près du château, dans les deux orientations et après un zoom.
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		suite.root.size = dimensions
		var ui = load("res://main.tscn").instantiate()
		ui.developer_mode = true
		suite.root.add_child(ui)
		ui.set_process(false)
		await suite.process_frame
		for zoom in [0.8, 1.0]:
			ui.start_game(0)
			ui.board.castle_view()
			ui.board.set_zoom(zoom, ui.board.size / 2)
			var cell: Vector2i = ui.game.exit_cell + Vector2i(0, -5)
			var point: Vector2 = ui.board.pan + (Vector2(cell) + Vector2.ONE * 0.5) * ui.board.CELL * ui.board.zoom
			suite.gui_click(ui.board.get_global_transform_with_canvas() * point)
			suite.check(ui.game.towers.has(cell) and ui.game.gold == 550, "Actual click builds on the formerly forbidden empty approach cell")
		ui.queue_free()
		await suite.process_frame
