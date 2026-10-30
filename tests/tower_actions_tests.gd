extends RefCounted
## Ces scénarios reproduisent un vrai appui qui dure pendant plusieurs actualisations de l'interface.
## Un clic instantané, appui et relâchement dans la même image, ne révélait pas l'annulation du bouton de fiche.
## On vérifie les huit types de tours, avant les vagues, pendant le combat et en pause, dans les deux orientations.


## Envoie seulement l'appui ou le relâchement, pour pouvoir faire avancer l'interface entre les deux.
## point est exprimé dans les coordonnées réelles de la fenêtre, après la mise à l'échelle des contrôles.
static func send_button(suite, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = point
	event.global_position = point
	suite.root.push_input(event, true)


## Maintient le bouton pressé pendant trois actualisations ordinaires de main.gd, puis le relâche.
## Le temps est avancé explicitement pour obtenir un test rapide et reproductible sans attendre une personne.
static func held_click(suite, ui, button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	send_button(suite, point, true)
	suite.check(button.button_pressed, "Context action receives the initial press")

	for refresh in range(3):
		ui._process(0.11)
		suite.check(button.button_pressed, "Context action remains pressed across periodic UI refresh")

	send_button(suite, point, false)


## Achète une tour, ouvre sa fiche par un toucher, puis vérifie les deux actions lors d'un appui prolongé.
## La vente et l'amélioration sont désormais proposées uniquement par cette fiche.
static func run(suite) -> void:
	var ui = load("res://main.tscn").instantiate()
	ui.developer_mode = true
	suite.root.add_child(ui)
	ui.set_process(false)
	ui.start_game(0)
	await suite.process_frame

	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		suite.root.size = dimensions
		await suite.process_frame
		ui.apply_layout(true)

		for phase in ["preparation", "combat", "paused"]:
			for kind in range(ui.game.TYPES.size()):
				ui.close_inspection()
				ui.game.reset(1)
				ui.game.gold = 10000
				ui.selected = Vector2i(-1, -1)
				ui.board.entry_view()

				if phase != "preparation":
					ui.game.start_wave()
				ui.game.paused = phase == "paused"
				ui.refresh_ui()

				var catalog_button: Button = ui.type_buttons[kind]
				suite.gui_click(catalog_button.get_global_rect().get_center())

				var cell: Vector2i = ui.game.entry + Vector2i(3, -1)
				var local_point: Vector2 = ui.board.pan + (Vector2(cell) + Vector2.ONE * 0.5) * ui.board.CELL * ui.board.zoom
				suite.gui_click(ui.board.get_global_transform_with_canvas() * local_point)

				suite.check(
					ui.game.towers.has(cell),
					"Tower is placed through actual GUI before using global actions",
				)
				suite.check(ui.selected == cell, "Newly placed tower is selected")
				suite.gui_click(ui.board.get_global_transform_with_canvas() * local_point)
				suite.check(
					ui.inspector.pinned and not ui.inspector.sell_button.disabled,
					"Touching tower exposes its contextual actions",
				)

				# Une amélioration doit également résister aux actualisations qui se produisent pendant l'appui.
				var gold_before_upgrade: int = ui.game.gold
				var price: int = ui.game.upgrade_cost(ui.game.towers[cell])
				held_click(suite, ui, ui.inspector.upgrade_button)
				suite.check(ui.game.towers[cell].level == 2, "Held context upgrade click applies one level")
				suite.check(ui.game.gold == gold_before_upgrade - price, "Held context upgrade charges once")

				var gold_before_sale: int = ui.game.gold
				var refund := int(ui.game.towers[cell].spent * 0.7)
				held_click(suite, ui, ui.inspector.sell_button)
				suite.check(not ui.game.towers.has(cell), "Held context sale click removes the placed tower")
				suite.check(ui.game.gold == gold_before_sale + refund, "Held context sale refunds exactly once")
				suite.check(
					ui.selected == Vector2i(-1, -1) and not ui.inspector.visible,
					"Context actions are disabled after successful sale",
				)

	ui.queue_free()
	await suite.process_frame
