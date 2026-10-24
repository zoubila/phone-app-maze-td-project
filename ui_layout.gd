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
	ui.board.refresh()

## Place les commandes sous la carte dans l'espace logique width × height.
## Le catalogue forme deux rangées de quatre tours ; le plateau absorbe la hauteur disponible.
static func portrait_layout(ui, width: float, height: float) -> void:
	var content := width - 64
	place(ui.title_label, 32, 30, content, 42)
	place(ui.subtitle_label, 32, 76, content, 28)
	place(ui.status, 32, 112, content, 32)
	place(ui.message, 32, 150, content, 30)
	place(ui.grid_choice, 32, 188, content - 360, 48)
	place(ui.entry_button, width - 380, 188, 108, 48)
	place(ui.castle_button, width - 260, 188, 108, 48)
	place(ui.overview_button, width - 140, 188, 108, 48)
	ui.board.position = Vector2(32, 248)
	# Réserve le bas aux commandes ; resize_view conserve le cadrage de la carte pendant la rotation.
	ui.board.resize_view(Vector2(content, height - 680))
	place(ui.map_info, 32, height - 420, content - 160, 40)
	place(ui.zoom_out_button, width - 176, height - 422, 64, 44)
	place(ui.zoom_in_button, width - 96, height - 422, 64, 44)
	ui.detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	place(ui.detail, 32, height - 373, content, 48)
	# Quatre boutons séparés par trois espaces de 8 unités.
	var button_width := (content - 24) / 4
	for i in range(ui.type_buttons.size()):
		place(ui.type_buttons[i], 32 + (i % 4) * (button_width + 8), height - 317 + (i / 4) * 61, button_width, 56)
	var half := (content - 16) / 2
	place(ui.upgrade_button, 32, height - 184, half, 52)
	place(ui.sell_button, 48 + half, height - 184, half, 52)
	place(ui.wave_button, 32, height - 118, half, 60)
	var small := (half - 16) / 2
	place(ui.pause_button, 48 + half, height - 118, small, 60)
	place(ui.speed_button, 64 + half + small, height - 118, small, 60)
	ui.footer_label.visible = true
	place(ui.footer_label, 32, height - 48, content, 25)

## Place la carte à gauche et les commandes dans une colonne à droite.
## width et height sont les dimensions logiques après mise à l'échelle ; le catalogue a deux colonnes.
static func landscape_layout(ui, width: float, height: float) -> void:
	# Colonne de commandes de largeur fixe dans l'espace logique ; la carte occupe la largeur restante.
	var panel_width := 356.0
	var panel_x := width - panel_width - 24
	var map_width := panel_x - 48
	place(ui.title_label, 24, 20, map_width, 42)
	place(ui.subtitle_label, 24, 62, map_width, 24)
	place(ui.status, 24, 94, map_width, 30)
	place(ui.message, 24, 132, map_width, 30)
	place(ui.grid_choice, 24, 174, 280, 44)
	place(ui.entry_button, 316, 174, 100, 44)
	place(ui.castle_button, 428, 174, 100, 44)
	place(ui.overview_button, 540, 174, 100, 44)
	place(ui.zoom_out_button, 652, 174, 64, 44)
	place(ui.zoom_in_button, 728, 174, 64, 44)
	ui.board.position = Vector2(24, 232)
	ui.board.resize_view(Vector2(map_width, height - 292))
	place(ui.map_info, 24, height - 48, map_width, 30)
	ui.detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(ui.detail, panel_x, 24, panel_width, 100)
	var half := (panel_width - 12) / 2
	for i in range(ui.type_buttons.size()):
		place(ui.type_buttons[i], panel_x + (i % 2) * (half + 12), 140 + (i / 2) * 76, half, 64)
	place(ui.upgrade_button, panel_x, height - 268, panel_width, 52)
	place(ui.sell_button, panel_x, height - 204, panel_width, 52)
	place(ui.wave_button, panel_x, height - 132, panel_width, 52)
	place(ui.pause_button, panel_x, height - 68, half, 44)
	place(ui.speed_button, panel_x + half + 12, height - 68, half, 44)
	ui.footer_label.visible = false
