require 'socket'
require 'thread'
require 'optparse'
require 'timeout'
require 'resolv'
require_relative 'version'

#Autor do projeto Adiel Santos Fontes

# Cores
GREEN  = "\e[32m"
RED    = "\e[31m"
BLUE   = "\e[34m"
BOLD   = "\e[1m"
RESET  = "\e[0m"
YELLOW = "\e[33m"

# Sinal de interrupção (Ctrl+C)
@interrupted = false
trap("INT") do
  unless @interrupted
    @interrupted = true
    puts "\n#{RED}[!] Interrupção detectada. Aguardando threads finalizarem...#{RESET}"
  end
end

class FydelisScanner
  SERVICE_PORTS = {
    21 => "FTP", 22 => "SSH", 23 => "Telnet", 25 => "SMTP",
    53 => "DNS", 80 => "HTTP", 110 => "POP3", 111 => "RPC",
    135 => "RPC", 139 => "NetBIOS", 143 => "IMAP", 443 => "HTTPS",
    445 => "SMB", 993 => "IMAPS", 995 => "POP3S",
    1433 => "MSSQL", 1521 => "Oracle", 2049 => "NFS",
    3306 => "MySQL", 3389 => "RDP", 5432 => "PostgreSQL",
    5900 => "VNC", 5985 => "WinRM-HTTP", 5986 => "WinRM-HTTPS",
    6379 => "Redis", 8080 => "HTTP-Proxy", 8443 => "HTTPS-Alt",
    27017 => "MongoDB", 9200 => "Elasticsearch"
  }.freeze

  TOP_PORTS = SERVICE_PORTS.keys.sort.freeze

  def initialize(options)
    @host           = options[:host]
    @ports          = options[:ports] || TOP_PORTS
    @threads        = options[:threads] || 50
    @connect_timeout = options[:timeout] || 0.3
    @banner_timeout = 0.5
    @verbose        = options[:verbose] || false
    @closed         = []
    @mutex          = Mutex.new
    @output_file    = options[:output] ? File.open(options[:output], 'w') : nil
    @total_ports    = @ports.size
    @scanned        = 0

    # Aplica perfil de velocidade se definido
    case options[:speed]
    when "insane"  then @threads = 500; @connect_timeout = 0.1
    when "fast"    then @threads = 100; @connect_timeout = 0.3
    when "normal"  then @threads = 50;  @connect_timeout = 1.0
    when "polite"  then @threads = 10;  @connect_timeout = 3.0
    end

    # Resolve DNS uma única vez
    begin
      @ip = Resolv.getaddress(@host)
    rescue Resolv::ResolvError => e
      safe_puts "#{RED}[!] Erro ao resolver hostname: #{e.message}#{RESET}"
      exit 1
    end
  end

  def run
    safe_puts "#{YELLOW}#{BOLD}=== FYDELIS SECURITY SCANNER v#{Fydelis::VERSION} ===#{RESET}"
    safe_puts "[*] Alvo: #{@host} (#{@ip})"
    safe_puts "[*] Portas: #{@ports.size} (#{@ports.first}-#{@ports.last})"
    safe_puts "[*] Threads: #{@threads} | Timeout: #{@connect_timeout}s"
    safe_puts ""

    queue = Queue.new
    @ports.each { |p| queue << p }

    start_time = Time.now

    workers = Array.new(@threads) do
      Thread.new do
        loop do
          break if @interrupted
          port = queue.pop(true) rescue break
          scan_port(port)
        end
      end
    end

    workers.each(&:join)


    @output_file.close if @output_file

    safe_puts ""
    safe_puts "#{BLUE}[*] Escaneamento finalizado para #{@host}#{RESET}"
    safe_puts "#{RED}[-] #{@closed.size} portas fechadas#{RESET}" if @closed.any?
    safe_puts "#{GREEN}[+] #{@ports.size - @closed.size} portas abertas#{RESET}" if @closed.size < @ports.size
    safe_puts "#{BLUE}[*] Concluído em #{(Time.now - start_time).round(2)}s.#{RESET}"
  end

  private

  def scan_port(port)
    @mutex.synchronize { @scanned += 1 }

    Socket.tcp(@ip, port, connect_timeout: @connect_timeout) do |socket|
      banner = grab_banner(socket)
      service = SERVICE_PORTS[port] || "Desconhecido"
      msg = "#{GREEN}[+] Porta #{port.to_s.ljust(6)} | #{service.ljust(14)} | #{banner}#{RESET}"
      safe_puts msg
    end
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
    @mutex.synchronize { @closed << port }
    if @verbose
      safe_puts "#{RED}[-] Porta #{port.to_s.ljust(6)} | FECHADA#{RESET}"
    end
  rescue => e
    safe_puts "#{RED}[!] Erro na porta #{port}: #{e.message}#{RESET}"
  end

  def grab_banner(socket)
    if IO.select([socket], nil, nil, @banner_timeout)
      banner = socket.recv(1024)&.strip
      return banner.nil? || banner.empty? ? "Sem banner" : banner.gsub(/[^[:print:]]/, '')
    end
    "N/A"
  rescue
    "N/A"
  end

  def safe_puts(msg)
    @mutex.synchronize do
      puts msg
      # Verifica se o arquivo existe e se ele está aberto antes de escrever
      if @output_file && !@output_file.closed?
        @output_file.puts(msg.gsub(/\e\[\d+m/, ''))
      end
    end
  end
end