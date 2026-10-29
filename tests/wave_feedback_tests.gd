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
