# Analyse Forensique et Débogage Système

## Analyse de processus et performances

### 1. Localisation des ressources

* **Scénarios de test :** Accessibles dans le dossier `proc_perf_diag/scenario`.
* **Guide méthodologique :** Le fichier `proc_perf_diag/Methodology.md` décrit les étapes d'implémentation et les indicateurs d'observation.

---

### 2. Analyse opérationnelle des scénarios

#### 2.1 La boucle infinie (`infinite_loop`)

**Observation initiale :**
Pour vérifier l'état du processus, on utilise `ps aux` :

```bash
ps aux | awk 'NR==1 || /infinite_loop/'

```

* **En exécution :** Le processus affiche le statut **R (Running)** et une utilisation CPU de **100%**.
* **À l'arrêt :** Le processus disparaît immédiatement de la table des processus.

**Problématique :** Pourquoi le système ne crache-t-il pas malgré un CPU à 100% ?
L'outil `htop` permet de visualiser la répartition sur les cœurs :

```bash
htop -p $(pgrep infinite_loop)

```

**Analyse de la charge :**

* Sur une configuration à **16 cœurs**, une instance à 100% ne représente que **6,25%** de la capacité totale.
* En lançant 4 instances, on mobilise 4 cœurs (soit 25% du total). Le système reste fluide car il dispose de 12 cœurs libres pour les autres tâches.

> **Le risque de la "Fork Bomb" :** > Contrairement à une boucle simple, une Fork Bomb se réplique de manière exponentielle. Elle sature la totalité des cœurs et la table des processus, provoquant un gel (**freeze**) complet de la machine.

---

#### 2.2 Blocage I/O (`IO_blocking`)

Le programme est en attente d'une interaction utilisateur (clavier ou `Ctrl+D`).

**Observation de l'état :**

* **État S (Interruptible Sleep) :** Le processus est en sommeil. Il ne consomme pas de CPU et attend un événement (signal ou entrée réseau/clavier).

**Analyse avec `strace` :**
Pour voir ce qui se passe au niveau du noyau, on suit les appels système :

```bash
sudo strace -p $(pgrep IO_blocking)

```

Le processus se bloque sur : `read(0,` (où `0` est le descripteur de `stdin`).

**Sortie de blocage :**
Lorsqu'on ferme l'entrée (Ctrl+D) :

```plaintext
read(0, "", 1024) = 0
exit_group(0)     = ?
+++ exited with 0 +++

```

* `read(...) = 0` : Indique la fin de fichier (**EOF**).
* `exit_group(0)` : Terminaison propre du programme.

---

#### 2.3 La fuite mémoire (`memory_leak`)

**Définition :** Mémoire réservée par un programme, devenue inaccessible mais non rendue au système.

**Les 3 caractéristiques d'une fuite :**

1. **L'occupation :** Réservation de RAM auprès de l'OS.
2. **La perte de contrôle :** Perte du pointeur (l'adresse mémoire) ; le programme ne sait plus où est la donnée.
3. **L'oubli de libération :** Absence de l'instruction `free()`.

**Distinction VIRT vs RES :**

* **VIRT (Mémoire Virtuelle) :** La "promesse" faite par le système via `malloc`.
* **RES (Mémoire Résidente) :** La mémoire physique réelle utilisée (activée ici par `memset`).

**Diagnostic avec `htop` :**
En triant par `PERCENT_MEM` (touche `F6`), on observe la colonne `RES` augmenter de **256 Mo** à chaque itération.

> **Piège de l'optimisation :** > Avec les flags `-O2` ou `-O3`, le compilateur supprime le `memset` s'il juge que la mémoire n'est jamais relue. La fuite devient alors invisible dans la colonne `RES`. Il faut compiler sans optimisation pour les tests.

**Protection du noyau (OOM Killer) :**
Via `strace`, on voit l'appel `mmap` (segment de  octets). Lorsque la RAM est saturée (ex: 6.75 GB), le noyau déclenche le **OOM Killer**.

* **Résultat :** `+++ killed by SIGKILL +++`. Le système sacrifie le processus pour survivre.

**Conséquences majeures :**

* **Thrashing :** Ralentissement extrême dû au passage incessant entre RAM et Swap (disque).
* **Instabilité :** Les autres applications ne peuvent plus allouer de mémoire et plantent.
* **Crash :** Arrêt brutal du service (critique en production).

---
