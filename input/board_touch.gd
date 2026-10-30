extends RefCounted
## Suit les doigts posés sur le plateau pour reconnaître un pincement, y compris sans geste natif du système.
## Un seul doigt garde les clics/glissements émulés par Godot ; deux doigts commandent le zoom et le déplacement.
## Sur Android, laisser enable_pan_and_scale_gestures désactivé : son détecteur natif peut annuler les contacts
## quand les deux doigts se posent ensemble, avant que ce suivi direct ait reçu leur déplacement.

var points: Dictionary = {}
var pinched := false
var previous_center := Vector2.ZERO
var previous_distance := 0.0


## Oublie les doigts après une rotation ou un redémarrage : un ancien geste ne doit pas déplacer la nouvelle vue.
func reset() -> void:
	points.clear()
	pinched = false
	previous_distance = 0.0


## Renvoie true si l'événement a déjà été traité et ne doit pas devenir un clic sur une case.
func handle(view, event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			points[event.index] = event.position
		else:
			points.erase(event.index)

		if points.size() >= 2:
			pinched = true
			view.dragging = false
			view.moved = true
			view.view_dragged.emit()
			remember_pair()
		elif pinched or event.canceled:
			view.dragging = false
			view.moved = true
			if points.is_empty():
				pinched = false
		return true

	if event is InputEventScreenDrag:
		if points.has(event.index):
			points[event.index] = event.position
		if points.size() >= 2:
			move_pair(view)
		return true

	# Certains systèmes envoient à la fois les doigts et un geste natif : ne pas appliquer le zoom deux fois.
	if event is InputEventMagnifyGesture and points.size() >= 2:
		return true
	if event is InputEventMouse and pinched:
		return true
	return false


## Mémorise le milieu des deux premiers doigts et leur distance, pour mesurer le mouvement suivant.
func remember_pair() -> void:
	var pair := points.values()
	previous_center = (Vector2(pair[0]) + Vector2(pair[1])) / 2.0
	previous_distance = Vector2(pair[0]).distance_to(Vector2(pair[1]))


## Le rapport des distances change le zoom ; le déplacement du milieu des doigts fait glisser la carte.
## Le même point du monde reste ainsi sous les doigts pendant leur mouvement.
func move_pair(view) -> void:
	var old_center := previous_center
	var old_distance := previous_distance
	remember_pair()
	if old_distance < 1.0 or previous_distance < 1.0:
		return
	view.set_zoom(view.zoom * previous_distance / old_distance, old_center)
	view.pan += previous_center - old_center
	view.clamp_pan()
	view.refresh()
