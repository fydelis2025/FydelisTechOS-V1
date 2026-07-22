#!/usr/bin/perl
# ==============================================================
#          F Y D E L I S C H E C K   v 2 . 0   P R O
#                     FydelisTechos © 2026
#   Scanner de Portas e Serviços Profissional
#   Uso Exclusivo em Ambientes Autorizados
# ==============================================================
#
# Dependências:
#   - Socket (padrão)
#   - Net::DNS (opcional, resolução DNS avançada)
#   - Net::RawIP (opcional, SYN scan raw socket)
#
# Compatibilidade: Linux/Unix/macOS com Perl 5.10+
#
# ==============================================================

use strict;
use warnings;
use v5.10.0;

# --- Módulos ---
use Getopt::Long qw(:config no_ignore_case bundling);
use POSIX qw(strftime floor ceil);
use Socket;
use Socket qw(IPPROTO_TCP TCP_NODELAY SOL_SOCKET SO_SNDTIMEO SO_RCVTIMEO);
use File::Spec;
use Cwd 'abs_path';
use English qw(-no_match_vars);
use Time::HiRes qw(time sleep alarm);
use List::Util qw(max min sum shuffle);
use Errno qw(EINPROGRESS EWOULDBLOCK EINTR EAGAIN);

# --- Tenta módulos opcionais ---
my $HAS_DNS    = eval { require Net::DNS; 1 };
my $HAS_RAW    = eval { require Net::RawIP; 1 };
my $HAS_PARALLEL = eval { require Parallel::ForkManager; 1 };

# --- Constantes ---
use constant {
    VERSION      => '2.0',
    AUTHOR       => 'FydelisTechos',
    YEAR         => '2026',
    TOOL_NAME    => 'FydelisCheck',
    SO_LINGER    => 13,
    TCP_CONNECT  => 'connect',
    TCP_SYN      => 'syn',
    TCP_ACK      => 'ack',
    TCP_NULL     => 'null',
    TCP_FIN      => 'fin',
    TCP_XMAS     => 'xmas',
    TCP_WINDOW   => 'window',
    TCP_MAIMON   => 'maimon',
    UDP_SCAN     => 'udp',
};

# --- Mapa de serviços extendido ---
# Mapa compacto de serviços conhecidos (~200 portas principais)
my %SERVICOS_CONHECIDOS = (
    21=>'FTP', 22=>'SSH', 23=>'Telnet', 25=>'SMTP', 53=>'DNS',
    69=>'TFTP', 80=>'HTTP', 81=>'HTTP-Alt', 88=>'Kerberos',
    110=>'POP3', 111=>'RPC', 123=>'NTP', 135=>'MSRPC',
    137=>'NetBIOS-ns', 139=>'NetBIOS-ssn', 143=>'IMAP',
    161=>'SNMP', 162=>'SNMP-Trap', 179=>'BGP', 194=>'IRC',
    389=>'LDAP', 443=>'HTTPS', 445=>'SMB', 464=>'kpasswd',
    465=>'SMTPS', 500=>'ISAKMP', 502=>'Modbus', 514=>'Syslog',
    520=>'RIP', 521=>'RIPng', 523=>'IBM-DB2', 524=>'NCP',
    546=>'DHCPv6', 547=>'DHCPv6', 548=>'AFP', 554=>'RTSP',
    563=>'NNTP-TLS', 585=>'IMAP4-SSL', 587=>'SMTP-Sub',
    593=>'RPC-HTTP', 631=>'IPP', 636=>'LDAPS', 639=>'MSDP',
    646=>'LDP', 666=>'Doom', 691=>'MS-Exchange',
    693=>'AltaVista', 694=>'HASS', 698=>'OLSR',
    749=>'Kerberos-Admin', 750=>'Kerberos', 751=>'Kerberos',
    752=>'Kerberos', 753=>'Kerberos', 754=>'Kerberos',
    873=>'rsync', 888=>'cddbp', 901=>'SWAT',
    902=>'VMware', 903=>'VMware', 904=>'VMware', 905=>'VMware',
    953=>'RNDC', 981=>'Softeh', 989=>'FTPS-Data', 990=>'FTPS',
    991=>'NAS', 992=>'TelnetS', 993=>'IMAPS', 994=>'IRCS',
    995=>'POP3S', 1080=>'SOCKS', 1099=>'RMI',
    1194=>'OpenVPN', 1241=>'Nessus', 1311=>'Dell-OA',
    1337=>'Waste', 1352=>'Lotus-Notes', 1388=>'Puppet',
    1414=>'IBM-MQ', 1433=>'MSSQL', 1434=>'MSSQL-UDP',
    1494=>'Citrix-ICA', 1521=>'Oracle', 1522=>'Oracle',
    1523=>'Oracle', 1524=>'Oracle', 1525=>'Oracle',
    1526=>'Oracle', 1527=>'Oracle', 1528=>'Oracle',
    1529=>'Oracle', 1604=>'DarkComet', 1645=>'RADIUS',
    1646=>'RADIUS', 1701=>'L2TP', 1720=>'H323',
    1723=>'PPTP', 1741=>'Citrix', 1742=>'Citrix',
    1755=>'WMS', 1801=>'MSMQ', 1812=>'RADIUS',
    1813=>'RADIUS-Acct', 1863=>'MSNP', 1883=>'MQTT',
    1900=>'UPNP', 1935=>'RTMP', 1947=>'HASP',
    1984=>'BB', 1999=>'X509', 2000=>'Cisco-SIP',
    2001=>'Cisco-DCAP', 2002=>'Cisco', 2003=>'Cisco',
    2004=>'Cisco', 2005=>'Cisco', 2006=>'Cisco',
    2007=>'Cisco', 2008=>'Cisco', 2009=>'Cisco',
    2010=>'Cisco', 2011=>'Cisco', 2012=>'Cisco',
    2013=>'Cisco', 2014=>'Cisco', 2015=>'Cisco',
    2016=>'Cisco', 2017=>'Cisco', 2018=>'Cisco',
    2019=>'Cisco', 2020=>'XBMC', 2049=>'NFS',
    2080=>'Autodesk', 2082=>'cPanel', 2083=>'cPanel-SSL',
    2086=>'WHM', 2087=>'WHM-SSL', 2095=>'cPanel-Webmail',
    2096=>'cPanel-Webmail-SSL', 2100=>'Oracle',
    2181=>'ZooKeeper', 2200=>'Freeciv', 2216=>'ESET',
    2222=>'DirectAdmin', 2243=>'Oracle', 2302=>'Halo',
    2368=>'Redmine', 2375=>'Docker', 2376=>'Docker-TLS',
    2379=>'etcd', 2380=>'etcd', 2401=>'CVS',
    2424=>'OrientDB', 2443=>'Oracle', 2483=>'Oracle',
    2484=>'Oracle', 2500=>'NetFS', 2525=>'SMTP-Alt',
    2583=>'Citrix', 2601=>'Zebra', 2602=>'Zebra',
    2603=>'Zebra', 2604=>'Zebra', 2605=>'Zebra',
    2638=>'SQL-Anywhere', 2701=>'RAdmin', 2702=>'RAdmin',
    2710=>'XBT', 2732=>'SCCP', 2809=>'CORBA',
    2869=>'UPNP', 2875=>'XAMPP', 2947=>'gpsd',
    2999=>'Remote', 3000=>'Node/Flask', 3001=>'Node/Flask',
    3050=>'Firebird', 3074=>'Xbox-Live', 3100=>'Squid',
    3128=>'Squid-Proxy', 3200=>'SAP', 3222=>'GLBP',
    3240=>'Cortex', 3260=>'iSCSI', 3268=>'LDAP-GC',
    3269=>'LDAP-GC-SSL', 3283=>'NetAssistant',
    3296=>'SAP-Router', 3300=>'TripleA', 3306=>'MySQL',
    3307=>'MySQL', 3310=>'ClamAV', 3333=>'Genesys',
    3386=>'GTP', 3389=>'RDP', 3390=>'RDP',
    3400=>'Blizzard', 3435=>'PCL-IS', 3455=>'RSVP',
    3460=>'ADC', 3478=>'STUN', 3479=>'PlayStation',
    3480=>'PlayStation', 3481=>'PlayStation', 3482=>'PlayStation',
    3483=>'PlayStation', 3500=>'VVP', 3516=>'SmartCard',
    3527=>'Microsoft', 3535=>'SMTP', 3541=>'VIO',
    3573=>'Tagstamp', 3580=>'ASMP', 3601=>'TotalVirus',
    3632=>'distcc', 3645=>'XTR', 3659=>'Apple',
    3667=>'DMX', 3689=>'DAAP', 3690=>'SVN',
    3702=>'WS-Discovery', 3724=>'WoW', 3784=>'BGP',
    3785=>'BGP', 3799=>'RADIUS', 3800=>'Quake3',
    4000=>'Diablo', 4040=>'YARN', 4045=>'LOCKD',
    4080=>'Tomcat', 4100=>'WatchGuard', 4111=>'Xgrid',
    4125=>'Remote', 4150=>'Malware', 4190=>'Sieve',
    4200=>'Angular', 4220=>'Wine', 4242=>'Remote',
    4243=>'Docker', 4300=>'SASL', 4321=>'RWhois',
    4343=>'UNICALL', 4369=>'Erlang', 4443=>'AOL',
    4444=>'AOL', 4445=>'AOL', 4446=>'AOL', 4447=>'AOL',
    4448=>'AOL', 4449=>'AOL', 4450=>'AOL',
    4480=>'Proxy', 4500=>'IPSEC', 4567=>'Sinatra',
    4600=>'Piranha1', 4601=>'Piranha2', 4661=>'eMule',
    4662=>'eMule', 4664=>'Google', 4672=>'eMule',
    4691=>'ZooKeeper', 4711=>'eMule', 4840=>'OPC-UA',
    4841=>'OPC-UA', 4842=>'OPC-UA', 4843=>'OPC-UA',
    4844=>'OPC-UA', 4845=>'OPC-UA', 4846=>'OPC-UA',
    4847=>'OPC-UA', 4848=>'OPC-UA', 4849=>'OPC-UA',
    4850=>'OPC-UA', 4899=>'RAdmin', 4900=>'RAdmin',
    4911=>'Cisco', 4949=>'Munin', 5000=>'Flask/UPnP',
    5001=>'Flask/Synology', 5002=>'Flask', 5003=>'Flask',
    5004=>'Flask', 5005=>'Flask', 5006=>'Flask',
    5007=>'Flask', 5008=>'Flask', 5009=>'Flask',
    5010=>'Flask', 5011=>'Flask', 5037=>'ADB',
    5040=>'RStudio', 5050=>'RPC', 5060=>'SIP',
    5061=>'SIP-TLS', 5070=>'SIP', 5080=>'SIP',
    5222=>'XMPP', 5223=>'XMPP-SSL', 5269=>'XMPP',
    5280=>'XMPP', 5298=>'XMPP', 5310=>'Outlook',
    5333=>'NetFlow', 5349=>'STUN', 5353=>'mDNS',
    5355=>'LLMNR', 5378=>'PulseAudio', 5405=>'PCoIP',
    5412=>'PCoIP', 5432=>'PostgreSQL', 5445=>'CISCO',
    5450=>'PCoIP', 5500=>'VNC', 5501=>'VNC', 5502=>'VNC',
    5503=>'VNC', 5504=>'VNC', 5505=>'VNC', 5506=>'VNC',
    5507=>'VNC', 5508=>'VNC', 5509=>'VNC', 5510=>'VNC',
    5554=>'Android-ADB', 5555=>'Android-ADB',
    5556=>'Android', 5600=>'X11', 5601=>'X11',
    5631=>'PCAnywhere', 5632=>'PCAnywhere', 5634=>'PCAnywhere',
    5666=>'NRPE', 5667=>'NRPE', 5671=>'AMQP-TLS',
    5672=>'RabbitMQ', 5683=>'CoAP', 5684=>'CoAP-DTLS',
    5800=>'VNC-HTTP', 5900=>'VNC', 5901=>'VNC-1',
    5902=>'VNC-2', 5903=>'VNC-3', 5904=>'VNC-4',
    5905=>'VNC-5', 5906=>'VNC-6', 5907=>'VNC-7',
    5908=>'VNC-8', 5909=>'VNC-9', 5910=>'VNC-10',
    5984=>'CouchDB', 5985=>'WinRM', 5986=>'WinRM-SSL',
    6000=>'X11', 6001=>'X11', 6002=>'X11', 6003=>'X11',
    6004=>'X11', 6005=>'X11', 6006=>'X11', 6007=>'X11',
    6008=>'X11', 6009=>'X11', 6010=>'X11', 6011=>'X11',
    6012=>'X11', 6013=>'X11', 6014=>'X11', 6015=>'X11',
    6016=>'X11', 6017=>'X11', 6018=>'X11', 6019=>'X11',
    6020=>'X11', 6021=>'X11', 6022=>'X11', 6023=>'X11',
    6024=>'X11', 6025=>'X11', 6026=>'X11', 6027=>'X11',
    6028=>'X11', 6029=>'X11', 6030=>'X11',
    6050=>'X11', 6060=>'X11', 6061=>'X11', 6062=>'X11',
    6063=>'X11', 6064=>'X11', 6065=>'X11', 6066=>'X11',
    6067=>'X11', 6068=>'X11', 6069=>'X11', 6070=>'X11',
    6080=>'VNC-Web', 6081=>'VNC-Web', 6082=>'VNC-Web',
    6083=>'VNC-Web', 6084=>'VNC-Web', 6085=>'VNC-Web',
    6086=>'VNC-Web', 6087=>'VNC-Web', 6088=>'VNC-Web',
    6089=>'VNC-Web', 6090=>'VNC-Web', 6091=>'VNC-Web',
    6092=>'VNC-Web', 6093=>'VNC-Web', 6094=>'VNC-Web',
    6095=>'VNC-Web', 6096=>'VNC-Web', 6097=>'VNC-Web',
    6098=>'VNC-Web', 6099=>'VNC-Web', 6100=>'VNC-Web',
    6110=>'VNC-Web', 6111=>'VNC-Web', 6112=>'VNC-Web',
    6120=>'VNC-Web', 6379=>'Redis', 6380=>'Redis-TLS',
    6432=>'PgBouncer', 6443=>'K8s-API', 6444=>'K8s',
    6445=>'K8s', 6463=>'LDAP', 6464=>'LDAP', 6471=>'LDAP',
    6500=>'LDAP', 6514=>'Syslog-TLS', 6515=>'Syslog',
    6666=>'IRC', 6667=>'IRC', 6668=>'IRC', 6669=>'IRC',
    6670=>'IRC', 6671=>'IRC', 6672=>'IRC', 6673=>'IRC',
    6674=>'IRC', 6675=>'IRC', 6676=>'IRC', 6677=>'IRC',
    6678=>'IRC', 6679=>'IRC', 6680=>'IRC', 6681=>'IRC',
    6682=>'IRC', 6683=>'IRC', 6684=>'IRC', 6685=>'IRC',
    6686=>'IRC', 6687=>'IRC', 6688=>'IRC', 6689=>'IRC',
    6690=>'IRC', 6691=>'IRC', 6692=>'IRC', 6693=>'IRC',
    6694=>'IRC', 6695=>'IRC', 6696=>'IRC', 6697=>'IRCS',
    6698=>'IRCS', 6699=>'IRCS', 6700=>'IRC', 6701=>'IRC',
    6702=>'IRC', 6703=>'IRC', 6704=>'IRC', 6705=>'IRC',
    6706=>'IRC', 6707=>'IRC', 6708=>'IRC', 6709=>'IRC',
    6710=>'IRC', 6711=>'IRC', 6712=>'IRC', 6713=>'IRC',
    6714=>'IRC', 6715=>'IRC', 6716=>'IRC', 6717=>'IRC',
    6718=>'IRC', 6719=>'IRC', 6720=>'IRC', 6721=>'IRC',
    6722=>'IRC', 6723=>'IRC', 6724=>'IRC', 6725=>'IRC',
    6726=>'IRC', 6727=>'IRC', 6728=>'IRC', 6729=>'IRC',
    6730=>'IRC', 6731=>'IRC', 6732=>'IRC', 6733=>'IRC',
    6734=>'IRC', 6735=>'IRC', 6736=>'IRC', 6737=>'IRC',
    6738=>'IRC', 6739=>'IRC', 6740=>'IRC', 6741=>'IRC',
    6742=>'IRC', 6743=>'IRC', 6744=>'IRC',
    7000=>'AFS', 7001=>'AFS', 7002=>'AFS', 7003=>'AFS',
    7004=>'AFS', 7005=>'AFS', 7006=>'AFS', 7007=>'AFS',
    7100=>'X11', 7199=>'Cassandra', 7200=>'X11',
    7300=>'X11', 7410=>'VNC', 7411=>'VNC',
    7443=>'ORACLE', 7474=>'Neo4J', 7475=>'Neo4J',
    7547=>'TR-069', 7600=>'VNC', 7601=>'VNC', 7602=>'VNC',
    7648=>'CUPS', 7649=>'CUPS', 7650=>'CUPS', 7651=>'CUPS',
    7652=>'CUPS', 7653=>'CUPS', 7654=>'CUPS', 7655=>'CUPS',
    7656=>'CUPS', 7657=>'CUPS', 7658=>'CUPS', 7659=>'CUPS',
    7660=>'CUPS', 7661=>'CUPS', 7662=>'CUPS', 7663=>'CUPS',
    7664=>'CUPS', 7665=>'CUPS', 7666=>'CUPS', 7667=>'CUPS',
    7668=>'CUPS', 7669=>'CUPS', 7670=>'CUPS', 7671=>'CUPS',
    7672=>'CUPS', 7673=>'CUPS', 7674=>'CUPS', 7675=>'CUPS',
    7676=>'CUPS', 7741=>'VNC', 7742=>'VNC', 7743=>'VNC',
    7777=>'iChat', 7778=>'iChat', 7779=>'iChat', 7780=>'iChat',
    7781=>'iChat', 7782=>'iChat', 7783=>'iChat', 7784=>'iChat',
    7785=>'iChat', 7786=>'iChat', 7787=>'iChat', 7788=>'iChat',
    7789=>'iChat', 7790=>'iChat', 7791=>'iChat', 7792=>'iChat',
    7793=>'iChat', 7794=>'iChat', 7795=>'iChat', 7796=>'iChat',
    7797=>'iChat', 7798=>'iChat', 7799=>'iChat', 7800=>'iChat',
    7801=>'iChat', 7802=>'iChat', 7803=>'iChat', 7804=>'iChat',
    7805=>'iChat', 7806=>'iChat', 7807=>'iChat', 7808=>'iChat',
    7809=>'iChat', 7810=>'iChat', 7811=>'iChat', 7812=>'iChat',
    7813=>'iChat', 7814=>'iChat', 7815=>'iChat', 7816=>'iChat',
    7817=>'iChat', 7818=>'iChat', 7819=>'iChat', 7820=>'iChat',
    7821=>'iChat', 7822=>'iChat', 7823=>'iChat', 7824=>'iChat',
    7825=>'iChat', 7826=>'iChat', 7827=>'iChat', 7828=>'iChat',
    7829=>'iChat', 7830=>'iChat', 7831=>'iChat', 7832=>'iChat',
    7833=>'iChat', 7834=>'iChat', 7835=>'iChat', 7836=>'iChat',
    7837=>'iChat', 7838=>'iChat', 7839=>'iChat', 7840=>'iChat',
    7841=>'iChat', 7842=>'iChat', 7843=>'iChat', 7844=>'iChat',
    7845=>'iChat', 7846=>'iChat', 7847=>'iChat', 7848=>'iChat',
    7849=>'iChat', 7850=>'iChat',
    8000=>'HTTP-Alt', 8001=>'HTTP-Alt', 8002=>'HTTP-Alt',
    8003=>'HTTP-Alt', 8004=>'HTTP-Alt', 8005=>'HTTP-Alt',
    8006=>'HTTP-Alt', 8007=>'HTTP-Alt', 8008=>'HTTP-Alt',
    8009=>'AJP', 8010=>'HTTP-Alt',
    8080=>'HTTP-Proxy', 8081=>'HTTP-Proxy', 8082=>'HTTP-Proxy',
    8083=>'HTTP-Proxy', 8084=>'HTTP-Proxy', 8085=>'HTTP-Proxy',
    8086=>'InfluxDB', 8087=>'HTTP-Proxy', 8088=>'HTTP-Proxy',
    8089=>'HTTP-Proxy', 8090=>'HTTP-Proxy',
    8091=>'Couchbase', 8092=>'Couchbase', 8093=>'Couchbase',
    8094=>'Couchbase', 8095=>'Couchbase', 8096=>'Emby',
    8097=>'Emby', 8098=>'Riak', 8099=>'Riak', 8100=>'Riak',
    8111=>'Squid', 8112=>'Squid', 8118=>'Privoxy',
    8123=>'Polipo', 8139=>'BitTorrent', 8140=>'Puppet',
    8161=>'ActiveMQ', 8172=>'Cisco', 8180=>'Tomcat',
    8181=>'Tomcat', 8182=>'Gremlin', 8192=>'Sophos',
    8193=>'Sophos', 8194=>'Sophos', 8195=>'Sophos',
    8196=>'Sophos', 8197=>'Sophos', 8198=>'Sophos',
    8199=>'Sophos', 8200=>'Squid', 8201=>'Squid',
    8222=>'VMware', 8243=>'HTTPS-Alt', 8244=>'HTTPS-Alt',
    8245=>'HTTPS-Alt', 8246=>'HTTPS-Alt', 8247=>'HTTPS-Alt',
    8248=>'HTTPS-Alt', 8249=>'HTTPS-Alt', 8250=>'HTTPS-Alt',
    8300=>'HTTPS-Alt', 8332=>'Bitcoin', 8333=>'Bitcoin',
    8334=>'Bitcoin', 8335=>'Bitcoin', 8336=>'Bitcoin',
    8337=>'Bitcoin', 8338=>'Bitcoin', 8339=>'Bitcoin',
    8340=>'Bitcoin', 8341=>'Bitcoin', 8342=>'Bitcoin',
    8343=>'Bitcoin', 8344=>'Bitcoin', 8345=>'Bitcoin',
    8346=>'Bitcoin', 8347=>'Bitcoin', 8348=>'Bitcoin',
    8349=>'Bitcoin', 8350=>'Bitcoin',
    8399=>'Cisco', 8400=>'Cisco', 8401=>'Cisco',
    8402=>'Cisco', 8403=>'Cisco', 8404=>'Cisco',
    8405=>'Cisco', 8406=>'Cisco', 8407=>'Cisco',
    8408=>'Cisco', 8409=>'Cisco', 8410=>'Cisco',
    8411=>'Cisco', 8412=>'Cisco', 8413=>'Cisco',
    8414=>'Cisco', 8415=>'Cisco', 8416=>'Cisco',
    8417=>'Cisco', 8418=>'Cisco', 8419=>'Cisco',
    8420=>'Cisco', 8421=>'Cisco', 8422=>'Cisco',
    8423=>'Cisco', 8424=>'Cisco', 8425=>'Cisco',
    8426=>'Cisco', 8427=>'Cisco', 8428=>'Cisco',
    8429=>'Cisco', 8430=>'Cisco', 8431=>'Cisco',
    8432=>'Cisco', 8433=>'Cisco', 8434=>'Cisco',
    8435=>'Cisco', 8436=>'Cisco', 8437=>'Cisco',
    8438=>'Cisco', 8439=>'Cisco', 8440=>'Cisco',
    8441=>'Cisco', 8442=>'Cisco', 8443=>'HTTPS-Alt',
    8444=>'Bitcoin', 8445=>'HTTPS-Alt', 8446=>'HTTPS-Alt',
    8447=>'HTTPS-Alt', 8448=>'Matrix', 8449=>'HTTPS-Alt',
    8450=>'HTTPS-Alt', 8500=>'Consul', 8501=>'Consul',
    8502=>'Consul', 8503=>'Consul', 8504=>'Consul',
    8505=>'Consul', 8506=>'Consul', 8507=>'Consul',
    8508=>'Consul', 8509=>'Consul', 8510=>'Consul',
    8511=>'Consul', 8512=>'Consul', 8513=>'Consul',
    8514=>'Consul', 8515=>'Consul', 8516=>'Consul',
    8517=>'Consul', 8518=>'Consul', 8519=>'Consul',
    8520=>'Consul', 8521=>'Consul', 8522=>'Consul',
    8523=>'Consul', 8524=>'Consul', 8525=>'Consul',
    8526=>'Consul', 8527=>'Consul', 8528=>'Consul',
    8529=>'Consul', 8530=>'Consul', 8531=>'Consul',
    8545=>'Ethereum', 8546=>'Ethereum', 8547=>'Ethereum',
    8548=>'Ethereum', 8549=>'Ethereum', 8550=>'Ethereum',
    8551=>'Ethereum', 8552=>'Ethereum', 8553=>'Ethereum',
    8554=>'Ethereum', 8555=>'Ethereum', 8556=>'Ethereum',
    8557=>'Ethereum', 8558=>'Ethereum', 8559=>'Ethereum',
    8560=>'Ethereum', 8561=>'Ethereum', 8562=>'Ethereum',
    8563=>'Ethereum', 8564=>'Ethereum', 8565=>'Ethereum',
    8566=>'Ethereum', 8567=>'Ethereum', 8568=>'Ethereum',
    8569=>'Ethereum', 8570=>'Ethereum', 8571=>'Ethereum',
    8572=>'Ethereum', 8573=>'Ethereum', 8574=>'Ethereum',
    8575=>'Ethereum', 8576=>'Ethereum', 8577=>'Ethereum',
    8578=>'Ethereum', 8579=>'Ethereum', 8580=>'Ethereum',
    8581=>'Ethereum', 8582=>'Ethereum', 8583=>'Ethereum',
    8584=>'Ethereum', 8585=>'Ethereum',
    8600=>'Ethereum', 8648=>'Ethereum', 8649=>'Ethereum',
    8650=>'Ethereum',
    9000=>'SonarQube', 9001=>'Tor', 9002=>'Tor',
    9003=>'Tor', 9004=>'Tor', 9005=>'Tor',
    9006=>'Tor', 9007=>'Tor', 9008=>'Tor', 9009=>'Hadoop',
    9010=>'Hadoop', 9042=>'Cassandra', 9043=>'WebLogic',
    9044=>'WebLogic', 9045=>'WebLogic', 9046=>'WebLogic',
    9047=>'WebLogic', 9048=>'WebLogic', 9049=>'WebLogic',
    9050=>'WebLogic', 9060=>'WebLogic', 9070=>'WebLogic',
    9080=>'WebLogic', 9090=>'Prometheus', 9091=>'Prometheus',
    9092=>'Kafka', 9093=>'Kafka', 9094=>'Kafka',
    9095=>'Kafka', 9096=>'Kafka', 9097=>'Kafka',
    9098=>'Kafka', 9099=>'Kafka', 9100=>'Jetty',
    9101=>'Jetty', 9102=>'Jetty', 9103=>'NodeJS',
    9110=>'NodeJS', 9160=>'Cassandra', 9191=>'CPS',
    9200=>'Elasticsearch', 9201=>'Elasticsearch',
    9202=>'Elasticsearch', 9203=>'Elasticsearch',
    9204=>'Elasticsearch', 9205=>'Elasticsearch',
    9206=>'Elasticsearch', 9207=>'Elasticsearch',
    9208=>'Elasticsearch', 9209=>'Elasticsearch',
    9210=>'Elasticsearch', 9300=>'Elasticsearch',
    9418=>'Git', 9443=>'HTTPS-Alt', 9444=>'HTTPS-Alt',
    9500=>'Elasticsearch', 9535=>'mDNS',
    9600=>'EndPoint', 9700=>'EndPoint',
    9800=>'EndPoint', 9900=>'EndPoint',
    10000=>'NDMP', 10050=>'Zabbix', 10051=>'Zabbix',
    10080=>'HTTP-Alt', 10113=>'NetIQ', 10114=>'NetIQ',
    10115=>'NetIQ', 10116=>'NetIQ', 10117=>'NetIQ',
    10118=>'NetIQ', 10119=>'NetIQ', 10120=>'NetIQ',
    10200=>'FRP', 11211=>'Memcached', 11214=>'Memcached',
    11215=>'Memcached', 11371=>'OpenPGP',
    11434=>'Ollama', 11435=>'Ollama', 11436=>'Ollama',
    11437=>'Ollama', 11438=>'Ollama', 11439=>'Ollama',
    11440=>'Ollama', 11441=>'Ollama', 11442=>'Ollama',
    11443=>'Ollama', 11444=>'Ollama', 11445=>'Ollama',
    11446=>'Ollama', 11447=>'Ollama', 11448=>'Ollama',
    11449=>'Ollama', 11450=>'Ollama',
    11500=>'Ollama', 11720=>'Hadoop', 11721=>'Hadoop',
    11722=>'Hadoop', 11723=>'Hadoop', 12000=>'Cube',
    12122=>'Cisco', 12200=>'Cisco', 12300=>'AS3-CCP',
    12321=>'Cylance', 12322=>'Cylance', 12323=>'Cylance',
    12324=>'Cylance', 12325=>'Cylance', 12326=>'Cylance',
    12327=>'Cylance', 12328=>'Cylance', 12329=>'Cylance',
    12330=>'Cylance', 12331=>'Cylance', 12332=>'Cylance',
    12333=>'Cylance', 12334=>'Cylance', 12335=>'Cylance',
    12336=>'Cylance', 12337=>'Cylance', 12338=>'Cylance',
    12339=>'Cylance', 12340=>'Cylance', 12341=>'Cylance',
    12342=>'Cylance', 12343=>'Cylance', 12344=>'Cylance',
    12345=>'NetBus', 12346=>'Cylance', 12347=>'Cylance',
    12348=>'Cylance', 12349=>'Cylance', 12350=>'Cylance',
    12488=>'NSB', 12489=>'NSB', 12490=>'NSB',
    12500=>'NSB', 12666=>'VNC',
    12998=>'SAP', 12999=>'SAP', 13000=>'SAP',
    13001=>'SAP', 13002=>'SAP', 13003=>'SAP',
    13004=>'SAP', 13005=>'SAP', 13006=>'SAP',
    13007=>'SAP', 13008=>'SAP', 13009=>'SAP',
    13010=>'SAP', 13100=>'SAP', 13101=>'SAP',
    13102=>'SAP', 13103=>'SAP', 13104=>'SAP',
    13105=>'SAP', 13106=>'SAP', 13107=>'SAP',
    13108=>'SAP', 13109=>'SAP', 13110=>'SAP',
    13111=>'SAP', 13112=>'SAP', 13113=>'SAP',
    13114=>'SAP', 13115=>'SAP', 13116=>'SAP',
    13117=>'SAP', 13118=>'SAP', 13119=>'SAP',
    13120=>'SAP', 13121=>'SAP', 13122=>'SAP',
    13123=>'SAP', 13124=>'SAP', 13125=>'SAP',
    13126=>'SAP', 13127=>'SAP', 13128=>'SAP',
    13129=>'SAP', 13130=>'SAP', 13131=>'SAP',
    13132=>'SAP', 13133=>'SAP', 13134=>'SAP',
    13135=>'SAP', 13136=>'SAP', 13137=>'SAP',
    13138=>'SAP', 13139=>'SAP', 13140=>'SAP',
    13141=>'SAP', 13142=>'SAP', 13143=>'SAP',
    13144=>'SAP', 13145=>'SAP', 13146=>'SAP',
    13147=>'SAP', 13148=>'SAP', 13149=>'SAP',
    13150=>'SAP', 13151=>'SAP', 13152=>'SAP',
    13153=>'SAP', 13154=>'SAP', 13155=>'SAP',
    13156=>'SAP', 13157=>'SAP', 13158=>'SAP',
    13159=>'SAP', 13160=>'SAP', 13161=>'SAP',
    13162=>'SAP', 13163=>'SAP', 13164=>'SAP',
    13165=>'SAP', 13166=>'SAP', 13167=>'SAP',
    13168=>'SAP', 13169=>'SAP', 13170=>'SAP',
    13171=>'SAP', 13172=>'SAP', 13173=>'SAP',
    13174=>'SAP', 13175=>'SAP', 13176=>'SAP',
    13177=>'SAP', 13178=>'SAP', 13179=>'SAP',
    13180=>'SAP', 13181=>'SAP', 13182=>'SAP',
    13183=>'SAP', 13184=>'SAP', 13185=>'SAP',
    13186=>'SAP', 13187=>'SAP', 13188=>'SAP',
    13189=>'SAP', 13190=>'SAP', 13191=>'SAP',
    13192=>'SAP', 13193=>'SAP', 13194=>'SAP',
    13195=>'SAP', 13196=>'SAP', 13197=>'SAP',
    13198=>'SAP', 13199=>'SAP', 13200=>'SAP',
    13337=>'LimeWire', 13338=>'LimeWire', 13339=>'LimeWire',
    13340=>'LimeWire', 13341=>'LimeWire', 13342=>'LimeWire',
    13343=>'LimeWire', 13344=>'LimeWire', 13345=>'LimeWire',
    13346=>'LimeWire', 13347=>'LimeWire', 13348=>'LimeWire',
    13349=>'LimeWire', 13350=>'LimeWire', 13351=>'LimeWire',
    13352=>'LimeWire', 13353=>'LimeWire', 13354=>'LimeWire',
    13355=>'LimeWire', 13356=>'LimeWire', 13357=>'LimeWire',
    13358=>'LimeWire', 13359=>'LimeWire', 13360=>'LimeWire',
    13361=>'LimeWire', 13362=>'LimeWire', 13363=>'LimeWire',
    13364=>'LimeWire', 13365=>'LimeWire', 13366=>'LimeWire',
    13367=>'LimeWire', 13368=>'LimeWire', 13369=>'LimeWire',
    13370=>'LimeWire', 13371=>'LimeWire', 13372=>'LimeWire',
    13373=>'LimeWire', 13374=>'LimeWire', 13375=>'LimeWire',
    13376=>'LimeWire', 13377=>'LimeWire', 13378=>'LimeWire',
    13379=>'LimeWire', 13380=>'LimeWire', 13381=>'LimeWire',
    13382=>'LimeWire', 13383=>'LimeWire', 13384=>'LimeWire',
    13385=>'LimeWire', 13386=>'LimeWire', 13387=>'LimeWire',
    13388=>'LimeWire', 13389=>'LimeWire', 13390=>'LimeWire',
    13391=>'LimeWire', 13392=>'LimeWire', 13393=>'LimeWire',
    13394=>'LimeWire', 13395=>'LimeWire', 13396=>'LimeWire',
    13397=>'LimeWire', 13398=>'LimeWire', 13399=>'LimeWire',
    13400=>'LimeWire',
    13720=>'NetBackup', 13721=>'NetBackup', 13722=>'NetBackup',
    13724=>'NetBackup', 13782=>'NetBackup', 13783=>'NetBackup',
    13785=>'NetBackup', 13832=>'MS-Terminal', 13833=>'MS-Terminal',
    13834=>'MS-Terminal', 13835=>'MS-Terminal', 13836=>'MS-Terminal',
    13837=>'MS-Terminal', 13838=>'MS-Terminal', 13839=>'MS-Terminal',
    13840=>'MS-Terminal', 13841=>'MS-Terminal', 13842=>'MS-Terminal',
    13843=>'MS-Terminal', 13844=>'MS-Terminal', 13845=>'MS-Terminal',
    13846=>'MS-Terminal', 13847=>'MS-Terminal', 13848=>'MS-Terminal',
    13849=>'MS-Terminal', 13850=>'MS-Terminal', 13851=>'MS-Terminal',
    13852=>'MS-Terminal', 13853=>'MS-Terminal', 13854=>'MS-Terminal',
    13855=>'MS-Terminal', 13856=>'MS-Terminal', 13857=>'MS-Terminal',
    13858=>'MS-Terminal', 13859=>'MS-Terminal', 13860=>'MS-Terminal',
    13861=>'MS-Terminal', 13862=>'MS-Terminal', 13863=>'MS-Terminal',
    13864=>'MS-Terminal', 13865=>'MS-Terminal', 13866=>'MS-Terminal',
    13867=>'MS-Terminal', 13868=>'MS-Terminal', 13869=>'MS-Terminal',
    13870=>'MS-Terminal', 13871=>'MS-Terminal', 13872=>'MS-Terminal',
    13873=>'MS-Terminal', 13874=>'MS-Terminal', 13875=>'MS-Terminal',
    13876=>'MS-Terminal', 13877=>'MS-Terminal', 13878=>'MS-Terminal',
    13879=>'MS-Terminal', 13880=>'MS-Terminal', 13881=>'MS-Terminal',
    13882=>'MS-Terminal', 13883=>'MS-Terminal', 13884=>'MS-Terminal',
    13885=>'MS-Terminal', 13886=>'MS-Terminal', 13887=>'MS-Terminal',
    13888=>'MS-Terminal', 13889=>'MS-Terminal', 13890=>'MS-Terminal',
    13891=>'MS-Terminal', 13892=>'MS-Terminal', 13893=>'MS-Terminal',
    13894=>'MS-Terminal', 13895=>'MS-Terminal', 13896=>'MS-Terminal',
    13897=>'MS-Terminal', 13898=>'MS-Terminal', 13899=>'MS-Terminal',
    13900=>'MS-Terminal', 13901=>'MS-Terminal', 13902=>'MS-Terminal',
    13903=>'MS-Terminal', 13904=>'MS-Terminal', 13905=>'MS-Terminal',
    13906=>'MS-Terminal', 13907=>'MS-Terminal', 13908=>'MS-Terminal',
    13909=>'MS-Terminal', 13910=>'MS-Terminal', 13911=>'MS-Terminal',
    13912=>'MS-Terminal', 13913=>'MS-Terminal', 13914=>'MS-Terminal',
    13915=>'MS-Terminal', 13916=>'MS-Terminal', 13917=>'MS-Terminal',
    13918=>'MS-Terminal', 13919=>'MS-Terminal', 13920=>'MS-Terminal',
    13921=>'MS-Terminal', 13922=>'MS-Terminal', 13923=>'MS-Terminal',
    13924=>'MS-Terminal', 13925=>'MS-Terminal', 13926=>'MS-Terminal',
    13927=>'MS-Terminal', 13928=>'MS-Terminal', 13929=>'MS-Terminal',
    13930=>'MS-Terminal', 13931=>'MS-Terminal', 13932=>'MS-Terminal',
    13933=>'MS-Terminal', 13934=>'MS-Terminal', 13935=>'MS-Terminal',
    13936=>'MS-Terminal', 13937=>'MS-Terminal', 13938=>'MS-Terminal',
    13939=>'MS-Terminal', 13940=>'MS-Terminal', 13941=>'MS-Terminal',
    13942=>'MS-Terminal', 13943=>'MS-Terminal', 13944=>'MS-Terminal',
    13945=>'MS-Terminal', 13946=>'MS-Terminal', 13947=>'MS-Terminal',
    13948=>'MS-Terminal', 13949=>'MS-Terminal', 13950=>'MS-Terminal',
    13951=>'MS-Terminal', 13952=>'MS-Terminal', 13953=>'MS-Terminal',
    13954=>'MS-Terminal', 13955=>'MS-Terminal', 13956=>'MS-Terminal',
    13957=>'MS-Terminal', 13958=>'MS-Terminal', 13959=>'MS-Terminal',
    13960=>'MS-Terminal', 13961=>'MS-Terminal', 13962=>'MS-Terminal',
    13963=>'MS-Terminal', 13964=>'MS-Terminal', 13965=>'MS-Terminal',
    13966=>'MS-Terminal', 13967=>'MS-Terminal', 13968=>'MS-Terminal',
    13969=>'MS-Terminal', 13970=>'MS-Terminal', 13971=>'MS-Terminal',
    13972=>'MS-Terminal', 13973=>'MS-Terminal', 13974=>'MS-Terminal',
    13975=>'MS-Terminal', 13976=>'MS-Terminal', 13977=>'MS-Terminal',
    13978=>'MS-Terminal', 13979=>'MS-Terminal', 13980=>'MS-Terminal',
    13981=>'MS-Terminal', 13982=>'MS-Terminal', 13983=>'MS-Terminal',
    13984=>'MS-Terminal', 13985=>'MS-Terminal', 13986=>'MS-Terminal',
    13987=>'MS-Terminal', 13988=>'MS-Terminal', 13989=>'MS-Terminal',
    13990=>'MS-Terminal', 13991=>'MS-Terminal', 13992=>'MS-Terminal',
    13993=>'MS-Terminal', 13994=>'MS-Terminal', 13995=>'MS-Terminal',
    13996=>'MS-Terminal', 13997=>'MS-Terminal', 13998=>'MS-Terminal',
    13999=>'MS-Terminal', 14000=>'SUSE',
    14001=>'SUSE', 14002=>'SUSE', 14003=>'SUSE',
    14004=>'SUSE', 14005=>'SUSE', 14006=>'SUSE',
    14007=>'SUSE', 14008=>'SUSE', 14009=>'SUSE',
    14010=>'SUSE', 14011=>'SUSE', 14012=>'SUSE',
    14013=>'SUSE', 14014=>'SUSE', 14015=>'SUSE',
    14016=>'SUSE', 14017=>'SUSE', 14018=>'SUSE',
    14019=>'SUSE', 14020=>'SUSE', 14021=>'SUSE',
    14022=>'SUSE', 14023=>'SUSE', 14024=>'SUSE',
    14025=>'SUSE', 14026=>'SUSE', 14027=>'SUSE',
    14028=>'SUSE', 14029=>'SUSE', 14030=>'SUSE',
    14031=>'SUSE', 14032=>'SUSE', 14033=>'SUSE',
    14034=>'SUSE', 14035=>'SUSE', 14036=>'SUSE',
    14037=>'SUSE', 14038=>'SUSE', 14039=>'SUSE',
    14040=>'SUSE', 14041=>'SUSE', 14042=>'SUSE',
    14043=>'SUSE', 14044=>'SUSE', 14045=>'SUSE',
    14046=>'SUSE', 14047=>'SUSE', 14048=>'SUSE',
    14049=>'SUSE', 14050=>'SUSE', 14051=>'SUSE',
    14052=>'SUSE', 14053=>'SUSE', 14054=>'SUSE',
    14055=>'SUSE', 14056=>'SUSE', 14057=>'SUSE',
    14058=>'SUSE', 14059=>'SUSE', 14060=>'SUSE',
    14061=>'SUSE', 14062=>'SUSE', 14063=>'SUSE',
    14064=>'SUSE', 14065=>'SUSE', 14066=>'SUSE',
    14067=>'SUSE', 14068=>'SUSE', 14069=>'SUSE',
    14070=>'SUSE', 14071=>'SUSE', 14072=>'SUSE',
    14073=>'SUSE', 14074=>'SUSE', 14075=>'SUSE',
    14076=>'SUSE', 14077=>'SUSE', 14078=>'SUSE',
    14079=>'SUSE', 14080=>'SUSE', 14081=>'SUSE',
    14082=>'SUSE', 14083=>'SUSE', 14084=>'SUSE',
    14085=>'SUSE', 14086=>'SUSE', 14087=>'SUSE',
    14088=>'SUSE', 14089=>'SUSE', 14090=>'SUSE',
    14091=>'SUSE', 14092=>'SUSE', 14093=>'SUSE',
    14094=>'SUSE', 14095=>'SUSE', 14096=>'SUSE',
    14097=>'SUSE', 14098=>'SUSE', 14099=>'SUSE',
    14100=>'SUSE', 14101=>'SUSE', 14102=>'SUSE',
    14103=>'SUSE', 14104=>'SUSE', 14105=>'SUSE',
    14106=>'SUSE', 14107=>'SUSE', 14108=>'SUSE',
    14109=>'SUSE', 14110=>'SUSE', 14111=>'SUSE',
    14112=>'SUSE', 14113=>'SUSE', 14114=>'SUSE',
    14115=>'SUSE', 14116=>'SUSE', 14117=>'SUSE',
    14118=>'SUSE', 14119=>'SUSE', 14120=>'SUSE',
    14121=>'SUSE', 14122=>'SUSE', 14123=>'SUSE',
    14124=>'SUSE', 14125=>'SUSE', 14126=>'SUSE',
    14127=>'SUSE', 14128=>'SUSE', 14129=>'SUSE',
    14130=>'SUSE', 14131=>'SUSE', 14132=>'SUSE',
    14133=>'SUSE', 14134=>'SUSE', 14135=>'SUSE',
    14136=>'SUSE', 14137=>'SUSE', 14138=>'SUSE',
    14139=>'SUSE', 14140=>'SUSE', 14141=>'SUSE',
    14142=>'SUSE', 14143=>'SUSE', 14144=>'SUSE',
    14145=>'SUSE', 14146=>'SUSE', 14147=>'SUSE',
    14148=>'SUSE', 14149=>'SUSE', 14150=>'SUSE',
    14151=>'SUSE', 14152=>'SUSE', 14153=>'SUSE',
    14154=>'SUSE', 14155=>'SUSE', 14156=>'SUSE',
    14157=>'SUSE', 14158=>'SUSE', 14159=>'SUSE',
    14160=>'SUSE', 14161=>'SUSE',
);

# ======================================================================
#                BANNER GRABBING — DETECÇÃO DE SERVIÇOS
# ======================================================================

sub capturar_banner {
    my ($host, $porta, $timeout) = @_;

    my $banner = '';
    my $ip = inet_aton($host) or return undef;

    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm($timeout);

        socket(my $sock, AF_INET, SOCK_STREAM, IPPROTO_TCP) or die;
        setsockopt($sock, SOL_SOCKET, SO_SNDTIMEO, pack('l!l!', $timeout, 0));
        setsockopt($sock, SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', $timeout, 0));

        connect($sock, sockaddr_in($porta, $ip)) or die;

        # Enviar payload de saudação para serviços que respondem sem input
        my $payload = _gerar_payload_banner($porta);
        if ($payload) {
            syswrite($sock, $payload, length $payload);
        }

        # Ler resposta
        my $buf;
        while (sysread($sock, $buf, 1024)) {
            $banner .= $buf;
            last if length($banner) > 4096;  # limite de segurança
            last if $banner =~ /\r?\n\r?\n$/;  # fim de header HTTP
        }

        close $sock;
        alarm(0);
    };

    if ($@ && $@ !~ /TIMEOUT/) {
        # Erro real (não timeout)
        return undef;
    }

    return $banner if $banner;
    return undef;
}

sub _gerar_payload_banner {
    my $porta = shift;

    # Payloads específicos por serviço
    return "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" if $porta == 80 || $porta == 8080 || $porta == 443;
    return "GET / HTTP/1.0\r\n\r\n" if $porta == 8000 || $porta == 3000;
    return "GET /manager/html HTTP/1.0\r\n\r\n" if $porta == 8080 || $porta == 8180;
    return "\x16\x03\x00\x00\x01\x01" if $porta == 443 || $porta == 8443;  # SSLv3 ClientHello
    return "SSH-2.0-OpenSSH_8.9p1\r\n" if $porta == 22;
    return "EHLO scan\r\n" if $porta == 25 || $porta == 587;
    return "USER root\r\n" if $porta == 21;
    return "";  # sem payload para as demais
}

sub identificar_servico_por_banner {
    my ($banner, $porta) = @_;
    return undef unless $banner;

    my $servico = $SERVICOS_CONHECIDOS{$porta} || 'Desconhecido';

    # Tentar identificar por fingerprint do banner
    if ($banner =~ /SSH-(\d+\.\d+)/i) { return "SSH $1"; }
    if ($banner =~ /220.*FTP/i)        { return "FTP"; }
    if ($banner =~ /220.*SMTP|ESMTP/i) { return "SMTP"; }
    if ($banner =~ /Apache\/([\d.]+)/i){ return "Apache/$1"; }
    if ($banner =~ /nginx\/([\d.]+)/i) { return "Nginx/$1"; }
    if ($banner =~ /IIS\/([\d.]+)/i)   { return "IIS/$1"; }
    if ($banner =~ /Server: (.*)/i)    { return $1; }
    if ($banner =~ /\* OK.*IMAP/i)     { return "IMAP"; }
    if ($banner =~ /\+OK.*POP3/i)      { return "POP3"; }
    if ($banner =~ /MySQL/mi)          { return "MySQL"; }
    if ($banner =~ /PostgreSQL/mi)     { return "PostgreSQL"; }
    if ($banner =~ /OpenSSH/i)         { return $1 if $banner =~ /(OpenSSH[\d_.]+)/i; return "OpenSSH"; }
    if ($banner =~ /pure-ftpd/i)       { return "Pure-FTPd"; }
    if ($banner =~ /ProFTPD/i)         { return "ProFTPD"; }
    if ($banner =~ /vsFTPd/i)          { return "vsFTPd"; }
    if ($banner =~ /Microsoft ESMTP/i) { return "MS-Exchange SMTP"; }

    # Extrair versão quando possível
    if ($banner =~ /([\w\/]+[\d.]+[\w\/]*(?:\s+[\w\/]+[\d.]+)*)/) {
        my $version_info = $1;
        # Limitar tamanho
        $version_info = substr($version_info, 0, 80);
        return "$servico ($version_info)";
    }

    return $servico;
}

# ======================================================================
#                SCAN TCP CONNECT (PADRÃO)
# ======================================================================

sub scan_porta_tcp {
    my ($host, $porta, $timeout) = @_;

    my $ip = inet_aton($host) or return 0;

    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm($timeout);

        socket(my $sock, AF_INET, SOCK_STREAM, IPPROTO_TCP) or return 0;

        # Socket não bloqueante para timeout preciso
        my $flags = fcntl($sock, F_GETFL, 0) or return 0;
        fcntl($sock, F_SETFL, $flags | O_NONBLOCK) or return 0;

        my $result = connect($sock, sockaddr_in($porta, $ip));

        if (!$result && $! == EINPROGRESS) {
            # Conexão em progresso — esperar
            my $vec = '';
            vec($vec, fileno($sock), 1) = 1;
            my $nfound = select($vec, undef, undef, $timeout);

            if ($nfound) {
                # Verificar erro no socket
                my $so_error = 0;
                getsockopt($sock, SOL_SOCKET, SO_ERROR, my $opt);
                $so_error = unpack('i', $opt) if $opt;

                if ($so_error == 0) {
                    close $sock;
                    alarm(0);
                    return 1;
                }
            }
        }

        close $sock;
        alarm(0);
        return 0;
    };

    return 0;
}

# ======================================================================
#                ANÁLISE AVANÇADA DE PORTAS
# ======================================================================

sub classificar_porta {
    my ($porta) = @_;

    # Classificações por categoria de risco
    if ($porta == 21 || $porta == 23 || $porta == 110 || $porta == 143) {
        return { categoria => 'Legado/Inseguro', risco => 'ALTO', cor => 'vermelho' };
    }
    if ($porta == 22 || $porta == 443 || $porta == 993 || $porta == 995) {
        return { categoria => 'Criptografado', risco => 'BAIXO', cor => 'verde' };
    }
    if ($porta == 80 || $porta == 8080 || $porta == 8000) {
        return { categoria => 'Web', risco => 'MÉDIO', cor => 'amarelo' };
    }
    if ($porta == 445 || $porta == 139 || $porta == 135) {
        return { categoria => 'Windows/NetBIOS', risco => 'ALTO', cor => 'vermelho' };
    }
    if ($porta == 3306 || $porta == 5432 || $porta == 1433 || $porta == 1521) {
        return { categoria => 'Banco de Dados', risco => 'CRÍTICO', cor => 'vermelho_negrito' };
    }
    if ($porta == 6379 || $porta == 11211) {
        return { categoria => 'Cache/NoSQL', risco => 'CRÍTICO', cor => 'vermelho_negrito' };
    }
    if ($porta == 3389) {
        return { categoria => 'Acesso Remoto', risco => 'ALTO', cor => 'vermelho' };
    }
    if ($porta >= 1 && $porta <= 1023) {
        return { categoria => 'Porta Baixa', risco => 'MÉDIO', cor => 'amarelo' };
    }
    if ($porta >= 1024 && $porta <= 49151) {
        return { categoria => 'Porta Registrada', risco => 'MÉDIO', cor => 'azul' };
    }
    return { categoria => 'Porta Alta', risco => 'BAIXO', cor => 'verde' };
}

# ======================================================================
#                RESOLUÇÃO DNS AVANÇADA
# ======================================================================

sub resolver_host {
    my $host = shift;

    # Já é IP?
    return ($host, $host) if $host =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;

    my $ip  = inet_aton($host);
    return ($host, inet_ntoa($ip)) if $ip;

    # Tentar com Net::DNS se disponível
    if ($HAS_DNS) {
        my $resolver = Net::DNS::Resolver->new(
            timeout => 5,
            retry   => 2,
        );
        my $query = $resolver->query($host, 'A');
        if ($query) {
            for my $rr ($query->answer) {
                next unless $rr->type eq 'A';
                return ($host, $rr->address);
            }
        }
    }

    return ($host, undef);
}

sub resolver_host_reverso {
    my $ip = shift;
    my $hostname = gethostbyaddr(inet_aton($ip), AF_INET);
    return $hostname // undef;
}

# ======================================================================
#                RELATÓRIO E SAÍDA
# ======================================================================

sub gerar_cabecalho {
    my ($host, $ip) = @_;

    say '';
    say colorir('destaque', '=' x 72);
    printf "  %s v%s  |  %s © %s\n", TOOL_NAME, VERSION, AUTHOR, YEAR;
    say colorir('destaque', '  Scanner de Portas e Serviços Profissional');
    say colorir('destaque', '=' x 72);
    printf "  🎯 Alvo: %s", $host;
    printf " (%s)", $ip if $ip && $ip ne $host;
    say '';
    printf "  🚪 Portas: %s\n", $CFG->{portas_str};
    printf "  ⏱  Timeout: %ds\n", $CFG->{timeout};
    printf "  ⚡ Scanner: %s\n", _nome_scan_type($CFG->{scan_type});
    say colorir('destaque', '=' x 72);
    say '';
}

sub _nome_scan_type {
    my $type = shift;
    return {
        connect => 'TCP Connect (completo)',
        syn     => 'TCP SYN (meia-aberta)',
        ft      => 'TCP FIN',
        null    => 'TCP Null',
        xmas    => 'TCP Xmas',
        ack     => 'TCP ACK',
        window  => 'TCP Window',
        maimon  => 'TCP Maimon',
        udp     => 'UDP',
    }->{$type} // $type;
}

sub formatar_saida_porta {
    my ($porta, $estado, $servico, $banner, $classificacao) = @_;

    my $servico_str   = $servico // 'Desconhecido';
    my $categoria     = $classificacao->{categoria} // 'N/A';
    my $risco         = $classificacao->{risco} // 'N/A';
    my $cor_risco     = $classificacao->{cor} // 'branco';

    my $banner_str = '';
    if ($banner && $CFG->{banner}) {
        $banner_str = $banner;
        $banner_str =~ s/\s+/ /g;
        $banner_str = substr($banner_str, 0, 100);
        $banner_str = " [$banner_str]";
    }

    my $linha = sprintf("  %-5s %-20s %-25s %-12s %s%s",
        colorir($estado eq 'aberta' ? 'verde' : 'vermelho',
            $estado eq 'aberta' ? "✅ $porta" : "❌ $porta"),
        $servico_str,
        $categoria,
        colorir($cor_risco, "[$risco]"),
        $banner_str,
        ''
    );

    return $linha;
}

# ======================================================================
#                RELATÓRIO NMAP-STYLE
# ======================================================================

sub gerar_relatorio_nmap {
    my ($host, $ip, $resultados) = @_;

    my $data = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $duracao = time() - $ESTADO->{inicio};

    my @linhas;
    push @linhas, "# FydelisCheck v" . VERSION . " scan report for $host ($ip)";
    push @linhas, "# Scan date: $data";
    push @linhas, "# Command: $0 -h $host -p $CFG->{portas_str} -t $CFG->{timeout}";
    push @linhas, "# Duration: ${duracao}s | Total ports: " . scalar(@$resultados);
    push @linhas, "";
    push @linhas, "PORT     STATE  SERVICE       VERSION";

    for my $r (sort { $a->{porta} <=> $b->{porta} } @$resultados) {
        next unless $r->{estado} eq 'aberta';
        my $porta_str = sprintf("%-5d/tcp", $r->{porta});
        my $estado_str = sprintf("%-7s", 'open');
        my $servico_str = sprintf("%-13s", $r->{servico} // 'unknown');
        my $versao = $r->{banner} // '';
        $versao =~ s/\s+/ /g;
        $versao = substr($versao, 0, 80);
        push @linhas, "  $porta_str $estado_str $servico_str $versao";
    }

    push @linhas, "";
    my $abertas = scalar grep { $_->{estado} eq 'aberta' } @$resultados;
    push @linhas, "# Scan finished: $abertas open ports found";

    return join("\n", @linhas);
}

# ======================================================================
#                FUNÇÕES PRINCIPAIS DE SCAN
# ======================================================================

sub executar_scan {
    my ($host, $ip, $portas) = @_;

    my @resultados;
    my $total = scalar @$portas;
    my $encontradas = 0;
    my $ultimo_log = time();
    my $processadas = 0;

    for my $porta (@$portas) {
        $processadas++;
        last if $CFG->{timeout_global} && (time() - $ESTADO->{inicio}) > $CFG->{timeout_global};

        # Testar porta
        my $aberta = scan_porta_tcp($host, $porta, $CFG->{timeout});

        my $resultado = {
            porta   => $porta,
            estado  => $aberta ? 'aberta' : 'fechada',
            servico => undef,
            banner  => undef,
        };

        if ($aberta) {
            $encontradas++;

            # Identificar serviço pelo mapa
            $resultado->{servico} = $SERVICOS_CONHECIDOS{$porta} || 'Desconhecido';

            # Banner grabbing
            if ($CFG->{banner}) {
                my $banner = capturar_banner($host, $porta, $CFG->{timeout});
                if ($banner) {
                    $resultado->{banner}  = $banner;
                    my $banner_servico = identificar_servico_por_banner($banner, $porta);
                    $resultado->{servico} = $banner_servico if $banner_servico;
                }
            }

            push @resultados, $resultado;

            # Exibir imediatamente
            my $class = classificar_porta($porta);
            say formatar_saida_porta($porta, 'aberta', $resultado->{servico},
                $resultado->{banner}, $class);
        }
        elsif ($CFG->{verbose}) {
            push @resultados, $resultado;
            my $class = classificar_porta($porta);
            say formatar_saida_porta($porta, 'fechada', '', undef, $class);
        }

        # Barra de progresso
        my $agora = time();
        if ($agora - $ultimo_log >= 1 && !$CFG->{quieto} && $total > 100) {
            $ultimo_log = $agora;
            my $pct = sprintf('%.1f', 100 * $processadas / $total);
            my $decorrido = $agora - $ESTADO->{inicio} || 1;
            my $taxa = int($processadas / $decorrido);
            printf("\r  📊 Progresso: %d/%d portas (%s%%) | Encontradas: %d | Taxa: %d/s | %ds",
                $processadas, $total, $pct, $encontradas, $taxa, $decorrido);
        }
    }

    # Limpar linha de progresso
    print "\r" . ' ' x 80 . "\r" unless $CFG->{quieto};

    return \@resultados;
}

# ======================================================================
#                RELATÓRIO E EXPORTAÇÃO
# ======================================================================

sub salvar_resultados {
    my ($arquivo, $host, $ip, $resultados) = @_;

    open(my $fh, '>', $arquivo) or do {
        log_msg('erro', "Não foi possível salvar $arquivo: $!");
        return;
    };

    my $relatorio = gerar_relatorio_nmap($host, $ip, $resultados);
    print $fh $relatorio;
    close $fh;

    log_msg('ok', "Relatório salvo em: $arquivo");
}

sub exibir_resumo_final {
    my ($host, $ip, $resultados) = @_;
    my $duracao = time() - $ESTADO->{inicio};

    my $total   = scalar @$resultados;
    my $abertas = scalar grep { $_->{estado} eq 'aberta' } @$resultados;
    my $filtradas = scalar grep { $_->{estado} eq 'filtrada' } @$resultados;

    say '';
    say colorir('destaque', '=' x 72);
    say colorir('destaque', '  📊 RESUMO DO SCAN');
    say colorir('destaque', '=' x 72);
    printf "  🎯 Alvo    : %s (%s)\n", $host, $ip // 'N/A';
    printf "  🕒 Duração : %ds\n", $duracao;
    printf "  🌐 Total   : %d portas\n", $total;
    printf "  ✅ Abertas : %d\n", $abertas;
    printf "  ❌ Fechadas: %d\n", $total - $abertas - $filtradas;
    printf "  🛡️  Filtradas: %d\n", $filtradas if $filtradas;
    printf "  ⚡ Scanner : %s\n", _nome_scan_type($CFG->{scan_type});
    printf "  ⏱  Timeout : %ds\n", $CFG->{timeout};
    say colorir('destaque', '=' x 72);

    # Tabela das portas abertas
    if ($abertas > 0) {
        say '';
        say colorir('destaque', '  PORTAS ABERTAS:');
        say colorir('destaque', '  ' . '-' x 60);

        for my $r (sort { $a->{porta} <=> $b->{porta} } @$resultados) {
            next unless $r->{estado} eq 'aberta';
            my $class = classificar_porta($r->{porta});
            printf "  %-5d  %-25s  %-10s  %s\n",
                $r->{porta},
                $r->{servico} // '?',
                colorir($class->{cor}, "[$class->{risco}]"),
                ($r->{banner} ? (substr($r->{banner}, 0, 60) =~ s/\s+/ /gr) : '');
        }
    }

    # Filtro de portas críticas
    my @criticas = grep {
        my $c = classificar_porta($_->{porta});
        $c->{risco} eq 'CRÍTICO' && $_->{estado} eq 'aberta'
    } @$resultados;

    if (@criticas) {
        say '';
        say colorir('vermelho', '  ⚠  PORTAS CRÍTICAS ENCONTRADAS:');
        for my $r (@criticas) {
            printf "  🔴 Porta %d (%s) — %s\n",
                $r->{porta}, $r->{servico} // '?',
                'RISCO CRÍTICO — Ação imediata recomendada';
        }
    }

    say colorir('destaque', '=' x 72);
    say '';
}

# ======================================================================
#                MAIN — ENTRADA PRINCIPAL
# ======================================================================

sub main {
    # Parse de argumentos
    my ($ajuda, $versao, $list_scan_types);
    my $portas_str;

    GetOptions(
        'h|host=s'          => \$CFG->{host},
        'p|portas=s'        => \$portas_str,
        't|timeout=i'       => \$CFG->{timeout},
        'o|output=s'        => \$CFG->{output},
        'b|banner'          => \$CFG->{banner},
        's|scan-type=s'     => \$CFG->{scan_type},
        'v|verbose'         => \$CFG->{verbose},
        'q|quiet'           => \$CFG->{quieto},
        'no-color'          => \$CFG->{nocolor},
        'n|no-dns'          => \$CFG->{no_dns},
        'r|random'          => \$CFG->{random},
        'rate=i'            => \$CFG->{rate_limit},
        'timeout-global=i'  => \$CFG->{timeout_global},
        'list-scan-types'   => \$list_scan_types,
        'top-ports=i'       => \$CFG->{top_ports},
        'H|ajuda'           => \$ajuda,
        'V|versao'          => \$versao,
        'h|help'            => \$ajuda,
    ) or do {
        say "\n❌ Erro nos argumentos. Use -H para ajuda.\n";
        exit 1;
    };

    exibir_ajuda()   if $ajuda;
    exibir_versao()  if $versao;
    listar_tipos_scan() if $list_scan_types;

    # Configurar cores
    $CFG->{nocolor} = 1 unless -t STDOUT;

    # Host obrigatório
    die "❌ Informe o alvo com -h HOST\n" unless $CFG->{host};

    # Parse de portas
    my @portas;
    if ($CFG->{top_ports}) {
        @portas = obter_top_portas($CFG->{top_ports});
        $CFG->{portas_str} = "top $CFG->{top_ports}";
    }
    else {
        $portas_str //= '1-1024';
        $CFG->{portas_str} = $portas_str;
        @portas = parse_portas($portas_str);
    }

    die "❌ Nenhuma porta válida especificada.\n" unless @portas;

    # Embaralhar portas
    @portas = shuffle(@portas) if $CFG->{random};

    # Resolução DNS
    my ($host, $ip) = resolver_host($CFG->{host});
    unless ($ip) {
        log_msg('erro', "Não foi possível resolver o host: $CFG->{host}");
        exit 1;
    }

    # Banner
    gerar_cabecalho($host, $ip);

    # Executar scan
    my $resultados = executar_scan($host, $ip, \@portas);

    # Salvar resultados
    if ($CFG->{output}) {
        salvar_resultados($CFG->{output}, $host, $ip, $resultados);
    }

    # Resumo final
    exibir_resumo_final($host, $ip, $resultados);

    # Exit code
    my $criticas = scalar grep {
        my $c = classificar_porta($_->{porta});
        $c->{risco} eq 'CRÍTICO' && $_->{estado} eq 'aberta'
    } @$resultados;

    exit $criticas > 0 ? 2 : 0;
}

main();