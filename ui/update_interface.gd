extends RefCounted
## Met les commandes visibles en accord avec l'écran courant, sans créer de nouveaux boutons.
## Le menu bloque le temps dans main.gd ; ce fichier ne fait qu'actualiser l'affichage.


## Affiche soit le menu de préparation, soit la partie et ses commandes flottantes.
static func refresh(ui) -> void:
	ui.menu_screen.visible = ui.in_menu
	ui.board.visible = not ui.in_menu
	ui.hud_panel.visible = not ui.in_menu
	ui.status.visible = not ui.in_menu
	ui.message.visible = not ui.in_menu
	ui.pause_button.visible = not ui.in_menu and not ui.game.ended
	ui.speed_button.visible = not ui.in_menu and not ui.game.ended
	ui.settings_button.visible = not ui.in_menu and not ui.game.ended
	ui.preparation_hint.visible = not ui.in_menu and not ui.game.active and not ui.game.ended

	for button in ui.type_buttons:
		button.visible = not ui.in_menu
		button.disabled = ui.game.ended

	if ui.in_menu:
		ui.wave_button.hide()
		ui.end_screen.hide()
		return

	ui.status.text = "Or %d  •  Château %d  •  Vague %d/100" % [ui.game.gold, ui.game.lives, ui.game.wave]
	ui.message.text = ui.game.message
	ui.pause_button.text = "Reprendre" if ui.game.paused else "Pause"
	ui.pause_button.disabled = ui.game.ended
	ui.speed_button.text = "Vitesse ×%d" % ui.game.speed_multiplier

	# Le lancement anticipé existe seulement pendant la préparation. Rejouer appartient à l'écran de résultat.
	ui.wave_button.visible = not ui.game.active and not ui.game.ended
	ui.wave_button.disabled = ui.game.paused
	ui.wave_button.text = "Lancer vague %d · %d s" % [ui.game.wave + 1, int(ceil(ui.game.preparation))]
	var next_plan: Dictionary = ui.game.wave_plan(ui.game.wave + 1)
	var next_threat := "résistance physique" if next_plan.armor == "physical" else "résistance magique"
	if next_plan.air:
		next_threat = "volants + terrestres"
	if next_plan.boss > 0:
		next_threat += " + boss"
	ui.preparation_hint.text = "PRÉPAREZ VOS TOURS  ·  Vague %d : %s" % [ui.game.wave + 1, next_threat]

	var highlighted = ui.selected_kind

	if ui.game.towers.has(ui.selected):
		highlighted = int(ui.game.towers[ui.selected].kind)
	else:
		ui.selected = Vector2i(-1, -1)

	for kind in range(ui.type_buttons.size()):
		preload("res://ui/control_factory.gd").catalog_style(ui.type_buttons[kind], kind == highlighted)

	if ui.game.ended:
		ui.wave_feedback.clear()
		ui.close_inspection()
	ui.end_screen.refresh(ui.game)
	ui.board.selected = ui.selected
	ui.refresh_inspection()
	ui.board.refresh()
