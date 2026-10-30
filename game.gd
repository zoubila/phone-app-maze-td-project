extends RefCounted
## Ce fichier représente une partie de Maze TD et garde ses données au même endroit.
## Commencez la lecture par reset, puis tick : ce sont les deux grandes étapes de la vie d'une partie.
## Les règles détaillées sont rangées dans gameplay/ ; les fonctions ci-dessous indiquent où les trouver.
## Il n'y a qu'une seule partie : self transmet cet objet aux fonctions qui doivent lire ou modifier ses données.

const Navigation = preload("res://gameplay/navigation.gd")
const Construction = preload("res://gameplay/construction.gd")
const Waves = preload("res://gameplay/waves.gd")
const Enemies = preload("res://gameplay/enemies.gd")
const TowerCombat = preload("res://gameplay/tower_combat.gd")
const Bosses = preload("res://gameplay/bosses.gd")
const Simulation = preload("res://gameplay/simulation.gd")
const Difficulty = preload("res://gameplay/difficulty.gd")

# Les événements visuels annoncent des faits du modèle, sans déplacer les règles dans l'interface.
signal wave_repelled(number: int, bonus: int)
signal wave_started(number: int)


const LAST_WAVE := 100
const MAX_LEVEL := 7
const COMBAT_SPEEDS := [1, 2, 3, 5]
const SIMULATION_STEP := 1.0 / 60.0
# Les monstres parcourent ce court sas hors grille avant d'atteindre la case d'entrée.
const PORTAL_APPROACH_CELLS := 4.0
const GRID_SIZES := [Vector2i(100, 50), Vector2i(50, 25), Vector2i(200, 100)]
const TYPES = preload("res://gameplay/tower_catalog.gd").TYPES

# La carte compte cols colonnes et rows lignes. entry est l'arrivée des monstres à gauche.
# exit_cell est la case du château à droite. Vector2i contient les deux coordonnées entières d'une case.
var cols := 100
var rows := 50
var entry := Vector2i.ZERO
var exit_cell := Vector2i.ZERO

# Chaque tour est rangée sous la clé de sa case. Les champs de sa fiche indiquent son type et son état.
# flow contient les distances au château ; route est un chemin minimal utilisé pour la ligne dessinée.
var towers: Dictionary = {}
var flow := PackedInt32Array()
var route: Array[Vector2i] = []

# enemies contient les monstres. shots contient seulement les animations de tir encore visibles.
# Une Array est une liste ; un Dictionary associe des clés, comme hp, à des valeurs.
var enemies: Array = []
var shots: Array = []

# Ces variables décrivent les ressources et l'avancement de la partie.
# active signifie qu'une vague est en cours ; ended indique une fin de partie ; won indique une victoire.
var gold := 600
var difficulty_index := 1
# Cette protection concerne seulement les essais explicitement lancés en mode développeur.
var developer_mode := false
var lives := 20
var wave := 0
var best := 0
var active := false
var ended := false
var won := false
var paused := false
var speed_multiplier := 1

# On garde ici le temps de combat qu'il reste à simuler. Cela évite de perdre du temps à vitesse élevée.
# preparation est l'attente avant la vague ; spawn_clock est l'attente avant le prochain monstre.
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
var presentation_time := 0.0


## Godot appelle cette fonction au moment de créer une partie avec new().
## Elle prépare les tirages aléatoires, puis initialise la grille et les ressources de départ.
func _init() -> void:
	rng.randomize()
	reset(0)


## Recommence une partie sur la grille choisie par grid_index : 0, 1 ou 2.
## Les tours et monstres disparaissent, l'or et les vies reviennent à leur valeur de départ.
## Le record best est conservé. Aucun fichier de sauvegarde n'est lu ou écrit ici.
func reset(grid_index: int = 0, difficulty: int = 1, developer: bool = false) -> void:
	developer_mode = developer
	difficulty_index = clampi(difficulty, 0, Difficulty.PROFILES.size() - 1)
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
	presentation_time = 0.0
	message = "Bâtissez ou lancez la vague dès que vous êtes prêt."
	rebuild_flow()


## Applique la difficulté aux gains des monstres et aux bonus, sans toucher au budget initial ni à la revente.
func combat_income(amount: int) -> int:
	return Difficulty.income(difficulty_index, amount)


## Vérifie si cell désigne une case qui existe sur la carte.
## Renvoie true si ses coordonnées sont valides, ou false si elle est hors de la grille.
func inside(cell: Vector2i) -> bool:
	return Navigation.inside(self, cell)


## Renvoie les cases réservées au château ; le portail est désormais entièrement hors grille.
## Le château est dessiné principalement hors grille : seules trois cases de la dernière colonne le recouvrent.
## Les toits élevés sont hors grille et ne doivent pas condamner les cases vides au-dessus de l'arrivée.
## Il suit la sortie pour fonctionner avec les trois tailles de carte.
## Ces zones interdisent uniquement la construction : les monstres peuvent toujours les traverser.
func landmark_areas() -> Array[Rect2i]:
	var grid := Rect2i(Vector2i.ZERO, Vector2i(cols, rows))
	return [
		Rect2i(exit_cell + Vector2i(0, -2), Vector2i(1, 3)).intersection(grid),
	]


## Vérifie la réservation avant tout achat, indépendamment du zoom, de la souris ou du toucher.
## Le dessin du plateau utilise les mêmes zones pour ne pas afficher une limite différente de la règle.
func is_landmark_area(cell: Vector2i) -> bool:
	for area in landmark_areas():
		if area.has_point(cell):
			return true
	return false


## Transforme une position de grille (x, y) en numéro de case.
## Ce numéro permet de ranger les distances dans une liste simple plutôt que dans un tableau à deux dimensions.
func cell_id(cell: Vector2i) -> int:
	return Navigation.cell_id(self, cell)


## Calcule, pour chaque case, le nombre minimal de pas nécessaires pour atteindre le château.
## Une distance de -1 signifie que la case est inaccessible ; le château a une distance de 0.
## ignored permet de faire le calcul comme si une tour avait disparu, sans vraiment la détruire.
## La liste renvoyée est un résultat temporaire : elle ne remplace pas encore le chemin utilisé par les monstres.
func field_without(ignored := Vector2i(-1, -1)) -> PackedInt32Array:
	return Navigation.field_without(self, ignored)


## Choisit le prochain déplacement d'un monstre depuis la case cell.
## Il faut une case voisine dont la distance au château est plus petite que la distance actuelle.
## Les déplacements diagonaux sont interdits. Sans voisin accessible, la fonction renvoie la case de départ.
func next_cell(cell: Vector2i, distances: PackedInt32Array) -> Vector2i:
	return Navigation.next_cell(self, cell, distances)


## Met à jour les distances et le chemin affiché après l'ajout ou le retrait d'une tour.
## Un monstre entre deux cases termine son déplacement avant de choisir un nouveau chemin.
## Le compteur revision prévient le dessin du plateau que la ligne du chemin doit être reconstruite.
func rebuild_flow() -> void:
	Navigation.rebuild_flow(self)


## Essaie d'acheter une tour de type kind sur la case cell.
## La construction doit être abordable et laisser un passage à l'entrée et à tous les monstres terrestres.
## Renvoie true après un achat réussi. En cas de refus, renvoie false sans retirer d'or et explique la raison dans message.
func build(cell: Vector2i, kind: int) -> bool:
	return Construction.build(self, cell, kind)


## Calcule le prix du prochain niveau à partir du prix initial et du niveau actuel.
## ceil arrondit au nombre entier supérieur : on ne peut pas payer une fraction de pièce d'or.
## Cette fonction calcule un prix ; upgrade vérifie ensuite le niveau maximal et le budget.
func upgrade_cost(tower: Dictionary) -> int:
	return Construction.upgrade_cost(self, tower)


## Essaie d'améliorer la tour située sur cell.
## Une réussite retire le prix, augmente le niveau et ajoute 60 points de vie actuels.
## L'investissement total est mémorisé pour la revente. La portée et la cadence ne changent pas.
func upgrade(cell: Vector2i) -> bool:
	return Construction.upgrade(self, cell)


## Vend la tour de cell et rembourse 70 % de tout l'or investi dans cette tour.
## La case redevient libre et les chemins sont recalculés immédiatement, même pendant une vague.
## Renvoie false si aucune tour n'existe à cet endroit ou si la partie est terminée.
func sell(cell: Vector2i) -> bool:
	return Construction.sell(self, cell)


## Décrit la composition de la vague number, sans la démarrer.
## Le résultat indique son effectif, la présence de volants, la résistance des terrestres et le type de boss.
## Pour boss, 0 signifie aucun boss, 1 un mini boss et 2 un gros boss.
func wave_plan(number: int) -> Dictionary:
	return Waves.wave_plan(self, number)


## Lance la vague suivante sans attendre la fin du compte à rebours.
## Elle prépare le nombre d'apparitions, remet leur minuterie à zéro et annonce la composition au joueur.
## Renvoie false si une vague est déjà active, si le jeu est en pause ou si la campagne est terminée.
func start_wave() -> bool:
	return Waves.start_wave(self)


## Calcule les points de vie initiaux d'un ennemi de la vague number.
## Les points de vie progressent de 6 % par vague ; les volants ont un coefficient de 0,6.
## Le coefficient du mini boss est 16 et celui du gros boss est 75.
func enemy_health(number: int, flying: bool = false, boss: int = 0) -> float:
	return Waves.enemy_health(self, number, flying, boss)


## Crée le prochain monstre et l'ajoute à la liste des ennemis de la partie.
## Les vagues mixtes alternent volants et terrestres ; le boss prévu apparaît en dernier.
## Le dictionnaire renvoyé est le monstre lui-même : modifier ses champs modifie donc ce monstre dans le jeu.
func spawn_enemy() -> Dictionary:
	return Waves.spawn_enemy(self)


## Calcule la position précise du monstre entre les centres de ses cases.
## Le résultat est exprimé en cases, avec des décimales pour obtenir un déplacement fluide.
## Le dessin multiplie ensuite cette position par la taille graphique d'une case.
func position_of(enemy: Dictionary) -> Vector2:
	return Enemies.position_of(self, enemy)


## Renvoie le coefficient qui transforme les dégâts en fonction de la résistance.
## Une résistance au type school donne 0,5 ; l'autre type donne 1,5.
## Une unité sans résistance, notamment aérienne, reçoit le coefficient neutre de 1.
func damage_multiplier(enemy: Dictionary, school: String) -> float:
	return TowerCombat.damage_multiplier(self, enemy, school)


## Renvoie la portée du type de tour, exprimée en nombre de cases.
## Le niveau n'intervient pas dans ce calcul : améliorer une tour n'augmente pas sa portée.
func tower_range(tower: Dictionary) -> float:
	return TowerCombat.tower_range(self, tower)


## Vérifie qu'un monstre est vivant et appartient à la catégorie visée par la tour : sol ou air.
## Cette fonction ne mesure pas la distance ; fire_tower vérifiera aussi que la cible est à portée.
func can_target(tower: Dictionary, enemy: Dictionary) -> bool:
	return TowerCombat.can_target(self, tower, enemy)


## Applique l'effet d'une attaque sur un ennemi compatible avec la tour.
## Selon le type, elle retire des points de vie, applique un ralentissement ou mémorise un poison.
## source est la case de la tour : elle distingue les poisons de tours différentes, qui peuvent se cumuler.
func apply_hit(source: Vector2i, tower: Dictionary, enemy: Dictionary) -> void:
	TowerCombat.apply_hit(self, source, tower, enemy)


## Cherche, parmi les ennemis à portée, celui qui a le moins de chemin restant jusqu'au château.
## Applique les dégâts ou le contrôle, à lui seul ou aux ennemis proches pour une attaque de zone.
## Si une cible est trouvée, prépare le délai avant le prochain tir et l'animation correspondante.
func fire_tower(cell: Vector2i, tower: Dictionary) -> void:
	TowerCombat.fire_tower(self, cell, tower)


## Applique les dégâts des poisons pendant dt secondes de jeu.
## Chaque tour empoisonneuse possède sa propre durée restante ; un effet expiré est retiré.
## Le dernier calcul de dégâts est limité au temps réellement restant, pour ne pas infliger de dégâts supplémentaires.
func poison_tick(enemy: Dictionary, dt: float) -> void:
	TowerCombat.poison_tick(self, enemy, dt)


## Déplace un ennemi pendant dt secondes de jeu, à sa vitesse éventuellement ralentie.
## Un terrestre termine chaque segment avant de choisir la case suivante ; un volant suit la ligne directe.
## Si le monstre arrive au château, escape retire les vies correspondantes.
func move_enemy(enemy: Dictionary, dt: float) -> void:
	Enemies.move_enemy(self, enemy, dt)


## Enregistre une arrivée au château une seule fois et met les points de vie du monstre à zéro.
## Le joueur perd une vie pour une unité, trois pour un mini boss et cinq pour un gros boss.
## Le champ escaped permettra de retirer ce monstre sans donner d'or.
func escape(enemy: Dictionary) -> void:
	Enemies.escape(self, enemy)


## Cherche les tours dont le retrait pourrait raccourcir le chemin restant du gros boss.
## Au maximum seize tours sont examinées pour limiter le temps de calcul sur les grandes cartes.
## La liste renvoyée contient des cases candidates ; aucune tour n'est encore attaquée.
func shortening_targets(enemy: Dictionary) -> Array[Vector2i]:
	return Bosses.shortening_targets(self, enemy)


## Fait tenter au gros boss une attaque sur une tour dont la disparition lui serait utile.
## force supprime le tirage de probabilité, ce qui rend ce scénario vérifiable dans les tests.
## Si les points de vie de la tour tombent à zéro, elle est retirée sans remboursement et le chemin change.
func boss_attack(enemy: Dictionary, force := false) -> bool:
	return Bosses.boss_attack(self, enemy, force)


## Fait avancer la partie à partir de delta secondes réellement écoulées.
## La pause arrête cette progression. La préparation avance normalement, sans accélération de combat.
## Pendant le combat, le temps accéléré est découpé en petits pas identiques pour conserver les mêmes résultats.
func tick(delta: float) -> void:
	Simulation.tick(self, delta)


## Exécute un petit intervalle dt de combat, exprimé en secondes de jeu.
## L'ordre est important : apparitions, poison et mouvement, attaques des boss, tirs des tours, puis récompenses.
## Les dernières étapes déterminent si le château tombe ou si la vague et la campagne sont terminées.
func combat_step(dt: float) -> void:
	Simulation.combat_step(self, dt)
