# Scénario 4 : Pare-feu Bloquant les Connexions

## Description du problème
Un pare-feu (iptables, firewalld, ufw, ou pare-feu externe) bloque les connexions entrantes ou sortantes. Les services semblent fonctionner localement mais sont inaccessibles depuis l'extérieur, ou inversement, le serveur ne peut pas accéder à des ressources externes.

## Symptômes observés
- Connexions refusées (Connection refused)
- Timeouts lors de tentatives de connexion
- Services actifs mais inaccessibles
- Impossibilité d'accéder à internet depuis le serveur
- Certains ports accessibles, d'autres non

## Démarche de diagnostic complète

### Étape 1 : Identifier le système de pare-feu actif

```bash
# Vérifier iptables
sudo iptables -L -n -v
sudo iptables -S  # Format plus lisible

# Vérifier ip6tables (IPv6)
sudo ip6tables -L -n -v

# Vérifier nftables (remplaçant moderne d'iptables)
sudo nft list ruleset

# Vérifier ufw (Ubuntu/Debian)
sudo ufw status verbose
sudo systemctl status ufw


**Déterminer quel système est actif :**
- Si iptables a des règles → iptables actif
- Si firewalld running → firewalld actif (gère iptables en arrière-plan)
- Si ufw active → ufw actif (frontend pour iptables)
- Plusieurs peuvent coexister (attention aux conflits)

### Étape 2 : Analyser les règles iptables en détail

```bash
# Lister toutes les chaînes avec compteurs
sudo iptables -L -n -v --line-numbers

# Chaînes principales
sudo iptables -L INPUT -n -v --line-numbers
sudo iptables -L OUTPUT -n -v --line-numbers
sudo iptables -L FORWARD -n -v --line-numbers

# Politique par défaut
sudo iptables -L | grep policy

# Tables NAT (pour redirection de ports)
sudo iptables -t nat -L -n -v

# Table mangle (modification de paquets)
sudo iptables -t mangle -L -n -v
```

**Interprétation :**
```
Chain INPUT (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination
1      123  4567 ACCEPT     all  --  lo     *       0.0.0.0/0            0.0.0.0/0
2      456  8901 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:22
3      789  2345 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:80
4        0     0 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0
```

**Analyse :**
- **Policy DROP** → tout est bloqué par défaut (sécurisé)
- **Policy ACCEPT** → tout est autorisé par défaut (dangereux)
- Règle 1 : autorise loopback (nécessaire)
- Règle 2 : autorise SSH (port 22)
- Règle 3 : autorise HTTP (port 80)
- Règle 4 : drop tout le reste
- **pkts = 0** → règle jamais utilisée (peut-être inutile)
- **pkts élevé** → règle fréquemment déclenchée

### Étape 3 : Tester la connectivité avec tcpdump

```bash
# Capturer sur l'interface externe
sudo tcpdump -i eth0 -nn 'port 80' -v

# Capturer les paquets SYN (tentatives de connexion)
sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0 and port 80'

# Capturer avec timestamp
sudo tcpdump -i eth0 -nn -tttt 'port 80'

# Voir tous les paquets droppés (si logging activé)
sudo tcpdump -i any -nn 'icmp[icmptype] = icmp-unreach'
```

**Pendant la capture, tester depuis une autre machine :**
```bash
curl -v http://IP_SERVEUR:80
nc -zv IP_SERVEUR 80
```

**Interprétation tcpdump :**
```
# CAS 1 : Paquet arrive mais pas de réponse (DROP par firewall)
15:30:00.123 IP 192.168.1.100.45678 > 192.168.1.200.80: Flags [S], seq 1234567890
[... aucune réponse ...]

# CAS 2 : Paquet arrive et reçoit RST (REJECT par firewall)
15:30:00.123 IP 192.168.1.100.45678 > 192.168.1.200.80: Flags [S], seq 1234567890
15:30:00.124 IP 192.168.1.200.80 > 192.168.1.100.45678: Flags [R], seq 0

# CAS 3 : Paquet arrive et reçoit SYN-ACK (OK)
15:30:00.123 IP 192.168.1.100.45678 > 192.168.1.200.80: Flags [S], seq 1234567890
15:30:00.124 IP 192.168.1.200.80 > 192.168.1.100.45678: Flags [S.], seq 9876543210, ack 1234567891

# CAS 4 : Aucun paquet visible
[... rien ...] → firewall en amont bloque avant d'arriver au serveur
```

### Étape 4 : Tester avec nmap depuis l'extérieur

```bash
# Scanner un port spécifique
nmap -p 80 IP_SERVEUR

# Scanner plusieurs ports
nmap -p 22,80,443 IP_SERVEUR

# Scan SYN (plus furtif, nécessite root)
sudo nmap -sS -p 1-1000 IP_SERVEUR

# Scan complet avec détection de service
sudo nmap -sV -p- IP_SERVEUR

# Si ICMP est bloqué
nmap -Pn -p 80,443 IP_SERVEUR

# Avec scripts NSE pour détecter firewall
nmap -p 80 --script=firewalk IP_SERVEUR
```

**Interprétation nmap :**
```
PORT    STATE       SERVICE
22/tcp  open        ssh
80/tcp  filtered    http       ← FIREWALL BLOQUE
443/tcp closed      https
```

- **open** → port accessible et service répond
- **filtered** → firewall bloque (pas de réponse ou ICMP unreachable)
- **closed** → port accessible mais rien n'écoute
- **open|filtered** → incertain (généralement UDP)

### Étape 5 : Analyser les logs du pare-feu

```bash
# Logs iptables (si logging activé)
sudo journalctl -k | grep -i iptables

# Logs firewalld
sudo journalctl -u firewalld -f
sudo firewall-cmd --get-log-denied

# Logs ufw
sudo tail -f /var/log/ufw.log

# Pour activer le logging iptables
sudo iptables -I INPUT -j LOG --log-prefix "iptables-INPUT: " --log-level 4
sudo iptables -I OUTPUT -j LOG --log-prefix "iptables-OUTPUT: " --log-level 4
```

**Exemple de log :**
```
Jan 07 15:30:00 server kernel: iptables-INPUT: IN=eth0 OUT= SRC=192.168.1.100 DST=192.168.1.200 PROTO=TCP SPT=45678 DPT=80 [...]
```

- **IN=eth0** → interface d'entrée
- **SRC=192.168.1.100** → IP source
- **DST=192.168.1.200** → IP destination
- **DPT=80** → port destination
- Permet d'identifier exactement ce qui est bloqué

### Étape 6 : Vérifier les règles ufw (Ubuntu)

```bash
# Statut détaillé
sudo ufw status verbose
sudo ufw status numbered

# Voir les règles brutes
sudo ufw show raw

# Applications définies
sudo ufw app list
sudo ufw app info 'Apache Full'

# Logs
sudo ufw logging on
sudo ufw logging medium
```

**Interprétation :**
```
Status: active
Logging: on (medium)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     DENY IN     Anywhere    ← BLOQUÉ
```

### Étape 7 : Tester les connexions sortantes

```bash
# Tester HTTP sortant
curl -v http://google.com
wget -v http://google.com

# Tester DNS sortant
dig google.com
nslookup google.com

# Tester un port spécifique
telnet google.com 80
nc -zv google.com 80

# Voir les connexions sortantes actives
sudo ss -tunap | grep ESTAB

# Vérifier les règles OUTPUT
sudo iptables -L OUTPUT -n -v
```

**Si bloqué en sortie :**
```bash
# Vérifier la politique par défaut
sudo iptables -L OUTPUT | grep policy

# Capturer pour voir si paquets sortent
sudo tcpdump -i eth0 -nn dst google.com
```

### Étape 8 : Identifier les connexions bloquées en temps réel

```bash
# Monitoring avec watch
watch -n 1 'sudo iptables -L -n -v | head -20'

# Monitoring des compteurs
sudo iptables -Z  # Reset compteurs
# ... attendre quelques minutes ...
sudo iptables -L -n -v  # Voir ce qui a augmenté

# Pour firewalld
watch -n 1 'sudo firewall-cmd --list-all'

# Monitoring des paquets droppés
watch -n 1 'sudo iptables -L INPUT -n -v | grep DROP'
```