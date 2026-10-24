extends RefCounted
## MODÈLE DU JEU : règles, économie, chemins et simulation de combat.
## RefCounted est un objet de données ; il ne dessine rien et ne lit aucun fichier.
## main.gd l'instancie et appelle tick ; board.gd et inspection.gd lisent ses données.
## Les coordonnées et portées de ce fichier sont exprimées en cases, les durées en secondes.
## Les tours et ennemis sont des Dictionary : tower.level lit la clé "level", sans classe dédiée.

# PARAMÈTRES GLOBAUX : fin de campagne, niveau maximal, vitesses et pas fixe de simulation.
const LAST_WAVE := 100
const MAX_LEVEL := 7
const COMBAT_SPEEDS := [1, 2, 3, 5]
const SIMULATION_STEP := 1.0 / 60.0
# Vector2i stocke (largeur, hauteur), contrairement au libellé hauteur × longueur de l'interface.
const GRID_SIZES := [Vector2i(100, 50), Vector2i(50, 25), Vector2i(200, 100)]
# CATALOGUE DES TOURS, indexé de 0 à 7.
# cost : prix N1 ; damage : dégâts par tir ou DPS du poison ; range : portée en cases.
# delay : secondes entre applications ; mode : single, aoe (zone), slow, slow_aoe ou dot (poison).
# school : physical, magic ou none ; air : cible aérienne uniquement si true ; color : couleur provisoire.
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

# GRILLE ET NAVIGATION : entrée à gauche, château à droite, au milieu de la hauteur.
var cols := 100
var rows := 50
var entry := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
# Chaque clé de towers est une case Vector2i ; sa valeur décrit la tour (type, niveau, PV…).
# flow contient les distances jusqu'au château ; route est un seul chemin minimal dessiné depuis l'entrée.
var towers: Dictionary = {}
var flow := PackedInt32Array()
var route: Array[Vector2i] = []
# enemies contient les monstres vivants ou en attente de retrait ; shots ne sert qu'aux effets visuels.
var enemies: Array = []
var shots: Array = []
# ÉTAT DE PARTIE : ressources, progression et indicateurs de combat/pause/victoire.
# best est le record chargé/sauvegardé par main.gd et conservé lors de reset.
var gold := 600
var lives := 20
var wave := 0
var best := 0
var active := false
var ended := false
var won := false
var paused := false
var speed_multiplier := 1
# HORLOGES : accumulator stocke le temps de combat encore à simuler ; preparation est le compte à rebours.
# spawn_clock sépare les apparitions ; to_spawn est le nombre restant et spawned le nombre déjà créé.
var combat_accumulator := 0.0
var preparation := 60.0
var spawn_clock := 0.0
var to_spawn := 0
var spawned := 0
# message est le retour destiné au joueur ; destroyed compte les tours détruites par les boss.
# revision invalide le cache du chemin dans board ; next_enemy_id identifie chaque unité pour sa fiche.
var message := ""
var destroyed := 0
var revision := 0
var rng := RandomNumberGenerator.new()
var next_enemy_id := 1

## Constructeur : initialise le générateur aléatoire et crée une partie sur la grille par défaut.
## Godot appelle automatiquement cette méthode lors de Model.new().
func _init() -> void:
	rng.randomize()
	reset(0)

## Recommence une partie avec la grille désignée par grid_index (0, 1 ou 2).
## Efface tours, ennemis et compteurs de partie, puis recalcule les chemins.
## Le record best est conservé ; cette méthode ne lit ni ne sauvegarde de fichier.
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

## Renvoie true si cell est une case comprise dans les limites de la grille.
func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows

## Convertit une case (x, y) en indice pour les tableaux à une dimension.
## La formule y × cols + x permet de stocker toute la grille dans flow.
func cell_id(cell: Vector2i) -> int:
	return cell.y * cols + cell.x

## Calcule les distances minimales de toutes les cases jusqu'au château.
## ignored désigne une tour à considérer comme absente, pour simuler sa destruction.
## Renvoie un tableau : 0 au château, -1 pour une case inaccessible, sinon le nombre de pas.
## Ne modifie pas les tours ni le champ flow actuellement utilisé par la partie.
func field_without(ignored := Vector2i(-1, -1)) -> PackedInt32Array:
	# Un octet par case indique un obstacle. Les tableaux compacts limitent la mémoire des grandes grilles.
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	# Parcourt les tours actuellement présentes, indexées par leur case.
	for cell in towers:
		if cell != ignored:
			blocked[cell_id(cell)] = 1
	var distances := PackedInt32Array()
	distances.resize(cols * rows)
	distances.fill(-1)
	# Parcours en largeur (BFS) depuis le château : toutes les arêtes valent un pas.
	# La file mémorise les cases à visiter ; head lit la prochaine et tail réserve la place suivante.
	var queue := PackedInt32Array()
	queue.resize(cols * rows)
	var head := 0
	var tail := 1
	var goal := cell_id(exit_cell)
	queue[0] = goal
	distances[goal] = 0
	# La première visite donne la distance minimale ; une case inaccessible reste à -1.
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

## Choisit une case voisine dont la distance au château est plus petite.
## distances est le champ de navigation à consulter. Les déplacements sont orthogonaux.
## Renvoie cell si aucun voisin ne rapproche du château ; l'ordre départage les ex æquo.
func next_cell(cell: Vector2i, distances: PackedInt32Array) -> Vector2i:
	var distance := distances[cell_id(cell)]
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
		var next: Vector2i = cell + direction
		if inside(next) and distances[cell_id(next)] >= 0 and distances[cell_id(next)] < distance:
			return next
	return cell

## Recalcule flow et le chemin route affiché depuis l'entrée après un changement de tours.
## Redirige les ennemis terrestres déjà au centre d'une case, sans téléportation.
## Incrémente revision pour prévenir le rendu que son tracé en cache doit changer.
func rebuild_flow() -> void:
	flow = field_without()
	route.clear()
	var cell := entry
	if flow[cell_id(cell)] >= 0:
		route.append(cell)
		while cell != exit_cell:
			cell = next_cell(cell, flow)
			route.append(cell)
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		# Un ennemi déjà entre deux cases finit son segment actuel avant de consulter le nouveau chemin.
		if not enemy.air and enemy.hp > 0 and enemy.fraction <= 0.000001:
			enemy.next = next_cell(enemy.cell, flow)
	revision += 1

## Tente de construire une tour de type kind sur cell, y compris pendant une vague.
## Refuse les cases occupées, l'or insuffisant et tout placement bloquant des monstres.
## Renvoie true après achat ; sinon false, avec la raison dans message et sans débit d'or.
func build(cell: Vector2i, kind: int) -> bool:
	if ended or not inside(cell) or kind < 0 or kind >= TYPES.size():
		message = "Construction impossible sur cette case."
		return false
	if cell == entry or cell == exit_cell or towers.has(cell):
		message = "Cette case ne peut pas accueillir de tour."
		return false
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		if not enemy.air and enemy.hp > 0 and (cell == enemy.cell or cell == enemy.next):
			message = "Une unité traverse cette case. Choisissez une case libre."
			return false
	var cost := int(TYPES[kind].cost)
	if gold < cost:
		message = "%s : il manque %d or." % [TYPES[kind].name, cost - gold]
		return false
	# Placement provisoire pour tester la navigation avant de facturer.
	# kind est l'index du catalogue, cooldown le délai de tir restant, spent le total investi.
	towers[cell] = {"kind": kind, "level": 1, "cooldown": 0.0, "spent": cost, "hp": 120.0}
	# Vérifie le nouveau champ : l'entrée ET chaque monstre terrestre doivent encore atteindre le château.
	# En cas de refus, la tour provisoire est retirée avant tout débit d'or.
	var candidate := field_without()
	if candidate[cell_id(entry)] < 0:
		towers.erase(cell)
		message = "Passage fermé : achat refusé, aucun or débité."
		return false
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		if not enemy.air and enemy.hp > 0 and candidate[cell_id(enemy.next)] < 0:
			towers.erase(cell)
			message = "Ce placement piégerait des monstres : achat refusé."
			return false
	gold -= cost
	rebuild_flow()
	message = "Chemin le plus court : %d cases." % route.size()
	return true

## Renvoie le coût du prochain niveau : prix initial × 1,45^niveau actuel, arrondi au-dessus.
## Le plafond de niveau est contrôlé par upgrade, pas par ce calcul.
func upgrade_cost(tower: Dictionary) -> int:
	return int(ceil(float(TYPES[int(tower.kind)].cost) * pow(1.45, int(tower.level))))

## Améliore la tour de cell jusqu'au niveau 7 si l'or le permet.
## Débite le prix, mémorise l'investissement et ajoute 60 PV actuels ; la portée reste fixe.
## Renvoie true si l'amélioration réussit, sinon false et renseigne message.
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

## Vend la tour de cell et rend 70 % du total investi, arrondi à l'entier inférieur.
## Libère la case puis recalcule les chemins. Autorisé en combat et en pause.
## Renvoie false si la partie est terminée ou si la case ne contient aucune tour.
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

## Décrit la composition de la vague number sans modifier la partie.
## Le dictionnaire renvoyé contient présence d'aériens, catégorie de boss, résistance et effectif.
## boss vaut 0 sans boss, 1 pour un mini boss, 2 aux vagues 50 et 100.
func wave_plan(number: int) -> Dictionary:
	return {"air": number % 10 == 0, "boss": 2 if number == 50 or number == 100 else (1 if number % 10 == 0 else 0), "armor": "physical" if number % 2 == 1 else "magic", "count": 8 + number * 2}

## Démarre la prochaine vague immédiatement, en écourtant la préparation.
## Initialise les compteurs d'apparition et le message ; renvoie true si le départ est accepté.
## Renvoie false en pause, en combat, après la fin de partie ou après la vague 100.
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

## Renvoie les PV initiaux selon le numéro de vague, le vol et la catégorie de boss.
## Progression de 6 % par vague ; aérien ×0,6, mini boss ×16, gros boss ×75.
func enemy_health(number: int, flying: bool = false, boss: int = 0) -> float:
	return 50.0 * pow(1.06, maxi(0, number - 1)) * (0.6 if flying else 1.0) * (75.0 if boss == 2 else (16.0 if boss == 1 else 1.0))

## Crée et ajoute le prochain monstre de la vague, puis renvoie son dictionnaire.
## Alterne sol/air sur les vagues mixtes ; la dernière apparition porte le boss prévu.
## Attribue un identifiant stable pour les infobulles et met à jour les compteurs d'apparition.
func spawn_enemy() -> Dictionary:
	var plan := wave_plan(wave)
	var boss := int(plan.boss) if to_spawn == 1 else 0
	# Une apparition sur deux vole dans une vague mixte ; le boss reste toujours terrestre.
	var flying: bool = plan.air and boss == 0 and spawned % 2 == 0
	var hp := enemy_health(wave, flying, boss)
	var reward: int = (8 + wave * 2) * (30 if boss == 2 else (8 if boss == 1 else 1))
	# STRUCTURE D'UN MONSTRE : cell/next sont ses cases et fraction sa progression de 0 à 1 entre elles.
	# flight mesure le trajet aérien en cases ; speed est la vitesse en cases/seconde.
	# slow_time/slow_factor décrivent le givre ; poison associe chaque source à une durée et un DPS.
	# hp/max_hp servent au combat et à la barre de vie ; reward est l'or gagné ; escaped interdit la récompense.
	# attack_clock cadence les tentatives du gros boss ; armor indique le type de résistance.
	var enemy := {"air": flying, "boss": boss, "armor": "none" if flying else plan.armor, "hp": hp, "max_hp": hp, "cell": entry, "next": next_cell(entry, flow), "fraction": 0.0, "flight": 0.0, "speed": 4.0 if flying else (1.4 if boss > 0 else 2.5), "slow_time": 0.0, "slow_factor": 1.0, "poison": {}, "reward": reward, "attack_clock": 6.0, "escaped": false}
	enemy.id = next_enemy_id
	next_enemy_id += 1
	enemies.append(enemy)
	spawned += 1
	to_spawn -= 1
	return enemy

## Renvoie la position continue du monstre, en cases et centrée dans les cases.
## Interpole cell → next avec fraction au sol, ou entrée → château avec flight en l'air.
## Le rendu multiplie ensuite cette position par CELL pour obtenir ses coordonnées graphiques.
func position_of(enemy: Dictionary) -> Vector2:
	if enemy.air:
		return Vector2(entry).lerp(Vector2(exit_cell), float(enemy.flight) / maxf(1.0, cols - 1)) + Vector2.ONE * 0.5
	return Vector2(enemy.cell).lerp(Vector2(enemy.next), float(enemy.fraction)) + Vector2.ONE * 0.5

## Renvoie le facteur de résistance : 0,5 pour le type résisté, 1,5 pour l'autre.
## Un aérien ou une cible sans armure reçoit ×1 ; can_target gère séparément le droit de tirer.
func damage_multiplier(enemy: Dictionary, school: String) -> float:
	if enemy.air or enemy.armor == "none":
		return 1.0
	return 0.5 if enemy.armor == school else 1.5

## Renvoie la portée en cases du type de tour ; elle ne dépend jamais du niveau.
func tower_range(tower: Dictionary) -> float:
	return float(TYPES[int(tower.kind)].range)

## Renvoie true si l'ennemi est vivant et appartient à la catégorie sol/air de la tour.
## Ne vérifie pas la distance : fire_tower contrôle la portée au moment du ciblage.
func can_target(tower: Dictionary, enemy: Dictionary) -> bool:
	return enemy.hp > 0 and bool(TYPES[int(tower.kind)].air) == bool(enemy.air)

## Applique l'effet d'un impact : dégâts immédiats, ralentissement ou poison.
## source est la case de la tour et sert de clé pour distinguer les poisons cumulables.
## Modifie directement le dictionnaire enemy ; ignore une cible sol/air incompatible.
func apply_hit(source: Vector2i, tower: Dictionary, enemy: Dictionary) -> void:
	if not can_target(tower, enemy):
		return
	var spec: Dictionary = TYPES[int(tower.kind)]
	var level := int(tower.level)
	if spec.mode == "slow" or spec.mode == "slow_aoe":
		var factor := maxf(0.35, (0.6 if spec.mode == "slow" else 0.75) - (level - 1) * 0.04)
		# Le plus petit facteur est le ralentissement le plus fort. Un effet plus faible ne le remplace pas.
		# Une réapplication assez forte renouvelle la durée au lieu de multiplier les ralentissements.
		if enemy.slow_time <= 0 or factor <= enemy.slow_factor:
			enemy.slow_factor = factor
			enemy.slow_time = 2.0 + level * 0.2
	elif spec.mode == "dot":
		# Une clé par tour : cette tour renouvelle son poison, mais plusieurs tours cumulent leurs poisons.
		enemy.poison[source] = {"time": 4.0 + level * 0.5, "dps": float(spec.damage) * pow(1.55, level - 1)}
	else:
		enemy.hp -= float(spec.damage) * pow(1.55, level - 1) * damage_multiplier(enemy, spec.school)

## Cherche une cible à portée, en donnant priorité à la plus proche du château sur son trajet.
## Applique l'impact à cette cible ou à sa zone, puis lance le délai avant le prochain tir.
## Ajoute un effet visuel dans shots ; sans cible, la tour reste prête à tirer.
func fire_tower(cell: Vector2i, tower: Dictionary) -> void:
	var target: Dictionary = {}
	var shortest := INF
	var radius := tower_range(tower)
	var origin := Vector2(cell) + Vector2.ONE * 0.5
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		if not can_target(tower, enemy) or origin.distance_squared_to(position_of(enemy)) > radius * radius:
			continue
		# Compare la distance de trajet restante, pas la distance à vol d'oiseau au château.
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
		# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
		for enemy in enemies:
			# 2,25 = 1,5² : rayon de zone de 1,5 case ; comparer les carrés évite une racine carrée.
			if can_target(tower, enemy) and position_of(enemy).distance_squared_to(point) <= 2.25:
				apply_hit(cell, tower, enemy)
	else:
		apply_hit(cell, tower, target)
	tower.cooldown = float(spec.delay)
	shots.append({"from": origin, "to": point, "color": spec.color, "life": 0.18, "splash": splash})

## Fait subir à enemy les dégâts de ses poisons pendant dt secondes de jeu.
## Chaque source a sa propre durée ; limite les dégâts au temps restant et retire les effets expirés.
func poison_tick(enemy: Dictionary, dt: float) -> void:
	# keys() fournit une liste distincte : on peut retirer un poison expiré pendant cette boucle.
	for source in enemy.poison.keys():
		var effect: Dictionary = enemy.poison[source]
		var duration := minf(dt, float(effect.time))
		enemy.hp -= duration * effect.dps * damage_multiplier(enemy, "magic")
		effect.time -= dt
		if effect.time <= 0:
			enemy.poison.erase(source)

## Avance un monstre pendant dt secondes de jeu en tenant compte du ralentissement actif.
## Au sol, termine chaque segment avant de choisir le suivant ; dans les airs, suit la ligne directe.
## Appelle escape quand le monstre atteint le château.
func move_enemy(enemy: Dictionary, dt: float) -> void:
	var distance: float = enemy.speed * dt * (enemy.slow_factor if enemy.slow_time > 0 else 1.0)
	if enemy.air:
		enemy.flight += distance
		if enemy.flight >= cols - 1:
			escape(enemy)
		return
	# Consomme la distance sur un ou plusieurs segments sans sauter de virage lors d'un grand dt.
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

## Marque une fuite au château une seule fois, sans récompense en or.
## Retire 1 vie pour une unité, 3 pour un mini boss et 5 pour un gros boss ; met ses PV à zéro.
func escape(enemy: Dictionary) -> void:
	if enemy.escaped:
		return
	enemy.escaped = true
	enemy.hp = 0.0
	lives = maxi(0, lives - (5 if enemy.boss == 2 else (3 if enemy.boss == 1 else 1)))

## Renvoie les cases de tours dont la disparition raccourcirait le trajet restant de ce boss.
## Teste au maximum 16 tours tirées au hasard, avec un champ de distances temporaire par tour.
## La simulation de retrait ne détruit aucune construction.
func shortening_targets(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var anchor: Vector2i = enemy.next
	var current := flow[cell_id(anchor)]
	# Échantillonnage sans remise de 16 tours maximum pour borner le coût sur les grands labyrinthes.
	var candidates: Array = towers.keys()
	var tested := 0
	while not candidates.is_empty() and tested < 16:
		var index := rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		tested += 1
		# Le champ temporaire suppose cette tour retirée ; on compare depuis la prochaine case du boss.
		var alternate := field_without(cell)
		if alternate[cell_id(anchor)] >= 0 and alternate[cell_id(anchor)] < current:
			result.append(cell)
	return result

## Fait tenter au gros boss une attaque contre une tour utile à son raccourci.
## force contourne seulement la probabilité de 65 %, principalement pour les tests.
## Renvoie true si une attaque a lieu ; détruit et recalcule les chemins si les PV de la tour tombent à zéro.
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
	return true

## Point d'entrée du temps : delta est la durée réelle écoulée depuis la dernière image.
## La préparation ignore la vitesse de combat ; pause et fin de partie arrêtent la simulation.
## Accumule le temps accéléré, puis exécute des pas fixes pour garder le combat cohérent à ×1/×5.
func tick(delta: float) -> void:
	if paused or ended:
		return
	if not active:
		for shot in shots:
			shot.life -= delta
		# Fonction anonyme de filtrage : conserve seulement les effets visuels dont la durée est positive.
		shots = shots.filter(func(shot): return shot.life > 0)
		preparation = maxf(0.0, preparation - delta)
		if preparation <= 0.0001:
			start_wave()
		return
	# Le temps réel est accéléré puis découpé en pas de 1/60 s.
	# Ainsi ×5 ne transforme pas un grand intervalle en une seule attaque ou un grand saut.
	combat_accumulator += delta * speed_multiplier
	while combat_accumulator + 0.0000001 >= SIMULATION_STEP and active and not ended:
		combat_accumulator -= SIMULATION_STEP
		combat_step(SIMULATION_STEP)
	if not active:
		combat_accumulator = 0.0

## Exécute dt secondes de combat simulé : apparitions, poison, déplacements, boss puis tours.
## Retire les morts, verse leurs récompenses et détermine défaite, fin de vague ou victoire.
## Appelée par tick à pas fixe ; les tests peuvent aussi l'utiliser directement.
func combat_step(dt: float) -> void:
	for shot in shots:
		shot.life -= dt
	# Fonction anonyme de filtrage : conserve seulement les effets visuels dont la durée est positive.
	shots = shots.filter(func(shot): return shot.life > 0)
	# 1. APPARITIONS : une unité toutes les 0,65 seconde de jeu, jusqu'à épuiser la vague.
	spawn_clock -= dt
	while to_spawn > 0 and spawn_clock <= 0:
		spawn_enemy()
		spawn_clock += 0.65
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		# 2. EFFETS ET DÉPLACEMENT : le poison agit avant le mouvement ; une mort arrête cette unité.
		poison_tick(enemy, dt)
		if enemy.hp <= 0:
			continue
		# Découpe le pas au moment où le givre expire : seule la première portion reste ralentie.
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
	# Parcourt les tours actuellement présentes, indexées par leur case.
	for cell in towers:
		var tower: Dictionary = towers[cell]
		# 3. TIRS : diminue l'attente ; une tour prête cherche une cible, sans modifier sa cadence par niveau.
		tower.cooldown = maxf(0.0, tower.cooldown - dt)
		if tower.cooldown <= 0.0000001:
			fire_tower(cell, tower)
	# 4. NETTOYAGE ET RÉCOMPENSES : garde les vivants ; une fuite ne verse jamais d'or.
	var survivors: Array = []
	# Parcourt les dictionnaires de monstres actuellement stockés dans le modèle.
	for enemy in enemies:
		if enemy.hp > 0:
			survivors.append(enemy)
		elif not enemy.escaped:
			gold += int(enemy.reward)
	enemies = survivors
	# 5. FIN DE COMBAT : la défaite est prioritaire ; sinon attend toutes les apparitions et tous les morts.
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
