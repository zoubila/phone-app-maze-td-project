extends Panel
## Passive hover card; pinned touch card with explicit contextual actions.
signal sell_requested(cell: Vector2i)
signal upgrade_requested(cell: Vector2i)
signal dismiss_requested

var target: Dictionary = {}
var pinned := false
var title_label: Label
var body_label: Label
var close_button: Button
var sell_button: Button
var upgrade_button: Button
var anchor := Vector2.ZERO

func _ready() -> void:
	size = Vector2(320, 300)
	z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17271ff5")
	style.border_color = Color("d5bc77")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color("00000066")
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	title_label = make_label(Vector2(14, 10), Vector2(240, 30), 21)
	body_label = make_label(Vector2(14, 48), Vector2(292, 186), 17)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = make_button("×", Vector2(264, 6), Vector2(44, 40))
	close_button.pressed.connect(func(): dismiss_requested.emit())
	upgrade_button = make_button("Améliorer", Vector2(12, 244), Vector2(144, 44))
	upgrade_button.pressed.connect(func():
		if target.get("type") == "tower":
			upgrade_requested.emit(target.cell))
	sell_button = make_button("Vendre", Vector2(164, 244), Vector2(144, 44))
	sell_button.pressed.connect(func():
		if target.get("type") == "tower":
			sell_requested.emit(target.cell))
	hide_card()

func make_label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eee4c8"))
	add_child(label)
	return label

func make_button(text_value: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = dimensions
	button.text = text_value
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

func hide_card() -> void:
	target = {}
	pinned = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_card(value: Dictionary, point: Vector2, pin: bool) -> void:
	target = value.duplicate()
	anchor = point
	pinned = pin
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if pin and value.type != "catalog" else Control.MOUSE_FILTER_IGNORE
	close_button.visible = pin
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP if pin else Control.MOUSE_FILTER_IGNORE
	var actions: bool = pin and value.type == "tower"
	sell_button.visible = actions
	upgrade_button.visible = actions
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP if actions else Control.MOUSE_FILTER_IGNORE
	upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP if actions else Control.MOUSE_FILTER_IGNORE

func fit_inside(bounds: Rect2) -> void:
	var desired := anchor + Vector2(16, 16)
	if desired.x + size.x > bounds.end.x - 12:
		desired.x = anchor.x - size.x - 16
	if desired.y + size.y > bounds.end.y - 12:
		desired.y = anchor.y - size.y - 16
	position = Vector2(clampf(desired.x, bounds.position.x + 12, bounds.end.x - size.x - 12), clampf(desired.y, bounds.position.y + 12, bounds.end.y - size.y - 12))

func update_card(game) -> bool:
	if target.is_empty():
		return false
	if target.type == "enemy":
		for enemy in game.enemies:
			if enemy.id == target.id and enemy.hp > 0:
				title_label.text = "Gros boss" if enemy.boss == 2 else ("Mini boss" if enemy.boss == 1 else ("Unité aérienne" if enemy.air else "Monstre terrestre"))
				var resistance := "Aucune faiblesse physique" if enemy.air else ("Aucune résistance" if enemy.armor == "none" else ("Résiste au physique • faible à la magie" if enemy.armor == "physical" else "Résiste à la magie • faible au physique"))
				var speed: float = enemy.speed * (enemy.slow_factor if enemy.slow_time > 0 else 1.0)
				body_label.text = "PV : %.0f / %.0f\n%s\nVitesse : %.2f cases/s\nRécompense : %d or\nCiblage : %s\nGivre : %s • Poison : %d\n%s" % [maxf(0, enemy.hp), enemy.max_hp, resistance, speed, enemy.reward, "Ballistes uniquement" if enemy.air else "tours terrestres", "actif" if enemy.slow_time > 0 else "non", enemy.poison.size(), "Peut détruire les constructions" if enemy.boss == 2 else ("Fiche fixe • × pour fermer" if pinned else "Cliquer / toucher pour garder la fiche")]
				return true
		return false
	var tower: Dictionary
	var catalog: bool = target.type == "catalog"
	if catalog:
		tower = {"kind": target.kind, "level": 1, "hp": 120.0, "spent": game.TYPES[int(target.kind)].cost}
	elif game.towers.has(target.cell):
		tower = game.towers[target.cell]
	else:
		return false
	var spec: Dictionary = game.TYPES[int(tower.kind)]
	var level := int(tower.level)
	var damage := float(spec.damage) * pow(1.55, level - 1)
	var effect := ""
	match spec.mode:
		"slow", "slow_aoe":
			var factor := maxf(0.35, (0.6 if spec.mode == "slow" else 0.75) - (level - 1) * 0.04)
			effect = "Ralentit de %.0f %% • zéro dégât\nDurée : %.1f s • %s" % [(1.0 - factor) * 100, 2.0 + level * 0.2, "en zone" if spec.mode == "slow_aoe" else "une cible"]
		"dot": effect = "Poison magique : %.1f dégâts/s\nDurée : %.1f s par application" % [damage, 4.0 + level * 0.5]
		_: effect = "%.1f dégâts %s / tir\n%.1f s entre tirs • %s" % [damage, "physiques" if spec.school == "physical" else "magiques", spec.delay, "zone" if spec.mode == "aoe" else "une cible"]
	title_label.text = "%s • %s" % [spec.name, "à construire" if catalog else "N%d/7" % level]
	var price := int(game.upgrade_cost(tower))
	body_label.text = "Cibles : %s\n%s\nPortée fixe : %.1f cases\nPV : %.0f / %.0f\n%s\n%s" % ["air uniquement" if spec.air else "sol uniquement", effect, game.tower_range(tower), tower.hp, 120.0 + (level - 1) * 60, "Prix : %d or" % spec.cost if catalog else ("Niveau maximum atteint" if level == 7 else "Amélioration : %d or" % price), "Choisir une case pour construire" if catalog else "Vente : %d or (70 %%)" % int(tower.spent * 0.7)]
	sell_button.text = "Vendre • %d or" % int(tower.spent * 0.7)
	upgrade_button.text = "Niveau 7" if level == 7 else "N%d • %d or" % [level + 1, price]
	upgrade_button.disabled = game.ended or level == 7 or game.gold < price
	sell_button.disabled = game.ended
	return true
