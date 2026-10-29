extends RefCounted
## La marche suit la distance réellement parcourue, sans changer les règles du combat.
## Une immobilisation conserve donc l'image, et accélérer ou ralentir le monstre adapte ses pas.
const Art = preload("res://rendering/unit_art.gd")
const FRAMES_PER_CELL := 8.0 / 2.5
var states: Dictionary = {}

## Met à jour aussi les ennemis hors écran pour conserver leur phase après un déplacement de caméra.
func update(game) -> void:
	var alive: Dictionary = {}
	for enemy in game.enemies:
		if not Art.has_walk(enemy):
			continue
		var id: int = enemy.id
		var position: Vector2 = game.position_of(enemy)
		var age: float = enemy.get("portal_age", 0.0)
		alive[id] = true
		if not states.has(id) or age < float(states[id].age):
			states[id] = {"position": position, "distance": 0.0, "left": false, "age": age}
			continue
		var state: Dictionary = states[id]
		var movement: Vector2 = position - Vector2(state.position)
		state.distance += movement.length()
		if absf(movement.x) > 0.0001:
			state.left = movement.x < 0.0
		state.position = position
		state.age = age
	for id in states.keys():
		if not alive.has(id):
			states.erase(id)

## À la vitesse normale de 2,5 cases/seconde, le cycle joue huit images par seconde.
static func frame_index(distance: float) -> int:
	return posmod(floori(maxf(0.0, distance) * FRAMES_PER_CELL), Art.GOBLIN_WALK.size())

func texture(enemy: Dictionary) -> Texture2D:
	if not Art.has_walk(enemy) or not states.has(enemy.id):
		return Art.enemy_icon(enemy)
	return Art.GOBLIN_WALK[frame_index(float(states[enemy.id].distance))]

## Le miroir couvre les déplacements vers la gauche ; les virages verticaux gardent le dernier sens.
func facing_left(enemy: Dictionary) -> bool:
	return Art.has_walk(enemy) and states.has(enemy.id) and bool(states[enemy.id].left)
