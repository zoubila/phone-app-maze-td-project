extends RefCounted
## Un fichier PNG par unité, réutilisé sur le plateau et dans le catalogue.
## Les futurs exports d'animation pourront remplacer ces poses sans découper une planche commune.
const TOWERS = [
	preload("res://assets/tours/archer_n01_repos.png"),
	preload("res://assets/tours/canon_n01_repos.png"),
	preload("res://assets/tours/sorcier_n01_repos.png"),
	preload("res://assets/tours/arcane_n01_repos.png"),
	preload("res://assets/tours/balliste_n01_repos.png"),
	preload("res://assets/tours/frost_n01_repos.png"),
	preload("res://assets/tours/seisme_n01_repos.png"),
	preload("res://assets/tours/poison_n01_repos.png"),
]
const ENEMIES = [
	preload("res://assets/ennemis/terrestres/gobelin_repos.png"),
	preload("res://assets/ennemis/terrestres/mage_repos.png"),
	preload("res://assets/ennemis/aeriens/dragon_repos.png"),
	preload("res://assets/ennemis/boss/ogre_repos.png"),
]
const GOBLIN_WALK = [
	preload("res://assets/ennemis/terrestres/gobelin_marche_01.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_02.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_03.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_04.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_05.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_06.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_07.png"),
	preload("res://assets/ennemis/terrestres/gobelin_marche_08.png"),
]

## Seul le gobelin possède un cycle fourni ; les autres monstres gardent leur pose actuelle.
static func has_walk(enemy: Dictionary) -> bool:
	return not enemy.air and enemy.boss == 0 and enemy.armor == "physical"

static func tower_icon(kind: int) -> Texture2D:
	return TOWERS[clampi(kind, 0, 7)]

static func enemy_icon(enemy: Dictionary) -> Texture2D:
	var index := 0 if enemy.armor == "physical" else 1
	if enemy.air:
		index = 2
	if enemy.boss > 0:
		index = 3
	return ENEMIES[index]
