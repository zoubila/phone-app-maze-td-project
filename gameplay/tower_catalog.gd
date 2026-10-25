extends RefCounted
## Ce catalogue définit les huit types de tours au niveau 1.
## Chaque dictionnaire est une fiche : prix, dégâts, portée, cadence, type de cible et couleur provisoire.
## Modifier ces valeurs change l'équilibrage ; déplacer leur déclaration ici ne change aucune valeur.
## L'ordre de la liste est conservé, car le numéro du type est utilisé par les tours et les boutons.

# cost est le prix initial ; damage est le dégât d'un tir, ou le dégât par seconde du poison.
# range est une portée en cases ; delay est l'attente entre deux tirs, en secondes de jeu.
# mode distingue une cible (single), une zone (aoe), un ralentissement (slow) et un poison (dot).
# school est la catégorie de dégâts ; air=true réserve la tour aux unités aériennes.
# color donne la couleur du dessin provisoire, sans modifier les règles de la tour.


const TYPES := [
	{
		"name": "Archer",
		"cost": 50,
		"damage": 15.0,
		"range": 3.6,
		"delay": 1.2,
		"mode": "single",
		"school": "physical",
		"air": false,
		"color": Color("#FF0203"),
	},
	{
		"name": "Canon",
		"cost": 85,
		"damage": 30.0,
		"range": 4.0,
		"delay": 2.0,
		"mode": "aoe",
		"school": "physical",
		"air": false,
		"color": Color("d58b63"),
	},
	{
		"name": "Sorcier",
		"cost": 65,
		"damage": 22.0,
		"range": 3.6,
		"delay": 1.2,
		"mode": "single",
		"school": "magic",
		"air": false,
		"color": Color("bd9de8"),
	},
	{
		"name": "Arcane",
		"cost": 100,
		"damage": 26.0,
		"range": 3.4,
		"delay": 1.8,
		"mode": "aoe",
		"school": "magic",
		"air": false,
		"color": Color("df9ace"),
	},
	{
		"name": "Balliste",
		"cost": 70,
		"damage": 24.0,
		"range": 5.0,
		"delay": 0.9,
		"mode": "single",
		"school": "physical",
		"air": true,
		"color": Color("f1d18a"),
	},
	{
		"name": "Frost",
		"cost": 60,
		"damage": 0.0,
		"range": 3.2,
		"delay": 0.8,
		"mode": "slow",
		"school": "none",
		"air": false,
		"color": Color("8ed7df"),
	},
	{
		"name": "Séisme",
		"cost": 90,
		"damage": 0.0,
		"range": 3.0,
		"delay": 1.5,
		"mode": "slow_aoe",
		"school": "none",
		"air": false,
		"color": Color("c7a883"),
	},
	{
		"name": "Poison",
		"cost": 80,
		"damage": 7.0,
		"range": 3.5,
		"delay": 1.2,
		"mode": "dot",
		"school": "magic",
		"air": false,
		"color": Color("9bc974"),
	}
]
