extends Panel
## FICHE D'INFORMATIONS : aperçu au survol ou panneau fixé par clic/toucher.
## Panel est un contrôle visuel ; cette fiche lit les données mais ne modifie pas le modèle.
## Ses signaux transmettent les demandes de vente/amélioration à main.gd.
# CONTRAT AVEC MAIN : seules les tours construites peuvent émettre une vente ou une amélioration.
signal sell_requested(cell: Vector2i)
signal upgrade_requested(cell: Vector2i)
signal dismiss_requested

# target vaut {} sans cible, ou contient type=tower/catalog/enemy avec cell/kind/id.
# pinned distingue une fiche gardée au toucher d'un simple aperçu qui suit le survol.
var target: Dictionary = {}
var pinned := false
var title_label: Label
var body_label: Label
var close_button: Button
var sell_button: Button
var upgrade_button: Button
# Point de référence dans main, avant calcul des marges et du placement final de la fiche.
var anchor := Vector2.ZERO

## Crée le fond de la fiche, ses textes et ses boutons, puis la masque.
## Relie les boutons à des signaux : main.gd exécute les actions, pas cette fiche.
func _ready() -> void:
	size = Vector2(320, 300)
	z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17271ff5")
	style.border_color = Color("d5bc77")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color("00000066")
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	title_label = make_label(Vector2(14, 10), Vector2(240, 30), 21)
	body_label = make_label(Vector2(14, 48), Vector2(292, 186), 17)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = make_button("×", Vector2(264, 6), Vector2(44, 40))
	# Ce petit rappel anonyme demande seulement la fermeture ; main reçoit le signal.
	close_button.pressed.connect(func(): dismiss_requested.emit())
	upgrade_button = make_button("Améliorer", Vector2(12, 244), Vector2(144, 44))
	# Fonction anonyme de bouton : transmet la case mémorisée, pas une nouvelle sélection au survol.
	upgrade_button.pressed.connect(func():
		if target.get("type") == "tower":
			upgrade_requested.emit(target.cell))
	sell_button = make_button("Vendre", Vector2(164, 244), Vector2(144, 44))
	# Même principe pour la revente : l'action reste attachée à la tour de la fiche.
	sell_button.pressed.connect(func():
		if target.get("type") == "tower":
			sell_requested.emit(target.cell))
	hide_card()

## Crée et renvoie un texte à la position pos et aux dimensions demandées.
## Ignore les événements souris pour qu'un aperçu ne bloque pas le clic sur le plateau.
func make_label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eee4c8"))
	add_child(label)
	return label

## Crée et renvoie un bouton de fiche avec une police commune et sans focus clavier.
## La connexion à son action est faite par _ready.
func make_button(text_value: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = dimensions
	button.text = text_value
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

## Masque la fiche et efface sa cible ainsi que son état fixé.
## La fiche cachée laisse les événements atteindre le plateau.
func hide_card() -> void:
	target = {}
	pinned = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Affiche la cible value près du point d'ancrage point, exprimé dans les coordonnées de main.
## pin fixe la fiche pour le tactile ; un aperçu au survol ignore tous les clics.
## Les boutons Vendre/Améliorer sont réservés aux tours construites, pas au catalogue ni aux monstres.
func show_card(value: Dictionary, point: Vector2, pin: bool) -> void:
	target = value.duplicate()
	anchor = point
	pinned = pin
	visible = true
	# STOP réserve les clics à la fiche fixée ; IGNORE laisse atteindre le plateau.
	# Le catalogue reste traversable pour permettre de construire dès le premier toucher.
	mouse_filter = Control.MOUSE_FILTER_STOP if pin and value.type != "catalog" else Control.MOUSE_FILTER_IGNORE
	close_button.visible = pin
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP if pin else Control.MOUSE_FILTER_IGNORE
	var actions: bool = pin and value.type == "tower"
	sell_button.visible = actions
	upgrade_button.visible = actions
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP if actions else Control.MOUSE_FILTER_IGNORE
	upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP if actions else Control.MOUSE_FILTER_IGNORE

## Place la fiche près de anchor en la gardant dans le rectangle bounds du plateau.
## Essaie la droite et le bas, puis l'autre côté si nécessaire, avec des marges de 12 unités.
func fit_inside(bounds: Rect2) -> void:
	var desired := anchor + Vector2(16, 16)
	if desired.x + size.x > bounds.end.x - 12:
		desired.x = anchor.x - size.x - 16
	if desired.y + size.y > bounds.end.y - 12:
		desired.y = anchor.y - size.y - 16
	position = Vector2(clampf(desired.x, bounds.position.x + 12, bounds.end.x - size.x - 12), clampf(desired.y, bounds.position.y + 12, bounds.end.y - size.y - 12))

## Lit le modèle game pour remplir les textes et l'état des boutons, sans changer le jeu.
## Retrouve un monstre par son identifiant stable ; calcule les valeurs actuelles de la tour.
## Renvoie false si la cible n'existe plus, afin que main.gd ferme la fiche.
func update_card(game) -> bool:
	if target.is_empty():
		return false
	# BRANCHE MONSTRE : recherche par id, pour ne jamais transférer la fiche à un autre monstre semblable.
	if target.type == "enemy":
		for enemy in game.enemies:
			if enemy.id == target.id and enemy.hp > 0:
				title_label.text = "Gros boss" if enemy.boss == 2 else ("Mini boss" if enemy.boss == 1 else ("Unité aérienne" if enemy.air else "Monstre terrestre"))
				var resistance := "Aucune faiblesse physique" if enemy.air else ("Aucune résistance" if enemy.armor == "none" else ("Résiste au physique • faible à la magie" if enemy.armor == "physical" else "Résiste à la magie • faible au physique"))
				var speed: float = enemy.speed * (enemy.slow_factor if enemy.slow_time > 0 else 1.0)
				body_label.text = "PV : %.0f / %.0f\n%s\nVitesse : %.2f cases/s\nRécompense : %d or\nCiblage : %s\nGivre : %s • Poison : %d\n%s" % [maxf(0, enemy.hp), enemy.max_hp, resistance, speed, enemy.reward, "Ballistes uniquement" if enemy.air else "tours terrestres", "actif" if enemy.slow_time > 0 else "non", enemy.poison.size(), "Peut détruire les constructions" if enemy.boss == 2 else ("Fiche fixe • × pour fermer" if pinned else "Cliquer / toucher pour garder la fiche")]
				return true
		return false
	var tower: Dictionary
	# BRANCHE TOUR : le catalogue simule les statistiques N1 sans créer ni acheter de tour.
	var catalog: bool = target.type == "catalog"
	if catalog:
		tower = {"kind": target.kind, "level": 1, "hp": 120.0, "spent": game.TYPES[int(target.kind)].cost}
	elif game.towers.has(target.cell):
		tower = game.towers[target.cell]
	else:
		return false
	var spec: Dictionary = game.TYPES[int(tower.kind)]
	var level := int(tower.level)
	var damage := float(spec.damage) * pow(1.55, level - 1)
	var effect := ""
	# Adapte la description au type d'effet : givre sans dégâts, poison en DPS ou dégâts par impact.
	match spec.mode:
		"slow", "slow_aoe":
			var factor := maxf(0.35, (0.6 if spec.mode == "slow" else 0.75) - (level - 1) * 0.04)
			effect = "Ralentit de %.0f %% • zéro dégât\nDurée : %.1f s • %s" % [(1.0 - factor) * 100, 2.0 + level * 0.2, "en zone" if spec.mode == "slow_aoe" else "une cible"]
		"dot": effect = "Poison magique : %.1f dégâts/s\nDurée : %.1f s par application" % [damage, 4.0 + level * 0.5]
		_: effect = "%.1f dégâts %s / tir\n%.1f s entre tirs • %s" % [damage, "physiques" if spec.school == "physical" else "magiques", spec.delay, "zone" if spec.mode == "aoe" else "une cible"]
	title_label.text = "%s • %s" % [spec.name, "à construire" if catalog else "N%d/7" % level]
	# Calcule le prochain prix et le remboursement réel ; les boutons reflètent or, niveau et fin de partie.
	var price := int(game.upgrade_cost(tower))
	body_label.text = "Cibles : %s\n%s\nPortée fixe : %.1f cases\nPV : %.0f / %.0f\n%s\n%s" % ["air uniquement" if spec.air else "sol uniquement", effect, game.tower_range(tower), tower.hp, 120.0 + (level - 1) * 60, "Prix : %d or" % spec.cost if catalog else ("Niveau maximum atteint" if level == 7 else "Amélioration : %d or" % price), "Choisir une case pour construire" if catalog else "Vente : %d or (70 %%)" % int(tower.spent * 0.7)]
	sell_button.text = "Vendre • %d or" % int(tower.spent * 0.7)
	upgrade_button.text = "Niveau 7" if level == 7 else "N%d • %d or" % [level + 1, price]
	upgrade_button.disabled = game.ended or level == 7 or game.gold < price
	sell_button.disabled = game.ended
	return true
