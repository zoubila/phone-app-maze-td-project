extends SceneTree
## Scénario reproductible pour mesurer une défense qui dépense uniquement l'or réellement gagné.
## Aucune invulnérabilité, aucun ennemi retiré artificiellement, aucune récompense inventée.
## Exemple : Godot --headless --path . --script tools/mesurer-equilibrage.gd -- --waves=30 --difficulty=1
## Ce joueur automatique reste une stratégie de référence, pas une preuve de difficulté pour tous les joueurs.

const Model = preload("res://game.gd")
var metrics: Dictionary


## Attend que le moteur soit prêt avant de créer le modèle et le fichier de mesures.
func _initialize() -> void:
	call_deferred("run")


## Lit une option numérique sous la forme --nom=valeur, avec une valeur de repli explicite.
func argument(name: String, fallback: int) -> int:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--" + name + "="):
			return value.get_slice("=", 1).to_int()
	return fallback


## Mesure où les ennemis meurent dans le trajet courant : 0 près de l'entrée, 1 près du château.
func record_kill(game, enemy: Dictionary) -> void:
	var progress: float
	if enemy.air:
		progress = float(enemy.flight) / maxf(1, game.cols - 1)
	else:
		var remaining: float = game.flow[game.cell_id(enemy.next)] + 1.0 - float(enemy.fraction)
		progress = 1.0 - remaining / maxf(1, game.flow[game.cell_id(game.entry)])
	metrics.kills += 1
	metrics.progress += clampf(progress, 0.0, 1.0)


## Lance des vagues successives avec le vrai pas de simulation, et écrit une ligne CSV par vague.
func run() -> void:
	var difficulty := clampi(argument("difficulty", 1), 0, 3)
	var limit := clampi(argument("waves", 30), 1, 100)
	var grid := clampi(argument("grid", 1), 0, 2)
	var strategy := argument("strategy", 1)
	var game = Model.new()
	game.reset(grid, difficulty)
	game.rng.seed = 1337
	game.enemy_defeated.connect(func(enemy): record_kill(game, enemy))
	var output := "user://equilibrage-%d.csv" % difficulty
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--output="):
			output = value.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Impossible de créer le rapport : " + output)
		quit(1)
		return
	file.store_csv_line(PackedStringArray([
		"vague", "or_avant", "or_depense", "or_gagne", "or_apres", "tours", "ameliorations",
		"vies_perdues", "vies_restantes", "monstres_tues", "progression_moyenne_avant_mort_pct",
		"longueur_chemin", "budget_si_tout_tue", "vague_terminee",
	]))
	var starter: Array[Vector2i] = []
	for index in range(8):
		var cell := Vector2i(2 + index / 2, game.entry.y + (-1 if index % 2 == 0 else 1))
		if game.build(cell, [2, 1, 2, 3, 5, 4, 1, 2][index]):
			starter.append(cell)
	# Six parois alternent leur ouverture. Leur construction est progressive et soumise au budget normal.
	var walls: Array = []
	for column in range(6):
		var gap: int = game.rows - 2 if column % 2 == 0 else 1
		for row in range(game.rows):
			if row != gap:
				walls.append([Vector2i(7 + column * 6, row), [1, 3, 6, 2, 0, 4][row % 6]])
	var cursor := 0
	var anti_air: Array[Vector2i] = [starter[5]]
	for wave in range(1, limit + 1):
		var before: int = 600 if wave == 1 else game.gold
		var lives: int = game.lives
		var upgrades := 0
		var target := mini(7, 1 + wave / 2)
		# La stratégie équilibrée prépare les vagues aériennes annoncées au lieu de tout investir au sol.
		if strategy == 1 and wave >= 7:
			var desired := 1 + (wave + 2) / 10 + maxi(0, wave - 40) / 10
			while anti_air.size() < desired:
				var index := anti_air.size()
				var position := Vector2i(4 + (index % 12) * 3, game.entry.y + (-2 if index < 12 else 2))
				if not game.build(position, 4):
					break
				anti_air.append(position)
			for level in range(2, mini(7, 1 + wave / 3) + 1):
				for cell in anti_air:
					if game.towers.has(cell) and game.towers[cell].level < level and game.upgrade(cell):
						upgrades += 1
		# Répartir les améliorations évite de dépenser tout le budget sur une seule tour.
		for level in range(2, target + 1):
			for cell in starter:
				if game.towers.has(cell) and game.towers[cell].level < level and game.upgrade(cell):
					upgrades += 1
		while wave >= 12 and cursor < walls.size():
			var item: Array = walls[cursor]
			if game.gold < game.TYPES[item[1]].cost:
				break
			game.build(item[0], item[1])
			cursor += 1
		for cell in game.towers.keys():
			while game.towers[cell].level < target:
				if not game.upgrade(cell):
					break
				upgrades += 1
		var spent: int = before - game.gold
		var after_build: int = game.gold
		metrics = {"kills": 0, "progress": 0.0}
		game.start_wave()
		var elapsed := 0.0
		while game.active and elapsed < 1800:
			game.tick(0.25)
			elapsed += 0.25
		var mean: float = 100.0 * metrics.progress / maxi(1, metrics.kills)
		file.store_csv_line(PackedStringArray([
			str(wave), str(before), str(spent), str(game.gold - after_build), str(game.gold),
			str(game.towers.size()), str(upgrades), str(lives - game.lives), str(game.lives),
			str(metrics.kills), "%.1f" % mean, str(game.route.size()),
			str(game.wave_plan(wave).income.total), str(not game.active and (not game.ended or game.won)),
		]))
		file.flush()
		print("Vague %d | or %d | vies %d | tours %d | morts à %.1f %% du chemin" % [wave, game.gold, game.lives, game.towers.size(), mean])
		if game.ended or game.active:
			break
		await process_frame
	file.close()
	print("Rapport : ", ProjectSettings.globalize_path(output))
	quit()
