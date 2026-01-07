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

### 2.4 Le processus Zombie (`zombie_process`) 

**Observation concrète :**
Le lancement du binaire `./zombie_process` génère une structure hiérarchique composée d'un processus parent et de 5 processus fils.

**Identification des PIDs :**
L'outil `pgrep` liste les identifiants uniques alloués par le noyau :

```bash
pgrep zombie_process
# Sortie : 
128042 (Parent)
128043
128044
128045
128046
128047

```

**Analyse de la hiérarchie et des états :**
L'exécution de `pstree` confirme la filiation directe :

```bash
pstree 128042
# Résultat : zombie_process───5*[zombie_process]

```

L'état des processus dans la table `ps` montre que les 5 fils sont en statut **Z (Zombie)**, tandis que le parent est en statut **S (Sleep)**.

**Diagnostic par traçage système (`strace`) :**
L'analyse de l'activité du parent (PID 128042) via `strace` identifie la cause du blocage :

```bash
sudo strace -p 128042
# Sortie : strace: Process 128042 attached
#          restart_syscall(<... resuming interrupted read ...>

```

Le processus parent est suspendu sur un appel système de lecture (`read`). Il est en attente d'une interaction sur l'entrée standard avant de poursuivre son exécution. Tant que cet appel n'est pas complété, le parent ne peut pas exécuter l'instruction `wait()` nécessaire pour "récolter" le statut de sortie des fils et les libérer de la table des processus.

**Cycle de terminaison :**

1. **Phase de rétention :** Les fils ont terminé leur exécution (`exit`), mais leurs descripteurs restent inscrits dans la table des processus car le parent est occupé par son `syscall`.
2. **Reprise et Nettoyage :** À la clôture du processus parent, le noyau réattribue les zombies au processus `init` (PID 1) qui procède immédiatement à leur suppression définitive.

---

### 2.5 Le danger critique : Saturation du `pid_max`

Bien qu'un processus zombie ne consomme plus de ressources CPU ou RAM, il demeure une menace pour la stabilité du système en raison de la gestion des identifiants (PIDs).

* **Mécanisme :** Chaque processus, même mort (zombie), occupe un emplacement dans la **table des processus** du noyau pour conserver son code de sortie.
* **Limite système :** Le nombre total de PIDs est fini. Cette limite est définie dans le fichier `/proc/sys/kernel/pid_max`.
* **Conséquence d'une prolifération :** Si une application défaillante génère des milliers de zombies sans jamais les récolter, elle finit par atteindre la limite `pid_max`.

> **Impact opérationnel :** Une fois la table saturée, le noyau est incapable d'allouer de nouveaux PIDs. Le système ne peut plus lancer aucune commande (`ls`, `ps`, `sh`), rendant toute intervention technique impossible sans un redémarrage matériel ou l'arrêt forcé du processus parent fautif.

---

### 2.6 Le processus stoppé (`stopped_process`)

**Observation du comportement :**
Le binaire `./stopped_process` simule un état de suspension volontaire. À l'exécution, le programme s'interrompt de lui-même après avoir affiché ses informations de contrôle.

**Analyse de l'état via `ps` :**
L'examen de la table des processus montre deux états distincts selon le moment de l'observation :

```bash
baloo     112485  0.0  0.0   2680  1536 pts/3    T    16:37   0:00 ./stopped_process
baloo     112748  0.0  0.0   2680  1536 pts/3    S+   16:38   0:00 ./stopped_process

```

* **État T (Stopped) :** Le processus est suspendu. Il est toujours présent en mémoire mais le kernel ne lui alloue plus de temps CPU.
* **État S+ (Interruptible Sleep) :** Le processus est en attente d'un événement au premier plan (foreground).

**Interactions utilisateur et signaux :**
Dans un usage quotidien, cet état **T** est généralement provoqué manuellement par l'utilisateur via la combinaison de touches **`Ctrl+Z`** (envoie le signal `SIGTSTP`).

La gestion de ces processus suspendus s'effectue avec les commandes de contrôle de job :

* **`jobs`** : Liste les processus stoppés dans le shell courant.
* **`fg` (Foreground)** : Reprend l'exécution du processus au premier plan.
* **`bg` (Background)** : Reprend l'exécution en arrière-plan.
* **`kill -CONT <PID>`** : Envoie le signal de continuation au niveau du noyau, indépendamment du shell.

**Analyse de la terminaison avec `strace` :**
L'utilisation de `strace` lors de l'arrêt forcé du processus (via `kill -TERM`) révèle la réception du signal par le noyau :

```bash
sudo strace -p 129889
# Sortie :
# restart_syscall(<... resuming interrupted read ...>) = ? ERESTART_RESTARTBLOCK (Interrupted by signal)
# --- SIGTERM {si_signo=SIGTERM, si_code=SI_USER, si_pid=130300, si_uid=1000} ---
# +++ killed by SIGTERM +++

```

**Décryptage de la trace :**

1. **`RESTART_RESTARTBLOCK`** : Le processus était initialement bloqué sur un appel système (`read`). Le noyau tente de redémarrer cet appel après une interruption.
2. **`SIGTERM`** : On identifie ici la source de l'arrêt. Le champ `si_pid=130300` indique précisément quel processus a envoyé l'ordre de fermeture, et `si_uid=1000` confirme qu'il s'agit de l'utilisateur (baloo).
3. **`killed by SIGTERM`** : Le processus ne traite pas le signal lui-même (pas de gestionnaire d'exception) ; c'est le noyau qui met fin au processus de manière propre.


