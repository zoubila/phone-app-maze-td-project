extends RefCounted
## DISPOSITION MOBILE : deux agencements des mêmes contrôles, sans changer la partie.
## Les méthodes static s'appellent sur le script directement, sans créer d'instance.
## Les positions sont logiques : arrange règle l'échelle pour les adapter aux pixels de l'écran.

## Renvoie la zone utilisable en coordonnées du viewport, hors encoches et barres système.
## Sur ordinateur ou si le système ne fournit pas de zone valide, utilise tout le viewport.
## Convertit les pixels de fenêtre en coordonnées logiques selon le rapport de taille.
static func safe_viewport_area(viewport_size: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)

	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return full

	var window_size := Vector2(DisplayServer.window_get_size())

	if window_size.x <= 0 or window_size.y <= 0:
		return full

	var window_origin := Vector2(DisplayServer.window_get_position())
	var safe := Rect2(DisplayServer.get_display_safe_area()).intersection(Rect2(window_origin, window_size))

	if not safe.has_area():
		return full
	# La zone système est en pixels ; l'interface peut être étirée dans un autre espace de coordonnées.
	var ratio := viewport_size / window_size
	return Rect2((safe.position - window_origin) * ratio, safe.size * ratio)

## Positionne et dimensionne control dans son parent ; les valeurs sont des unités logiques.
## Utilitaire commun aux dispositions portrait et paysage pour éviter de répéter les affectations.
static func place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)

## Choisit portrait ou paysage selon area, puis adapte l'échelle de toute l'interface.
## ui est la scène main ; area est sa zone sûre. Les références sont 720×1280 et 1280×720.
## Réutilise les mêmes contrôles et le même modèle : une rotation ne relance aucune partie.
static func arrange(ui, area: Rect2) -> void:
	if not area.has_area():
		return
	ui.landscape = area.size.x >= area.size.y

	var reference := Vector2(1280, 720) if ui.landscape else Vector2(720, 1280)
	# Prend le rapport le plus petit pour que toute l'interface tienne dans la zone sûre.
	# Le surplus de largeur/hauteur augmente ensuite l'espace logique disponible.
	var factor := minf(area.size.x / reference.x, area.size.y / reference.y)
	ui.position = area.position
	ui.scale = Vector2.ONE * factor
	ui.layout_size = area.size / factor

	if ui.landscape:
		landscape_layout(ui, ui.layout_size.x, ui.layout_size.y)
	else:
		portrait_layout(ui, ui.layout_size.x, ui.layout_size.y)
	place_overlays(ui)
	ui.menu_screen.position = Vector2.ZERO
	ui.menu_screen.size = ui.layout_size
	ui.menu_screen.arrange()
	ui.end_screen.position = ui.board.position
	ui.end_screen.size = ui.board.size
	ui.end_screen.arrange()
	ui.settings_screen.position = Vector2.ZERO
	ui.settings_screen.size = ui.layout_size
	ui.settings_screen.arrange()
	ui.board.refresh()


## En portrait, le catalogue occupe deux rangées au bas de l'écran ; tout le reste devient le plateau.
static func portrait_layout(ui, width: float, height: float) -> void:
	ui.board.position = Vector2(12, 12)
	ui.board.resize_view(Vector2(width - 24, height - 184))

	var button_width := (width - 48) / 4.0

	for kind in range(ui.type_buttons.size()):
		place(
			ui.type_buttons[kind],
			12 + (kind % 4) * (button_width + 8),
			height - 160 + (kind / 4) * 76,
			button_width,
			68,
		)


## En paysage, une seule colonne étroite contient les tours ; le plateau utilise toute la hauteur.
static func landscape_layout(ui, width: float, height: float) -> void:
	var catalog_width := 144.0
	ui.board.position = Vector2(12, 12)
	ui.board.resize_view(Vector2(width - catalog_width - 36, height - 24))

	var button_height := (height - 24 - 7 * 8) / 8.0

	for kind in range(ui.type_buttons.size()):
		place(
			ui.type_buttons[kind],
			width - catalog_width - 12,
			12 + kind * (button_height + 8),
			catalog_width,
			button_height,
		)


## Les commandes de pause et vitesse flottent sur le décor, à l'intérieur du plateau.
## Le fond laisse voir la forêt ; seul le rectangle de chaque bouton intercepte les touchers.
static func place_overlays(ui) -> void:
	var board: Rect2 = Rect2(ui.board.position, ui.board.size)
	place(ui.hud_panel, board.position.x + 8, board.position.y + 8, board.size.x - 16, 56)
	place(ui.status, board.position.x + 20, board.position.y + 22, board.size.x - 320, 30)
	ui.status.add_theme_font_size_override("font_size", 16 if board.size.x < 800 else 20)
	place(ui.pause_button, board.end.x - 292, board.position.y + 14, 100, 44)
	place(ui.speed_button, board.end.x - 184, board.position.y + 14, 116, 44)
	place(ui.settings_button, board.end.x - 60, board.position.y + 14, 44, 44)
	place(ui.wave_button, board.get_center().x - 136, board.end.y - 108, 272, 44)
	place(ui.message, board.position.x + 18, board.end.y - 42, board.size.x - 36, 26)
