extends RefCounted
## Regroupe les quatre difficultés pour que le menu, les PV et les revenus utilisent les mêmes valeurs.
## L'or de départ, les coûts, la portée, la cadence et la vitesse des monstres restent identiques.

const PROFILES := [
	{"name": "Débutant", "health_start": 0.70, "health_end": 0.70, "income": 1.15,
		"description": "PV −30 % · Or gagné +15 %"},
	{"name": "Normal", "health_start": 1.0, "health_end": 1.0, "income": 1.0,
		"description": "PV et revenus standards"},
	{"name": "Difficile", "health_start": 1.20, "health_end": 1.50, "income": 0.90,
		"description": "PV +20 % → +50 % · Or gagné −10 %"},
	{"name": "Fin du monde", "health_start": 1.50, "health_end": 2.25, "income": 0.85,
		"description": "PV +50 % → +125 % · Or gagné −15 %"},
]


## Renvoie un profil valide ; une valeur extérieure au catalogue est ramenée à ses limites.
static func profile(index: int) -> Dictionary:
	return PROFILES[clampi(index, 0, PROFILES.size() - 1)]


## Atteint progressivement le multiplicateur maximal à la vague 25, puis le conserve.
## Cette montée évite d'appliquer immédiatement toute la difficulté au petit budget des premières vagues.
static func health_multiplier(index: int, wave: int) -> float:
	var settings := profile(index)
	var progress := clampf(float(wave - 1) / 24.0, 0.0, 1.0)
	return lerpf(float(settings.health_start), float(settings.health_end), progress)


## Ajuste seulement les gains de combat et les bonus de vague, en arrondissant à la pièce la plus proche.
## Les remboursements de vente sont exclus : vendre ne doit jamais devenir une source de bénéfice.
static func income(index: int, amount: int) -> int:
	if amount <= 0:
		return 0
	return maxi(1, roundi(amount * float(profile(index).income)))
