extends RefCounted
## Fixe d'abord le budget total d'une vague, puis le partage entre les monstres et le bonus de réussite.
## Le nombre d'ennemis ne peut ainsi plus multiplier une seconde fois une récompense qui croît déjà rapidement.

const Difficulty = preload("res://gameplay/difficulty.gd")
const PRESERVED_WAVES := 6
const WAVE_SIX_INCOME := 438
const INCOME_STEP := 44.0
const INCOME_CURVATURE := 0.4


## Conserve exactement les gains des six premières vagues, y compris leur arrondi selon la difficulté.
## Ensuite, la courbe monte plus doucement. La prime de boss reste bornée dans le budget annoncé.
static func distribution(wave: int, count: int, boss: int, difficulty: int) -> Dictionary:
	var clear_bonus := Difficulty.income(difficulty, 20 + wave * 3)
	var boss_weight := 10 if boss == 2 else (4 if boss == 1 else 1)
	var total: int
	if wave <= PRESERVED_WAVES:
		var reward := Difficulty.income(difficulty, 8 + wave * 2)
		total = reward * count + clear_bonus
	else:
		var elapsed := float(wave - PRESERVED_WAVES)
		var base := roundi(WAVE_SIX_INCOME + INCOME_STEP * elapsed + INCOME_CURVATURE * elapsed * elapsed)
		var ordinary_reward := (base - (20 + wave * 3)) / count
		var boss_premium := (boss_weight - 1) * ordinary_reward
		total = Difficulty.income(difficulty, base + boss_premium)
	return {
		"total": total,
		"clear_bonus": clear_bonus,
		"enemy_budget": total - clear_bonus,
		"count": count,
		"boss_weight": boss_weight,
		"total_weight": count - 1 + boss_weight,
	}


## Répartit toutes les pièces exactement, sans en créer ni en perdre à cause des arrondis.
## Le boss reçoit plusieurs parts. Les ennemis échappés ne rapportent rien : leur part n'est jamais redistribuée.
static func enemy_reward(income: Dictionary, ordinal: int, is_boss: bool) -> int:
	var index := int(income.count) - 1 if is_boss else clampi(ordinal, 0, int(income.count) - 1)
	var weight := int(income.boss_weight) if is_boss else 1
	var budget := int(income.enemy_budget)
	var total_weight := int(income.total_weight)
	# Les divisions entières attribuent les pièces restantes au fil des apparitions, sans fraction de pièce.
	return (budget * (index + weight)) / total_weight - (budget * index) / total_weight
