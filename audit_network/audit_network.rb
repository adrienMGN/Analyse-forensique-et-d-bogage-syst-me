#!/usr/bin/env ruby
# frozen_string_literal: true

# Audit réseau : services exposés, connexions suspectes, problèmes de configuration

# Ports sensibles courants ftp, ssh, telnet, http, https, mysql, rdp, postgresql
PORTS_SENSIBLES = [21, 22, 23, 80, 443, 3306, 3389, 5432]

# Vérifie si une IP est privée ou non (sécurité basique)
def ip_privee?(ip)
  ip.start_with?('127.', '10.', '192.168.') || ip =~ /^172\.(1[6-9]|2[0-9]|3[01])\./
end

# 1. SERVICES EXPOSES
puts "\n=== SERVICES EXPOSES ==="
services_exposes = []
`ss -tulnp 2>/dev/null`.each_line do |ligne|
  if ligne =~ /(tcp|udp)\s+\S+\s+\d+\s+\d+\s+(\S+):(\d+)/
    proto, ip, port = $1, $2, $3.to_i
    services_exposes << "#{proto}/#{port} sur #{ip}"
    puts "  #{proto}/#{port} sur #{ip}"
    puts "    [ATTENTIN] Service sensible exposé" if (ip == '0.0.0.0' || ip == '::') && PORTS_SENSIBLES.include?(port)
  end
end
puts services_exposes.empty? ? "Aucun service exposé" : "Total: #{services_exposes.size} services"

# 2. CONNEXIONS SUSPECTES
puts "\n=== CONNEXIONS SUSPECTES ==="
connexions_suspectes = 0
`ss -tunp 2>/dev/null`.each_line do |ligne|
  if ligne =~ /ESTAB.*?(\S+):(\d+)\s+(\S+):(\d+)/
    local_ip, local_port, distant_ip, distant_port = $1, $2.to_i, $3, $4.to_i
    # si connexion vers IP publique sur port > 40000 or port de service connu
    if !ip_privee?(distant_ip) && distant_ip != '0.0.0.0' && distant_port > 40000
      puts "[ATTENTION] Connexion vers port inhabituel: #{local_ip}:#{local_port} -> #{distant_ip}:#{distant_port}"
      connexions_suspectes += 1
    end
  end
end
puts connexions_suspectes.zero? ? "Aucune connexion suspecte" : "Total: #{connexions_suspectes} connexions suspectes"

# 3. PROBLEMES DE CONFIGURATION
puts "\n=== CONFIGURATION RESEAU ==="
problemes = []

# Interfaces
`ip -o link show 2>/dev/null`.each_line do |ligne|
  if ligne =~ /^\d+:\s+(\S+):.*state (\w+)/
    nom, etat = $1.gsub(/@.*/, ''), $2
    # Ignorer les interfaces virtuelles courantes
    next if nom.start_with?('lo', 'docker', 'veth')
    
    ip_present = !`ip -o addr show #{nom} 2>/dev/null | grep inet`.empty?
    if etat == 'UP' && !ip_present
      puts "[PROBLEME] Interface #{nom} UP sans adresse IP"
      problemes << "interface_sans_ip"
    end
  end
end

# Route par défaut
route_defaut = `ip route show default 2>/dev/null`
if route_defaut.empty?
  puts "[PROBLEME] Pas de route par déf"
  problemes << "pas_route_defaut"
else
  puts "Route par défaut: OK"
end

# DNS
if File.exist?('/etc/resolv.conf')
  dns = File.read('/etc/resolv.conf').scan(/^nameserver\s+(\S+)/)
  if dns.empty?
    puts "[PROBLEME] Aucun serveur DNS configuré"
    problemes << "pas_dns"
  else
    puts "DNS configurés: #{dns.flatten.join(', ')}"
  end
else
  puts "[PROBLEME] /etc/resolv.conf manquant"
  problemes << "resolv_conf_manquant"
end

# Firewall (si root) 
if Process.uid.zero?
  fw = `iptables -L -n 2>/dev/null`
  if fw.empty? || !fw.include?('Chain')
    puts "[INFO] Aucune règle firewall configurée"
  else
    puts "Firewall: actif"
  end
end

puts "\n=== RESUME ==="
puts "Services exposés: #{services_exposes.size}"
puts "Connexions suspectes: #{connexions_suspectes}"
puts "Problèmes configuration: #{problemes.size}"

