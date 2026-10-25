# Maze TD

## Contraintes du projet

- Jeu mobile Android et iOS, dans un univers fantasy médiéval.
- Paysage par défaut, avec bascule automatique en portrait ou paysage selon l'orientation du smartphone. Conserver les deux dispositions et la partie en cours lors de la rotation.
- Concevoir les ressources et l'interface pour un écran mobile, avec commandes tactiles, lisibilité sur petit écran et prise en compte des zones sûres.
- Garder les éléments graphiques indépendants de la résolution et de l'orientation de l'écran.

## Ressources

- Ranger les exports dans `assets/` selon `assets/LISEZMOI.txt`.
- Conserver les originaux modifiables dans `assets/sources/`, exclu de l'import Godot par `.gdignore`.
- Le décor est raccordé dans `scenery.gd` : forêt, caverne et château utilisent les PNG de `assets/terrain/`. Les tours et monstres restent dessinés dans `board.gd`. L'interface se trouve dans `main.gd`, ses dispositions dans `ui_layout.gd` et les règles dans `game.gd`.
- Les fiches au survol et au toucher se trouvent dans `inspection.gd`. Garder les actions de vente et d'amélioration accessibles au toucher pendant les vagues et en pause ; le survol ne doit pas changer la tour sélectionnée.
- Les tirs se dessinent dans `projectiles.gd`. L'archer utilise `assets/projectiles/fleche.png`, orienté vers la droite au repos. Le vol est visuel ; les dégâts restent appliqués au tir dans `game.gd`.
