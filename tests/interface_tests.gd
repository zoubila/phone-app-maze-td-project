extends RefCounted
## Vérifie le parcours menu → partie → résultat, ainsi que le plateau agrandi et ses commandes flottantes.
## Les six formats simulent les deux orientations, une tablette et les écrans allongés, sans prétendre remplacer un essai physique.


## Exécute les mêmes actions avec les coordonnées réelles de chaque disposition.
static func run(suite) -> void:
	for dimensions in [
		Vector2i(1280, 720),
		Vector2i(720, 1280),
		Vector2i(1600, 720),
		Vector2i(1024, 768),
		Vector2i(1080, 2400),
		Vector2i(2400, 1080),
	]:
		suite.root.size = dimensions

		var ui = load("res://main.tscn").instantiate()
		suite.root.add_child(ui)
		ui.set_process(false)
		await suite.process_frame
		ui.apply_layout(true)
		suite.check(
			ui.in_menu and ui.menu_screen.visible and not ui.board.visible,
			"Application opens in menu, not in a running game",
		)
		ui._process(61.0)
		suite.check(
			ui.game.wave == 0 and ui.game.preparation == 60,
			"Waiting in menu does not start a wave or consume preparation",
		)

		var choice: int = int(dimensions.x) % 3
		ui.menu_screen.grid_choice.select(choice)
		suite.gui_click(ui.menu_screen.options_button.get_global_rect().get_center())
		suite.check(ui.in_menu and ui.game.wave == 0, "Options is a placeholder with no gameplay effect")
		suite.gui_click(ui.menu_screen.start_button.get_global_rect().get_center())
		suite.check(
			not ui.in_menu and not ui.menu_screen.visible and ui.board.visible,
			"Start button enters gameplay",
		)
		suite.check(ui.game.cols == ui.game.GRID_SIZES[choice].x, "Menu grid selection is used by the new game")
		suite.check(
			ui.game.preparation == 60 and ui.game.wave == 0,
			"Preparation begins only after starting the game",
		)

		# Le plateau doit occuper au moins 80 % de la surface, contre environ 40 % auparavant en paysage.
		var bounds: Rect2 = Rect2(Vector2.ZERO, ui.layout_size).grow(0.1)
		var board_rect: Rect2 = Rect2(ui.board.position, ui.board.size)
		suite.check(
			board_rect.get_area() / bounds.get_area() > 0.80,
			"Board occupies more than 80 percent of usable screen",
		)
		suite.check(ui.type_buttons.size() == 8, "Construction catalog contains exactly eight towers")

		for button in ui.type_buttons:
			var rect := Rect2(button.position, button.size)
			suite.check(bounds.encloses(rect), "Tower button stays inside safe layout")
			suite.check(not board_rect.intersects(rect), "Tower catalog does not cover the playable board")

		for button in [ui.pause_button, ui.speed_button, ui.settings_button, ui.wave_button]:
			suite.check(
				board_rect.encloses(Rect2(button.position, button.size)),
				"Floating command stays over the board background",
			)
		suite.check(
			not ui.has_method("sell_selected") and not ui.has_method("upgrade_selected"),
			"Obsolete global tower actions are removed",
		)
		suite.gui_click(ui.wave_button.get_global_rect().get_center())
		suite.check(
			ui.game.active and ui.game.wave == 1 and not ui.wave_button.visible,
			"Early wave launch works and hides during combat",
		)
		suite.gui_click(ui.speed_button.get_global_rect().get_center())
		suite.check(
			ui.game.speed_multiplier == 2 and ui.speed_button.text == "Vitesse ×2",
			"Floating speed command uses new label",
		)
		suite.gui_click(ui.pause_button.get_global_rect().get_center())
		suite.check(ui.game.paused, "Floating pause command works")

		var cell: Vector2i = ui.game.entry + Vector2i(3, -1)
		suite.gui_click(ui.type_buttons[4].get_global_rect().get_center())

		var point: Vector2 = ui.board.pan + (Vector2(cell) + Vector2.ONE * 0.5) * ui.board.CELL * ui.board.zoom
		suite.gui_click(ui.board.get_global_transform_with_canvas() * point)
		suite.check(
			ui.game.towers.has(cell) and ui.game.towers[cell].kind == 4,
			"Catalog places ballista on the larger board",
		)
		suite.gui_click(ui.board.get_global_transform_with_canvas() * point)
		suite.check(ui.inspector.pinned, "Touching placed tower opens its actions")
		suite.check(
			ui.inspection_bounds().encloses(Rect2(ui.inspector.position, ui.inspector.size)),
			"Card avoids floating controls",
		)
		suite.gui_click(ui.inspector.upgrade_button.get_global_rect().get_center())
		suite.check(ui.game.towers[cell].level == 2, "Upgrade is available exclusively through tower card")

		var before_sale: int = ui.game.gold
		var refund := int(ui.game.towers[cell].spent * 0.7)
		suite.gui_click(ui.inspector.sell_button.get_global_rect().get_center())
		suite.check(
			not ui.game.towers.has(cell) and ui.game.gold == before_sale + refund,
			"Tower-card sale works on the redesigned board",
		)

		# La molette et le pincement remplacent les anciens boutons moins et plus.
		var anchor: Vector2 = ui.board.size / 2.0
		var world: Vector2 = (anchor - ui.board.pan) / ui.board.zoom
		var previous_zoom: float = ui.board.zoom
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = anchor
		ui.board._gui_input(wheel)
		suite.check(ui.board.zoom > previous_zoom, "Mouse wheel zoom works without buttons")
		suite.check(
			((anchor - ui.board.pan) / ui.board.zoom).distance_to(world) < 0.01,
			"Zoom keeps the world point under the pointer",
		)

		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = anchor
		ui.board._gui_input(down)
		ui.board._gui_input(wheel)
		down.pressed = false
		ui.board._gui_input(down)
		suite.check(ui.game.towers.is_empty(), "Mouse hold plus wheel zoom does not purchase a tower")
		down.pressed = true
		ui.board._gui_input(down)
		previous_zoom = ui.board.zoom

		var gesture := InputEventMagnifyGesture.new()
		gesture.position = anchor
		gesture.factor = 1.25
		ui.board._gui_input(gesture)
		down.pressed = false
		ui.board._gui_input(down)
		suite.check(
			ui.board.zoom > previous_zoom and ui.game.towers.is_empty(),
			"Pinch zoom cannot finish as an accidental purchase",
		)

		# Un glissement doit rester un déplacement de caméra, sans construction.
		var old_pan: Vector2 = ui.board.pan
		down.pressed = true
		down.position = Vector2(100, 180)
		ui.board._gui_input(down)

		var motion := InputEventMouseMotion.new()
		motion.position = down.position + Vector2(-60, 30)
		ui.board._gui_input(motion)
		down.pressed = false
		down.position = motion.position
		ui.board._gui_input(down)
		suite.check(
			ui.board.pan != old_pan and ui.game.towers.is_empty(),
			"Dragging pans without placing a tower",
		)

		var gold: int = ui.game.gold
		# La fenêtre interrompt le temps, bloque les achats et conserve la pause après fermeture.
		suite.gui_click(ui.settings_button.get_global_rect().get_center())
		suite.check(ui.settings_screen.visible, "Gear opens settings")
		var remaining: float = ui.game.preparation
		ui._process(1.0)
		suite.check(ui.game.preparation == remaining, "Settings suspends the game clock")
		suite.gui_click(ui.type_buttons[0].get_global_rect().get_center())
		suite.check(not ui.inspector.visible, "Settings veil blocks the tower catalog")
		suite.gui_click(ui.settings_screen.options_button.get_global_rect().get_center())
		suite.check(ui.settings_screen.visible and not ui.in_menu, "Settings Options remains a placeholder")
		suite.gui_click(ui.settings_screen.close_button.get_global_rect().get_center())
		suite.check(not ui.settings_screen.visible and ui.game.paused, "Closing settings preserves pause")
		var wave: int = ui.game.wave
		suite.root.size = Vector2i(dimensions.y, dimensions.x)
		await suite.process_frame
		ui.apply_layout(true)
		ui.refresh_ui()
		suite.check(
			ui.game.gold == gold and ui.game.wave == wave and ui.game.paused,
			"Rotation preserves a live paused game",
		)

		for victory in [false, true]:
			ui.game.ended = true
			ui.game.won = victory
			ui.refresh_ui()
			suite.check(
				ui.end_screen.visible and not ui.wave_button.visible,
				"Result screen replaces wave launch after victory or defeat",
			)

			var center: Vector2 = ui.end_screen.position + ui.end_screen.card.position + ui.end_screen.card.size / 2
			var expected: Vector2 = ui.board.position + ui.board.size / 2
			suite.check(center.distance_to(expected) < 0.01, "Replay panel is centered over the board")
			suite.check(
				ui.end_screen.title.text == ("Victoire !" if victory else "Défaite"),
				"Result text matches victory or defeat",
			)
			suite.gui_click(ui.end_screen.replay_button.get_global_rect().get_center())
			suite.check(
				not ui.game.ended and ui.game.wave == 0 and not ui.end_screen.visible,
				"Central Replay button resets the game",
			)
			suite.check(ui.game.cols == ui.game.GRID_SIZES[choice].x, "Replay keeps chosen grid size")
			ui.game.ended = true
			ui.game.won = victory
			ui.refresh_ui()
			suite.gui_click(ui.end_screen.home_button.get_global_rect().get_center())
			suite.check(ui.in_menu and ui.menu_screen.visible and not ui.end_screen.visible, "Result returns to home after win or loss")
			suite.gui_click(ui.menu_screen.start_button.get_global_rect().get_center())
			suite.check(not ui.in_menu and not ui.game.ended and ui.game.wave == 0, "Start after home creates a fresh game")

		# Le retour depuis les paramètres ferme aussi la fenêtre et immobilise le compte à rebours.
		suite.gui_click(ui.settings_button.get_global_rect().get_center())
		var preparation: float = ui.game.preparation
		ui._process(1.0)
		suite.check(not ui.game.paused and ui.game.preparation == preparation, "Settings also suspends an unpaused game")
		suite.root.size = dimensions
		await suite.process_frame
		ui.apply_layout(true)
		suite.check(
			ui.settings_screen.visible and ui.settings_screen.card.position.is_equal_approx((ui.layout_size - ui.settings_screen.card.size) / 2),
			"Settings stays centered and open after rotation",
		)
		suite.gui_click(ui.settings_screen.home_button.get_global_rect().get_center())
		suite.check(ui.in_menu and not ui.settings_screen.visible, "Settings returns to home")
		ui._process(61.0)
		suite.check(ui.game.wave == 0 and ui.game.preparation == 60, "Home remains idle after leaving gameplay")

		var safe_area := Rect2(40, 24, 1200, 656)
		preload("res://ui_layout.gd").arrange(ui, safe_area)
		suite.check(
			safe_area.grow(0.1).encloses(Rect2(ui.position, ui.layout_size * ui.scale)),
			"New UI respects simulated mobile safe area",
		)
		ui.queue_free()
		await suite.process_frame

	suite.check(
		ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures"),
		"Android native pinch gesture support is enabled",
	)
