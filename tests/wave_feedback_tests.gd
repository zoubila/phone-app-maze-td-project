extends RefCounted
## Vérifie les événements de vague et leur affichage, sans changer les récompenses ou le rythme du jeu.

const Model = preload("res://game.gd")
const Simulation = preload("res://gameplay/simulation.gd")


static func run(suite) -> void:
	var game = Model.new()
	var repelled: Array = []
	var started: Array = []
	game.wave_repelled.connect(func(number, bonus): repelled.append([number, bonus]))
	game.wave_started.connect(func(number): started.append(number))
	suite.check(game.start_wave() and started == [1], "A new wave announces its number exactly once")
	suite.check(not game.start_wave() and started == [1], "An active wave is never announced twice")
	game.to_spawn = 0
	var original_gold: int = game.gold
	game.tick(0.02)
	suite.check(repelled == [[1, 23]], "Wave celebration carries the actual number and gold bonus")
	suite.check(game.gold == original_gold + 23 and game.preparation == 15.0, "Celebration preserves the reward and preparation duration")
	Simulation.finish_wave_if_needed(game)
	suite.check(repelled.size() == 1 and game.gold == original_gold + 23, "Refreshing a finished wave never pays or celebrates twice")
	game.start_wave()
	game.lives = 0
	game.to_spawn = 0
	game.tick(0.02)
	suite.check(game.ended and not game.won and repelled.size() == 1, "Castle defeat takes priority over celebration")
	game.reset(1)
	game.wave = 99
	game.start_wave()
	game.to_spawn = 0
	game.tick(0.02)
	suite.check(game.won and game.ended and repelled.back() == [100, 320], "Final wave keeps the actual campaign victory and bonus")

	suite.root.size = Vector2i(1280, 720)
	var ui = load("res://main.tscn").instantiate()
	ui.developer_mode = true
	suite.root.add_child(ui)
	ui.set_process(false)
	await suite.process_frame
	ui.start_game(1)
	ui.game.start_wave()
	suite.check(ui.wave_feedback.visible and not ui.wave_feedback.celebrating, "Starting combat displays an incoming-wave announcement")
	ui.game.to_spawn = 0
	ui.game.tick(0.02)
	ui.refresh_ui()
	suite.check(ui.wave_feedback.visible and ui.wave_feedback.celebrating, "Finishing a real simulated wave displays the celebration")
	suite.check(ui.wave_feedback.heading.text.contains("1") and ui.wave_feedback.reward.text.contains("23"), "Banner shows the actual wave and reward")
	suite.check(ui.preparation_hint.visible and ui.preparation_hint.text.contains("2"), "Preparation announces the next wave after the celebration")
	var cell: Vector2i = ui.game.entry + Vector2i(4, -3)
	var point: Vector2 = ui.board.pan + (Vector2(cell) + Vector2.ONE * 0.5) * ui.board.CELL * ui.board.zoom
	suite.gui_click(ui.board.get_global_transform_with_canvas() * point)
	suite.check(ui.game.towers.has(cell), "A celebration never intercepts construction clicks")
	ui.close_inspection()
	suite.root.size = Vector2i(720, 1280)
	await suite.process_frame
	ui.apply_layout(true)
	var card_area := Rect2(ui.wave_feedback.card.position, ui.wave_feedback.card.size)
	suite.check(Rect2(Vector2.ZERO, ui.board.size).encloses(card_area), "Rotating the phone keeps the banner within the board")
	suite.check(ui.wave_feedback.displayed_wave == 1, "Rotation preserves the current wave celebration")
	var preparation: float = ui.game.preparation
	var gold: int = ui.game.gold
	ui.wave_feedback._process(4.0)
	suite.check(not ui.wave_feedback.visible, "Celebration automatically disappears after its short duration")
	suite.check(ui.game.gold == gold and ui.game.preparation == preparation, "Visual animation never advances or pays the simulation")
	ui.game.start_wave()
	suite.check(not ui.wave_feedback.celebrating, "Next wave replaces the previous celebration with an incoming announcement")
	ui.return_home()
	suite.check(not ui.wave_feedback.visible and not ui.preparation_hint.visible, "Returning home clears celebration and preparation controls")
	ui.start_game(1)
	ui.game.wave = 99
	ui.game.start_wave()
	ui.game.to_spawn = 0
	ui.game.tick(0.02)
	ui.refresh_ui()
	suite.check(ui.end_screen.visible and not ui.wave_feedback.visible, "Campaign victory uses the final screen rather than a new-wave celebration")
	ui.queue_free()
	await suite.process_frame

	# Vérifie le tout premier état, le milieu et la dernière image : l'étoile ne doit jamais vivre seule.
	var feedback = preload("res://ui/wave_feedback.gd").new()
	suite.root.add_child(feedback)
	feedback.size = Vector2(696, 1096)
	for celebration in [false, true]:
		if celebration:
			feedback.show_repelled(10, 50, game.wave_plan(11))
		else:
			feedback.show_incoming(10)
		feedback.set_process(false)
		suite.check(feedback.visible and feedback.card.modulate.a == 0, "Banner starts fully transparent before its first animation frame")
		suite.check(feedback.decoration.get_parent() == feedback.card, "Star shares the same animated parent as panel and text")
		feedback._process(0.08)
		suite.near(feedback.card.modulate.a, 0.5, "Panel and all ornaments share the entrance fade")
		suite.check(feedback.decoration.get_global_transform().is_equal_approx(feedback.card.get_global_transform()), "Star follows the panel zoom during entrance")
		feedback._process(0.4)
		suite.near(feedback.card.modulate.a, 1.0, "Banner becomes fully visible as a group")
		feedback._process(feedback.duration - feedback.age - 0.1)
		suite.check(feedback.visible and feedback.card.modulate.a > 0 and feedback.card.modulate.a < 1, "Panel and star fade out before hiding")
		feedback._process(0.11)
		suite.check(not feedback.is_visible_in_tree() and not feedback.decoration.is_visible_in_tree(), "Star and panel disappear in the same frame")
		suite.check(feedback.card.modulate.a == 0, "Hidden banner keeps no opaque state for a subsequent announcement")
	feedback.show_repelled(20, 80, game.wave_plan(21))
	feedback.set_process(false)
	feedback._process(0.3)
	feedback.show_incoming(21)
	feedback.set_process(false)
	suite.check(feedback.age == 0 and feedback.card.modulate.a == 0, "Interrupting one announcement resets the complete visual group without a flash")
	feedback.queue_free()
	await suite.process_frame
