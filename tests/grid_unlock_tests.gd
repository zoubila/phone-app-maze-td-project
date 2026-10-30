extends RefCounted
## Vérifie les seuils exacts, la sauvegarde et le parcours du menu, sans toucher à la progression du joueur.

const Progress = preload("res://progression.gd")


## Utilise un fichier temporaire indépendant, supprimé à la fin du scénario.
static func run(suite) -> void:
	var path := "user://grid-tests-%d.cfg" % Time.get_ticks_usec()
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "best_wave", 99)
	legacy.set_value("other", "keep", "preserved")
	legacy.save(path)
	var progress = Progress.new()
	progress.save_path = path
	progress.load_save()
	suite.check(progress.best == 99 and progress.reached == [0, 0, 0], "Legacy global record is preserved without guessing a grid")
	suite.check(progress.is_unlocked(1) and not progress.is_unlocked(0) and not progress.is_unlocked(2), "New players can only select 25x50")
	progress.record_wave(1, 24)
	suite.check(not progress.is_unlocked(0), "Wave 24 does not unlock medium grid")
	progress.record_wave(0, 100)
	suite.check(progress.reached[0] == 0, "A locked grid cannot record normal progress")
	progress.record_wave(1, 25)
	suite.check(progress.is_unlocked(0) and not progress.is_unlocked(2), "Reaching small-grid wave 25 unlocks only medium grid")
	progress.record_wave(0, 49)
	suite.check(not progress.is_unlocked(2), "Medium-grid wave 49 does not unlock large grid")
	progress.record_wave(0, 50)
	suite.check(progress.is_unlocked(2), "Reaching medium-grid wave 50 unlocks large grid")
	progress.record_wave(0, 3)
	suite.check(progress.reached[0] == 50 and progress.save(), "Lower waves never erase records and save succeeds")
	var restored = Progress.new()
	restored.save_path = path
	restored.load_save()
	suite.check(restored.reached == [50, 25, 0] and restored.is_unlocked(2), "Grid records and unlocks survive reload")
	legacy.load(path)
	suite.check(legacy.get_value("other", "keep") == "preserved", "Saving preserves unrelated existing configuration")
	var fresh = Progress.new()
	for index in range(3):
		suite.check(fresh.is_unlocked(index, true), "Developer mode bypasses every grid lock")
		fresh.record_wave(index, 100, true)
	suite.check(fresh.reached == [0, 0, 0] and not fresh.dirty, "Developer waves do not unlock normal progression")
	suite.check(not fresh.is_unlocked(-1, true) and not fresh.is_unlocked(3, true), "Developer mode still rejects nonexistent grids")

	# Le menu réel refuse aussi une sélection forcée par code ou un appel direct de start_game.
	var ui = load("res://main.tscn").instantiate()
	ui.developer_mode = false
	ui.progression.save_path = "user://grid-ui-tests-%d.cfg" % Time.get_ticks_usec()
	suite.root.size = Vector2i(1280, 720)
	suite.root.add_child(ui)
	ui.set_process(false)
	await suite.process_frame
	suite.check(ui.menu_screen.grid_choice.selected == 1, "Menu defaults to the accessible small grid")
	suite.check(ui.menu_screen.grid_choice.is_item_disabled(0) and ui.menu_screen.grid_choice.is_item_disabled(2), "Locked dropdown entries are disabled")
	var menu = ui.menu_screen
	suite.gui_move(menu.grid_info_button.get_global_rect().get_center())
	suite.check(menu.grid_info_panel.visible, "Grid help opens on hover")
	suite.check(
		menu.grid_info_text.text.contains("vague 25 sur 25 × 50") and menu.grid_info_text.text.contains("vague 50 sur 50 × 100"),
		"Grid tooltip explains both unlock requirements",
	)
	suite.check(menu.grid_info_text.text.contains("Votre record : 0/25") and menu.grid_info_text.text.contains("Votre record : 0/50"), "Grid tooltip shows progress for both requirements")
	suite.gui_move(Vector2(8, 8))
	suite.check(not menu.grid_info_panel.visible, "Hover help closes when leaving its button")
	suite.gui_click(menu.grid_info_button.get_global_rect().get_center())
	suite.gui_move(Vector2(8, 8))
	suite.check(menu.grid_info_panel.visible and menu.grid_info_pinned, "Clicking grid help pins it for touch users")
	suite.root.size = Vector2i(720, 1280)
	await suite.process_frame
	ui.apply_layout(true)
	suite.check(Rect2(Vector2.ZERO, ui.layout_size).encloses(Rect2(menu.grid_info_panel.position, menu.grid_info_panel.size)), "Grid tooltip stays inside portrait layout")
	suite.check(menu.grid_info_text.get_visible_line_count() >= menu.grid_info_text.get_line_count(), "Both grid requirements fit without clipped lines")
	suite.gui_click(Vector2(8, 8))
	suite.check(not menu.grid_info_panel.visible, "Outside click closes pinned grid help")
	ui.menu_screen.grid_choice.select(2)
	suite.gui_click(ui.menu_screen.start_button.get_global_rect().get_center())
	suite.check(ui.in_menu and ui.menu_screen.grid_choice.selected == 1, "Forced locked selection cannot start a game")
	ui.start_game(0)
	suite.check(ui.in_menu, "Direct start also enforces the lock")
	ui.start_game(1)
	ui.game.wave = 24
	ui.game.start_wave()
	ui.game.lives = 0
	ui.game.combat_step(0)
	ui.return_home()
	suite.check(not ui.menu_screen.grid_choice.is_item_disabled(0), "Reaching wave 25 unlocks medium grid even if that wave is lost")
	var saved = Progress.new()
	saved.save_path = ui.progression.save_path
	saved.load_save()
	suite.check(saved.reached[1] == 25, "Wave-start event saves immediately to disk")
	ui.start_game(0)
	ui.game.wave = 49
	ui.game.start_wave()
	ui.return_home()
	suite.check(not ui.menu_screen.grid_choice.is_item_disabled(2), "Menu unlocks large grid after medium wave 50")
	ui.developer_mode = true
	ui.start_game(2)
	suite.check(not ui.in_menu and ui.game.cols == 200, "Developer can launch the large grid")
	ui.game.wave = 99
	ui.game.start_wave()
	suite.check(ui.progression.reached[2] == 0, "Developer gameplay does not update normal grid records")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.progression.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ui.queue_free()
	await suite.process_frame
