extends RefCounted
## Les mêmes illustrations servent au plateau et aux cartes du catalogue.
## Les atlas restent intacts : Godot prélève une région sans créer huit copies de l'image.

const TOWERS = preload("res://assets/tours/tours_toon_v2_atlas.png")
const ENEMIES = preload("res://assets/ennemis/ennemis_cartoon_atlas.png")
static var tower_icons: Array[AtlasTexture] = []
static var enemy_icons: Array[AtlasTexture] = []


## Calcule l'emprise réelle du sprite : le dessin et la sélection doivent utiliser la même taille.
## Le déplacement vertical bob anime la marche ; l'émergence réduit le sprite à la sortie du portail.
static func enemy_bounds(enemy: Dictionary, point: Vector2, bob: float = 0.0) -> Rect2:
	var dimensions := 48.0 if enemy.air else 38.0
	if enemy.boss > 0:
		dimensions = 68.0 if enemy.boss == 2 else 56.0
	var emergence := clampf(float(enemy.get("portal_age", 1.0)) / 0.32, 0.0, 1.0)
	dimensions *= lerpf(0.45, 1.0, emergence)
	return Rect2(point + Vector2(-dimensions * 0.5, -dimensions * 0.75 + bob), Vector2.ONE * dimensions)


## Prépare une texture par cellule de l'atlas ; le filtrage ne déborde pas sur la cellule voisine.
static func prepare_icons() -> void:
	if not tower_icons.is_empty():
		return
	for index in range(8):
		var icon := AtlasTexture.new()
		icon.atlas = TOWERS
		var dimensions := TOWERS.get_size() / Vector2(4, 2)
		icon.region = Rect2(Vector2(index % 4, index / 4) * dimensions, dimensions)
		icon.filter_clip = true
		tower_icons.append(icon)
	for index in range(4):
		var icon := AtlasTexture.new()
		icon.atlas = ENEMIES
		var dimensions := ENEMIES.get_size() / 2.0
		icon.region = Rect2(Vector2(index % 2, index / 2) * dimensions, dimensions)
		icon.filter_clip = true
		enemy_icons.append(icon)


## Renvoie l'illustration du type demandé ; l'ordre correspond au catalogue des règles.
static func tower_icon(kind: int) -> AtlasTexture:
	prepare_icons()
	return tower_icons[clampi(kind, 0, 7)]


## Les armures, volants et boss restent identifiés par les propriétés du modèle.
static func enemy_icon(enemy: Dictionary) -> AtlasTexture:
	prepare_icons()
	var index := 0 if enemy.armor == "physical" else 1
	if enemy.air:
		index = 2
	if enemy.boss > 0:
		index = 3
	return enemy_icons[index]
