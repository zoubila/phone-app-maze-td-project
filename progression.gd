extends RefCounted
## Conserve les vagues atteintes sur chaque taille de terrain entre deux parties.
## L'ordre des trois records correspond à GRID_SIZES : moyen, petit, grand.
## Le record global historique est conservé, mais ne permet pas de deviner la grille jouée.

const GRID_KEYS := ["50x100", "25x50", "100x200"]
var reached: Array[int] = [0, 0, 0]
var best := 0
var dirty := false
var save_path := "user://progress.cfg"


## Charge les records connus. Une ancienne sauvegarde sans records par grille garde tous ses autres réglages.
func load_save() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	best = maxi(0, int(config.get_value("progress", "best_wave", 0)))
	for index in range(GRID_KEYS.size()):
		reached[index] = clampi(int(config.get_value("grids", GRID_KEYS[index], 0)), 0, 100)
	dirty = false


## La petite grille est toujours accessible. Le mode développeur contourne les verrous sans modifier les records.
func is_unlocked(index: int, developer_mode: bool = false) -> bool:
	if index < 0 or index >= GRID_KEYS.size():
		return false
	if developer_mode:
		return true
	match index:
		0: return reached[1] >= 25
		1: return true
		2: return reached[0] >= 50
	return false


## Enregistre une vague au moment où elle commence, même si le château tombe pendant celle-ci.
## Les parties de développement ne débloquent rien dans la progression normale.
func record_wave(index: int, wave: int, developer_mode: bool = false) -> void:
	if developer_mode or not is_unlocked(index):
		return
	var value := clampi(wave, 0, 100)
	if value > reached[index]:
		reached[index] = value
		dirty = true


## Écrit les records en conservant les autres sections du fichier existant.
## En cas d'échec, dirty reste vrai afin que main.gd puisse réessayer plus tard.
func save() -> bool:
	var config := ConfigFile.new()
	config.load(save_path)
	config.set_value("progress", "best_wave", best)
	for index in range(GRID_KEYS.size()):
		config.set_value("grids", GRID_KEYS[index], reached[index])
	if config.save(save_path) != OK:
		return false
	dirty = false
	return true
