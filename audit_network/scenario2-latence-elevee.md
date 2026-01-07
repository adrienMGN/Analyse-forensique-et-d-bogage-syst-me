# Scénario 2 : Latence Réseau Élevée

## Description du problème
Les utilisateurs se plaignent de lenteurs importantes lors de l'accès à un serveur d'application. Les pages web mettent plusieurs secondes à charger, les transferts de fichiers sont très lents, et certaines connexions timeout.

## Symptômes observés
- Temps de réponse > 500ms (normal < 100ms)
- Timeouts fréquents
- Déconnexions intermittentes
- Bande passante apparemment sous-utilisée

## Démarche de diagnostic complète

### Étape 1 : Mesurer la latence de base avec ping

```bash
# Test de latence basique
ping -c 10 IP_SERVEUR

# Test avec taille de paquet différente
ping -c 10 -s 1400 IP_SERVEUR


# Ping continu avec timestamp
ping -D IP_SERVEUR | while read ligne; do echo "$(date): $ligne"; done
```

**Interprétation :**
```
PING 192.168.1.100 (192.168.1.100) 56(84) bytes of data.
64 bytes from 192.168.1.100: icmp_seq=1 ttl=64 time=145 ms
64 bytes from 192.168.1.100: icmp_seq=2 ttl=64 time=230 ms
64 bytes from 192.168.1.100: icmp_seq=3 ttl=64 time=89 ms

--- 192.168.1.100 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9013ms
rtt min/avg/max/mdev = 45.123/145.456/230.789/52.345 ms
```

**Indicateurs de problèmes :**
- mdev (écart-type) élevé > 50ms → latence instable
- packet loss > 1% → congestion ou problème réseau
- time élevé et variable → investigation nécessaire

### Étape 2 : Tracer le chemin réseau avec traceroute

```bash
# Traceroute standard
traceroute IP_SERVEUR

# Traceroute avec ICMP
sudo traceroute -I IP_SERVEUR

# Traceroute avec TCP (utile si ICMP bloqué)
sudo traceroute -T -p 80 IP_SERVEUR

```

**Interprétation :**
```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  gateway (192.168.1.1)  1.245 ms  1.123 ms  1.056 ms
 2  10.0.0.1 (10.0.0.1)  8.456 ms  8.234 ms  8.123 ms
 3  * * *  (timeout)
 4  isp-router.net (203.0.113.1)  45.678 ms  234.567 ms  189.234 ms
 5  8.8.8.8 (8.8.8.8)  50.123 ms  49.876 ms  50.234 ms
```

**Analyse :**
- Hop 3 avec `* * *` → routeur ne répond pas (pas forcément un problème)
- Hop 4 avec latence variable et élevée → **PROBLÈME IDENTIFIÉ**
- Latence augmente progressivement → normal
- Latence bondit soudainement → goulot d'étranglement

### Étape 3 : Utiliser MTR (traceroute + ping) pour analyse détaillée 

```bash
# MTR interactif (ncurses)
mtr IP_SERVEUR

# MTR en mode rapport (non-interactif)
mtr --report --report-cycles 100 IP_SERVEUR

# MTR avec TCP
mtr --tcp -P 80 --report --report-cycles 50 IP_SERVEUR

# MTR format JSON pour analyse
mtr --json --report-cycles 100 IP_SERVEUR > mtr-report.json
```

**Interprétation MTR :**
```
HOST: localhost                   Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- gateway                    0.0%   100    1.2   1.3   0.9   3.4   0.3
  2.|-- 10.0.0.1                   0.0%   100    8.5   8.7   7.8  12.3   0.8
  3.|-- isp-router.net            15.0%   100  145.2 167.3  89.4 345.6  52.1
  4.|-- destination                2.0%   100   52.3  54.1  48.7  89.2   6.4
```

**Indicateurs importants :**
- **Loss% élevé (>5%)** au niveau d'un hop → problème à ce routeur
- **Avg >> Best** → congestion intermittente
- **StDev élevé** → instabilité de la liaison
- **Loss% uniquement sur hop intermédiaire** → peut être normal (rate limiting ICMP)

### Étape 4 : Analyser les connexions actives

```bash
# Lister toutes les connexions établies
ss -tunap | grep ESTAB

# Connexions avec temps de retransmission
ss -ti

# Statistiques détaillées TCP
ss -ti dst IP_SERVEUR

# Nombre de connexions par état
ss -tan | awk '{print $1}' | sort | uniq -c
```

**Interprétation `ss -ti` :**
```
ESTAB  0  0  192.168.1.10:45678  192.168.1.100:80
         cubic wscale:7,7 rto:240 rtt:38/19 ato:40 mss:1460 pmtu:1500 
         rcvmss:1460 advmss:1460 cwnd:10 bytes_sent:12345 bytes_acked:12345
         segs_out:156 segs_in:145 send 3.2Mbps lastsnd:1234 lastrcv:1230 
         lastack:1230 pacing_rate 6.4Mbps retrans:0/5 rcv_rtt:45 rcv_space:14600
```

**Indicateurs de problèmes :**
- **rto (retransmission timeout) élevé** (>500ms) → latence détectée par TCP
- **rtt élevé** → latence réseau
- **retrans élevé** → pertes de paquets
- **cwnd faible** → fenêtre de congestion réduite
- **Nombreuses connexions CLOSE_WAIT** → problème applicatif

### Étape 5 : Vérifier la congestion et la bande passante

```bash
# Statistiques des interfaces réseau
ip -s link show

# Statistiques détaillées avec erreurs
ip -s -s link show eth0



```

**Interprétation `ip -s link` :**
```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    RX: bytes  packets  errors  dropped overrun mcast   
        1234567890 987654  45      23      12      5432
    TX: bytes  packets  errors  dropped carrier collsns 
        9876543210 876543  12      5       8       234
```

**Problèmes détectés :**
- **errors élevé** → problème matériel ou driver
- **dropped élevé** → buffers saturés
- **overrun** → CPU ne suit pas le débit
- **collisions** (hubs anciens) → réseau surchargé

### Étape 6 : Capturer et analyser le trafic avec tcpdump

```bash
# Capturer les retransmissions TCP
sudo tcpdump -i any 'tcp[tcpflags] & tcp-push != 0' -nn

# Analyser les fenêtres TCP (window size)
sudo tcpdump -i eth0 -nn -v 'tcp and host IP_SERVEUR'

# Capturer en filtrant un hôte spécifique
sudo tcpdump -i eth0 -nn -w latence.pcap host IP_SERVEUR

```

**Analyse des retransmissions :**
```bash
# Compter les retransmissions
sudo tcpdump -r latence.pcap -nn | grep "Retransmission" | wc -l

# Identifier les délais entre SYN et SYN-ACK
sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & (tcp-syn) != 0'
```

### Étape 7 : Vérifier la table de routage et le routage asymétrique

```bash
# Table de routage
ip route show
ip route get IP_SERVEUR

# Routage par table
ip route show table main
ip route show table local

# Vérifier les politiques de routage
ip rule show

# Tracer le routage inverse (depuis le serveur)
# Exécuter depuis le serveur :
traceroute IP_CLIENT
```

**Problème de routage asymétrique :**
- Le chemin aller et retour sont différents
- Peut causer des problèmes avec les firewalls stateful
- Utiliser `mtr` dans les deux sens pour comparer

### Étape 8 : Analyser les performances DNS

```bash
# Mesurer le temps de résolution DNS
time dig google.com
time nslookup google.com

# Tracer les requêtes DNS
dig +trace google.com

# Vérifier les serveurs DNS utilisés
cat /etc/resolv.conf
resolvectl status
```