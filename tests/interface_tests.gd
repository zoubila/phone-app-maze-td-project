extends RefCounted
## Vérifie les commandes avec des événements de souris envoyés à une véritable scène Godot.
## La simulation est figée pendant les clics ; le test peut ainsi examiner précisément l'effet de chaque bouton.




## Exécute les scénarios de ce fichier. suite fournit les fonctions check et near.
## check compte une vérification ; near compare des nombres avec une petite tolérance d'arrondi.
static func run(suite) -> void:
	var scene = load("res://main.tscn").instantiate()
	suite.root.size = Vector2i(720, 1280)
	suite.root.add_child(scene)

	# On arrête l'avancement automatique de la partie pendant les clics pour garder les résultats reproductibles.
	scene.set_process(false)
	await suite.process_frame
	suite.check(
		not scene.wave_button.disabled and scene.wave_button.text.contains("60"),
		"First-wave launch button is enabled at 60 seconds",
	)
	suite.gui_click(scene.wave_button.get_global_rect().get_center())
	suite.check(
		scene.game.active and scene.game.wave == 1 and scene.game.preparation == 0,
		"GUI click starts first wave without waiting",
	)

	var board: Control = scene.board
	var test_cell: Vector2i = scene.game.entry + Vector2i(2, 0)
	var screen: Vector2 = (Vector2(test_cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom + board.pan
	suite.check(board.cell_at(screen) == test_cell, "Screen-to-grid mapping")

	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	board._gui_input(press)
	press = press.duplicate()
	press.pressed = false
	board._gui_input(press)
	suite.check(scene.game.towers.has(test_cell), "Tap creates a tower through UI signal")
	scene.game.gold = 10000
	scene.game.preparation = 0
	scene.game.start_wave()
	scene.refresh_ui()
	await suite.process_frame
	suite.check(
		not scene.upgrade_button.disabled and not scene.sell_button.disabled,
		"Upgrade and sale buttons enabled during combat",
	)
	suite.gui_click(scene.upgrade_button.get_global_rect().get_center())
	suite.check(scene.game.towers[test_cell].level == 2, "Real GUI click upgrades a tower during combat")

	var sale_gold: int = scene.game.gold
	var expected_refund = int(scene.game.towers[test_cell].spent * 0.7)
	suite.gui_click(scene.sell_button.get_global_rect().get_center())
	suite.check(
		not scene.game.towers.has(test_cell) and scene.game.gold == sale_gold + expected_refund,
		"Real GUI click sells and credits refund during combat",
	)
	suite.gui_click(scene.type_buttons[4].get_global_rect().get_center())
	suite.check(scene.selected_kind == 4, "Ballista menu button selects antiair class")
	suite.gui_click(board.global_position + screen)
	suite.check(
		scene.game.towers.has(test_cell) and scene.game.towers[test_cell].kind == 4,
		"Ballista can be placed through actual GUI during combat",
	)
	scene.game.paused = true
	scene.refresh_ui()
	suite.gui_click(scene.upgrade_button.get_global_rect().get_center())
	suite.check(scene.game.towers[test_cell].level == 2, "Real GUI click upgrades in pause")
	suite.gui_click(scene.sell_button.get_global_rect().get_center())
	suite.check(not scene.game.towers.has(test_cell), "Real GUI click sells in pause")

	for speed in [2, 3, 5, 1]:
		suite.gui_click(scene.speed_button.get_global_rect().get_center())
		suite.check(
			scene.game.speed_multiplier == speed and scene.speed_button.text.contains(str(speed)),
			"Speed button cycles 1/2/3/5 and updates label",
		)

	var tower_count: int = scene.game.towers.size()
	press.pressed = true
	board._gui_input(press)

	var motion = InputEventMouseMotion.new()
	motion.position = screen + Vector2(-60, 30)
	board._gui_input(motion)
	press.pressed = false
	press.position = motion.position
	board._gui_input(press)
	suite.check(scene.game.towers.size() == tower_count, "Dragging never places a tower")

	var anchor = Vector2(300, 300)
	var world: Vector2 = (anchor - board.pan) / board.zoom
	board.set_zoom(1.3, anchor)
	suite.check(((anchor - board.pan) / board.zoom).distance_to(world) < 0.01, "Zoom preserves anchor")
	board.overview()
	suite.check(board.zoom < 0.2, "Overview supports full-sized maps")

	var before_overview: int = scene.game.towers.size()
	press.position = board.size / 2
	press.pressed = true
	board._gui_input(press)
	press = press.duplicate()
	press.pressed = false
	board._gui_input(press)
	suite.check(
		board.zoom == 1.0 and scene.game.towers.size() == before_overview,
		"Overview tap zooms without accidental construction",
	)
	board.castle_view()
	suite.check(
		board.cell_at(Vector2(
			board.size.x - board.scenery.LANDMARK_INSET,
			board.size.y / 2,
		)) == scene.game.exit_cell,
		"Castle shortcut frames the gate with room for its silhouette",
	)
	suite.check(
		ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR,
		"Phone sensor enables portrait and landscape",
	)
	suite.check(
		ProjectSettings.get_setting("display/window/size/window_width_override") > ProjectSettings.get_setting("display/window/size/window_height_override"),
		"Default desktop window is landscape",
	)
	scene.game.gold = 100000
	scene.game.build(scene.game.entry + Vector2i(1, 2), 0)

	var rotation_enemy: Dictionary = scene.game.spawn_enemy()
	rotation_enemy.fraction = 0.25

	var rotation_position: Vector2 = scene.game.position_of(rotation_enemy)
	var expected_wave: int = scene.game.wave
	var expected_gold: int = scene.game.gold
	var expected_towers: int = scene.game.towers.size()
	board.zoom = 1.0
	board.pan = board.size / 2.0 - Vector2(25, 25) * board.CELL

	var focus_before: Vector2 = (board.size / 2.0 - board.pan) / board.zoom

	# On simule plusieurs fenêtres : le paysage, le portrait, la tablette et les écrans très allongés.
	for dimensions in [
		Vector2i(1280, 720),
		Vector2i(720, 1280),
		Vector2i(1600, 720),
		Vector2i(1024, 768),
		Vector2i(1080, 2400),
		Vector2i(2400, 1080),
	]:
		suite.root.size = dimensions
		await suite.process_frame
		scene.apply_layout(true)
		scene.refresh_ui()
		await suite.process_frame
		suite.check(scene.landscape == (dimensions.x >= dimensions.y), "Layout follows device orientation")
		suite.check(
			scene.game.wave == expected_wave and scene.game.gold == expected_gold and scene.game.towers.size() == expected_towers,
			"Rotation preserves wave, gold and towers",
		)
		suite.check(
			scene.game.position_of(rotation_enemy) == rotation_position,
			"Rotation does not move or reset enemies",
		)
		suite.check(
			((board.size / 2.0 - board.pan) / board.zoom).distance_to(focus_before) < 0.01,
			"Rotation preserves camera focus",
		)

		var bounds = Rect2(Vector2.ZERO, scene.layout_size).grow(0.1)
		var interactive: Array[Control] = []

		for child in scene.get_children():
			if child is Control and child.visible:
				suite.check(
					bounds.encloses(Rect2(child.position, child.size)),
					"Visible control stays inside screen: " + child.name,
				)

				if child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					interactive.append(child)

		for a in range(interactive.size()):
			for b in range(a + 1, interactive.size()):
				suite.check(
					not Rect2(
						interactive[a].position,
						interactive[a].size,
					).intersects(Rect2(interactive[b].position, interactive[b].size)),
					"Touch targets do not overlap",
				)

		var speed_before: int = scene.game.speed_multiplier
		suite.gui_click(scene.speed_button.get_global_transform_with_canvas() * (scene.speed_button.size / 2.0))
		suite.check(
			scene.game.speed_multiplier != speed_before,
			"Speed control clickable after rotation and scaling",
		)

		var target_cell: Vector2i = board.cell_at(board.size / 2.0)
		scene.selected_kind = 0
		suite.gui_click(board.get_global_transform_with_canvas() * (board.size / 2.0))
		suite.check(scene.game.towers.has(target_cell), "Construction works after rotation and scaling")

		if scene.game.towers.has(target_cell):
			suite.gui_click(scene.upgrade_button.get_global_transform_with_canvas() * (scene.upgrade_button.size / 2.0))
			suite.check(scene.game.towers[target_cell].level == 2, "Upgrade works after rotation")
			suite.gui_click(scene.sell_button.get_global_transform_with_canvas() * (scene.sell_button.size / 2.0))
			suite.check(not scene.game.towers.has(target_cell), "Sale works after rotation")
		expected_gold = scene.game.gold
		expected_towers = scene.game.towers.size()
	board.overview()
	suite.root.size = Vector2i(720, 1280)
	await suite.process_frame
	scene.apply_layout(true)
	suite.near(board.zoom, board.minimum_zoom(), "Overview refits entire map after rotation")

	var safe_area = Rect2(40, 24, 1200, 656)
	preload("res://ui_layout.gd").arrange(scene, safe_area)
	suite.check(
		safe_area.grow(0.1).encloses(Rect2(scene.position, scene.layout_size * scene.scale)),
		"UI respects simulated notch and system-bar safe area",
	)
	scene.queue_free()
	await suite.process_frame
