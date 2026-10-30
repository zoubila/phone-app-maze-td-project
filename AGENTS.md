# Maze TD

## Contraintes du projet

- Jeu mobile Android et iOS, dans un univers fantasy médiéval.
- Paysage par défaut, avec bascule automatique en portrait ou paysage selon l'orientation du smartphone. Conserver les deux dispositions et la partie en cours lors de la rotation.
- Concevoir les ressources et l'interface pour un écran mobile, avec commandes tactiles, lisibilité sur petit écran et prise en compte des zones sûres.
- Garder les éléments graphiques indépendants de la résolution et de l'orientation de l'écran.

## Ressources

- Ranger les exports dans `assets/` selon `assets/LISEZMOI.txt`.
- Conserver les originaux modifiables dans `assets/sources/`, exclu de l'import Godot par `.gdignore`.
- Le décor est raccordé dans `scenery.gd` : sol médiéval, chênes, portail et bourg fortifié utilisent les PNG cartoon de `assets/terrain/`. Ce fichier dessine aussi le chemin en relief et les abords des portes. Les tours et monstres sont dessinés dans `rendering/board_renderer.gd`, qui prépare le tracé du chemin. `board.gd` gère la caméra et les interactions. Les règles détaillées sont dans `gameplay/`, l'interface dans `ui/` et sa disposition dans `ui_layout.gd`. `main.gd` relie les commandes à la partie `game.gd`.
- Les fiches au survol et au toucher se trouvent dans `inspection.gd`. Garder les actions de vente et d'amélioration accessibles au toucher pendant les vagues et en pause ; le survol ne doit pas changer la tour sélectionnée.
- Les tirs se dessinent dans `projectiles.gd`. L'archer utilise `assets/projectiles/fleche.png`, orienté vers la droite au repos. Le vol est visuel ; les dégâts restent appliqués au tir dans `gameplay/tower_combat.gd`.
- Les illustrations des tours et ennemis sont regroupées dans deux atlas chargés par `rendering/unit_art.gd`. Réutiliser les mêmes régions pour les cartes du catalogue et le plateau ; conserver le type, la portée et le coût dans le modèle.
- Les événements `wave_started` et `wave_repelled` du modèle pilotent `ui/wave_feedback.gd`. La célébration reste brève, laisse passer les clics et affiche uniquement le bonus réellement versé. La victoire finale conserve son écran de résultat.
- Le portail et son socle sont entièrement hors grille. `PORTAL_APPROACH_CELLS` définit le trajet réel jusqu'à l'entrée ; `portal_remaining` et `portal_age` pilotent la sortie progressive. Ne pas réintroduire de zone réservée sur les anciennes cases du portail. L'emprise du château reste protégée.
- Direction visuelle : cartoon mobile très lisible, volumes épais, couleurs franches et peu de détails fins. Les ressources v2 sont `sol_toon_v2.png`, `chene_toon_v2.png` et `tours_toon_v2_atlas.png`. La police de titres Lilita One et sa licence OFL sont dans `assets/polices/`.
- L'utilisateur prépare désormais les nouvelles animations. Se concentrer sur les ressources statiques et l'intégration de ses exports quand ils seront fournis.

## Lisibilité et commentaires

- L'utilisateur découvre GDScript. Expliquer les fonctions et les étapes importantes avec de vraies phrases en français, en précisant les données utilisées, le résultat et les raisons des vérifications.
- Écrire les couleurs hexadécimales avec le préfixe #, par exemple Color("#d58b63") ou Color("#112219b8"), pour que VS Code puisse afficher leur aperçu. Conserver les valeurs et la transparence lors d'un changement de notation.
- Séparer les responsabilités dans gameplay/, ui/, rendering/ et tests/. Garder les fonctions de coordination simples, sans multiplier les fichiers pour des détails insignifiants.
- Aérer les étapes avec des lignes vides et développer les dictionnaires et les conditions complexes sur plusieurs lignes. Éviter les longues conditions imbriquées difficiles à lire.
- Mettre à jour LIRE-LE-CODE.txt si un fichier change de rôle ou de dossier. Garder game.gd comme point d'accès aux règles pour main.gd et les tests.

## Interface de la partie

- Le menu initial contient le titre, la description, le choix de la grille, Commencer et Options (sans action pour le moment). Le temps de jeu ne doit pas avancer dans ce menu.
- La grille 25 × 50 est accessible dès le départ ; y atteindre la vague 25 débloque 50 × 100, puis y atteindre la vague 50 débloque 100 × 200. Sauvegarder par grille dès le lancement de la vague dans progression.gd. L'ancien record global reste distinct. Vérifier les verrous dans le menu et dans start_game.
- Le mode développeur est explicite : Jouer-MazeTD-Dev.cmd, option -Dev du lanceur, argument utilisateur --dev ou réglage maze_td/developer_mode. Il autorise toutes les grilles sans changer les déblocages normaux ; ne pas l'activer automatiquement dans une version de débogage.
- La sélection d'une tour assombrit légèrement le sol de sa case avant le dessin du sprite. Ne pas réintroduire de cadre autour de la tour.
- Réserver plus de 80 % de la surface utile au plateau. Le catalogue contient uniquement les huit tours, à droite en paysage et sous la carte en portrait.
- Vendre et Améliorer sont uniquement dans les fiches des tours. Ne pas réintroduire de boutons globaux ni de boutons Entrée, Château, Vue ou zoom.
- Pause et Vitesse sont des commandes flottantes à fond semi-transparent sur la carte. Le lancement anticipé flotte seulement pendant la préparation. Rejouer apparaît au centre du plateau après une victoire ou une défaite.
- Conserver le glissement de la carte, la molette et le pincement, sans achat involontaire à la fin d'un zoom.
- L'engrenage voisin de Pause et Vitesse ouvre une fenêtre qui suspend le temps et bloque les commandes derrière elle. Options reste sans effet ; Retour accueil quitte la partie pour le menu. La croix conserve l'état de pause antérieur. Le résultat propose aussi Retour accueil sous Rejouer.
