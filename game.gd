extends RefCounted
## Gameplay model; no rendering, filesystem or platform dependencies.

const LAST_WAVE := 100
const MAX_LEVEL := 7
const COMBAT_SPEEDS := [1, 2, 3, 5]
const SIMULATION_STEP := 1.0 / 60.0
const GRID_SIZES := [Vector2i(100, 50), Vector2i(50, 25), Vector2i(200, 100)]
const TYPES := [
	{"name": "Archer", "cost": 50, "damage": 15.0, "range": 3.6, "delay": 1.2, "mode": "single", "school": "physical", "air": false, "color": Color("#FF0203")},
	{"name": "Canon", "cost": 85, "damage": 30.0, "range": 4.0, "delay": 2.0, "mode": "aoe", "school": "physical", "air": false, "color": Color("d58b63")},
	{"name": "Sorcier", "cost": 65, "damage": 22.0, "range": 3.6, "delay": 1.2, "mode": "single", "school": "magic", "air": false, "color": Color("bd9de8")},
	{"name": "Arcane", "cost": 100, "damage": 26.0, "range": 3.4, "delay": 1.8, "mode": "aoe", "school": "magic", "air": false, "color": Color("df9ace")},
	{"name": "Balliste", "cost": 70, "damage": 24.0, "range": 5.0, "delay": 0.9, "mode": "single", "school": "physical", "air": true, "color": Color("f1d18a")},
	{"name": "Frost", "cost": 60, "damage": 0.0, "range": 3.2, "delay": 0.8, "mode": "slow", "school": "none", "air": false, "color": Color("8ed7df")},
	{"name": "Séisme", "cost": 90, "damage": 0.0, "range": 3.0, "delay": 1.5, "mode": "slow_aoe", "school": "none", "air": false, "color": Color("c7a883")},
	{"name": "Poison", "cost": 80, "damage": 7.0, "range": 3.5, "delay": 1.2, "mode": "dot", "school": "magic", "air": false, "color": Color("9bc974")}
]

var cols := 100
var rows := 50
var entry := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var towers: Dictionary = {}
var flow := PackedInt32Array()
var route: Array[Vector2i] = []
var enemies: Array = []
var shots: Array = []
var gold := 600
var lives := 20
var wave := 0
var best := 0
var active := false
var ended := false
var won := false
var paused := false
var speed_multiplier := 1
var combat_accumulator := 0.0
var preparation := 60.0
var spawn_clock := 0.0
var to_spawn := 0
var spawned := 0
var message := ""
var destroyed := 0
var revision := 0
var rng := RandomNumberGenerator.new()
var next_enemy_id := 1

func _init() -> void:
	rng.randomize()
	reset(0)

func reset(grid_index: int = 0) -> void:
	var dimensions: Vector2i = GRID_SIZES[clampi(grid_index, 0, 2)]
	cols = dimensions.x
	rows = dimensions.y
	entry = Vector2i(0, rows / 2)
	exit_cell = Vector2i(cols - 1, rows / 2)
	towers.clear()
	enemies.clear()
	shots.clear()
	gold = 600
	lives = 20
	wave = 0
	active = false
	ended = false
	won = false
	paused = false
	speed_multiplier = 1
	combat_accumulator = 0.0
	preparation = 60.0
	to_spawn = 0
	spawned = 0
	destroyed = 0
	next_enemy_id = 1
	message = "Bâtissez ou lancez la vague dès que vous êtes prêt."
	rebuild_flow()

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows

func cell_id(cell: Vector2i) -> int:
	return cell.y * cols + cell.x

func field_without(ignored := Vector2i(-1, -1)) -> PackedInt32Array:
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	for cell in towers:
		if cell != ignored:
			blocked[cell_id(cell)] = 1
	var distances := PackedInt32Array()
	distances.resize(cols * rows)
	distances.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(cols * rows)
	var head := 0
	var tail := 1
	var goal := cell_id(exit_cell)
	queue[0] = goal
	distances[goal] = 0
	while head < tail:
		var current := queue[head]
		head += 1
		var x := current % cols
		var y := current / cols
		for neighbor in [current + 1 if x + 1 < cols else -1, current + cols if y + 1 < rows else -1, current - cols if y > 0 else -1, current - 1 if x > 0 else -1]:
			if neighbor >= 0 and distances[neighbor] == -1 and blocked[neighbor] == 0:
				distances[neighbor] = distances[current] + 1
				queue[tail] = neighbor
				tail += 1
	return distances

func next_cell(cell: Vector2i, distances: PackedInt32Array) -> Vector2i:
	var distance := distances[cell_id(cell)]
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
		var next: Vector2i = cell + direction
		if inside(next) and distances[cell_id(next)] >= 0 and distances[cell_id(next)] < distance:
			return next
	return cell

func rebuild_flow() -> void:
	flow = field_without()
	route.clear()
	var cell := entry
	if flow[cell_id(cell)] >= 0:
		route.append(cell)
		while cell != exit_cell:
			cell = next_cell(cell, flow)
			route.append(cell)
	for enemy in enemies:
		if not enemy.air and enemy.hp > 0 and enemy.fraction <= 0.000001:
			enemy.next = next_cell(enemy.cell, flow)
	revision += 1

func build(cell: Vector2i, kind: int) -> bool:
	if ended or not inside(cell) or kind < 0 or kind >= TYPES.size():
		message = "Construction impossible sur cette case."
		return false
	if cell == entry or cell == exit_cell or towers.has(cell):
		message = "Cette case ne peut pas accueillir de tour."
		return false
	for enemy in enemies:
		if not enemy.air and enemy.hp > 0 and (cell == enemy.cell or cell == enemy.next):
			message = "Une unité traverse cette case. Choisissez une case libre."
			return false
	var cost := int(TYPES[kind].cost)
	if gold < cost:
		message = "%s : il manque %d or." % [TYPES[kind].name, cost - gold]
		return false
	towers[cell] = {"kind": kind, "level": 1, "cooldown": 0.0, "spent": cost, "hp": 120.0}
	var candidate := field_without()
	if candidate[cell_id(entry)] < 0:
		towers.erase(cell)
		message = "Passage fermé : achat refusé, aucun or débité."
		return false
	for enemy in enemies:
		if not enemy.air and enemy.hp > 0 and candidate[cell_id(enemy.next)] < 0:
			towers.erase(cell)
			message = "Ce placement piégerait des monstres : achat refusé."
			return false
	gold -= cost
	rebuild_flow()
	message = "Chemin le plus court : %d cases." % route.size()
	return true

func upgrade_cost(tower: Dictionary) -> int:
	return int(ceil(float(TYPES[int(tower.kind)].cost) * pow(1.45, int(tower.level))))

func upgrade(cell: Vector2i) -> bool:
	if ended or not towers.has(cell):
		message = "Sélectionnez une tour à améliorer."
		return false
	var tower: Dictionary = towers[cell]
	var cost := upgrade_cost(tower)
	if int(tower.level) >= MAX_LEVEL or gold < cost:
		message = "Niveau 7 atteint." if int(tower.level) >= MAX_LEVEL else "Amélioration : il manque %d or." % (cost - gold)
		return false
	gold -= cost
	tower.spent += cost
	tower.level += 1
	tower.hp += 60.0
	message = "%s améliorée au niveau %d." % [TYPES[int(tower.kind)].name, tower.level]
	return true

func sell(cell: Vector2i) -> bool:
	if ended or not towers.has(cell):
		message = "Sélectionnez une tour à vendre."
		return false
	var refund := int(towers[cell].spent * 0.7)
	gold += refund
	towers.erase(cell)
	rebuild_flow()
	message = "Tour vendue : +%d or." % refund
	return true

func wave_plan(number: int) -> Dictionary:
	return {"air": number % 10 == 0, "boss": 2 if number == 50 or number == 100 else (1 if number % 10 == 0 else 0), "armor": "physical" if number % 2 == 1 else "magic", "count": 8 + number * 2}

func start_wave() -> bool:
	if active or ended or paused or wave >= LAST_WAVE:
		return false
	preparation = 0.0
	wave += 1
	active = true
	spawned = 0
	to_spawn = int(wave_plan(wave).count)
	spawn_clock = 0.0
	var plan := wave_plan(wave)
	message = "Vague %d : %s%s" % [wave, "sol + air" if plan.air else "résistance " + plan.armor, " + GROS BOSS" if plan.boss == 2 else (" + mini boss" if plan.boss == 1 else "")]
	return true

func enemy_health(number: int, flying: bool = false, boss: int = 0) -> float:
	# A smooth increase every wave; flying units have 60% of ground HP.
	return 50.0 * pow(1.06, maxi(0, number - 1)) * (0.6 if flying else 1.0) * (75.0 if boss == 2 else (16.0 if boss == 1 else 1.0))

func spawn_enemy() -> Dictionary:
	var plan := wave_plan(wave)
	var boss := int(plan.boss) if to_spawn == 1 else 0
	var flying: bool = plan.air and boss == 0 and spawned % 2 == 0
	var hp := enemy_health(wave, flying, boss)
	var reward: int = (8 + wave * 2) * (30 if boss == 2 else (8 if boss == 1 else 1))
	var enemy := {"air": flying, "boss": boss, "armor": "none" if flying else plan.armor, "hp": hp, "max_hp": hp, "cell": entry, "next": next_cell(entry, flow), "fraction": 0.0, "flight": 0.0, "speed": 4.0 if flying else (1.4 if boss > 0 else 2.5), "slow_time": 0.0, "slow_factor": 1.0, "poison": {}, "reward": reward, "attack_clock": 6.0, "escaped": false}
	enemy.id = next_enemy_id
	next_enemy_id += 1
	enemies.append(enemy)
	spawned += 1
	to_spawn -= 1
	return enemy

func position_of(enemy: Dictionary) -> Vector2:
	if enemy.air:
		return Vector2(entry).lerp(Vector2(exit_cell), float(enemy.flight) / maxf(1.0, cols - 1)) + Vector2.ONE * 0.5
	return Vector2(enemy.cell).lerp(Vector2(enemy.next), float(enemy.fraction)) + Vector2.ONE * 0.5

func damage_multiplier(enemy: Dictionary, school: String) -> float:
	if enemy.air or enemy.armor == "none":
		return 1.0
	return 0.5 if enemy.armor == school else 1.5

func tower_range(tower: Dictionary) -> float:
	return float(TYPES[int(tower.kind)].range)

func can_target(tower: Dictionary, enemy: Dictionary) -> bool:
	return enemy.hp > 0 and bool(TYPES[int(tower.kind)].air) == bool(enemy.air)

func apply_hit(source: Vector2i, tower: Dictionary, enemy: Dictionary) -> void:
	if not can_target(tower, enemy):
		return
	var spec: Dictionary = TYPES[int(tower.kind)]
	var level := int(tower.level)
	if spec.mode == "slow" or spec.mode == "slow_aoe":
		var factor := maxf(0.35, (0.6 if spec.mode == "slow" else 0.75) - (level - 1) * 0.04)
		# The strongest slow wins. Repeated applications refresh its duration.
		if enemy.slow_time <= 0 or factor <= enemy.slow_factor:
			enemy.slow_factor = factor
			enemy.slow_time = 2.0 + level * 0.2
	elif spec.mode == "dot":
		# One DoT per source: refresh rather than stacking a tower's own hits.
		enemy.poison[source] = {"time": 4.0 + level * 0.5, "dps": float(spec.damage) * pow(1.55, level - 1)}
	else:
		enemy.hp -= float(spec.damage) * pow(1.55, level - 1) * damage_multiplier(enemy, spec.school)

func fire_tower(cell: Vector2i, tower: Dictionary) -> void:
	var target: Dictionary = {}
	var shortest := INF
	var radius := tower_range(tower)
	var origin := Vector2(cell) + Vector2.ONE * 0.5
	for enemy in enemies:
		if not can_target(tower, enemy) or origin.distance_squared_to(position_of(enemy)) > radius * radius:
			continue
		var remaining: float = (cols - 1 - enemy.flight) if enemy.air else (flow[cell_id(enemy.next)] + 1.0 - enemy.fraction)
		if remaining < shortest:
			target = enemy
			shortest = remaining
	if target.is_empty():
		return
	var spec: Dictionary = TYPES[int(tower.kind)]
	var point := position_of(target)
	var splash: bool = spec.mode == "aoe" or spec.mode == "slow_aoe"
	if splash:
		for enemy in enemies:
			if can_target(tower, enemy) and position_of(enemy).distance_squared_to(point) <= 2.25:
				apply_hit(cell, tower, enemy)
	else:
		apply_hit(cell, tower, target)
	tower.cooldown = float(spec.delay)
	shots.append({"from": origin, "to": point, "color": spec.color, "life": 0.18, "splash": splash})

func poison_tick(enemy: Dictionary, dt: float) -> void:
	for source in enemy.poison.keys():
		var effect: Dictionary = enemy.poison[source]
		var duration := minf(dt, float(effect.time))
		enemy.hp -= duration * effect.dps * damage_multiplier(enemy, "magic")
		effect.time -= dt
		if effect.time <= 0:
			enemy.poison.erase(source)

func move_enemy(enemy: Dictionary, dt: float) -> void:
	var distance: float = enemy.speed * dt * (enemy.slow_factor if enemy.slow_time > 0 else 1.0)
	if enemy.air:
		enemy.flight += distance
		if enemy.flight >= cols - 1:
			escape(enemy)
		return
	while distance > 0 and not enemy.escaped:
		var step := minf(distance, 1.0 - float(enemy.fraction))
		enemy.fraction += step
		distance -= step
		if enemy.fraction >= 0.999999:
			enemy.cell = enemy.next
			enemy.fraction = 0.0
			if enemy.cell == exit_cell:
				escape(enemy)
				break
			enemy.next = next_cell(enemy.cell, flow)

func escape(enemy: Dictionary) -> void:
	if enemy.escaped:
		return
	enemy.escaped = true
	enemy.hp = 0.0
	lives = maxi(0, lives - (5 if enemy.boss == 2 else (3 if enemy.boss == 1 else 1)))

func shortening_targets(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var anchor: Vector2i = enemy.next
	var current := flow[cell_id(anchor)]
	# Sample at most 16 constructions to bound work on very large mazes.
	var candidates: Array = towers.keys()
	var tested := 0
	while not candidates.is_empty() and tested < 16:
		var index := rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		tested += 1
		var alternate := field_without(cell)
		if alternate[cell_id(anchor)] >= 0 and alternate[cell_id(anchor)] < current:
			result.append(cell)
	return result

func boss_attack(enemy: Dictionary, force := false) -> bool:
	if enemy.boss != 2 or enemy.hp <= 0 or (not force and rng.randf() > 0.65):
		return false
	var candidates := shortening_targets(enemy)
	if candidates.is_empty():
		return false
	var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	towers[cell].hp -= 60.0 + wave * 3.0
	shots.append({"from": position_of(enemy), "to": Vector2(cell) + Vector2.ONE * 0.5, "color": Color("f16b54"), "life": 0.45, "splash": true})
	if towers[cell].hp <= 0:
		towers.erase(cell)
		destroyed += 1
		rebuild_flow()
		message = "Le boss a détruit une tour et raccourci son chemin !"
		# Existing movement edges remain valid; the new flow is used at next cell.
	return true

func tick(delta: float) -> void:
	if paused or ended:
		return
	if not active:
		for shot in shots:
			shot.life -= delta
		shots = shots.filter(func(shot): return shot.life > 0)
		# The first preparation minute and intermissions ignore the combat speed.
		preparation = maxf(0.0, preparation - delta)
		if preparation <= 0.0001:
			start_wave()
		return
	# Simulate at 60 Hz even at x5 so fire rates, movement and DoTs stay fair.
	combat_accumulator += delta * speed_multiplier
	while combat_accumulator + 0.0000001 >= SIMULATION_STEP and active and not ended:
		combat_accumulator -= SIMULATION_STEP
		combat_step(SIMULATION_STEP)
	if not active:
		combat_accumulator = 0.0

func combat_step(dt: float) -> void:
	for shot in shots:
		shot.life -= dt
	shots = shots.filter(func(shot): return shot.life > 0)
	spawn_clock -= dt
	while to_spawn > 0 and spawn_clock <= 0:
		spawn_enemy()
		spawn_clock += 0.65
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		poison_tick(enemy, dt)
		if enemy.hp <= 0:
			continue
		# Split at slow expiry so long frames cannot overapply a slow.
		var slowed := minf(dt, float(enemy.slow_time))
		if slowed > 0:
			move_enemy(enemy, slowed)
			enemy.slow_time = maxf(0.0, enemy.slow_time - slowed)
		if dt > slowed and not enemy.escaped:
			move_enemy(enemy, dt - slowed)
		if enemy.boss == 2 and not enemy.escaped:
			enemy.attack_clock -= dt
			if enemy.attack_clock <= 0:
				enemy.attack_clock += 6.0
				boss_attack(enemy)
	for cell in towers:
		var tower: Dictionary = towers[cell]
		tower.cooldown = maxf(0.0, tower.cooldown - dt)
		if tower.cooldown <= 0.0000001:
			fire_tower(cell, tower)
	var survivors: Array = []
	for enemy in enemies:
		if enemy.hp > 0:
			survivors.append(enemy)
		elif not enemy.escaped:
			gold += int(enemy.reward)
	enemies = survivors
	if lives <= 0:
		active = false
		ended = true
		message = "Le château est tombé. Recomposez votre labyrinthe."
	elif to_spawn == 0 and enemies.is_empty():
		active = false
		gold += 20 + wave * 3
		best = maxi(best, wave)
		preparation = 15.0
		message = "Vague repoussée. Préparez la suivante."
		if wave == LAST_WAVE:
			ended = true
			won = true
			message = "Victoire ! Les 100 vagues ont été repoussées."
