# Scénario 3 : Résolution DNS Défaillante

## Description du problème
Les noms de domaine ne se résolvent pas correctement, les applications affichent "Host not found" ou "DNS resolution failed". Parfois la résolution fonctionne mais est très lente (>5 secondes).

## Symptômes observés
- `ping google.com` échoue avec "unknown host"
- `curl http://exemple.com` timeout ou erreur de résolution
- Accès par IP fonctionne : `curl http://8.8.8.8` OK
- Navigation web impossible sauf avec IPs directes
- Résolution intermittente (marche puis ne marche plus)

## Démarche de diagnostic complète

### Étape 1 : Vérifier la configuration DNS du système

```bash
# Vérifier le fichier resolv.conf
cat /etc/resolv.conf

# Sur les systèmes avec systemd-resolved
resolvectl status
systemd-resolve --status  # ancienne commande

# Vérifier le service
systemctl status systemd-resolved

# Voir la configuration NetworkManager (si utilisé)
nmcli dev show | grep DNS
cat /etc/NetworkManager/NetworkManager.conf
```

**Interprétation `/etc/resolv.conf` :**
```
nameserver 8.8.8.8
nameserver 8.8.4.4
search example.local
options timeout:2 attempts:3
```

**Problèmes courants :**
- Aucun `nameserver` → pas de serveur DNS configuré
- `nameserver 127.0.0.1` sans service local → mauvaise configuration
- Serveur DNS inaccessible ou non fonctionnel
- Fichier vide ou corrompu

### Étape 2 : Tester la résolution DNS de base

```bash
# Test basique avec nslookup
nslookup google.com

# Test avec dig (plus détaillé)
dig google.com

# Test avec host (simple)
host google.com

# Spécifier un serveur DNS particulier
dig @8.8.8.8 google.com
nslookup google.com 8.8.8.8

# Test résolution inverse
dig -x 8.8.8.8
```

**Interprétation `dig` :**
```
; <<>> DiG 9.18.1 <<>> google.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; QUESTION SECTION:
;google.com.                    IN      A

;; ANSWER SECTION:
google.com.             299     IN      A       142.250.185.78

;; Query time: 23 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Tue Jan 07 14:30:00 CET 2026
;; MSG SIZE  rcvd: 55
```

**Status possibles :**
- **NOERROR** → résolution réussie
- **SERVFAIL** → serveur DNS a un problème
- **NXDOMAIN** → domaine n'existe pas
- **REFUSED** → serveur refuse de répondre
- **timeout** → serveur DNS injoignable

### Étape 3 : Vérifier la connectivité au serveur DNS

```bash
# Vérifier si le serveur DNS est joignable
DNS_SERVER=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
ping -c 4 $DNS_SERVER

# Tester le port DNS (53 UDP)
nc -zuv $DNS_SERVER 53

# Tester le port DNS TCP (utilisé si réponse > 512 bytes)
nc -zv $DNS_SERVER 53

# Scanner avec nmap
nmap -sU -p 53 $DNS_SERVER
nmap -sT -p 53 $DNS_SERVER
```

**Interprétation :**
- Si ping échoue → serveur DNS injoignable (routage ou firewall)
- Si port 53 fermé → service DNS non actif
- Si port filtered → firewall bloque

### Étape 4 : Tracer la requête DNS complète

```bash
# Tracer toute la chaîne de résolution
dig +trace google.com

# Avec plus de détails
dig +trace +additional google.com

# Tracer une requête spécifique (ex: MX records)
dig +trace MX google.com
```

**Interprétation `dig +trace` :**
```
.                       518400  IN      NS      a.root-servers.net.
[...]
com.                    172800  IN      NS      a.gtld-servers.net.
[...]
google.com.             172800  IN      NS      ns1.google.com.
[...]
google.com.             300     IN      A       142.250.185.78
```

**Où peut se situer le problème :**
- Échec au niveau root servers → problème majeur de connectivité internet
- Échec au niveau TLD (.com) → problème spécifique ou filtrage
- Échec au niveau authoritative → serveurs DNS du domaine cible down
- Timeout partout → connectivité réseau ou firewall
### Étape 5 : Vérifier les performances DNS (timing)

```bash
# Mesurer le temps de résolution
time dig google.com
time nslookup google.com

# Statistiques détaillées
dig google.com +stats

# Tester le cache (première requête vs requête en cache)
dig google.com +short
dig google.com +short

# Comparer avec Google DNS
dig @8.8.8.8 google.com +stats
dig @1.1.1.1 google.com +stats
dig @208.67.222.222 google.com +stats
```

**Interprétation :**
- Query time < 50ms → excellent
- Query time 50-200ms → acceptable
- Query time > 200ms → problématique
- Query time > 1000ms → très problématique

**Si lent :**
- Cache DNS vide (normal la première fois)
- Serveur DNS distant ou surchargé
- Problème de latence réseau
- Serveur DNS filtering/rate limiting

### Étape 6 : Tester le cache DNS local

```bash
# Vérifier si systemd-resolved est actif
systemctl status systemd-resolved

# Voir les statistiques du cache
resolvectl statistics

# Vider le cache DNS
sudo resolvectl flush-caches

# Pour nscd (si utilisé à la place)
sudo systemctl restart nscd

# Pour dnsmasq (si utilisé)
sudo systemctl restart dnsmasq

# Tester avec et sans cache
dig google.com  # première requête
dig google.com  # deuxième requête (devrait être plus rapide)
```

**Interprétation statistiques :**
```
DNSSEC supported: yes
Cache:
  Current Cache Size: 152
  Cache Hits: 1234
  Cache Misses: 567
```

- Cache Miss rate élevé → cache inefficace
- Si pas de différence de temps → cache ne fonctionne pas

### Étape 7 : Vérifier le firewall et les règles iptables

```bash
# Vérifier si le DNS (port 53) est bloqué
sudo iptables -L OUTPUT -n -v | grep -E '53|domain'
sudo iptables -L INPUT -n -v | grep -E '53|domain'

# Vérifier les règles de forwarding
sudo iptables -L FORWARD -n -v

# Pour nftables
sudo nft list ruleset | grep -E '53|domain'

# Capturer les paquets DNS pour voir s'ils partent
sudo tcpdump -i any port 53 -n
```

**Test avec tcpdump :**
```bash
# Terminal 1: capturer
sudo tcpdump -i any port 53 -n -v

# Terminal 2: faire une requête
dig google.com @8.8.8.8
```

**Interprétation tcpdump :**
```
15:30:00.123456 IP 192.168.1.10.45678 > 8.8.8.8.53: 12345+ A? google.com. (28)
15:30:00.145678 IP 8.8.8.8.53 > 192.168.1.10.45678: 12345 1/0/0 A 142.250.185.78 (44)
```

- Voir query mais pas de response → serveur ne répond pas ou réponse bloquée
- Ne voir aucun paquet → requête bloquée en sortie
- Voir des ICMP errors → problème de routage

### Étape 8 : Vérifier la configuration pour les domaines locaux

```bash
# Vérifier /etc/hosts
cat /etc/hosts
```

**Problème possible :**
- Si `dns` manque → ne consultera jamais les serveurs DNS
- Si ordre incorrect → comportement inattendu

### Étape 9 : Tester différents types d'enregistrements DNS

```bash
# Enregistrement A (IPv4)
dig A google.com

# Enregistrement AAAA (IPv6)
dig AAAA google.com

# Enregistrement MX (mail servers)
dig MX google.com

# Enregistrement NS (nameservers)
dig NS google.com

# Enregistrement TXT (informations diverses)
dig TXT google.com

# Tous les enregistrements
dig ANY google.com

# Enregistrement PTR (reverse DNS)
dig -x 142.250.185.78
```

**Si certains types ne fonctionnent pas :**
- Problème spécifique au type de requête
- Filtrage réseau sélectif
- Serveur DNS ne supporte pas le type

### Étape 10 : Diagnostiquer DNSSEC

```bash
# Vérifier la validation DNSSEC
dig google.com +dnssec

# Tracer avec DNSSEC
dig +trace +dnssec google.com

# Vérifier si DNSSEC est activé localement
resolvectl status | grep DNSSEC

# Désactiver temporairement DNSSEC pour test
sudo mkdir -p /etc/systemd/resolved.conf.d/
echo -e "[Resolve]\nDNSSEC=no" | sudo tee /etc/systemd/resolved.conf.d/dnssec-off.conf
sudo systemctl restart systemd-resolved
```

**Si DNSSEC cause des problèmes :**
- Signature invalide ou expirée
- Clock skew (horloge système incorrecte)
- Serveur DNS ne supporte pas DNSSEC