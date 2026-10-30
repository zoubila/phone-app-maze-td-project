extends RefCounted
## Les outils de développement doivent faciliter les essais sans modifier les règles des parties normales.

const Model = preload("res://game.gd")


## Vérifie les fuites ordinaires et de boss, les limites du sélecteur, Rejouer et l'absence de faux records.
static func run(suite) -> void:
	for developer in [false, true]:
		for boss in [0, 1, 2]:
			var game = Model.new()
			game.reset(1, 1, developer)
			game.start_wave()
			var enemy: Dictionary = game.spawn_enemy()
			enemy.boss = boss
			game.lives = 1
			game.escape(enemy)
			game.combat_step(0)
			suite.check(enemy.escaped and enemy.hp == 0, "Escaped enemies disappear even in developer mode")
			suite.check(game.gold == 600, "Invulnerability does not award gold for an escaped enemy")
			suite.check(game.lives == (1 if developer else 0), "Only developer mode prevents castle damage")
			suite.check(game.ended == not developer, "Only normal gameplay can end in defeat")
	var protected = Model.new()
	protected.reset(1, 1, true)
	protected.start_wave()
	protected.lives = 0
	protected.combat_step(0)
	suite.check(not protected.ended, "Developer mode cannot lose even if a test directly sets lives to zero")
	protected.reset(1, 1, true)
	protected.wave = 99
	protected.start_wave()
	protected.to_spawn = 0
	protected.combat_step(0)
	suite.check(protected.ended and protected.won, "Developer invulnerability still permits the final victory")

	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		suite.root.size = dimensions
		var ui = load("res://main.tscn").instantiate()
		ui.developer_mode = true
		ui.progression.save_path = "user://dev-mode-tests-%d.cfg" % Time.get_ticks_usec()
		suite.root.add_child(ui)
		ui.set_process(false)
		await suite.process_frame
		suite.check(ui.menu_screen.dev_wave.visible, "Developer menu shows the starting-wave selector")
		suite.check(
			not Rect2(ui.menu_screen.dev_wave.position, ui.menu_screen.dev_wave.size).intersects(Rect2(ui.menu_screen.dev_wave_more.position, ui.menu_screen.dev_wave_more.size)),
			"Developer wave input does not overlap its touch buttons",
		)
		ui.menu_screen.dev_wave.value = 1000
		suite.check(ui.menu_screen.dev_wave.value == 100, "Starting-wave selector clamps at 100")
		ui.menu_screen.dev_wave.value = -10
		suite.check(ui.menu_screen.dev_wave.value == 1, "Starting-wave selector clamps at 1")
		for first_wave in [1, 10, 50, 100]:
			ui.menu_screen.dev_wave.get_line_edit().text = str(first_wave)
			suite.gui_click(ui.menu_screen.start_button.get_global_rect().get_center())
			suite.check(ui.game.developer_mode and ui.game.wave == first_wave - 1 and not ui.game.active, "Menu prepares precisely the chosen developer wave")
			suite.check(ui.game.gold == 600 and ui.game.enemies.is_empty(), "Skipping waves gives no artificial rewards or enemies")
			suite.check(ui.wave_button.text.contains(str(first_wave)), "Launch command displays the chosen wave")
			suite.gui_click(ui.wave_button.get_global_rect().get_center())
			suite.check(ui.game.active and ui.game.wave == first_wave, "Manual wave launch respects developer selection")
			suite.check(ui.status.text.contains("∞"), "HUD indicates castle invulnerability")
			ui.game.best = first_wave
			ui.save_progress()
			suite.check(not FileAccess.file_exists(ui.progression.save_path), "Developer wave jumps never create a normal progression file")
			# La victoire reste possible et Rejouer conserve la vague d'essai, même si le menu a changé depuis.
			ui.game.ended = true
			ui.menu_screen.dev_wave.value = 2
			ui.restart_game()
			suite.check(ui.game.wave == first_wave - 1 and ui.game.developer_mode, "Replay retains the developer starting wave and protection")
			ui.return_home()
		ui.developer_mode = false
		ui.menu_screen.configure_grids(ui.progression, false)
		suite.check(not ui.menu_screen.dev_wave.visible, "Normal menu hides developer tools")
		ui.menu_screen.dev_wave.value = 100
		ui.start_game(1, 1, 100)
		suite.check(ui.game.wave == 0 and not ui.game.developer_mode, "Normal mode ignores every developer wave override")
		ui.queue_free()
		await suite.process_frame
