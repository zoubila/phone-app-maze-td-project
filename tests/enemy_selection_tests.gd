extends RefCounted
## Vérifie la sélection sur le sprite, le mouvement pendant l'appui et la fermeture hors de la fiche.

const Art = preload("res://rendering/unit_art.gd")
const Touch = preload("res://tests/touch_gestures_tests.gd")


## Envoie une moitié de clic pour pouvoir déplacer le monstre entre l'appui et le relâchement.
static func mouse_button(suite, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	suite.root.push_input(event, true)


## Les scénarios sont répétés en portrait et paysage, pour les terrestres, volants et deux tailles de boss.
static func run(suite) -> void:
	var original_emulation := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		suite.root.size = dimensions
		var ui = load("res://main.tscn").instantiate()
		ui.developer_mode = true
		suite.root.add_child(ui)
		ui.set_process(false)
		await suite.process_frame
		ui.start_game(1)
		var board = ui.board
		for kind in range(4):
			ui.game.enemies.clear()
			var enemy: Dictionary = ui.game.spawn_enemy()
			enemy.portal_remaining = 0.0
			enemy.portal_age = 1.0
			enemy.cell = ui.game.entry + Vector2i(6, 0)
			enemy.next = enemy.cell + Vector2i.RIGHT
			enemy.fraction = 0.1
			enemy.air = kind == 1
			enemy.boss = maxi(0, kind - 1)
			var bounds: Rect2 = Art.enemy_bounds(enemy, ui.game.position_of(enemy) * board.CELL)
			var head: Vector2 = board.pan + (bounds.position + bounds.size * Vector2(0.5, 0.12)) * board.zoom
			var screen_head: Vector2 = board.get_global_transform_with_canvas() * head
			suite.check(board.pick_item(head).get("id") == enemy.id, "Visible monster head is selectable for every unit size")
			mouse_button(suite, screen_head, true)
			enemy.fraction = 0.95
			mouse_button(suite, screen_head, false)
			suite.check(ui.inspector.visible and ui.inspector.pinned and ui.inspector.target.get("id") == enemy.id, "Moving during a press still pins the originally touched monster")
			var card_position: Vector2 = ui.inspector.position
			suite.gui_move(Vector2(2, 2))
			enemy.hp = 31
			ui.refresh_ui()
			suite.check(ui.inspector.pinned and ui.inspector.position == card_position and ui.inspector.body_label.text.contains("PV : 31 /"), "Pinned information remains visible and refreshes after pointer departure")
			# La fiche change de côté en portrait : choisir une case réellement hors de son rectangle.
			var empty := Vector2.ZERO
			for dx in range(1, 10):
				for dy in range(-5, 6):
					var point: Vector2 = board.pan + (Vector2(ui.game.entry + Vector2i(dx, dy)) + Vector2.ONE * 0.5) * board.CELL * board.zoom
					var screen_point: Vector2 = board.get_global_transform_with_canvas() * point
					if Rect2(Vector2(0, 100), board.size - Vector2(0, 250)).has_point(point) and not ui.inspector.get_global_rect().has_point(screen_point) and board.pick_item(point).is_empty():
						empty = point
			var gold: int = ui.game.gold
			suite.gui_click(board.get_global_transform_with_canvas() * empty)
			suite.check(not ui.inspector.visible and ui.game.towers.is_empty() and ui.game.gold == gold, "Outside board click dismisses without buying a tower")
			var body: Vector2 = board.pan + ui.game.position_of(enemy) * board.CELL * board.zoom
			await Touch.tap(suite, board.get_global_transform_with_canvas() * body)
			suite.check(ui.inspector.visible and ui.inspector.pinned and ui.inspector.target.get("id") == enemy.id, "Raw touch input pins the monster card")
			await Touch.tap(suite, Vector2(2, 2))
			suite.check(not ui.inspector.visible, "Touching outside the board dismisses the monster card")
			suite.gui_click(board.get_global_transform_with_canvas() * body)
			var paused: bool = ui.game.paused
			suite.gui_click(ui.pause_button.get_global_rect().get_center())
			suite.check(not ui.inspector.visible and ui.game.paused != paused, "HUD click dismisses the card and still activates its command")
		ui.queue_free()
		await suite.process_frame
	Input.emulate_mouse_from_touch = original_emulation
