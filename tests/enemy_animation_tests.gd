extends RefCounted
## Vérifie le lien entre déplacements réels, pause, cadence et nettoyage des états visuels.
const WalkAnimation = preload("res://rendering/enemy_animation.gd")
const Art = preload("res://rendering/unit_art.gd")

static func run(suite) -> void:
	var game = suite.Model.new()
	game.reset(1)
	game.start_wave()
	var enemy: Dictionary = game.spawn_enemy()
	enemy.armor = "physical"
	var animation = WalkAnimation.new()
	animation.update(game)
	suite.check(animation.texture(enemy) == Art.GOBLIN_WALK[0], "goblin starts with first walk frame")
	game.move_enemy(enemy, 0.125)
	animation.update(game)
	suite.check(animation.texture(enemy) == Art.GOBLIN_WALK[1], "goblin steps while approaching from portal")
	var previous_distance: float = animation.states[enemy.id].distance
	enemy.slow_time = 1.0
	enemy.slow_factor = 0.5
	game.move_enemy(enemy, 0.125)
	animation.update(game)
	suite.near(float(animation.states[enemy.id].distance) - previous_distance, 0.15625, "frost slows visual stride with actual movement")
	enemy.slow_time = 0.0
	game.paused = true
	var stopped: Texture2D = animation.texture(enemy)
	game.tick(1.0)
	animation.update(game)
	suite.check(animation.texture(enemy) == stopped, "pause freezes walk frame")
	game.paused = false
	game.speed_multiplier = 5
	previous_distance = animation.states[enemy.id].distance
	game.tick(0.1)
	animation.update(game)
	suite.near(float(animation.states[enemy.id].distance) - previous_distance, 1.25, "speed five accelerates visual stride with simulation")
	suite.check(WalkAnimation.frame_index(2.5) == 0, "walk wraps after eight frames")
	suite.check(WalkAnimation.frame_index(0.0) == 0, "zero movement preserves first frame")
	# Une distance identique produit la même phase, quelle que soit sa durée réelle.
	suite.check(WalkAnimation.frame_index(0.625) == 2, "walk cadence follows distance rather than wall clock")
	enemy.portal_remaining = 0.0
	enemy.cell = game.entry + Vector2i(5, 0)
	enemy.next = enemy.cell + Vector2i.LEFT
	enemy.fraction = 0.0
	animation.update(game)
	enemy.fraction = 0.25
	animation.update(game)
	suite.check(animation.facing_left(enemy), "left movement mirrors goblin")
	enemy.cell += Vector2i.LEFT
	enemy.next = enemy.cell + Vector2i.UP
	enemy.fraction = 0.0
	animation.update(game)
	enemy.fraction = 0.25
	animation.update(game)
	suite.check(animation.facing_left(enemy), "vertical movement preserves last horizontal facing")
	enemy.air = true
	suite.check(not Art.has_walk(enemy), "flying enemies do not use goblin walk")
	enemy.air = false
	enemy.boss = 1
	suite.check(not Art.has_walk(enemy), "boss keeps its own illustration")
	enemy.boss = 0
	enemy.armor = "magic"
	suite.check(not Art.has_walk(enemy), "mage keeps its own illustration")
	game.enemies.clear()
	animation.update(game)
	suite.check(animation.states.is_empty(), "removed enemies release visual state")
