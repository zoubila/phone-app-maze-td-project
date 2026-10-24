# Maze TD

## Contraintes du projet

- Jeu mobile Android et iOS, dans un univers fantasy médiéval.
- Paysage par défaut, avec bascule automatique en portrait ou paysage selon l'orientation du smartphone. Conserver les deux dispositions et la partie en cours lors de la rotation.
- Concevoir les ressources et l'interface pour un écran mobile, avec commandes tactiles, lisibilité sur petit écran et prise en compte des zones sûres.
- Garder les éléments graphiques indépendants de la résolution et de l'orientation de l'écran.

## Ressources

- Ranger les exports dans `assets/` selon `assets/LISEZMOI.txt`.
- Conserver les originaux modifiables dans `assets/sources/`, exclu de l'import Godot par `.gdignore`.
- Les sprites ne sont pas encore raccordés au jeu : les dessins actuels se trouvent dans `board.gd`, l'interface dans `main.gd`, ses dispositions adaptatives dans `ui_layout.gd` et les règles dans `game.gd`.
- Les fiches au survol et au toucher se trouvent dans `inspection.gd`. Garder les actions de vente et d'amélioration accessibles au toucher pendant les vagues et en pause ; le survol ne doit pas changer la tour sélectionnée.
