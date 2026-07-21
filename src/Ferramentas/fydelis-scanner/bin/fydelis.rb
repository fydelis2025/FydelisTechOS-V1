#!/usr/bin/env ruby
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

#Autor do projeto Adiel Santos Fontes

require 'fydelis/version'
require 'fydelis/scanner'
require 'optparse'

options = { host: nil, ports: [] }

parser = OptionParser.new do |opts|
  opts.on("-t", "--target HOST", "Host ou IP alvo") do |v|
    options[:host] = v
  end

  opts.on("-p", "--ports P", "Portas (ex: 22,80 ou 1-1000 ou 22,80,100-200)") do |v|
    options[:ports] = v.split(',').flat_map do |part|
      if part.include?('-')
        a, b = part.split('-').map(&:to_i)
        (a..b).to_a
      else
        part.to_i
      end
    end.uniq.sort
  end

  opts.on("--top-ports", "Escanear as portas mais comuns (#{FydelisScanner::TOP_PORTS.size} portas)") do
    options[:ports] = FydelisScanner::TOP_PORTS
  end

  opts.on("--speed MODE", %w[insane fast normal polite],
          "Perfil de velocidade: insane, fast, normal, polite") do |v|
    options[:speed] = v
  end

  opts.on("--timeout SECONDS", Float,
          "Timeout de conexão em segundos (padrão: 0.3)") do |v|
    options[:timeout] = v
  end

  opts.on("--threads N", Integer,
          "Número de threads (padrão: 50)") do |v|
    options[:threads] = v
  end

  opts.on("-o", "--output FILE",
          "Salvar resultado em arquivo (sem cores)") do |v|
    options[:output] = v
  end

  opts.on("-v", "--verbose",
          "Mostrar portas fechadas também") do |v|
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Exibe esta mensagem de ajuda") do
    puts "FYDELIS SECURITY SCANNER v#{Fydelis::VERSION}"
    puts "Scanner de portas TCP rápido e leve"
    puts ""
    puts "Uso: #{$0} -t <host> [opções]"
    puts ""
    puts "Exemplos:"
    puts "  #{$0} -t 127.0.0.1 -p 22,80,443"
    puts "  #{$0} -t scanme.nmap.org -p 1-1000 --speed fast"
    puts "  #{$0} -t 192.168.1.1 --top-ports -o resultado.txt"
    puts ""
    puts "Opções:"
    puts opts
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  puts "Erro: #{e.message}"
  puts "Use --help para ver as opções disponíveis."
  exit 1
end

if options[:ports].empty?
  options[:ports] = FydelisScanner::TOP_PORTS
end

if options[:host].nil? || options[:host].empty?
  puts "Erro: Nenhum alvo especificado."
  puts "Use --help para ver as opções disponíveis."
  exit 1
end

FydelisScanner.new(options).run