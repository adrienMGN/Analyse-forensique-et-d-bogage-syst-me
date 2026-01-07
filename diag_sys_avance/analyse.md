# 4. Outils de diagnostic système avancés

## - 1. Créer un tableau de bord de diagnostic système (format texte ou HTML) agrégeant les informations de tous ces outils.

Le tableau de bord consiste en un script bash de diagnostic système au format texte. Il regroupe plusieurs outils d’analyse système et permet de les exécuter de manière interactive, selon la volonté de l’utilisateur.
Le script parcourt une liste de commandes prédéfinies et demande systématiquement si le diagnostic doit être lancé. Les résultats sont ensuite affichés directement dans le terminal.

Les commandes sont celles présentés dans le sujet. Il est nécessaire de préalablement installer le paquet `sysstat` (pour `iostat` notamment).
Pour que la commande sar fonctionne il est aussi nécessaire d'activer le service `sysstat` avec `systemctl` et dans `/etc/default/sysstat`, afin d'avoir un jeu de mesure toutes les 10 minutes.
Enfin, certaines commande doivent être exécutées en super-utilisateur (`iotop` et `dmesg`).

## - 2. Identifier et documenter un problème de performance sustème réel ou simulé en utilisant ces outils.

L'exécution de ces commandes sur mon poste personnel en temps normal ne met pas en valeur de problème de performance.
Afin d'en simuler un, j'ai utilisé le scénario perte de mémoire `memory_leak.c` du premier exercice.
Je l'ai lancé jusqu'à avoir une perte de mémoire d'environ 10 Gb, puis j'ai exécuté l'ensemble de mes diagnostiques. Leur résultats est disponible dans le fichier `trace.log` (4212).

### Sortie de la commande `vmstat`

La commande `vmstat` révèle déjà un problème de mémoire :

```text
procs ----------mémoire---------- -échange- -----io---- -système- ------cpu-----
 r  b   swpd  libre tampon  cache   si   so    bi    bo   in   cs us sy id wa st
 7  0 3388752 165680  54172 1427904    4  124   231   165  679 1486  5  2 93  0  0
```

On observe dans les colonnes de la mémoire que le swap et le cache sont saturés, et qu'il n'y a presque plus de mémoire libre.

Rien à signaler sur `iostat`, `mpstat` ou `iotop`.

`sar` ne fait que des relevés périodiques (toutes les 10 minutes dans ma configuration), et l'incident, très court, ne s'est pas produit pendant une mesure.
Le cas contraire, on pourrait constater une hausse des métriques "kbswpfree", "kbswpused", "%swpused", "kbswpcad", "%swpcad".

### Extraits des logs `dmesg`

Les logs de `dmesg` sont très longs, mais `grep` permet néamoins de relever quelques messages utiles qui témoignent clairement d'un accident mémoire, comme par exemple :

```text
[ 3457.652054] oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=ce874473016f653bd23ffc32aa15c8495bb82b01e853120a3a9b4517aab368ce,mems_allowed=0,global_oom,task_memcg=/kubepods/burstable/pod3902af1e-8c>
[ 3457.652078] Out of memory: Killed process 10843 (prometheus-conf) total-vm:719984kB, anon-rss:5064kB, file-rss:0kB, shmem-rss:0kB, UID:1000 pgtables:108kB oom_score_adj:997
[ 3457.652105] Tasks in /kubepods/burstable/pod3902af1e-8ce1-42e1-a2a5-dc04f4240c4f/ed9dcd836d0c7e3e379b2387ef5e15e70f1c932dbce0fce685606bb2f4d62036 are going to be killed due to memory.oom.group set
[ 3457.652109] Out of memory: Killed process 10843 (prometheus-conf) total-vm:719984kB, anon-rss:5064kB, file-rss:0kB, shmem-rss:0kB, UID:1000 pgtables:108kB oom_score_adj:997
[ 3457.694556] tailscaled invoked oom-killer: gfp_mask=0x140cca(GFP_HIGHUSER_MOVABLE|__GFP_COMP), order=0, oom_score_adj=0
[ 3457.694562] CPU: 12 PID: 1241 Comm: tailscaled Tainted: G           OE      6.1.0-41-amd64 #1  Debian 6.1.158-1
[ 3457.694565] Hardware name: Dell Inc. Precision 3460/08PFGW, BIOS 2.10.0 11/07/2023
[ 3457.694566] Call Trace:
[ 3457.694567]  <TASK>
[ 3457.694570]  dump_stack_lvl+0x44/0x5c
[ 3457.694575]  dump_header+0x4c/0x22b
[ 3457.694578]  oom_kill_process.cold+0xb/0x10
[ 3457.694580]  out_of_memory+0x1fd/0x4c0
[ 3457.694583]  __alloc_pages_slowpath.constprop.0+0x6fe/0xe60
[ 3457.694586]  __alloc_pages+0x305/0x330
[ 3457.694588]  folio_alloc+0x17/0x50
[ 3457.694590]  __filemap_get_folio+0x155/0x340
[ 3457.694593]  filemap_fault+0x139/0x910
[ 3457.694595]  ? filemap_map_pages+0x153/0x700
[ 3457.694598]  __do_fault+0x30/0x110
[ 3457.694601]  do_fault+0x1b9/0x410
[ 3457.694603]  __handle_mm_fault+0x660/0xfa0
[ 3457.694606]  handle_mm_fault+0xdb/0x2d0
[ 3457.694609]  do_user_addr_fault+0x191/0x550
[ 3457.694612]  exc_page_fault+0x70/0x170
[ 3457.694614]  asm_exc_page_fault+0x22/0x30
[ 3457.694616] RIP: 0033:0x425a00
[ 3457.694621] Code: Unable to access opcode bytes at 0x4259d6.
[ 3457.694621] RSP: 002b:00007ffd5c3f2c90 EFLAGS: 00010213
[ 3457.694623] RAX: 000000c000059838 RBX: 0000000000000004 RCX: 00000325094e2c7a
[ 3457.694624] RDX: 0000000000000014 RSI: 0000000001de8660 RDI: 0000000000000000
[ 3457.694625] RBP: 00007ffd5c3f2cc0 R08: 00000000fffffffd R09: 000000c000059838
[ 3457.694627] R10: 00007ffd5c3f8080 R11: 00000000001a5da4 R12: 00007ffd5c3f2c78
[ 3457.694627] R13: 000000c000622c40 R14: 0000000001de4680 R15: 0000000000000002
[ 3457.694630]  </TASK>
...
...
...
[ 3460.691564] oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=user.slice,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte>
[ 3460.691578] Out of memory: Killed process 115727 (memory_leak) total-vm:15469196kB, anon-rss:11724804kB, file-rss:1272kB, shmem-rss:0kB, UID:1000 pgtables:30128kB oom_score_adj:200
```

Enfin, la dernière commande du diagnostique, `systemd-analyze` n'est pas pertinente puisque l'accident n'a pas eu lieu au lancement de la machine.
