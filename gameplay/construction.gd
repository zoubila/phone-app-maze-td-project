extends RefCounted
## Ce fichier gère l'achat, l'amélioration et la vente des tours.
## Il modifie l'or et les constructions de la partie reçue dans game.
## L'interface ne décide jamais seule qu'un achat est autorisé : ces fonctions vérifient les règles.


## Essaie d'acheter une tour de type kind sur la case cell.
## La construction doit être abordable et laisser un passage à l'entrée et à tous les monstres terrestres.
## Renvoie true après un achat réussi. En cas de refus, renvoie false sans retirer d'or et explique la raison dans message.
static func build(game, cell: Vector2i, kind: int) -> bool:
	if game.ended or not game.inside(cell) or kind < 0 or kind >= game.TYPES.size():
		game.message = "Construction impossible sur cette case."
		return false

	# La réservation couvre seulement les cases réellement occupées par le château dans la grille.
	# Ce refus a lieu avant l'ajout d'une tour, le paiement ou le recalcul du chemin.
	if game.is_landmark_area(cell):
		game.message = "Zone réservée au château : construction interdite."
		return false

	if cell == game.entry or cell == game.exit_cell or game.towers.has(cell):
		game.message = "Cette case ne peut pas accueillir de tour."
		return false

	# Un monstre terrestre déjà présent doit conserver sa case actuelle et sa destination immédiate.
	for enemy in game.enemies:
		if float(enemy.get("portal_remaining", 0.0)) > 0.0:
			continue
		if not enemy.air and enemy.hp > 0 and (cell == enemy.cell or cell == enemy.next):
			game.message = "Une unité traverse cette case. Choisissez une case libre."
			return false

	var cost = int(game.TYPES[kind].cost)

	if game.gold < cost:
		game.message = "%s : il manque %d or." % [game.TYPES[kind].name, cost - game.gold]
		return false
	game.towers[cell] = {"kind": kind, "level": 1, "cooldown": 0.0, "spent": cost, "hp": 120.0}

	# La tour a été ajoutée provisoirement. On vérifie maintenant les chemins AVANT de débiter le prix.
	# En cas de refus, la tour provisoire est retirée : le joueur ne perd pas d'or.
	var candidate = game.field_without()

	if candidate[game.cell_id(game.entry)] < 0:
		game.towers.erase(cell)
		game.message = "Passage fermé : achat refusé, aucun or débité."
		return false

	# Un monstre terrestre déjà présent doit conserver sa case actuelle et sa destination immédiate.
	for enemy in game.enemies:
		if float(enemy.get("portal_remaining", 0.0)) > 0.0:
			continue
		if not enemy.air and enemy.hp > 0 and candidate[game.cell_id(enemy.next)] < 0:
			game.towers.erase(cell)
			game.message = "Ce placement piégerait des monstres : achat refusé."
			return false

	# À ce stade, toutes les conditions sont acceptées ; le paiement peut réellement avoir lieu.
	game.gold -= cost
	game.rebuild_flow()
	game.message = "Chemin le plus court : %d cases." % game.route.size()
	return true


## Calcule le prix du prochain niveau à partir du prix initial et du niveau actuel.
## ceil arrondit au nombre entier supérieur : on ne peut pas payer une fraction de pièce d'or.
## Cette fonction calcule un prix ; upgrade vérifie ensuite le niveau maximal et le budget.
static func upgrade_cost(game, tower: Dictionary) -> int:
	return int(ceil(float(game.TYPES[int(tower.kind)].cost) * pow(1.45, int(tower.level))))


## Essaie d'améliorer la tour située sur cell.
## Une réussite retire le prix, augmente le niveau et ajoute 60 points de vie actuels.
## L'investissement total est mémorisé pour la revente. La portée et la cadence ne changent pas.
static func upgrade(game, cell: Vector2i) -> bool:
	if game.ended or not game.towers.has(cell):
		game.message = "Sélectionnez une tour à améliorer."
		return false

	var tower: Dictionary = game.towers[cell]
	var cost = game.upgrade_cost(tower)

	if int(tower.level) >= game.MAX_LEVEL or game.gold < cost:
		game.message = "Niveau 7 atteint." if int(tower.level) >= game.MAX_LEVEL else "Amélioration : il manque %d or." % (cost - game.gold)
		return false

	# À ce stade, toutes les conditions sont acceptées ; le paiement peut réellement avoir lieu.
	game.gold -= cost
	tower.spent += cost
	tower.level += 1
	tower.hp += 60.0
	game.message = "%s améliorée au niveau %d." % [game.TYPES[int(tower.kind)].name, tower.level]
	return true


## Vend la tour de cell et rembourse 70 % de tout l'or investi dans cette tour.
## La case redevient libre et les chemins sont recalculés immédiatement, même pendant une vague.
## Renvoie false si aucune tour n'existe à cet endroit ou si la partie est terminée.
static func sell(game, cell: Vector2i) -> bool:
	if game.ended or not game.towers.has(cell):
		game.message = "Sélectionnez une tour à vendre."
		return false

	var refund = int(game.towers[cell].spent * 0.7)
	game.gold += refund
	game.towers.erase(cell)
	game.rebuild_flow()
	game.message = "Tour vendue : +%d or." % refund
	return true
