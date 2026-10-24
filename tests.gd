extends SceneTree
const Model = preload("res://game.gd")
var checks := 0
var failures := 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(title)

func near(value: float, expected: float, title: String) -> void:
	check(absf(value - expected) < 0.001, title + " (%f vs %f)" % [value, expected])

func _initialize() -> void:
	call_deferred("run")

func tower(kind: int, level := 1) -> Dictionary:
	return {"kind": kind, "level": level, "spent": Model.TYPES[kind].cost, "hp": 120.0 + (level - 1) * 60, "cooldown": 0.0}

func enemy(game, air := false, armor := "none") -> Dictionary:
	var item: Dictionary = game.spawn_enemy()
	item.air = air
	item.armor = armor
	item.hp = 1000.0
	item.max_hp = 1000.0
	return item

func gui_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)

func run() -> void:
	var started := Time.get_ticks_msec()
	var game = Model.new()
	for index in range(3):
		game.reset(index)
		check(game.cols == Model.GRID_SIZES[index].x and game.rows == Model.GRID_SIZES[index].y, "Selected dimensions")
		check(game.route.size() == game.cols, "Unobstructed shortest path")
		game.gold = 100000
		for y in range(game.rows):
			game.build(Vector2i(3, y), 0)
		check(game.towers.size() == game.rows - 1, "Final blocking placement refused")
		check(game.gold == 100000 - (game.rows - 1) * 50, "Refused construction never charged")
		var astar := AStarGrid2D.new()
		astar.region = Rect2i(0, 0, game.cols, game.rows)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.update()
		for cell in game.towers:
			astar.set_point_solid(cell)
		var reference := astar.get_id_path(game.entry, game.exit_cell)
		check(reference.size() == game.route.size(), "Shortest path agrees with independent AStarGrid2D")
		for i in range(1, game.route.size()):
			var difference: Vector2i = game.route[i] - game.route[i - 1]
			check(absi(difference.x) + absi(difference.y) == 1 and not game.towers.has(game.route[i]), "Path continuity and obstacle avoidance")
	game.reset(1)
	check(not game.build(game.entry, 0) and not game.build(game.exit_cell, 0), "Protect entry and exit")
	check(not game.build(Vector2i(-1, 2), 0) and not game.build(Vector2i(game.cols, 2), 0), "Reject out-of-bounds coordinates")
	check(not game.build(Vector2i(1, 1), -1) and not game.build(Vector2i(1, 1), 8), "Reject invalid tower types")
	game.gold = 0
	check(not game.build(Vector2i(1, 1), 0), "Reject unaffordable purchase")
	for kind in range(8):
		game.reset(1)
		game.gold = 100000
		var cell := Vector2i(1, 1)
		check(game.build(cell, kind), "Build each of eight tower classes")
		var previous_damage: float = float(Model.TYPES[kind].damage)
		for level in range(2, 8):
			var price: int = game.upgrade_cost(game.towers[cell])
			var previous_gold: int = game.gold
			check(game.upgrade(cell), "Upgrade succeeds through level seven")
			check(game.towers[cell].level == level and game.gold == previous_gold - price, "Upgrade price and level")
			near(game.tower_range(game.towers[cell]), float(Model.TYPES[kind].range), "Range stays fixed at every upgrade level")
		check(not game.upgrade(cell) and game.towers[cell].level == 7, "Level seven cap")
		var refund := int(game.towers[cell].spent * 0.7)
		var before: int = game.gold
		check(game.sell(cell) and game.gold == before + refund, "Refund all investment at 70 percent")
	game.reset(1)
	game.speed_multiplier = 2
	check(game.start_wave(), "Can launch the first wave immediately")
	check(game.active and game.wave == 1 and game.preparation == 0, "Manual launch clears preparation countdown")
	check(not game.start_wave() and game.wave == 1, "Repeated launch cannot create a second active wave")
	game.reset(1)
	game.speed_multiplier = 2
	game.tick(59.9)
	check(not game.active and game.wave == 0, "No wave before 60 seconds even in double speed")
	game.paused = true
	game.tick(2.0)
	near(game.preparation, 0.1, "Pause freezes preparation")
	game.paused = false
	game.tick(0.1)
	check(game.active and game.wave == 1, "Automatic start at one minute")
	check(game.build(Vector2i(1, 1), 0), "Can build during wave")
	check(game.upgrade(Vector2i(1, 1)), "Can upgrade during wave")
	game.paused = true
	check(game.upgrade(Vector2i(1, 1)), "Can upgrade while paused")
	check(game.sell(Vector2i(1, 1)), "Can sell while paused during wave")
	check(game.build(Vector2i(1, 1), 4), "Can place antiair ballista while paused during wave")
	check(game.sell(Vector2i(1, 1)), "Can sell antiair tower")
	game.paused = false
	game.tick(0.1)
	check(game.enemies.size() == 1, "Automatic spawning")
	var original: Vector2 = game.position_of(game.enemies[0])
	game.paused = true
	game.tick(0.1)
	check(game.position_of(game.enemies[0]) == original, "Pause freezes enemies")
	game.paused = false
	game.tick(0.1)
	near(game.position_of(game.enemies[0]).distance_to(original), 0.5, "Double combat speed")
	for wave in range(1, 101):
		var plan: Dictionary = game.wave_plan(wave)
		check(bool(plan.air) == (wave % 10 == 0), "Flying units every tenth wave")
		check(plan.boss == (2 if wave == 50 or wave == 100 else (1 if wave % 10 == 0 else 0)), "Mini and major boss schedule")
		check(plan.armor == ("physical" if wave % 2 == 1 else "magic"), "Alternating ground resistances")
		if wave > 1:
			near(game.enemy_health(wave) / game.enemy_health(wave - 1), 1.06, "Enemy health increases by six percent each wave")
	for wave in range(10, 101, 10):
		game.reset(1)
		game.wave = wave
		game.to_spawn = game.wave_plan(wave).count
		var air_count := 0
		var ground_count := 0
		while game.to_spawn > 0:
			var mixed: Dictionary = game.spawn_enemy()
			if mixed.air:
				air_count += 1
				near(mixed.max_hp, game.enemy_health(wave) * 0.6, "Flying HP reduced to 60 percent of ground HP")
			elif mixed.boss == 0:
				ground_count += 1
		check(air_count > 0 and ground_count > 0, "Every flying wave includes regular ground enemies")
	check(game.enemy_health(10, true) < 60.0, "First flying wave no longer has 224 HP per flyer")
	near(game.enemy_health(10, false, 1), game.enemy_health(10) * 16.0, "Mini boss durability doubled from prototype 03")
	for boss_wave in [50, 100]:
		near(game.enemy_health(boss_wave, false, 2), game.enemy_health(boss_wave) * 75.0, "Major boss durability tripled from prototype 03")
	for level in [1, 7]:
		game.reset(1)
		game.gold = 100000
		var archer_cell: Vector2i = game.entry + Vector2i(1, -1)
		game.build(archer_cell, 0)
		for upgrade_index in range(level - 1):
			game.upgrade(archer_cell)
		game.preparation = 0
		game.start_wave()
		var dummy: Dictionary = enemy(game)
		dummy.hp = 100000.0
		dummy.speed = 0.0
		game.to_spawn = 0
		var previous_hp: float = dummy.hp
		var arrow_times: Array[float] = []
		for frame in range(300):
			game.tick(1.0 / 60.0)
			if dummy.hp < previous_hp:
				arrow_times.append((frame + 1) / 60.0)
				previous_hp = dummy.hp
		check(arrow_times.size() == 5, "Archer fires five arrows in five seconds at levels one and seven")
		for index in range(1, arrow_times.size()):
			check(arrow_times[index] - arrow_times[index - 1] >= 1.2 - 0.000001, "Archer animation has 1.2 simulated seconds between arrows")
		game.enemies.clear()
		dummy = enemy(game)
		var untouched: float = dummy.hp
		game.fire_tower(game.entry + Vector2i(4, 0), game.towers[archer_cell])
		near(dummy.hp, untouched, "Upgraded archer cannot hit outside its base range")
	game.reset(1)
	game.build(game.entry + Vector2i(1, -1), 0)
	game.preparation = 0
	game.start_wave()
	var ttk_dummy: Dictionary = enemy(game)
	ttk_dummy.hp = 300.0
	ttk_dummy.speed = 0.0
	game.to_spawn = 0
	var measured_ttk := 0.0
	while ttk_dummy.hp > 0 and measured_ttk < 60.0:
		game.tick(1.0 / 60.0)
		measured_ttk += 1.0 / 60.0
	check(measured_ttk >= 22.8 and measured_ttk < 22.9, "Archer TTK is 22.8 seconds against neutral stationary 300 HP target")
	game.reset(1)
	game.build(game.entry + Vector2i(2, -1), 4)
	game.build(game.entry + Vector2i(7, -1), 4)
	game.wave = 9
	game.preparation = 0
	game.start_wave()
	for frame in range(1000):
		game.tick(0.1)
		# Isolate antiair balance: ground units are removed by the harness.
		for item in game.enemies:
			if not item.air:
				item.hp = 0
		if not game.active:
			break
	check(not game.active and game.lives == 20, "Two level-one ballistas can defeat the first flying contingent")
	# Dynamic building may reroute, but may never trap an already spawned enemy.
	game.reset(1)
	game.gold = 100000
	for cell in [Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 5), Vector2i(5, 3), Vector2i(5, 5)]:
		game.build(cell, 0)
	game.preparation = 0.0
	game.start_wave()
	var trapped: Dictionary = game.spawn_enemy()
	trapped.cell = Vector2i(4, 4)
	trapped.next = Vector2i(5, 4)
	trapped.fraction = 0.5
	var trap_gold: int = game.gold
	check(not game.build(Vector2i(6, 4), 0), "Cannot trap a ground unit away from the entrance route")
	check(game.gold == trap_gold and not game.towers.has(Vector2i(6, 4)), "Trapping placement is rolled back without charge")
	check(not game.build(trapped.cell, 0) and not game.build(trapped.next, 0), "Cannot build under a moving ground enemy")
	var moving_position: Vector2 = game.position_of(trapped)
	check(game.sell(Vector2i(4, 3)), "Selling works in live combat")
	check(game.position_of(trapped) == moving_position, "Live sale and repath do not teleport units")
	# Identical simulated time must produce identical combat at every speed.
	var reference: Dictionary = {}
	for speed in Model.COMBAT_SPEEDS:
		game.reset(1)
		game.gold = 10000
		game.build(game.entry + Vector2i(2, -1), 0)
		game.build(game.entry + Vector2i(4, 1), 7)
		game.build(game.entry + Vector2i(6, -1), 4)
		game.wave = 9
		game.preparation = 0
		game.start_wave()
		game.speed_multiplier = speed
		for frame in range(600 / speed):
			game.tick(0.02)
		var health := 0.0
		var positions := 0.0
		for item in game.enemies:
			health += item.hp
			positions += game.position_of(item).x
		var result := {"gold": game.gold, "lives": game.lives, "spawned": game.spawned, "health": health, "positions": positions}
		if reference.is_empty():
			reference = result
		else:
			check(result.gold == reference.gold and result.lives == reference.lives and result.spawned == reference.spawned, "Speed does not alter outcomes or spawn timing")
			near(result.health, reference.health, "Speed preserves damage and poison")
			near(result.positions, reference.positions, "Speed preserves movement")
	game.reset(1)
	var armored := enemy(game, false, "physical")
	var warded := enemy(game, false, "magic")
	game.apply_hit(Vector2i.ZERO, tower(0), armored)
	game.apply_hit(Vector2i.ZERO, tower(0), warded)
	near(armored.hp, 992.5, "Physical resistance halves physical damage")
	near(warded.hp, 977.5, "Physical vulnerability multiplies physical damage")
	game.apply_hit(Vector2i.ZERO, tower(2), armored)
	game.apply_hit(Vector2i.ZERO, tower(2), warded)
	near(armored.hp, 959.5, "Magic vulnerability")
	near(warded.hp, 966.5, "Magic resistance")
	var flying := enemy(game, true)
	for kind in range(8):
		if kind != 4:
			game.apply_hit(Vector2i.ZERO, tower(kind), flying)
	near(flying.hp, 1000.0, "Air immune to all ground damage towers")
	check(flying.poison.is_empty() and flying.slow_time == 0, "Ground controls cannot affect air")
	game.apply_hit(Vector2i.ZERO, tower(4), flying)
	near(flying.hp, 976.0, "Beacon deals neutral physical damage to air")
	var ground := enemy(game)
	game.apply_hit(Vector2i.ZERO, tower(4), ground)
	near(ground.hp, 1000.0, "Beacon never damages ground")
	for kind in [5, 6]:
		game.apply_hit(Vector2i.ZERO, tower(kind, 7), ground)
		near(ground.hp, 1000.0, "Slow towers do zero damage at every level")
		check(ground.slow_time > 0 and ground.slow_factor < 1, "Slow applied")
	var strongest: float = ground.slow_factor
	game.apply_hit(Vector2i.ZERO, tower(6), ground)
	near(ground.slow_factor, strongest, "Weaker slow cannot replace stronger one")
	for kind in [1, 3, 6]:
		game.reset(1)
		var first := enemy(game)
		var second := enemy(game)
		var source: Vector2i = game.entry + Vector2i(1, 1)
		game.fire_tower(source, tower(kind))
		if kind == 6:
			check(first.slow_time > 0 and second.slow_time > 0 and first.hp == 1000 and second.hp == 1000, "Seismic area control has no damage")
		else:
			check(first.hp < 1000 and second.hp < 1000, "Physical and magical area damage")
	game.reset(1)
	ground = enemy(game, false, "physical")
	game.apply_hit(Vector2i(1, 1), tower(7), ground)
	near(ground.hp, 1000.0, "Poison has no instant damage")
	game.apply_hit(Vector2i(1, 1), tower(7), ground)
	check(ground.poison.size() == 1, "Same poison source refreshes without stacking")
	game.poison_tick(ground, 1.0)
	near(ground.hp, 989.5, "DoT deals magic damage with resistance multiplier")
	game.apply_hit(Vector2i(2, 1), tower(7), ground)
	check(ground.poison.size() == 2, "Distinct poison sources stack")
	game.poison_tick(ground, 10.0)
	near(ground.hp, 905.5, "DoT expiry prevents excess damage on long frame")
	check(ground.poison.is_empty(), "Expired poison removed")
	# Real movement after a major boss destroys a relevant wall, without teleporting.
	game.reset(1)
	game.gold = 10000
	for y in range(10, 15):
		game.build(Vector2i(3, y), 0)
	game.wave = 50
	game.to_spawn = 1
	var boss: Dictionary = game.spawn_enemy()
	check(boss.boss == 2 and not boss.air, "Major boss remains ground on a flying wave")
	var before_path: int = game.flow[game.cell_id(boss.next)]
	var before_position: Vector2 = game.position_of(boss)
	var before_gold: int = game.gold
	check(game.boss_attack(boss, true), "Major boss attacks a shortening construction")
	check(game.destroyed == 1 and game.towers.size() == 4, "Construction destroyed")
	check(game.flow[game.cell_id(boss.next)] < before_path, "Destruction strictly shortens boss path")
	check(game.position_of(boss) == before_position, "Repath does not teleport boss")
	check(game.gold == before_gold, "Destroyed tower gives no refund")
	game.move_enemy(boss, 0.1)
	near(game.position_of(boss).distance_to(before_position), 0.14, "Movement remains continuous after destruction")
	var minor: Dictionary = enemy(game)
	minor.boss = 1
	check(not game.boss_attack(minor, true), "Mini boss cannot destroy towers")
	game.reset(1)
	game.wave = 50
	game.to_spawn = 1
	boss = game.spawn_enemy()
	game.gold = 1000
	game.active = false
	game.build(Vector2i(2, 2), 0)
	check(not game.boss_attack(boss, true), "Boss ignores constructions that do not shorten path")
	game.reset(1)
	game.wave = 10
	game.to_spawn = 2
	var air: Dictionary = game.spawn_enemy()
	minor = game.spawn_enemy()
	check(air.air and not minor.air and minor.boss == 1, "Tenth wave combines flying units and terrestrial mini boss")
	var point: Vector2 = game.position_of(air)
	game.move_enemy(air, 1.0)
	near(game.position_of(air).distance_to(point), 4.0, "Air follows direct route")
	game.wave = 1
	var reward_early: int = game.spawn_enemy().reward
	game.wave = 99
	check(game.spawn_enemy().reward > reward_early, "Rewards increase with wave")
	# Exercise the full campaign state machine. Enemies are deliberately killed
	# by the harness; this tests scheduling, payouts and victory, not balancing.
	game = Model.new()
	game.reset(1)
	game.preparation = 0.0
	var kills := 0
	for expected_wave in range(1, 101):
		check(game.start_wave(), "Start each campaign wave")
		var gold_before: int = game.gold
		var steps := 0
		while game.active and steps < 500:
			game.tick(0.65)
			for item in game.enemies:
				item.hp = 0
				kills += 1
			steps += 1
		check(not game.active and game.best == expected_wave, "Every wave clears and updates record")
		check(game.gold > gold_before, "Each wave pays rewards")
		var once: int = game.gold
		game.tick(0.1)
		check(game.gold == once, "No duplicate clear bonus")
	check(game.ended and game.won and game.wave == 100, "Victory exactly at wave 100")
	check(not game.start_wave(), "No wave 101")
	game.reset(1)
	game.preparation = 0
	game.start_wave()
	game.lives = 1
	game.to_spawn = 1
	var leak: Dictionary = game.spawn_enemy()
	leak.cell = game.exit_cell - Vector2i.RIGHT
	leak.next = game.exit_cell
	leak.fraction = 0.95
	game.tick(0.1)
	check(game.ended and not game.won and game.lives == 0, "Ground escape causes defeat")
	check(game.gold == 600, "No gold for escaped enemy")
	game.reset(1)
	check(not game.ended and game.wave == 0 and game.preparation == 60, "Replay restores first preparation")
	# UI input uses actual GUI events: tap builds, drag pans without building.
	var scene = load("res://main.tscn").instantiate()
	root.size = Vector2i(720, 1280)
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	check(not scene.wave_button.disabled and scene.wave_button.text.contains("60"), "First-wave launch button is enabled at 60 seconds")
	gui_click(scene.wave_button.get_global_rect().get_center())
	check(scene.game.active and scene.game.wave == 1 and scene.game.preparation == 0, "GUI click starts first wave without waiting")
	var board: Control = scene.board
	var test_cell: Vector2i = scene.game.entry + Vector2i(2, 0)
	var screen: Vector2 = (Vector2(test_cell) + Vector2.ONE * 0.5) * board.CELL * board.zoom + board.pan
	check(board.cell_at(screen) == test_cell, "Screen-to-grid mapping")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	board._gui_input(press)
	press = press.duplicate()
	press.pressed = false
	board._gui_input(press)
	check(scene.game.towers.has(test_cell), "Tap creates a tower through UI signal")
	scene.game.gold = 10000
	scene.game.preparation = 0
	scene.game.start_wave()
	scene.refresh_ui()
	await process_frame
	check(not scene.upgrade_button.disabled and not scene.sell_button.disabled, "Upgrade and sale buttons enabled during combat")
	gui_click(scene.upgrade_button.get_global_rect().get_center())
	check(scene.game.towers[test_cell].level == 2, "Real GUI click upgrades a tower during combat")
	var sale_gold: int = scene.game.gold
	var expected_refund := int(scene.game.towers[test_cell].spent * 0.7)
	gui_click(scene.sell_button.get_global_rect().get_center())
	check(not scene.game.towers.has(test_cell) and scene.game.gold == sale_gold + expected_refund, "Real GUI click sells and credits refund during combat")
	gui_click(scene.type_buttons[4].get_global_rect().get_center())
	check(scene.selected_kind == 4, "Ballista menu button selects antiair class")
	gui_click(board.global_position + screen)
	check(scene.game.towers.has(test_cell) and scene.game.towers[test_cell].kind == 4, "Ballista can be placed through actual GUI during combat")
	scene.game.paused = true
	scene.refresh_ui()
	gui_click(scene.upgrade_button.get_global_rect().get_center())
	check(scene.game.towers[test_cell].level == 2, "Real GUI click upgrades in pause")
	gui_click(scene.sell_button.get_global_rect().get_center())
	check(not scene.game.towers.has(test_cell), "Real GUI click sells in pause")
	for speed in [2, 3, 5, 1]:
		gui_click(scene.speed_button.get_global_rect().get_center())
		check(scene.game.speed_multiplier == speed and scene.speed_button.text.contains(str(speed)), "Speed button cycles 1/2/3/5 and updates label")
	var tower_count: int = scene.game.towers.size()
	press.pressed = true
	board._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = screen + Vector2(-60, 30)
	board._gui_input(motion)
	press.pressed = false
	press.position = motion.position
	board._gui_input(press)
	check(scene.game.towers.size() == tower_count, "Dragging never places a tower")
	var anchor := Vector2(300, 300)
	var world: Vector2 = (anchor - board.pan) / board.zoom
	board.set_zoom(1.3, anchor)
	check(((anchor - board.pan) / board.zoom).distance_to(world) < 0.01, "Zoom preserves anchor")
	board.overview()
	check(board.zoom < 0.2, "Overview supports full-sized maps")
	var before_overview: int = scene.game.towers.size()
	press.position = board.size / 2
	press.pressed = true
	board._gui_input(press)
	press = press.duplicate()
	press.pressed = false
	board._gui_input(press)
	check(board.zoom == 1.0 and scene.game.towers.size() == before_overview, "Overview tap zooms without accidental construction")
	board.castle_view()
	check(board.cell_at(Vector2(board.size.x - 35, board.size.y / 2)) == scene.game.exit_cell, "Castle shortcut")
	# Rotate and resize a live paused game. Test actual GUI coordinates as well
	# as bounds, non-overlap, safe-area scaling and preservation of game state.
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR, "Phone sensor enables portrait and landscape")
	check(ProjectSettings.get_setting("display/window/size/window_width_override") > ProjectSettings.get_setting("display/window/size/window_height_override"), "Default desktop window is landscape")
	scene.game.gold = 100000
	scene.game.build(scene.game.entry + Vector2i(1, 2), 0)
	var rotation_enemy: Dictionary = scene.game.spawn_enemy()
	rotation_enemy.fraction = 0.25
	var rotation_position: Vector2 = scene.game.position_of(rotation_enemy)
	var expected_wave: int = scene.game.wave
	var expected_gold: int = scene.game.gold
	var expected_towers: int = scene.game.towers.size()
	board.zoom = 1.0
	board.pan = board.size / 2.0 - Vector2(25, 25) * board.CELL
	var focus_before: Vector2 = (board.size / 2.0 - board.pan) / board.zoom
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(1600, 720), Vector2i(1024, 768), Vector2i(1080, 2400), Vector2i(2400, 1080)]:
		root.size = dimensions
		await process_frame
		scene.apply_layout(true)
		scene.refresh_ui()
		await process_frame
		check(scene.landscape == (dimensions.x >= dimensions.y), "Layout follows device orientation")
		check(scene.game.wave == expected_wave and scene.game.gold == expected_gold and scene.game.towers.size() == expected_towers, "Rotation preserves wave, gold and towers")
		check(scene.game.position_of(rotation_enemy) == rotation_position, "Rotation does not move or reset enemies")
		check(((board.size / 2.0 - board.pan) / board.zoom).distance_to(focus_before) < 0.01, "Rotation preserves camera focus")
		var bounds := Rect2(Vector2.ZERO, scene.layout_size).grow(0.1)
		var interactive: Array[Control] = []
		for child in scene.get_children():
			if child is Control and child.visible:
				check(bounds.encloses(Rect2(child.position, child.size)), "Visible control stays inside screen: " + child.name)
				if child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					interactive.append(child)
		for a in range(interactive.size()):
			for b in range(a + 1, interactive.size()):
				check(not Rect2(interactive[a].position, interactive[a].size).intersects(Rect2(interactive[b].position, interactive[b].size)), "Touch targets do not overlap")
		var speed_before: int = scene.game.speed_multiplier
		gui_click(scene.speed_button.get_global_transform_with_canvas() * (scene.speed_button.size / 2.0))
		check(scene.game.speed_multiplier != speed_before, "Speed control clickable after rotation and scaling")
		var target_cell: Vector2i = board.cell_at(board.size / 2.0)
		scene.selected_kind = 0
		gui_click(board.get_global_transform_with_canvas() * (board.size / 2.0))
		check(scene.game.towers.has(target_cell), "Construction works after rotation and scaling")
		if scene.game.towers.has(target_cell):
			gui_click(scene.upgrade_button.get_global_transform_with_canvas() * (scene.upgrade_button.size / 2.0))
			check(scene.game.towers[target_cell].level == 2, "Upgrade works after rotation")
			gui_click(scene.sell_button.get_global_transform_with_canvas() * (scene.sell_button.size / 2.0))
			check(not scene.game.towers.has(target_cell), "Sale works after rotation")
		expected_gold = scene.game.gold
		expected_towers = scene.game.towers.size()
	board.overview()
	root.size = Vector2i(720, 1280)
	await process_frame
	scene.apply_layout(true)
	near(board.zoom, board.minimum_zoom(), "Overview refits entire map after rotation")
	var safe_area := Rect2(40, 24, 1200, 656)
	preload("res://ui_layout.gd").arrange(scene, safe_area)
	check(safe_area.grow(0.1).encloses(Rect2(scene.position, scene.layout_size * scene.scale)), "UI respects simulated notch and system-bar safe area")
	scene.queue_free()
	print("CHECKS: %d / FAILURES: %d / CAMPAIGN KILLS: %d / MS: %d" % [checks, failures, kills, Time.get_ticks_msec() - started])
	quit(0 if failures == 0 else 1)
