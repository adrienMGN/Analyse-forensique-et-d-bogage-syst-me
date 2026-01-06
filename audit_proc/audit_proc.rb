#!/usr/bin/env ruby

if ARGV.empty?
  puts "Usage: ruby audit_proc.rb <PID>"
  exit 1
end

TARGET = ARGV[0]
REPORT_FILE = "process_report_#{TARGET}.txt"

def run(cmd)
  output = `#{cmd} 2>&1`
end

# resolver PID?
pid = TARGET

File.open(REPORT_FILE, "w") do |f|

  f.puts "----- INFORMATIONS GÉNÉRALES -----"
  f.puts run("ps -p #{pid}")
  f.puts

  f.puts "----- CONSOMMATION DES RESSOURCES -----"
  f.puts run("ps -p #{pid} -o %cpu,%mem,etime") # tjrs 0 ?
  f.puts

  f.puts "----- ARBRE DES PROCESSUS -----"
  f.puts run("pstree -ps #{pid}") # tjrs le même ?
  f.puts

  f.puts "----- FICHIERS OUVERTS -----"
  f.puts run("lsof -w -p #{pid}") # sans warnings?
  f.puts

  f.puts "----- INFORMATIONS /proc -----"
  f.puts "\nCommande : " + run("cat /proc/#{pid}/cmdline")
  f.puts run("grep -E '^(State|PPid|Threads):' /proc/#{pid}/status")
  f.puts "\nMémoire (kB) :"
  f.puts run("grep -E '^(VmSize|VmRSS|VmPeak|VmSwap):' /proc/#{pid}/status")
  f.puts

  f.puts "----- APPELS SYSTÈME RÉCENTS (3s) -----"
  f.puts run("timeout 3 strace -c -p #{pid}")
  f.puts

end

puts "report #{REPORT_FILE}"
