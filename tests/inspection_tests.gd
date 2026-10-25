extends RefCounted
## Vérifie les fiches des tours et monstres ainsi que la revente après sélection.
## Le scénario est répété sur plusieurs tailles d'écran pour couvrir le paysage, le portrait et les mises à l'échelle.




## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> void:
	var ui = load("res://main.tscn").instantiate()
	suite.root.add_child(ui)
	ui.set_process(false)
	ui.start_game(0)
	await suite.process_frame

	var board: Control = ui.board

	for dimensions in [
		Vector2i(1280, 720),
		Vector2i(720, 1280),
		Vector2i(1600, 720),
		Vector2i(1024, 768),
		Vector2i(1080, 2400),
		Vector2i(2400, 1080),
	]:
		ui.close_inspection()
		ui.game.reset(0)
		ui.game.gold = 100000
		ui.selected = Vector2i(-1, -1)
		suite.root.size = dimensions
		await suite.process_frame
		ui.apply_layout(true)
		board.entry_view()
		board.set_zoom(1.3, Vector2(35, board.size.y / 2))
		board.pan.x -= 200.0

		var first_cell: Vector2i = ui.game.entry + Vector2i(4, -1)
		var second_cell: Vector2i = ui.game.entry + Vector2i(8, -1)
		ui.game.build(first_cell, 0)
		ui.game.build(second_cell, 1)
		ui.game.start_wave()
		ui.game.paused = true
		ui.refresh_ui()
		await suite.process_frame

		# Ce point vise le toit, hors du centre de la case : c'est l'emplacement qui sélectionnait auparavant la mauvaise tour.
		var roof: Vector2 = board.pan + ((Vector2(first_cell) + Vector2.ONE * 0.5) * board.CELL + Vector2(
			0,
			-23,
		)) * board.zoom

		var screen_roof: Vector2 = board.get_global_transform_with_canvas() * roof
		var picked: Dictionary = board.pick_item(roof)
		suite.check(
			picked.get("type") == "tower" and picked.get("cell") == first_cell,
			"Visible roof selects tower rather than neighboring tile",
		)
		suite.gui_move(screen_roof)
		suite.check(
			ui.inspector.visible and not ui.inspector.pinned and ui.inspector.target.get("cell") == first_cell,
			"Tower hover opens a passive information card",
		)
		suite.check(ui.selected == Vector2i(-1, -1), "Hover never changes sale selection")
		suite.check(
			ui.inspector.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Hover card cannot block the selection click",
		)

		var before_gold: int = ui.game.gold
		suite.gui_click(screen_roof)
		suite.check(
			ui.selected == first_cell and ui.game.towers.size() == 2 and ui.game.gold == before_gold,
			"Roof click selects without buying an unintended tower",
		)
		suite.check(
			ui.inspector.pinned and ui.inspector.sell_button.visible and not ui.inspector.sell_button.disabled,
			"Touch card exposes an enabled sale action during paused combat",
		)
		suite.check(
			ui.inspector.body_label.text.contains("Vente : 35 or") and ui.inspector.body_label.text.contains("Portée fixe : 3.6"),
			"Tower card reports real refund and fixed range",
		)
		suite.check(
			Rect2(board.position, board.size).encloses(Rect2(ui.inspector.position, ui.inspector.size)),
			"Tower card fits within board in every orientation",
		)

		var second_roof: Vector2 = board.pan + ((Vector2(second_cell) + Vector2.ONE * 0.5) * board.CELL + Vector2(
			0,
			-23,
		)) * board.zoom
		suite.gui_move(board.get_global_transform_with_canvas() * second_roof)
		suite.check(
			ui.selected == first_cell and ui.inspector.target.get("cell") == first_cell,
			"Hover cannot replace a pinned tower or redirect a sale",
		)
		suite.gui_click(ui.inspector.sell_button.get_global_transform_with_canvas() * (ui.inspector.sell_button.size / 2))
		suite.check(
			not ui.game.towers.has(first_cell) and ui.game.towers.has(second_cell),
			"Context sale removes the chosen tower only",
		)
		suite.check(
			ui.game.gold == before_gold + 35 and ui.game.towers.size() == 1,
			"Context sale refunds once and creates no ghost tower",
		)
		suite.check(
			not ui.inspector.visible and ui.selected == Vector2i(-1, -1),
			"Sale dismisses stale card and selection",
		)
		suite.gui_click(board.get_global_transform_with_canvas() * second_roof)
		suite.check(ui.selected == second_cell, "Another tower can be selected after a contextual sale")

		var refund = int(ui.game.towers[second_cell].spent * 0.7)
		before_gold = ui.game.gold
		suite.gui_click(ui.inspector.sell_button.get_global_transform_with_canvas() * (ui.inspector.sell_button.size / 2))
		suite.check(
			ui.game.towers.is_empty() and ui.game.gold == before_gold + refund,
			"Second tower can be sold from its contextual information",
		)
		suite.gui_move(ui.type_buttons[2].get_global_transform_with_canvas() * (ui.type_buttons[2].size / 2))
		suite.check(
			ui.inspector.visible and not ui.inspector.pinned and ui.inspector.target.get("kind") == 2,
			"Catalog tower hover displays stats",
		)
		suite.gui_click(ui.type_buttons[2].get_global_transform_with_canvas() * (ui.type_buttons[2].size / 2))
		suite.check(
			ui.inspector.pinned and ui.inspector.target.get("type") == "catalog",
			"Catalog click keeps tower information visible on mobile",
		)

		var build_point: Vector2 = board.pan + (Vector2(first_cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom
		suite.gui_click(board.get_global_transform_with_canvas() * build_point)
		suite.check(
			ui.game.towers.has(first_cell) and ui.game.towers[first_cell].kind == 2,
			"Catalog information does not require an extra tap before building",
		)
		suite.check(not ui.inspector.visible, "Construction dismisses catalog card")
		suite.gui_click(board.get_global_transform_with_canvas() * roof)
		suite.gui_click(ui.inspector.upgrade_button.get_global_transform_with_canvas() * (ui.inspector.upgrade_button.size / 2))
		suite.check(
			ui.game.towers[first_cell].level == 2 and ui.inspector.title_label.text.contains("N2/7"),
			"Context upgrade updates level and pinned stats",
		)
		suite.gui_click(ui.inspector.close_button.get_global_transform_with_canvas() * (ui.inspector.close_button.size / 2))
		suite.check(
			not ui.inspector.visible and ui.selected == first_cell,
			"Closing card preserves the selected tower for its range and later inspection",
		)

		# La fiche d'un monstre doit suivre ses points de vie, mais ne doit ni acheter ni vendre de tour.
		var monster: Dictionary = ui.game.spawn_enemy()
		monster.cell = ui.game.entry + Vector2i(6, 0)
		monster.next = monster.cell + Vector2i.RIGHT
		monster.fraction = 0.5

		var other: Dictionary = ui.game.spawn_enemy()
		other.cell = ui.game.entry + Vector2i(10, 0)
		other.next = other.cell + Vector2i.RIGHT
		suite.check(monster.id != other.id, "Identical units receive stable distinct inspection identifiers")

		var monster_point: Vector2 = board.pan + ui.game.position_of(monster) * board.CELL * board.zoom
		suite.gui_move(board.get_global_transform_with_canvas() * monster_point)
		suite.check(
			ui.inspector.visible and not ui.inspector.pinned and ui.inspector.target.get("id") == monster.id,
			"Monster hover opens its information card",
		)
		suite.check(ui.selected == first_cell, "Monster hover does not clear the tower selected for sale")

		var tower_count: int = ui.game.towers.size()
		suite.gui_click(board.get_global_transform_with_canvas() * monster_point)
		suite.check(
			ui.inspector.pinned and ui.inspector.target.get("id") == monster.id,
			"Monster touch pins the correct unit",
		)
		suite.check(
			ui.game.towers.size() == tower_count and ui.selected == Vector2i(-1, -1),
			"Monster inspection neither buys a tower nor keeps a misleading sale target",
		)
		monster.hp = 37.0
		monster.slow_time = 1.2
		monster.slow_factor = 0.6
		monster.poison[Vector2i(1, 1)] = {"time": 2.0, "dps": 7.0}

		var card_position: Vector2 = ui.inspector.position
		monster.fraction = 0.8
		ui.refresh_ui()
		suite.check(
			ui.inspector.position == card_position,
			"Pinned mobile card stays still while its monster moves",
		)
		suite.check(
			ui.inspector.body_label.text.contains("PV : 37 /") and ui.inspector.body_label.text.contains("Poison : 1"),
			"Pinned monster card refreshes HP and active effects",
		)
		suite.check(
			not ui.inspector.sell_button.visible and not ui.inspector.upgrade_button.visible,
			"Monster card never exposes tower sale actions",
		)
		suite.check(
			Rect2(board.position, board.size).encloses(Rect2(ui.inspector.position, ui.inspector.size)),
			"Monster card stays within screen in all orientations",
		)
		monster.hp = 0.0
		ui.refresh_ui()
		suite.check(not ui.inspector.visible, "Dead unit card closes instead of switching to another unit")
		ui.inspect_item(
			{"type": "enemy", "id": other.id},
			board.pan + ui.game.position_of(other) * board.CELL * board.zoom,
		)
		before_gold = ui.game.gold
		suite.gui_click(board.get_global_transform_with_canvas() * Vector2(8, 8))
		suite.check(
			not ui.inspector.visible and ui.game.gold == before_gold and ui.game.towers.size() == tower_count,
			"Tap outside entity card dismisses it without purchasing",
		)
		suite.gui_click(board.get_global_transform_with_canvas() * roof)

		var drag_start: Vector2 = board.get_global_transform_with_canvas() * Vector2(50, 50)
		var down = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = drag_start
		suite.root.push_input(down, true)

		var drag = InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.position = drag_start + Vector2(-40, 40)
		suite.root.push_input(drag, true)
		down = down.duplicate()
		down.pressed = false
		down.position = drag.position
		suite.root.push_input(down, true)
		suite.check(
			not ui.inspector.visible and ui.game.towers.size() == tower_count,
			"Dragging closes the card without buying or selling",
		)

	var remaining_cell: Vector2i = ui.game.towers.keys()[0]
	ui.inspect_item(
		{"type": "tower", "cell": remaining_cell},
		board.pan + (Vector2(remaining_cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom,
	)
	suite.root.size = Vector2i(720, 1280)
	await suite.process_frame
	ui.apply_layout(true)
	ui.refresh_ui()
	suite.check(
		ui.inspector.visible and ui.inspector.pinned and ui.inspector.target.cell == remaining_cell,
		"Rotation preserves the pinned tower sale target",
	)
	suite.check(
		Rect2(board.position, board.size).encloses(Rect2(ui.inspector.position, ui.inspector.size)),
		"Pinned card refits screen after rotation",
	)
	ui.game.paused = false

	var before_live_sale: int = ui.game.gold
	var live_refund = int(ui.game.towers[remaining_cell].spent * 0.7)
	suite.gui_click(ui.inspector.sell_button.get_global_transform_with_canvas() * (ui.inspector.sell_button.size / 2))
	suite.check(
		not ui.game.towers.has(remaining_cell) and ui.game.gold == before_live_sale + live_refund,
		"Context sale works in unpaused combat after rotating",
	)
	ui.queue_free()
	await suite.process_frame
