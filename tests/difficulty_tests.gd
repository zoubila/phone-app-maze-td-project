extends RefCounted
## Vérifie que les difficultés modifient les valeurs réellement jouées et restent identiques après Rejouer.

const Model = preload("res://game.gd")
const Difficulty = preload("res://gameplay/difficulty.gd")


## Compare les quatre modes sur les terrestres, les volants, les boss et les revenus.
static func run(suite) -> void:
	var reference = Model.new()
	for wave in [1, 25, 50, 100]:
		for index in range(3):
			suite.check(
				Difficulty.health_multiplier(index, wave) < Difficulty.health_multiplier(index + 1, wave),
				"Each difficulty is strictly tougher than the preceding one",
			)
	for index in range(4):
		suite.near(Difficulty.health_multiplier(index, 25), [0.7, 1.0, 1.5, 2.25][index], "Final health multiplier matches the advertised difficulty")
		suite.check(Difficulty.income(index, 100) == [115, 100, 90, 85][index], "Income matches the advertised percentage")
	for index in range(4):
		var game = Model.new()
		game.reset(1, index)
		suite.check(game.gold == 600 and game.difficulty_index == index, "Difficulty preserves the initial construction budget")
		var previous_hp := 0.0
		for wave in range(1, 101):
			var multiplier := Difficulty.health_multiplier(index, wave)
			for flying in [false, true]:
				for boss in [0, 1, 2]:
					suite.near(game.enemy_health(wave, flying, boss), reference.enemy_health(wave, flying, boss) * multiplier, "Difficulty scales every enemy category")
			var hp: float = game.enemy_health(wave)
			suite.check(hp > previous_hp, "Monster health still increases every wave in every difficulty")
			previous_hp = hp
		suite.near(Difficulty.health_multiplier(index, 25), Difficulty.health_multiplier(index, 100), "Extra difficulty scaling stops growing at wave 25")
		game.wave = 49
		game.start_wave()
		game.to_spawn = 1
		var boss: Dictionary = game.spawn_enemy()
		suite.check(boss.boss == 2 and boss.reward == Difficulty.income(index, 108 * 30), "Boss reward uses the selected income multiplier")
		suite.near(boss.max_hp, game.enemy_health(50, false, 2), "Spawned boss uses difficulty-adjusted health")
		boss.hp = 0
		var bonus_events: Array[int] = []
		game.wave_repelled.connect(func(_wave, bonus): bonus_events.append(bonus))
		game.combat_step(0)
		var expected_bonus := Difficulty.income(index, 170)
		suite.check(game.gold == 600 + int(boss.reward) + expected_bonus, "Actual kill and clear payments use difficulty")
		suite.check(bonus_events == [expected_bonus], "Wave celebration reports the actual adjusted bonus")
		game.combat_step(0)
		suite.check(bonus_events.size() == 1, "Difficulty never duplicates the wave bonus")
		game.reset(1, index)
		var cell: Vector2i = game.entry + Vector2i(3, -1)
		game.build(cell, 0)
		game.sell(cell)
		suite.check(game.gold == 585, "Difficulty does not multiply sale refunds")

	# Un clic réel sur Commencer doit transmettre la difficulté, sans dépendre du mode développeur.
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		suite.root.size = dimensions
		var ui = load("res://main.tscn").instantiate()
		ui.developer_mode = true
		suite.root.add_child(ui)
		ui.set_process(false)
		await suite.process_frame
		suite.check(
			not Rect2(ui.menu_screen.grid_choice.position, ui.menu_screen.grid_choice.size).intersects(Rect2(ui.menu_screen.difficulty_choice.position, ui.menu_screen.difficulty_choice.size)),
			"Grid and difficulty selectors never overlap",
		)
		ui.menu_screen.grid_choice.select(1)
		for index in range(4):
			ui.menu_screen.difficulty_choice.select(index)
			ui.menu_screen.update_difficulty_hint()
			suite.check(ui.menu_screen.difficulty_hint.text.contains(Difficulty.profile(index).name), "Menu describes the selected difficulty")
			suite.check(ui.menu_screen.difficulty_hint.get_visible_line_count() >= ui.menu_screen.difficulty_hint.get_line_count(), "Difficulty description fits both orientations")
			suite.gui_click(ui.menu_screen.start_button.get_global_rect().get_center())
			suite.check(not ui.in_menu and ui.game.difficulty_index == index, "Start button uses selected difficulty")
			ui.menu_screen.difficulty_choice.select((index + 1) % 4)
			ui.game.ended = true
			ui.refresh_ui()
			suite.gui_click(ui.end_screen.replay_button.get_global_rect().get_center())
			suite.check(ui.game.difficulty_index == index and not ui.game.ended, "Replay retains actual difficulty even if menu choice changes")
			ui.return_home()
		ui.queue_free()
		await suite.process_frame
