# Analyse forensique et débogage système

## Analyse de processus et performances

---

1)
Localisation des ressources :

Scénarios de test : accessibles dans le dossier `proc_perf_diag/scenario`.

Guide méthodologique : le fichier `proc_perf_diag/Methodology.md` décrit les étapes d'implémentation et les indicateurs d'observation.

2) Analyse opérationnelle des scénarios de test
   2)1) La boucle infinie
   
Avec la commande ps aux (affichage du pourcentage de l'utilisation du cpu et de l'état) :

```bash
cd proc_perf_diag/scenario/
make
./infinite_loop
```

```bash
ps aux | awk 'NR==1 || /infinite_loop/'
```
En exécution : Le processus est visible et marqué du statut R (Running) et le cpu est à 100%.

À l'arrêt : Le processus disparaît de la table des processus système.

Question : Pourquoi si cpu est à 100% alors le pc ne reussi à executer d'autres commande ou bien ne crache pas ? 

La réponse s'obtient facilement avec `htop`: 

```bash
htop -p $(pgrep infinite_loop)
```

![capture htop](images/htop_infinite_loop.png)

Analyse de la charge CPU
Ma configuration de test dispose de 16 cœurs. Comme on peut le voir sur l'image, le lancement de quatre instances du programme infinite_loop mobilise entièrement quatre cœurs (soit 25 % de la capacité totale du processeur).

Le risque de la "Fork Bomb"
Cette expérience illustre pourquoi une Fork Bomb est redoutable : il s'agit d'un processus qui se réplique à l'infini et de manière exponentielle jusqu'à saturer la totalité des cœurs et de la mémoire, provoquant ainsi le blocage complet (freeze) de l'ordinateur.

Et donc la réponse à la question de tout à l'heure, c'est que `ps aux` affiche 100 %, mais que pour un seul cœur et si on lance plusieurs instance `ps aux` nous montreras plusieurs infinite_loop à 100 %, mais on ne pourra pas savoir où est la limite.

   2)2) Blocage I/O
