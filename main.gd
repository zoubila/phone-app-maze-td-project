extends Node2D

var game = preload("res://game.gd").new()
var board: Control
var selected := Vector2i(-1, -1)
var selected_kind := 0
var grid_index := 0
var status: Label
var message: Label
var map_info: Label
var detail: Label
var grid_choice: OptionButton
var wave_button: Button
var pause_button: Button
var speed_button: Button
var upgrade_button: Button
var sell_button: Button
var type_buttons: Array[Button] = []
var saved_best := 0
var ui_clock := 0.0

func _ready() -> void:
	var save := ConfigFile.new()
	if save.load("user://progress.cfg") == OK:
		game.best = int(save.get_value("progress", "best_wave", 0))
	saved_best = game.best
	make_ui()
	refresh_ui()

func label(text_value: String, pos: Vector2, dimensions: Vector2, font_size: int, color := Color("e9e1c8")) -> Label:
	var item := Label.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.clip_text = true
	add_child(item)
	return item

func button(text_value: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.position = pos
	item.size = dimensions
	item.add_theme_font_size_override("font_size", 19)
	item.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("24372a")
	normal.border_color = Color("60704c")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	item.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("374d35")
	item.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("1a281e")
	disabled.border_color = Color("394434")
	item.add_theme_stylebox_override("disabled", disabled)
	item.pressed.connect(action)
	add_child(item)
	return item

func make_ui() -> void:
	label("LES MARCHES DU ROYAUME", Vector2(32, 30), Vector2(656, 42), 31)
	label("MAZE TD  /  PROTOTYPE 04", Vector2(32, 76), Vector2(656, 28), 18, Color("a7b596"))
	status = label("", Vector2(32, 112), Vector2(656, 32), 22)
	message = label("", Vector2(32, 150), Vector2(656, 30), 18, Color("ebcc84"))
	grid_choice = OptionButton.new()
	grid_choice.position = Vector2(32, 188)
	grid_choice.size = Vector2(296, 48)
	grid_choice.add_theme_font_size_override("font_size", 18)
	for dimensions in game.GRID_SIZES:
		grid_choice.add_item("%d haut × %d long" % [dimensions.y, dimensions.x])
	grid_choice.item_selected.connect(change_grid)
	add_child(grid_choice)
	board = preload("res://board.gd").new()
	board.game = game
	board.position = Vector2(32, 248)
	board.size = Vector2(656, 600)
	board.cell_tapped.connect(interact)
	add_child(board)
	button("Entrée", Vector2(340, 188), Vector2(108, 48), board.entry_view)
	button("Château", Vector2(460, 188), Vector2(108, 48), board.castle_view)
	button("Vue", Vector2(580, 188), Vector2(108, 48), board.overview)
	map_info = label("", Vector2(32, 860), Vector2(496, 40), 18, Color("c9c7ac"))
	button("−", Vector2(544, 858), Vector2(64, 44), func(): board.set_zoom(board.zoom / 1.3, board.size / 2))
	button("+", Vector2(624, 858), Vector2(64, 44), func(): board.set_zoom(board.zoom * 1.3, board.size / 2))
	detail = label("", Vector2(32, 907), Vector2(656, 48), 18)
	for i in range(game.TYPES.size()):
		var index := i
		type_buttons.append(button("%s\n%d or" % [game.TYPES[i].name, game.TYPES[i].cost], Vector2(32 + (i % 4) * 166, 963 + (i / 4) * 61), Vector2(158, 56), func(): select_kind(index)))
	upgrade_button = button("Améliorer", Vector2(32, 1096), Vector2(320, 52), upgrade_selected)
	sell_button = button("Vendre", Vector2(368, 1096), Vector2(320, 52), sell_selected)
	wave_button = button("", Vector2(32, 1162), Vector2(320, 60), start_or_reset)
	pause_button = button("Pause", Vector2(368, 1162), Vector2(154, 60), toggle_pause)
	speed_button = button("×1", Vector2(538, 1162), Vector2(150, 60), toggle_speed)
	label("Toucher : bâtir / sélectionner  •  Glisser : déplacer la carte", Vector2(32, 1232), Vector2(656, 25), 16, Color("a7b596"))

func change_grid(index: int) -> void:
	if game.wave != 0 or not game.towers.is_empty():
		return
	grid_index = index
	game.reset(index)
	selected = Vector2i(-1, -1)
	board.entry_view()
	refresh_ui()

func select_kind(index: int) -> void:
	selected_kind = index
	selected = Vector2i(-1, -1)
	refresh_ui()

func interact(cell: Vector2i) -> void:
	if game.towers.has(cell):
		selected = cell
	elif game.build(cell, selected_kind):
		selected = cell
	refresh_ui()

func upgrade_selected() -> void:
	game.upgrade(selected)
	refresh_ui()

func sell_selected() -> void:
	if game.sell(selected):
		selected = Vector2i(-1, -1)
	refresh_ui()

func start_or_reset() -> void:
	if game.ended:
		game.reset(grid_index)
		selected = Vector2i(-1, -1)
		board.entry_view()
	else:
		game.start_wave()
	refresh_ui()

func toggle_pause() -> void:
	game.paused = not game.paused
	refresh_ui()

func toggle_speed() -> void:
	var index: int = game.COMBAT_SPEEDS.find(game.speed_multiplier)
	game.speed_multiplier = game.COMBAT_SPEEDS[(index + 1) % game.COMBAT_SPEEDS.size()]
	refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(pause_button):
		game.paused = true
		refresh_ui()

func refresh_ui() -> void:
	status.text = "Or %d  •  Château %d  •  Vague %d/100" % [game.gold, game.lives, game.wave]
	message.text = game.message
	map_info.text = "Chemin : %d cases  •  Tours : %d  •  Record : %d" % [game.route.size(), game.towers.size(), game.best]
	grid_choice.disabled = game.wave > 0 or not game.towers.is_empty()
	var highlighted_kind := int(game.towers[selected].kind) if game.towers.has(selected) else selected_kind
	for i in range(type_buttons.size()):
		type_buttons[i].modulate = Color("f8d788") if i == highlighted_kind else Color.WHITE
		type_buttons[i].disabled = game.ended
	if game.ended:
		wave_button.text = "Rejouer"
	elif game.active:
		wave_button.text = "Vague %d en cours" % game.wave
	else:
		wave_button.text = "Préparation : %d s" % int(ceil(game.preparation)) if game.wave == 0 else "Vague %d • %d s" % [game.wave + 1, int(ceil(game.preparation))]
	wave_button.disabled = game.active or (not game.ended and (game.paused or game.wave == 0))
	pause_button.text = "Reprendre" if game.paused else "Pause"
	pause_button.disabled = game.ended
	speed_button.text = "Combat ×%d" % game.speed_multiplier
	upgrade_button.disabled = true
	sell_button.disabled = true
	upgrade_button.tooltip_text = "Sélectionnez une tour construite sur la carte."
	var kind := selected_kind
	var level := 1
	if game.towers.has(selected):
		var tower: Dictionary = game.towers[selected]
		kind = int(tower.kind)
		level = int(tower.level)
		var cost: int = game.upgrade_cost(tower)
		upgrade_button.text = "Niveau maximum" if level >= 7 else "Niveau %d • %d or" % [level + 1, cost]
		if level < 7 and game.gold < cost:
			upgrade_button.text = "N%d : manque %d or" % [level + 1, cost - game.gold]
		upgrade_button.tooltip_text = "Niveau maximum atteint." if level >= 7 else "Améliorer cette tour pour %d or." % cost
		sell_button.text = "Vendre • %d or" % int(tower.spent * 0.7)
		upgrade_button.disabled = game.ended or level >= 7 or game.gold < cost
		sell_button.disabled = game.ended
	else:
		selected = Vector2i(-1, -1)
		upgrade_button.text = "Améliorer"
		sell_button.text = "Vendre"
	var spec: Dictionary = game.TYPES[kind]
	var effect := ""
	match spec.mode:
		"slow": effect = "Ralentit une cible • aucun dégât"
		"slow_aoe": effect = "Ralentit en zone • aucun dégât"
		"dot": effect = "Poison magique • %.1f dégâts/s" % (float(spec.damage) * pow(1.55, level - 1))
		_: effect = "%s • %s • %.0f/tir • %.1f s" % ["Physique" if spec.school == "physical" else "Magie", "zone" if spec.mode == "aoe" else "cible unique", float(spec.damage) * pow(1.55, level - 1), float(spec.delay)]
	var level_text := "N%d/7" % level if game.towers.has(selected) else "à construire"
	detail.text = "%s • %s • portée %.1f • %s\n%s" % [spec.name, level_text, float(spec.range), "air" if spec.air else "sol", effect]
	board.selected = selected
	board.refresh()

func _process(delta: float) -> void:
	game.tick(minf(delta, 0.25))
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0.0
		refresh_ui()
	else:
		board.refresh()
	if game.best != saved_best:
		var save := ConfigFile.new()
		save.set_value("progress", "best_wave", game.best)
		if save.save("user://progress.cfg") == OK:
			saved_best = game.best
