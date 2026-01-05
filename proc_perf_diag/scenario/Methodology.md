# Scénarios de test - Diagnostic de performance

Programmes de test pour analyser et diagnostiquer différents comportements système selon les consignes du TP.
Ces scénarios couvrent tous les états de processus principaux : **R, S, D, Z, T**

## Compilation

```bash
make
```

## Scénarios disponibles

### 1. infinite_loop
**Objectif**: Simuler une boucle infinie qui consomme 100% du CPU (état R)

**Exécution**:
```bash
./infinite_loop
```

**Diagnostic - Outils utilisés**:
```bash
# Identifier le processus et ses ressources
ps aux | grep infinite_loop           # %CPU élevé, état R
top -p $(pgrep infinite_loop)         # Monitoring en temps réel
htop -p $(pgrep infinite_loop)        # Vue détaillée

# Retrouver le processus
pgrep infinite_loop                   # Par nom
pidof infinite_loop                   # PID du processus

# Analyser avec /proc
cat /proc/$(pgrep infinite_loop)/stat # État, temps CPU
cat /proc/$(pgrep infinite_loop)/status # Infos détaillées

# Tracer les appels système
strace -p $(pgrep infinite_loop)      # Voir la boucle infinie
```

**État attendu**: R (Running)

---

### 2. IO_blocking
**Objectif**: Simuler un processus en attente d'entrée utilisateur (état S)

**Exécution**:
```bash
./IO_blocking
```

**Diagnostic - Outils utilisés**:
```bash
# Identifier l'état du processus
ps aux | grep IO_blocking             # État S (Sleeping)
ps -l $(pgrep IO_blocking)            # STAT = S+

# Fichiers ouverts
lsof -p $(pgrep IO_blocking)          # Voir stdin ouvert
lsof | grep IO_blocking               # Fichiers et descripteurs

# Tracer les appels système
strace -p $(pgrep IO_blocking)        # Voir le read() bloquant sur stdin

# Analyser avec /proc
cat /proc/$(pgrep IO_blocking)/fd     # Descripteurs de fichiers
ls -l /proc/$(pgrep IO_blocking)/fd/  # stdin, stdout, stderr
```

**État attendu**: S (Sleeping - interruptible)

---

### 3. memory_leak
**Objectif**: Créer une fuite mémoire (allocation sans libération)

**Exécution**:
```bash
./memory_leak
```

**Diagnostic - Outils utilisés**:
```bash
# Observer la consommation mémoire
ps aux | grep memory_leak             # %MEM augmente progressivement
top -p $(pgrep memory_leak)           # VSZ et RSS grandissent
htop -p $(pgrep memory_leak)          # Vue graphique de la mémoire

# Surveillance continue
watch -n 1 "ps -o pid,vsz,rss,cmd -p \$(pgrep memory_leak)"

# Analyser avec /proc
cat /proc/$(pgrep memory_leak)/status | grep Vm  # VmSize, VmRSS
cat /proc/$(pgrep memory_leak)/statm  # Pages mémoire
cat /proc/$(pgrep memory_leak)/maps   # Zones mémoire allouées

# Tracer les allocations
strace -p $(pgrep memory_leak) -e trace=brk,mmap  # Voir les malloc()
```

**État attendu**: S (Sleeping) avec mémoire croissante

---

### 4. zombie_process
**Objectif**: Créer des processus zombies (état Z)

**Exécution**:
```bash
./zombie_process
```

**Diagnostic - Outils utilisés**:
```bash
# Identifier les zombies
ps aux | grep 'Z'                     # État Z visible
ps -l | grep Z                        # STAT = Z
ps -ef | grep defunct                 # Voir <defunct>

# Analyser l'arbre parent/enfant
pstree -p $(pgrep zombie_process)     # Voir parent et enfants zombies
ps -o pid,ppid,stat,cmd | grep zombie # Relations parent/enfant

# Retrouver les processus
pgrep -a zombie                       # Tous les processus zombie*

# Analyser avec /proc
cat /proc/$(pgrep zombie_process)/status # État du parent
ls /proc/$(pgrep zombie_process)/task    # Threads du processus
```

**État attendu**: Z (Zombie) pour les enfants, S pour le parent

---

### 5. stopped_process
**Objectif**: Créer un processus dans l'état T (Stopped/Arrêté)

**Exécution**:
```bash
./stopped_process
```

**Diagnostic - Outils utilisés**:
```bash
# Identifier l'état arrêté
ps aux | grep stopped                 # État T visible
ps -l $(pgrep stopped)                # STAT = T

# Voir les signaux
cat /proc/$(pgrep stopped)/status | grep Sig  # SigPnd, SigBlk

# Analyser avec /proc
cat /proc/$(pgrep stopped)/stat       # État T dans le 3ème champ
cat /proc/$(pgrep stopped)/status     # State: T (stopped)

# Réactiver le processus
kill -CONT $(pgrep stopped)           # Envoyer SIGCONT

# Arrêter à nouveau (depuis un autre terminal ou avec Ctrl+Z)
kill -STOP $(pgrep stopped)           # Envoyer SIGSTOP
```

**État attendu**: T (Stopped)

---

### 6. disk_sleep
**Objectif**: Tenter de mettre un processus en état D (Disk sleep - sommeil non interruptible)

**Exécution**:
```bash
./disk_sleep
```

**Diagnostic - Outils utilisés**:
```bash
# Observer l'état (difficile à capturer, surveiller en continu)
watch -n 0.1 "ps -eo pid,stat,comm | grep disk_sleep"
ps aux | grep disk_sleep              # Chercher état D (rare)
ps -l $(pgrep disk_sleep)             # STAT = D si en opération I/O

# Voir les opérations I/O
lsof -p $(pgrep disk_sleep)           # Fichiers ouverts
cat /proc/$(pgrep disk_sleep)/io      # Statistiques I/O

# Tracer les appels système
strace -p $(pgrep disk_sleep) -e trace=write,sync,fsync  # Voir les opérations disque

# Analyser avec /proc
cat /proc/$(pgrep disk_sleep)/status  # État et statistiques
cat /proc/$(pgrep disk_sleep)/wchan   # Fonction kernel en attente
```

**État attendu**: D (Disk sleep - uninterruptible) pendant les opérations sync/fsync
**Note**: L'état D est transitoire et difficile à observer sans matériel lent ou NFS non-responsive

---

## Méthodologie de diagnostic générale

Pour chaque scénario, suivre cette approche :

1. **Identification** : `ps`, `pgrep`, `pidof`, `top`, `htop`
2. **Relations** : `pstree` pour voir l'arbre parent/enfant
3. **État détaillé** : `/proc/<PID>/status`, `/proc/<PID>/stat`
4. **Fichiers ouverts** : `lsof -p <PID>`
5. **Appels système** : `strace -p <PID>`
6. **Analyse continue** : `top`, `htop`, `watch`

## Arrêter les processus

```bash
# Arrêter un processus spécifique
kill $(pgrep nom_du_programme)

# Arrêter tous les scénarios
killall infinite_loop IO_blocking memory_leak zombie_process stopped_process disk_sleep

# Force kill si nécessaire
kill -9 $(pgrep nom_du_programme)

# Nettoyer les fichiers temporaires
rm -f /tmp/disk_sleep_test.dat
```

## Nettoyage

```bash
# Supprimer les exécutables
make clean
```

## États des processus - Récapitulatif

| État | Description | Scénario |
|------|-------------|----------|
| **R** | Running - En cours d'exécution ou prêt | `infinite_loop` |
| **S** | Sleeping - En sommeil interruptible | `IO_blocking`, `memory_leak` |
| **D** | Disk sleep - Sommeil non interruptible (I/O) | `disk_sleep` (transitoire) |
| **Z** | Zombie - Terminé en attente de récupération | `zombie_process` |
| **T** | Stopped - Arrêté par signal | `stopped_process` |
