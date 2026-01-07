# Scénario 1 : Service Web Inaccessible

## Description du problème
Un serveur web Apache/Nginx devrait être accessible sur le port 80/443, mais les clients ne peuvent pas s'y connecter. L'application semble fonctionner localement mais n'est pas accessible depuis l'extérieur.

## Symptômes observés
- Les utilisateurs reçoivent "Connection refused" ou "Connection timeout"
- Le service semble démarré sur le serveur
- Les logs du serveur web ne montrent aucune tentative de connexion

## Démarche de diagnostic complète

### Étape 1 : Vérifier que le service est en cours d'exécution

```bash
# Vérifier le statut du service
sudo systemctl status nginx
# ou
sudo systemctl status apache2

# Alternative : vérifier les processus
ps aux | grep -E 'nginx|apache2|httpd'
```

**Interprétation :**
- Si le service n'est pas actif → le démarrer avec `sudo systemctl start nginx`
- Si le service est en "failed" → consulter les logs : `journalctl -xeu nginx`

### Étape 2 : Vérifier que le service écoute sur les bons ports

```bash
# Méthode moderne avec ss
sudo ss -tlnp | grep -E ':80|:443'

# Alternative avec netstat (legacy)
sudo netstat -tlnp | grep -E ':80|:443'

# Détails complets des sockets
sudo ss -tlnp '( sport = :80 or sport = :443 )'
```

**Interprétation attendue :**
```
LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1234,fd=6))
LISTEN 0 511 0.0.0.0:443 0.0.0.0:* users:(("nginx",pid=1234,fd=7))
```

**Problèmes possibles :**
- Aucune ligne → le service n'écoute pas (problème de configuration)
- Écoute sur `127.0.0.1:80` uniquement → configuration limitée à localhost
- Port différent (ex: 8080) → mauvaise configuration

### Étape 3 : Tester la connectivité locale

```bash
# Test local avec curl
curl -v http://localhost:80
curl -v http://127.0.0.1:80

# Test avec telnet
telnet localhost 80

# Test avec nc (netcat)
nc -zv localhost 80
```

**Interprétation :**
- Si succès en local mais échec depuis l'extérieur → problème de firewall ou routage
- Si échec en local → problème de configuration du service

### Étape 4 : Vérifier la configuration réseau

```bash
# Afficher les interfaces réseau
ip addr show
ip link show

# Afficher la table de routage
ip route show

# Vérifier les routes par défaut
ip route get 8.8.8.8
```

**Interprétation :**
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
```

Vérifier que :
- L'interface a une adresse IP valide
- L'état est UP
- La passerelle par défaut est configurée

### Étape 5 : Vérifier le pare-feu (iptables/firewalld/ufw)

```bash
# Pour iptables
sudo iptables -L -n -v
sudo iptables -L INPUT -n -v | grep -E '80|443'

# Pour ufw (Ubuntu/Debian)
sudo ufw status verbose
sudo ufw status numbered
```

**Interprétation :**
- Rechercher des règles DROP ou REJECT sur les ports 80/443
- Vérifier que les services http/https sont autorisés

**Solution si bloqué :**
```bash
# iptables
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Étape 6 : Tester depuis l'extérieur

```bash
# Depuis une autre machine
curl -v http://IP_DU_SERVEUR:80
telnet IP_DU_SERVEUR 80

# Scanner les ports avec nmap
nmap -p 80,443 -sV IP_DU_SERVEUR
nmap -Pn -p 80,443 IP_DU_SERVEUR  # Si ping bloqué
```

**Interprétation nmap :**
```
PORT    STATE    SERVICE
80/tcp  open     http
443/tcp open     https
```

Si "filtered" → pare-feu bloque
Si "closed" → rien n'écoute sur le port

### Étape 7 : Analyser le trafic réseau

```bash
# Capturer les paquets sur le port 80
sudo tcpdump -i any port 80 -n -v

# Capture plus détaillée avec écriture dans un fichier
sudo tcpdump -i eth0 'port 80 or port 443' -w /tmp/capture.pcap -v

# Filtrer les SYN packets (tentatives de connexion)
sudo tcpdump -i any 'tcp[tcpflags] & tcp-syn != 0 and port 80'
```

**Interprétation :**
- Voir des paquets SYN mais pas de SYN-ACK → service ne répond pas
- Voir des paquets RST → connexion refusée
- Pas de paquets du tout → problème avant le serveur (réseau, firewall externe)

### Étape 8 : Vérifier les logs système

```bash
# Logs du service web
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/apache2/error.log

# Logs système
sudo journalctl -u nginx -f
sudo journalctl -u apache2 -f

# Logs du pare-feu (si activés)
sudo journalctl -k | grep -i 'iptables\|firewall'
sudo dmesg | grep -i 'iptables\|firewall'
```