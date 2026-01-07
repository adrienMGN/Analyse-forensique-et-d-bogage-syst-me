#!/usr/bin/env ruby

# helper script de test des scenarios
def run(cmd)
  puts ">> #{cmd}"
  system(cmd)
end

def reset
  puts "[*] Restauration du système..."
  run("iptables -F")
  run("iptables -X")
  run("iptables -P INPUT ACCEPT")
  run("iptables -P OUTPUT ACCEPT")
  run("iptables -P FORWARD ACCEPT")
  run("tc qdisc del dev eth0 root 2>/dev/null")
  run("echo 'nameserver 8.8.8.8' > /etc/resolv.conf")
  run("service nginx start 2>/dev/null || true")
  run("killall nc 2>/dev/null || true")
  puts "[✓] Système restauré à l'état normal"
end

case ARGV[0]
when "1", "service-inaccessible", "web_down"
  reset
  puts "\n[!] SCÉNARIO 1 : Service Web Inaccessible"
  puts "    Description : Le service nginx tourne mais n'est pas accessible"
  puts "    Symptômes : Connection refused sur le port 80"
  puts ""
  run("service nginx stop")
  puts "[✓] Nginx arrêté"

when "2", "latence-elevee", "slow"
  reset
  puts "\n[!] SCÉNARIO 2 : Latence Réseau Élevée"
  puts "    Description : Latence artificielle de 500ms sur l'interface"
  puts "    Symptômes : Temps de réponse très élevé, timeouts"
  puts ""
  run("tc qdisc add dev eth0 root netem delay 500ms")
  puts "[✓] Latence de 500ms ajoutée"

when "3", "dns-defaillant", "dns_kill"
  reset
  puts "\n[!] SCÉNARIO 3 : Résolution DNS Défaillante"
  puts "    Description : Configuration DNS supprimée"
  puts "    Symptômes : Impossible de résoudre les noms de domaine"
  puts ""
  run("echo '' > /etc/resolv.conf")
  puts "[✓] Configuration DNS vidée"

when "4", "pare-feu-bloquant", "firewall"
  reset
  puts "\n[!] SCÉNARIO 4 : Pare-feu Bloquant les Connexions"
  puts "    Description : Pare-feu bloque le trafic sur port 80 et 443"
  puts "    Symptômes : Connection refused/timeout sur les ports web"
  puts ""
  run("iptables -A INPUT -p tcp --dport 80 -j DROP")
  run("iptables -A INPUT -p tcp --dport 443 -j DROP")
  puts "[✓] Règles de blocage activées sur ports 80 et 443"

when "reset", "0"
  reset

else
  puts "Usage: ruby scenario.rb [NUMERO|NOM|COMMANDE]"
  puts ""
  puts "Scénarios disponibles :"
  puts "  1 | service-inaccessible | web_down    - Service web arrêté"
  puts "  2 | latence-elevee       | slow        - Latence réseau élevée (500ms)"
  puts "  3 | dns-defaillant       | dns_kill    - Configuration DNS vide"
  puts "  4 | pare-feu-bloquant    | firewall    - Firewall bloque ports 80/443"
  puts "  0 | reset                              - Restaurer l'état normal"
  puts ""
  puts "Exemples :"
  puts "  ruby scenario.rb 1"
  puts "  ruby scenario.rb latence-elevee"
  puts "  ruby scenario.rb reset"
end