extends SceneTree
## VÉRIFICATIONS AUTOMATISÉES : exécuter godot --headless --path . --script tests.gd.
## SceneTree sert ici de programme de test, et non de scène de jeu normale.
## Les messages de test restent en anglais pour garder les résultats existants identifiables.
## Les scénarios isolés et les morts artificielles ne mesurent pas l'équilibrage d'une partie jouée.
# Le même modèle que le jeu est testé ; checks et failures comptent les assertions exécutées/échouées.
const Model = preload("res://game.gd")

var checks := 0
var failures := 0

## Enregistre une vérification ; condition=false incrémente les échecs et affiche title.
## Ne stoppe pas la suite pour pouvoir signaler plusieurs problèmes dans une seule exécution.
func check(condition: bool, title: String) -> void:
	checks += 1

	if not condition:
		failures += 1
		push_error(title)

## Compare deux nombres avec une tolérance absolue de 0,001.
## Utilise check car les calculs flottants ne sont pas toujours égaux au bit près.
func near(value: float, expected: float, title: String) -> void:
	check(absf(value - expected) < 0.001, title + " (%f vs %f)" % [value, expected])

## Point d'entrée du script de tests, lancé avec --headless --script tests.gd.
## Diffère run pour attendre que Godot ait initialisé l'arbre de scènes.
func _initialize() -> void:
	call_deferred("run")

## Fabrique un dictionnaire de tour de test sans payer ni construire sur la carte.
## kind choisit le type, level le niveau ; utile pour isoler ciblage, impacts et effets.
func tower(kind: int, level := 1) -> Dictionary:
	return {
		"kind": kind,
		"level": level,
		"spent": Model.TYPES[kind].cost,
		"hp": 120.0 + (level - 1) * 60,
		"cooldown": 0.0,
	}

## Ajoute un ennemi de test au modèle game, puis force sa catégorie et ses PV à 1000.
## Renvoie le même dictionnaire que celui de la liste game.enemies pour suivre les modifications.
func enemy(game, air := false, armor := "none") -> Dictionary:
	var item: Dictionary = game.spawn_enemy()
	# Ces cibles isolent le combat sur la grille ; la vraie sortie du portail a ses propres tests.
	item.portal_remaining = 0.0
	item.portal_age = 1.0
	item.air = air
	item.armor = armor
	item.hp = 1000.0
	item.max_hp = 1000.0
	return item

## Envoie un appui puis un relâchement gauche dans le viewport pour tester un clic réel.
## point est en coordonnées du viewport, après transformation des contrôles si nécessaire.
func gui_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)

## Lance les groupes de vérifications dans un ordre fixe, puis affiche un bilan unique.
## Les scénarios détaillés sont dans tests/ ; ce fichier conserve les outils communs et le point de départ.
func run() -> void:
	var started = Time.get_ticks_msec()
	projectile_tests()
	preload("res://tests/progression_tests.gd").run(self)
	preload("res://tests/combat_tests.gd").run(self)

	var kills = preload("res://tests/campaign_tests.gd").run(self)
	await preload("res://tests/interface_tests.gd").run(self)
	await preload("res://tests/grid_unlock_tests.gd").run(self)
	await inspection_tests()
	await preload("res://tests/enemy_selection_tests.gd").run(self)
	await preload("res://tests/tower_actions_tests.gd").run(self)
	await preload("res://tests/touch_gestures_tests.gd").run(self)
	await preload("res://tests/wave_feedback_tests.gd").run(self)
	preload("res://tests/portal_tests.gd").run(self)

	print("CHECKS: %d / FAILURES: %d / CAMPAIGN KILLS: %d / MS: %d" % [
		checks,
		failures,
		kills,
		Time.get_ticks_msec() - started,
	])
	quit(0 if failures == 0 else 1)


## Déplace le pointeur vers point dans la fenêtre de test.
## Cet événement permet de vérifier le survol sans cliquer ni modifier la sélection.
func gui_move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)


## Exécute les scénarios de sélection et de fiches, qui attendent parfois une nouvelle image de Godot.
func inspection_tests() -> void:
	await preload("res://tests/inspection_tests.gd").run(self)


## Exécute les scénarios de flèches. Leur résultat est ajouté aux mêmes compteurs que les autres tests.
func projectile_tests() -> void:
	preload("res://tests/projectile_tests.gd").run(self)
