extends RefCounted
## Vérifie les vrais paiements des quatre difficultés, jusqu'à la vague 100.
## Les morts sont forcées ici pour tester la comptabilité ; la jouabilité utilise un scénario séparé sans triche.

const Model = preload("res://game.gd")
const Difficulty = preload("res://gameplay/difficulty.gd")


## Le total payé doit correspondre au budget, indépendamment des arrondis et du type d'ennemi.
static func run(suite) -> void:
	var game = Model.new()
	var early_totals := [123, 170, 225, 288, 359, 438]
	for difficulty in range(4):
		for wave in range(1, 101):
			game.reset(1, difficulty)
			game.wave = wave - 1
			game.start_wave()
			var plan: Dictionary = game.wave_plan(wave)
			var payments := 0
			while game.to_spawn > 0:
				var enemy: Dictionary = game.spawn_enemy()
				payments += int(enemy.reward)
				enemy.hp = 0
			game.combat_step(0)
			suite.check(game.gold - 600 == plan.income.total, "Actual full-wave income equals its fixed budget")
			suite.check(payments == plan.income.enemy_budget, "All monster shares add up exactly without rounding inflation")
			var paid: int = game.gold
			game.combat_step(0)
			suite.check(game.gold == paid, "A fixed budget cannot be paid twice")
			if wave <= 6:
				var expected_reward := Difficulty.income(difficulty, 8 + wave * 2)
				suite.check(payments == int(plan.count) * expected_reward, "Opening monster income is unchanged in every difficulty")
				if difficulty == 1:
					suite.check(game.gold - 600 == early_totals[wave - 1], "Normal waves one through six keep their exact previous budget")
	var expected_budgets := {10: 680, 20: 1195, 30: 1793, 50: 3391, 100: 8441}
	game.reset(1)
	for wave in expected_budgets:
		suite.check(game.wave_plan(wave).income.total == expected_budgets[wave], "Normal income matches the new reference curve")
	game.start_wave()
	var escaped: Dictionary = game.spawn_enemy()
	game.escape(escaped)
	for enemy_index in range(9):
		var enemy: Dictionary = game.spawn_enemy()
		enemy.hp = 0
	game.combat_step(0)
	suite.check(game.gold - 600 == 113, "Escaped monster loses its share instead of redistributing it")
	for level in range(1, 4):
		suite.near(game.tower_power(level), pow(1.55, level - 1), "First three tower levels preserve their original power")
	for wave in range(1, 7):
		suite.near(game.enemy_health(wave), 50.0 * pow(1.06, wave - 1), "Opening enemy health is unchanged")
	for checkpoint in [Vector2(10, 96), Vector2(20, 350), Vector2(30, 900), Vector2(50, 2200), Vector2(100, 6000)]:
		suite.near(game.enemy_health(int(checkpoint.x)), checkpoint.y, "Normal health follows the new controlled milestones")
	for wave in [1, 6, 7, 10, 25, 50, 100]:
		game.reset(1)
		game.wave = wave
		var plan: Dictionary = game.wave_plan(wave)
		game.to_spawn = plan.count
		var primary := 0
		var secondary := 0
		while game.to_spawn > 0:
			var enemy: Dictionary = game.spawn_enemy()
			if not enemy.air and enemy.boss == 0:
				if enemy.armor == plan.armor:
					primary += 1
				else:
					secondary += 1
		if wave <= 6:
			suite.check(secondary == 0, "Opening waves keep their single alternating resistance")
		else:
			suite.check(primary > secondary and secondary > 0, "Later waves mix both resistances while retaining their dominant type")
	suite.near(game.tower_power(7), 9.229444, "Level seven has a controlled power multiplier")
	for kind in [0, 1, 2, 3, 7]:
		var tower: Dictionary = suite.tower(kind, 7)
		var enemy: Dictionary = suite.enemy(game)
		var hp: float = enemy.hp
		game.apply_hit(Vector2i(3, 3), tower, enemy)
		var damage: float = float(game.TYPES[kind].damage) * game.tower_power(7)
		if kind == 7:
			game.poison_tick(enemy, 1.0)
		suite.near(hp - enemy.hp, damage, "Direct and poison damage share the advertised power curve")
	for boss in [0, 1, 2]:
		var enemy: Dictionary = suite.enemy(game)
		enemy.boss = boss
		game.apply_hit(Vector2i(3, 4), suite.tower(5, 7), enemy)
		suite.near(enemy.slow_factor, [0.36, 0.55, 0.60][boss], "Boss slow resistance limits permanent control without changing normal enemies")
