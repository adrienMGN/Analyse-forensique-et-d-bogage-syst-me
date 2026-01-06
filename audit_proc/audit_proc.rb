#!/usr/bin/env ruby

if ARGV.empty?
  puts "Usage : ruby audit_proc.rb <PID | nom_executable>"
  exit 1
end

TARGET = ARGV[0]
REPORT_FILE = "process_report_#{TARGET}.log"

def run(cmd)
  output = `#{cmd} 2>&1`
end

def resolve_pid(target)
  return target if target =~ /^\d+$/
  pids = run("pgrep -x #{target}").split

  if pids.empty?
    puts "Aucune correspondance"
    exit 1
  elsif pids.size > 1
    puts "Plusieurs correspondances :  #{pids.join(', ')}"
    exit 1
  end

  pids.first
end

pid = resolve_pid(TARGET)

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

puts "rapport: #{REPORT_FILE}"
