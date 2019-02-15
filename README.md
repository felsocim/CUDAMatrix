# CUDAMatrix

Programme de calcul matriciel utilisant la technologie CUDA de *nVidia*

## À propos

Dans le cadre d'un travail pratique, nous avons optimisé un programme de multiplication de matrices carrées, en utilisant la technologie CUDA, de façon à ce que les calculs soient effectués par le processeur de la carte graphique (GPU) plutôt que par le processeur central (CPU). Notre implémentation comprend plusieurs noyaux de calcul dont nous avons étudié les performances pour différentes dimensions de blocs de threads CUDA.

## Contenu du repertoire

Ce dépôt contient tous les fichiers relatifs au travail pratique réalisé.

- Dans le dossier *stats* se trouve le script Bash, *AutoCUDA.sh*, permettant d'effectuer des séries de mesures de performance de notre programme ainsi que le rapport où nous avons décrit notre implémentation et des résultats obtenus.

- La racine du dépôt contient des fichiers sources correspondants.

## Compilation

Le fichier **Makefile** fourni permet de compiler facilement le programme en exécutant une seule commande depuis la racine du dépôt :

```make```

Ne pas oublier d'installer le compilateur nVidia **nvcc** au préalable !

## Exécution

Les noyaux de calcul utilisant la technologies CUDA peuvent évidamment être exécutés uniquement sur une machine disposant d'une carte *nVidia* ayant le support de la technologie CUDA !

Il est possible de paramétrer le programme de façon à ce qu'il effectue les calculs sur GPU ou uniquement sur CPU à l'aide d'un des noyaux de calculs implémentés au choix. Dans le cas de l'exécution sur CPU uniquement, il est également possible d'activer la parallélisation des calculs avec OpenMP en choisissant le nombre de threads à mettre en œuvre.

Pour connaître la syntaxe des options du programme, il suffit de l'exécuter avec l'option **-h**.

## Auteurs

Le squelette du programme ainsi que le *Makefile* nous ont été fournis par notre enseignant, M. [Stéphane Vialle](http://www.metz.supelec.fr/metz/personnel/vialle/information-vialle/index.html). Les différents noyaux de calculs ont été implémentés par [Marek Felsoci](mailto:marek.felsoci@etu.unistra.fr) et Aurélien Rausch.

Voir le site sur [ce lien](http://www.metz.supelec.fr/metz/personnel/vialle/course/Unistra-M2-RISE-SDG/) pour en savoir plus sur l'unité d'enseignement et nos travaux pratiques.
