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
   
Lorsque je lance le programme IO_blocking, celui-ci attend que je saisisse des caractères ou que je tape Ctrl+D pour continuer. Tant que je n'effectue aucune action, le programme reste en attente.

En utilisant la commande ps aux, je peux observer son état :

État S (Interruptible Sleep) : Il s'agit de l'état le plus courant. Mon processus est en sommeil le temps qu'un événement survienne (une touche du clavier ou l'arrivée d'un paquet réseau). Il peut être réveillé à tout moment par un signal.

Afin de visualiser ce qu'il se passe au niveau du noyau, j'utilise l'outil strace pour suivre les appels système du processus en temps réel.

```bash
sudo strace -p $(pgrep IO_blocking)
```
```Plaintext
strace: Process 60594 attached
read(0,
```
Ici, l'affichage s'arrête sur read(0,. Le chiffre 0 correspond au descripteur de fichier de l'entrée standard (stdin). Cela me confirme que le processus est techniquement bloqué sur une opération de lecture.

Dès que j'interviens (par exemple en envoyant un signal d'interruption), strace affiche la fin de l'appel système et les signaux reçus :
```Plaintext
strace: Process 63920 attached
read(0, "", 1024)                       = 0
exit_group(0)                           = ?
+++ exited with 0 +++
```
`read(0, "", 1024) = 0` : L'appel système read se termine. La valeur de retour 0 indique que la fin du fichier a été atteinte (EOF). Il n'y a plus de données à lire, mais aucune erreur n'est survenue.

`exit_group(0)` : Le programme interprète cette fin de fichier comme une instruction de sortie normale. Il appelle donc exit_group avec le code de retour 0.

`exited with 0` : Le processus se termine avec succès.

   2)3) La fuite mémoire



