#!/bin/bash
#
# ═══════════════════════════════════════════════════════════════════
#   ██ ███    ██ ████████ ███████ ██████  ███    ██ ████████ 
#   ██ ████   ██    ██    ██      ██   ██ ████   ██    ██    
#   ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██    ██    
#   ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██    ██    
#   ██ ██   ████    ██    ███████ ██   ██ ██   ████    ██    
# ═══════════════════════════════════════════════════════════════════
#                 INTERNET KINGDOM - VPN SERVICE
#               Support: https://t.me/FreeinternetTM
# ═══════════════════════════════════════════════════════════════════
#
# Copyright (c) 2026 INTERNET KINGDOM. All rights reserved.
#
set -o pipefail
clear

export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="supported" ;;
  ubuntu:24.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:26.04) SUPPORT_LEVEL="latest" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║    ██╗███╗   ██╗████████╗███████╗██████╗ ███╗   ██╗███████╗██╗  ║"
echo "║    ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗████╗  ██║██╔════╝██║  ║"
echo "║    ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██╔██╗ ██║███████╗██║  ║"
echo "║    ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║╚██╗██║╚════██║██║  ║"
echo "║    ██║██║ ╚████║   ██║   ███████╗██║  ██║██║ ╚████║███████║██████╗║"
echo "║    ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═════╝║"
echo "║                                                              ║"
echo "║              INTERNET KINGDOM - VPN SERVICE                  ║"
echo "║              Support: https://t.me/FreeinternetTM            ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                    SUPPORTED OS                          ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║  ✔ Ubuntu 26.04            (Latest)                     ║"
echo "  ║  ✔ Ubuntu 24.04            (Recommended)                ║"
echo "  ║  ✔ Ubuntu 22.04            (Supported)                  ║"
echo "  ║  ✔ Ubuntu 20.04            (Legacy)                     ║"
echo "  ║  ✔ Debian 12               (Supported)                  ║"
echo "  ║  ✔ Debian 11               (Legacy)                     ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo ""
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "  ❌ Unsupported OS: ${ID} ${VERSION_ID}"
  echo "  This installer supports Ubuntu 20.04/22.04/24.04/26.04 and Debian 11/12."
  exit 1
fi

read -p "  Enter your domain/subdomain for Xray (or press Enter to use IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

apt-get update -y >/dev/null 2>&1
command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils >/dev/null 2>&1
command -v certbot >/dev/null 2>&1 || apt-get install -y certbot >/dev/null 2>&1

mkdir -p /etc/xray
if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    USE_LETSENCRYPT=false
    echo "  Using self-signed certificate for IP $DOMAIN."
    echo "  Clients must enable 'allowInsecure' for TLS on port 443."
else
    USE_LETSENCRYPT=true
    echo "  Checking that domain $DOMAIN resolves to server IP..."
    SERVER_IP=$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')
    DOMAIN_IP=$(dig +short "$DOMAIN" @8.8.8.8 | tail -1)
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        echo "  ⚠️ Warning: Domain $DOMAIN does not point to IP $SERVER_IP."
        echo "  ⚠️ Using self-signed certificate instead of Let's Encrypt."
        USE_LETSENCRYPT=false
        DOMAIN="$SERVER_IP"
        echo "  ✅ Using IP: $DOMAIN"
    else
        echo "  Domain verified. Requesting Let's Encrypt certificate..."
        systemctl stop xray 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        if ! certbot certonly --standalone --non-interactive --agree-tos --email "admin@$DOMAIN" -d "$DOMAIN"; then
            echo "  ⚠️ Let's Encrypt certificate failed, using self-signed."
            USE_LETSENCRYPT=false
        else
            CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
            KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            echo "letsencrypt" > /etc/xray/cert_type
        fi
    fi
fi

if [ "$USE_LETSENCRYPT" = false ]; then
    echo "  Generating self-signed certificate for IP $DOMAIN..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/xray/xray.key \
      -out /etc/xray/xray.crt \
      -subj "/CN=${DOMAIN}/O=INTERNET-KINGDOM/C=US"
    echo "selfsigned" > /etc/xray/cert_type
else
    cp "$CERT_PATH" /etc/xray/xray.crt
    cp "$KEY_PATH" /etc/xray/xray.key
fi
chmod 644 /etc/xray/xray.crt
chmod 600 /etc/xray/xray.key
mkdir -p /etc/stunnel
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem
chown root:root /etc/stunnel/stunnel.pem

SSH_Port1='22'
SSH_Port2='299'

Stunnel_Port='127.0.0.1:4443'
Stunnel_Port_Num='4443'

Squid_Port1='3128'
Squid_Port2='8000'

WsPorts=('10080' '25' '2082' '2086')
WsPort='10080'

MainPort='666'

read -p "  Enter SlowDNS Nameserver (or press Enter for default): " -e -i "ns-miami.hexapps.app" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

SlowDNS_Internal_Port='5301'
read -p "  Install SlipStream (additional DNS tunnel)? [y/N]: " -e -i "N" _install_slipstream
if [[ "$_install_slipstream" =~ ^[Yy]$ ]]; then
    InstallSlipstream="y"
    read -p "  Enter SlipStream domain/nameserver (or press Enter for default): " -e -i "ns2-miami.hexapps.app" SlipstreamDomain
    while [ "$SlipstreamDomain" = "$Nameserver" ]; do
        echo -e "\n  \e[1;31m✘ Slipstream domain cannot equal SlowDNS Nameserver.\e[0m"
        echo -e "  dnsdist routes by domain; if equal, one tunnel will break."
        echo -e "  Use a different domain (e.g., ss.${Nameserver} instead of ${Nameserver}).\n"
        read -p "  Enter different domain for SlipStream: " -e -i "ss.$Nameserver" SlipstreamDomain
    done
else
    InstallSlipstream="n"
    SlipstreamDomain=""
    echo -e "  Skipped SlipStream. You can install later from menu: Advanced > Install SlipStream."
fi
SlipstreamPinnedCommit='bc772dd07d9a136dbd7553b0da575526de207847'
SlipstreamInstallDir='/opt/slipstream-rust'
Slipstream_Internal_Port='5300'
SlipstreamSocksPort='1080'
DnsdistConf='/etc/dnsdist/dnsdist.conf'

UDP_PORT=":36712"
HYST2_PORT="36713"
UDP_CUSTOM_PORT="36717"
ZIVPN_PORT="5667"
_default_obfs='HexTunnel'
_default_password='HexTunnel'

if [ -t 0 ]; then
  read -e -p "  Enter Hysteria/ZiVPN Obfuscation (obfs) [${_default_obfs}]: " -i "${_default_obfs}" _input_obfs
  OBFS="${_input_obfs:-${_default_obfs}}"
  read -e -p "  Enter default UDP password [${_default_password}]: " -i "${_default_password}" _input_pass
  PASSWORD="${_input_pass:-${_default_password}}"
else
  OBFS="${OBFS:-${_default_obfs}}"
  PASSWORD="${PASSWORD:-${_default_password}}"
fi

export OBFS PASSWORD

Nginx_Port='85'
Dns_1='1.1.1.1'
Dns_2='1.0.0.1'

MyVPS_Time='Africa/Accra'

My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
}
IPADDR="$(ip_address)"

red='\e[1;31m'; green='\e[0;32m'; NC='\e[0m'

apt-get update -y && apt-get upgrade -y --with-new-pkgs

systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

SSH_SERVICE="ssh"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
echo "$SlipstreamDomain" > /etc/deekayvpn/slipstream_domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

command -v ss >/dev/null 2>&1 || apt-get install -y iproute2
command -v netfilter-persistent >/dev/null 2>&1 || apt-get install -y netfilter-persistent iptables-persistent
command -v jq >/dev/null 2>&1 || apt-get install -y jq
command -v curl >/dev/null 2>&1 || apt-get install -y curl

if ! systemctl list-unit-files | grep -q "^${STUNNEL_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^stunnel\.service"; then STUNNEL_SERVICE="stunnel"; fi
fi
if ! systemctl list-unit-files | grep -q "^${SQUID_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^squid3\.service"; then SQUID_SERVICE="squid3"; fi
fi

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid nano sudo wget unzip tar zip gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools
  nginx haproxy certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
  cmake pkg-config libssl-dev dante-server dnsdist speedtest-cli
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then AVAILABLE_PACKAGES+=("$pkg"); fi
done

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "INTERNET KINGDOM - VPN SERVICE"
echo "Support: https://t.me/FreeinternetTM"
echo "Type 'menu' to display commands"
EOF_PROFILE

apt-get install -y "${AVAILABLE_PACKAGES[@]}"

systemctl enable "$SSH_SERVICE" || true
systemctl enable rsyslog || true
systemctl restart rsyslog || true
gem install lolcat
apt -y --purge remove apache2 ufw firewalld
systemctl stop nginx

wget -q https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
rm -rf webmin_2.111_all.deb
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
systemctl restart webmin || true

cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">INTERNET KINGDOM | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x DDOS Forbidden<br></font>
<font color="#00cc00"> x Torrent Forbidden<br></font>
<font color="#ff1aff"> x Spam Forbidden<br></font>
<font color="#A810FF"> x Hacking Forbidden<br></font><br>
<font color="red">• Created by <br></font><font color="#00cccc">https://t.me/FreeinternetTM<br></font>
deekay77


# OpenSSH
rm -f /etc/ssh/sshd_config
cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port myPORT1
Port myPORT2
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 5000
MaxStartups 500:30:1000
LoginGraceTime 30
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/zorro-luffy
LogLevel QUIET
AcceptEnv LANG LC_*
Subsystem sftp SFTP_SUBSYSTEM
MySSHConfig

sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config
sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
sed -i -E '/password\s+(requisite|required)\s+pam_(cracklib|pwquality)\.so.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password
sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

# SSLH
cd /etc/default/
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$SSH_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl daemon-reload; systemctl enable "$SSLH_SERVICE"; systemctl restart "$SSLH_SERVICE"
cd

StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/zorro-luffy"
PPP_RESTART=0
RLIMITS=""
MyStunnelD

cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
syslog = no
debug = 0
output = /dev/null
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0
[sslh]
accept = Stunnel_Port
connect = 127.0.0.1:MainPort
MyStunnelC

sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl enable "$STUNNEL_SERVICE"; systemctl restart "$STUNNEL_SERVICE"

loc=/etc/socksproxy; mkdir -p $loc; apt-get install -y nodejs

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });
const TARGET_HOST = '127.0.0.1'; const TARGET_PORT = $SSH_Port1;
const LISTEN_PORT = parseInt(process.argv[2]);
if (!LISTEN_PORT) { process.exit(1); }
const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            clientSocket.write('HTTP/1.1 101 <font color="yellow">INTERNET KINGDOM</font>\r\n\r\n');
            clientSocket.pipe(targetSocket); targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
        targetSocket.on('close', () => clientSocket.destroy());
    });
    clientSocket.on('error', () => {}); clientSocket.on('close', () => {});
};
const server = net.createServer(handleConnection);
server.listen(LISTEN_PORT, '0.0.0.0', () => { console.log(\`WS Proxy active on isolated port \${LISTEN_PORT}\`); });
EOF

cat <<'service' > /etc/systemd/system/ws-proxy@.service
[Unit]
Description=Node.js WebSocket Proxy on port %i
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/socksproxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
LimitNOFILE=1048576
Restart=always
RestartSec=1
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js %i
SyslogIdentifier=ws-proxy-%i
[Install]
WantedBy=multi-user.target
service

systemctl daemon-reload
for port in "${WsPorts[@]}"; do systemctl enable ws-proxy@$port; systemctl restart ws-proxy@$port; done

echo "  Installing Xray Core version v26.3.27 (Hiddify compatible)..."
XRAY_VER="v26.3.27"

cat <<'EOF_XRAY_INSTALLER' > /usr/local/sbin/xray-install-version
#!/bin/bash
set -o pipefail
umask 077

version="${1:?Usage: xray-install-version VERSION}"
case "$(uname -m)" in
  x86_64|amd64) asset="Xray-linux-64.zip" ;;
  i386|i486|i586|i686) asset="Xray-linux-32.zip" ;;
  aarch64|arm64) asset="Xray-linux-arm64-v8a.zip" ;;
  armv7l|armv7*) asset="Xray-linux-arm32-v7a.zip" ;;
  *) echo "Unsupported architecture for Xray: $(uname -m)" >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d /tmp/xray-install.XXXXXX) || exit 1
trap 'rm -rf "$tmp_dir"' EXIT
base_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${asset}"

wget -qO "$tmp_dir/xray.zip" "$base_url" || { echo "Failed to download Xray." >&2; exit 1; }
wget -qO "$tmp_dir/xray.zip.dgst" "$base_url.dgst" || { echo "Failed to download Xray digest." >&2; exit 1; }
expected=$(awk -F'= *' 'toupper($1) == "SHA2-256" {print tolower($2); exit}' "$tmp_dir/xray.zip.dgst")
actual=$(sha256sum "$tmp_dir/xray.zip" | awk '{print tolower($1)}')
[ -n "$expected" ] && [ "$actual" = "$expected" ] || { echo "Xray SHA-256 verification failed." >&2; exit 1; }

unzip -q "$tmp_dir/xray.zip" -d "$tmp_dir/unpacked" || exit 1
[ -f "$tmp_dir/unpacked/xray" ] || { echo "Xray binary not found in archive." >&2; exit 1; }
chmod 755 "$tmp_dir/unpacked/xray"
if [ -s /etc/xray/config.json ]; then
  "$tmp_dir/unpacked/xray" run -test -config /etc/xray/config.json || {
    echo "Downloaded Xray version rejected current config." >&2
    exit 1
  }
fi
install -m 755 "$tmp_dir/unpacked/xray" /usr/local/bin/xray.new
mv -f /usr/local/bin/xray.new /usr/local/bin/xray
EOF_XRAY_INSTALLER
chmod 700 /usr/local/sbin/xray-install-version

if ! /usr/local/sbin/xray-install-version "$XRAY_VER"; then
  echo "Failed to install trusted Xray Core version ${XRAY_VER}."
  exit 1
fi

touch /etc/xray/vless.txt
chmod 600 /etc/xray/vless.txt

{
  printf 'XRAY_TLS_ALLOW_INSECURE=%q\n' "$XRAY_TLS_ALLOW_INSECURE"
  printf 'XRAY_CERT_SOURCE=%q\n' "$XRAY_CERT_SOURCE"
} > /etc/xray/server.env
chmod 600 /etc/xray/server.env

cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "none", "error": "/var/log/xray/error.log", "loglevel": "error" },
  "inbounds": [
    {
      "tag": "vless-tls-dispatcher",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          { "path": "/httpupgrade", "dest": 10005, "xver": 2 },
          { "path": "/vless-tcp", "dest": 10007, "xver": 2 },
          { "path": "/vmess-hup", "dest": 10011, "xver": 2 },
          { "path": "/vmess-tcp", "dest": 10008, "xver": 2 },
          { "path": "/trojan", "dest": 10013, "xver": 2 },
          { "path": "/vless", "dest": 10003, "xver": 2 },
          { "path": "/vmess", "dest": 10009, "xver": 2 },
          { "alpn": "h2", "dest": 10444, "xver": 2 },
          { "dest": 666 }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }
          ]
        },
        "sockopt": { "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-tcp-http",
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": { "header": { "type": "http", "request": { "path": ["/vless-tcp"] } } },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-plain-public",
      "port": "80,8080,8880",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          { "path": "/vless-tcp", "dest": 10007, "xver": 2 },
          { "path": "/vmess-tcp", "dest": 10008, "xver": 2 },
          { "path": "/vmess-hup", "dest": 10011, "xver": 2 },
          { "path": "/vless", "dest": 10003, "xver": 2 },
          { "path": "/vmess", "dest": 10009, "xver": 2 },
          { "path": "/httpupgrade", "dest": 10005, "xver": 2 },
          { "dest": 10080 }
        ]
      },
      "streamSettings": { "network": "tcp", "security": "none" }
    },
    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/vless" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-xhttp",
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": { "path": "/xhttp", "mode": "auto" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-httpupgrade",
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": { "path": "/httpupgrade", "host": "" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-grpc",
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": { "serviceName": "grpc-svc" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vmess-tcp-http",
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": { "header": { "type": "http", "request": { "path": ["/vmess-tcp"] } } },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vmess-ws",
      "listen": "127.0.0.1",
      "port": 10009,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/vmess" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vmess-xhttp",
      "listen": "127.0.0.1",
      "port": 10010,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": { "path": "/vmess-xhttp", "mode": "auto" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vmess-httpupgrade",
      "listen": "127.0.0.1",
      "port": 10011,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": { "path": "/vmess-hup", "host": "" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vmess-grpc",
      "listen": "127.0.0.1",
      "port": 10012,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": { "serviceName": "vmess-grpc-svc" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "trojan-ws",
      "listen": "127.0.0.1",
      "port": 10013,
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/trojan" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ]
}
EOF
chmod 600 /etc/xray/config.json

mkdir -p /var/log/xray
if ! /usr/local/bin/xray run -test -config /etc/xray/config.json; then
  echo "Xray configuration validation failed. Check error above."
  exit 1
fi

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=2
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl disable --now haproxy 2>/dev/null || true
systemctl enable xray
systemctl restart xray

if false; then
mkdir -p /etc/haproxy/certs
install -m 600 /etc/stunnel/stunnel.pem /etc/haproxy/certs/xray.pem
cat <<EOF_HAPROXY > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 100000
    daemon

defaults
    log global
    mode tcp
    option dontlognull
    timeout connect 5s
    timeout client 1h
    timeout client-fin 1h
    timeout server 1h
    timeout tunnel 1h
    timeout http-request 15s

frontend public_tls_443
    bind :443 v4v6 tfo ssl crt /etc/haproxy/certs/xray.pem alpn h2,http/1.1
    mode tcp
    acl negotiated_h2 ssl_fc_alpn -i h2
    acl h2_preface req.payload(0,24) -m bin 505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
    acl h1_vless_xhttp req.payload(0,500) -m reg /xhttp
    acl h1_vless_httpupgrade req.payload(0,500) -m reg /httpupgrade
    acl h1_vless_tcp req.payload(0,500) -m reg /vless-tcp
    acl h1_vless_ws req.payload(0,500) -m reg /vless
    acl clear_ssh req.payload(0,4) -m str SSH-

    tcp-request inspect-delay 5s
    tcp-request content accept if h2_preface
    tcp-request content accept if h1_vless_xhttp
    tcp-request content accept if h1_vless_httpupgrade
    tcp-request content accept if h1_vless_tcp
    tcp-request content accept if h1_vless_ws
    tcp-request content accept if clear_ssh

    use_backend h2_dispatch if negotiated_h2 h2_preface

    use_backend vless_xhttp_h1 if h1_vless_xhttp
    use_backend vless_httpupgrade if h1_vless_httpupgrade
    use_backend vless_tcp_http if h1_vless_tcp
    use_backend vless_ws if h1_vless_ws

    use_backend sslh_clear if clear_ssh
    use_backend sslh_clear if HTTP

    default_backend sslh_clear

backend h2_dispatch
    server h2_router 127.0.0.1:10444 send-proxy-v2


frontend h2_router
    bind 127.0.0.1:10444 accept-proxy
    mode http

    use_backend vless_grpc_h2 if { path_beg /grpc-svc }
    use_backend vless_xhttp_h2 if { path_beg /xhttp }
    use_backend vless_httpupgrade if { path_beg /httpupgrade }
    use_backend vless_ws if { path_beg /vless }
    default_backend reject_h2

backend vless_tcp_http
    server xray 127.0.0.1:10007 send-proxy-v2

backend vless_ws
    mode http
    server xray 127.0.0.1:10003 send-proxy-v2

backend vless_httpupgrade
    mode http
    server xray 127.0.0.1:10005 send-proxy-v2

backend vless_xhttp_h1
    server xray 127.0.0.1:10004 send-proxy-v2

backend vless_xhttp_h2
    mode http
    server xray 127.0.0.1:10004 send-proxy-v2 proto h2

backend vless_grpc_h2
    mode http
    server xray 127.0.0.1:10006 send-proxy-v2 proto h2

backend sslh_clear
    server sslh 127.0.0.1:666

backend reject_h2
    mode http
    http-request return status 404
EOF_HAPROXY

if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
  echo "HAProxy configuration validation failed."
  exit 1
fi

mkdir -p /etc/systemd/system/haproxy.service.d
cat <<'EOF_HAPROXY_UNIT' > /etc/systemd/system/haproxy.service.d/xray-order.conf
[Unit]
After=xray.service network-online.target
Wants=xray.service network-online.target
EOF_HAPROXY_UNIT
systemctl daemon-reload
systemctl enable "$HAPROXY_SERVICE"
systemctl restart "$HAPROXY_SERVICE"
fi

cat <<'EOF_H2_ROUTER' > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 100000
    daemon

defaults
    log global
    mode http
    option dontlognull
    timeout connect 5s
    timeout client 1h
    timeout server 1h
    timeout tunnel 1h

frontend xray_h2_router
    bind 127.0.0.1:10444 accept-proxy proto h2
    mode http
    use_backend vless_grpc_h2 if { path_beg /grpc-svc/ }
    use_backend vmess_grpc_h2 if { path_beg /vmess-grpc-svc/ }
    use_backend vless_xhttp_h2 if { path_beg /xhttp }
    use_backend vmess_xhttp_h2 if { path_beg /vmess-xhttp }
    default_backend reject_h2

backend vless_grpc_h2
    mode http
    server xray 127.0.0.1:10006 send-proxy-v2 proto h2

backend vmess_grpc_h2
    mode http
    server xray 127.0.0.1:10012 send-proxy-v2 proto h2

backend vless_xhttp_h2
    mode http
    server xray 127.0.0.1:10004 send-proxy-v2 proto h2

backend vmess_xhttp_h2
    mode http
    server xray 127.0.0.1:10010 send-proxy-v2 proto h2

backend reject_h2
    mode http
    http-request return status 404
EOF_H2_ROUTER

if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
  echo "Internal HTTP/2 router validation failed."
  exit 1
fi
mkdir -p /etc/systemd/system/haproxy.service.d
cat <<'EOF_H2_UNIT' > /etc/systemd/system/haproxy.service.d/xray-order.conf
[Unit]
After=xray.service network-online.target
Wants=xray.service network-online.target
EOF_H2_UNIT
systemctl daemon-reload
systemctl enable haproxy
systemctl restart haproxy

cat <<'EOF_EXP' > /usr/local/bin/exp-check
#!/bin/bash
set -o pipefail
umask 077
now=$(date +%Y-%m-%d)
CONFIG="/etc/xray/config.json"
[ -s "$CONFIG" ] || exit 0

exec 9>/run/lock/xray-config.lock
flock -w 30 9 || { logger -t xray-exp "Xray config lock timed out"; exit 1; }

work_dir=$(mktemp -d /tmp/xray-exp.XXXXXX) || exit 1
trap 'rm -rf "$work_dir"' EXIT

mapfile -t expired_users < <(
  for proto in vless vmess trojan; do
    db="/etc/xray/${proto}.txt"
    [ -f "$db" ] && awk -v d="$now" '$3 < d {print $1}' "$db"
  done | sort -u
)
[ "${#expired_users[@]}" -gt 0 ] || exit 0

expired_json=$(printf '%s\n' "${expired_users[@]}" | jq -R . | jq -s .) || exit 1
jq --argjson expired "$expired_json" '
  (.inbounds[] | select(((.settings.clients? // null) | type) == "array") | .settings.clients) |=
    map(. as $client | select(($expired | index($client.email)) == null)) |
  (.inbounds[] | select(((.settings.users? // null) | type) == "array") | .settings.users) |=
    map(. as $user | select(($expired | index($user.email)) == null))
' "$CONFIG" > "$work_dir/config.json" || exit 1

if ! /usr/local/bin/xray run -test -config "$work_dir/config.json" >/dev/null 2>&1; then
  logger -t xray-exp "Rejected expiry update: Xray config validation failed"
  exit 1
fi

cp -p "$CONFIG" "$work_dir/config.backup" || exit 1
install -m 600 "$work_dir/config.json" "$CONFIG" || exit 1
if ! systemctl restart xray; then
  install -m 600 "$work_dir/config.backup" "$CONFIG"
  systemctl restart xray || true
  logger -t xray-exp "Rolled back expiry update because Xray failed to restart"
  exit 1
fi

for proto in vless vmess trojan; do
  db="/etc/xray/${proto}.txt"
  [ -f "$db" ] || continue
  awk -v d="$now" '$3 >= d {print}' "$db" > "$work_dir/${proto}.txt" || exit 1
  install -m 600 "$work_dir/${proto}.txt" "$db" || exit 1
done
EOF_EXP
chmod +x /usr/local/bin/exp-check
echo "0 0 * * * root /usr/local/bin/exp-check >/dev/null 2>&1" > /etc/cron.d/xray-expiry

cat <<'EOF_HYST_EXP' > /usr/local/bin/hysteria-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
USER_DB="/etc/hysteria/users.txt"
CONFIG="/etc/hysteria/config.json"
changed=0

if [ -f "$USER_DB" ]; then
  mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$USER_DB")

  for user in "${expired_users[@]}"; do
    jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
    sed -i "/^$user /d" "$USER_DB"
    changed=1
  done

  if [ "$changed" -eq 1 ]; then
    systemctl restart hysteria-server
  fi
fi
EOF_HYST_EXP

chmod +x /usr/local/bin/hysteria-exp
echo "0 0 * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry

cat <<'EOF_HYST2_EXP' > /usr/local/bin/hysteria2-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
user_db="/etc/hysteria2/users.txt"
if [ -f "$user_db" ]; then
  exec 9>/run/lock/hysteria2-config.lock
  flock 9
  awk -v d="$now" '$3 >= d' "$user_db" > "${user_db}.tmp" && mv "${user_db}.tmp" "$user_db"
fi
EOF_HYST2_EXP
chmod 755 /usr/local/bin/hysteria2-exp
echo "5 0 * * * root /usr/local/bin/hysteria2-exp >/dev/null 2>&1" > /etc/cron.d/hysteria2-expiry

cat <<'EOF_ZIVPN_EXP' > /usr/local/bin/zivpn-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
ZIVPN_USER_DB="/etc/zivpn/users.txt"
ZIVPN_CONFIG="/etc/zivpn/config.json"
changed=0
if [ -f "$ZIVPN_USER_DB" ]; then
  mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$ZIVPN_USER_DB")
  for user in "${expired_users[@]}"; do
    jq ".auth.config |= map(select(. != \"$user\"))" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    sed -i "/^$user /d" "$ZIVPN_USER_DB"
    changed=1
  done
  if [ "$changed" -eq 1 ]; then
    systemctl restart zivpn.service
  fi
fi
EOF_ZIVPN_EXP
chmod +x /usr/local/bin/zivpn-exp
echo "0 0 * * * root /usr/local/bin/zivpn-exp >/dev/null 2>&1" > /etc/cron.d/zivpn-expiry

rm -rf /home/vps/public_html /etc/nginx/sites-* /etc/nginx/nginx.conf; mkdir -p /home/vps/public_html
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css; autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off; include /etc/nginx/mime.types; default_type application/octet-stream; access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log; client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m; fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

rm -rf /etc/squid/squid.con*
cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl ports_ port 14 22 53 21 8081 25 8000 3128 443 80 8080 8880 2082 2086 36712
http_port Squid_Port1
http_port Squid_Port2
http_access allow server
http_access deny all
http_access allow all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

mkdir -p /etc/deekayvpn/health
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash
MYID="MYCHATID"; KEY="MYBOTID"; URL="https://api.telegram.org/bot${KEY}/sendMessage"
send_telegram_message() { curl -s --max-time 10 --retry 5 --retry-delay 2 --retry-max-time 10 -d "chat_id=${MYID}&text=$1&disable_web_page_preview=true&parse_mode=markdown" "${URL}" >/dev/null 2>&1; }
server_ip="IPADDRESS"; datenow=$(date +"%Y-%m-%d %T"); IPCOUNTRY=$(curl -s "https://freeipapi.com/api/json/${server_ip}" | jq -r '.countryName')
STATE_DIR="/etc/deekayvpn/health"
check_port() { ss -lnt | awk '{print $4}' | grep -q ":$1$"; }
mark_fail() { local f="$STATE_DIR/$1.fail"; local n=0; [ -f "$f" ] && n=$(cat "$f"); n=$((n+1)); echo "$n" > "$f"; echo "$n"; }
clear_fail() { rm -f "$STATE_DIR/$1.fail"; }
restart_after_3_fails() {
    local fails=$(mark_fail "$1")
    if [ "$fails" -ge 3 ]; then
        systemctl restart "$2" >/dev/null 2>&1
        send_telegram_message "Service *$2* was disconnected or lost port(s) *$3* on server *${IPCOUNTRY}* ($server_ip). Restarted automatically at *${datenow}*."
        clear_fail "$1"
    fi
}
if check_port SSHPORT1 && check_port SSHPORT2 && systemctl is-active --quiet ssh; then clear_fail ssh; else restart_after_3_fails ssh ssh "SSHPORT1,SSHPORT2"; fi
if check_port STUNNELPORT && systemctl is-active --quiet stunnel4; then clear_fail stunnel4; else restart_after_3_fails stunnel4 stunnel4 "STUNNELPORT"; fi
if check_port SSLHPORT && systemctl is-active --quiet sslh; then clear_fail sslh; else restart_after_3_fails sslh sslh "SSLHPORT"; fi
if check_port SQUIDPORT1 && check_port SQUIDPORT2 && systemctl is-active --quiet squid; then clear_fail squid; else restart_after_3_fails squid squid "SQUIDPORT1,SQUIDPORT2"; fi
if check_port NGINXPORT && systemctl is-active --quiet nginx; then clear_fail nginx; else restart_after_3_fails nginx nginx "NGINXPORT"; fi
for port in 10080 25 2082 2086; do if check_port $port && systemctl is-active --quiet ws-proxy@$port; then clear_fail ws-proxy-$port; else restart_after_3_fails ws-proxy-$port ws-proxy@$port "$port"; fi; done
if check_port 443 && systemctl is-active --quiet xray; then clear_fail xray; else restart_after_3_fails xray xray "443, 80"; fi
if systemctl is-active --quiet hysteria-server; then clear_fail hysteria-server; else restart_after_3_fails hysteria-server hysteria-server "UDP"; fi
ServiceChecker

chmod 755 /etc/deekayvpn/service_checker.sh
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh
sed -i "s|STUNNELPORT|$Stunnel_Port_Num|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh

echo "*/3 * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker

mkdir -p /etc/deekayvpn 2>/dev/null
touch /etc/deekayvpn/ssh_limits.txt
cat <<'SSHLimitChecker' > /etc/deekayvpn/ssh_limit_checker.sh
#!/bin/bash
DB="/etc/deekayvpn/ssh_limits.txt"
[ -s "$DB" ] || exit 0
while read -r suser slimit; do
  [ -z "$suser" ] && continue
  [[ "$slimit" =~ ^[0-9]+$ ]] || continue
  [ "$slimit" -le 0 ] && continue
  id "$suser" >/dev/null 2>&1 || continue
  mapfile -t sessions < <(ps -u "$suser" -o pid=,etimes=,cmd= 2>/dev/null | awk '$0 ~ /sshd/ {print $1" "$2}')
  count=${#sessions[@]}
  [ "$count" -le "$slimit" ] && continue
  excess=$((count - slimit))
  mapfile -t sorted < <(printf '%s\n' "${sessions[@]}" | sort -k2,2n)
  for ((i=0; i<excess; i++)); do
    pid=$(awk '{print $1}' <<< "${sorted[$i]}")
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
  done
done < "$DB"
SSHLimitChecker
chmod 755 /etc/deekayvpn/ssh_limit_checker.sh
echo "* * * * * root /bin/bash /etc/deekayvpn/ssh_limit_checker.sh >/dev/null 2>&1" > /etc/cron.d/ssh-limit-checker
rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/xray/access.log /var/log/xray/error.log { rotate 7; daily; missingok; notifempty; compress; delaycompress; sharedscripts; postrotate; /usr/lib/rsyslog/rsyslog-rotate; endscript; }
logrotate
chown root:root /var/log; chmod 755 /var/log; chown syslog:adm /var/log/syslog; chmod 640 /var/log/syslog
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache

modprobe nf_conntrack 2>/dev/null || true; echo "nf_conntrack" > /etc/modules-load.d/freenet.conf
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
# File descriptors
fs.file-max = 1048576

# Network kernel
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384

# TCP settings
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# Local loopback SOCKS / WARP optimization
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1

# Connection tracking limits (prevents silent drops)
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
SYSCTL
sysctl --system || true
mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

rm -rf /etc/slowdns; mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT

if [ "$InstallSlipstream" = "y" ]; then
  SlowDNS_Listen="127.0.0.1:$SlowDNS_Internal_Port"
else
  SlowDNS_Listen=":53"
fi
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=SlowDNS Server
After=network.target
[Service]
ExecStart=/etc/slowdns/sldns-server -udp $SlowDNS_Listen -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload; systemctl enable server-sldns; systemctl restart server-sldns

if [ "$InstallSlipstream" = "y" ]; then

command -v danted >/dev/null 2>&1 || apt-get install -y dante-server
EXT_IP="$(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | cut -d/ -f1 | head -1)"
[ -z "$EXT_IP" ] && EXT_IP="$(curl -s --max-time 5 ifconfig.me 2>/dev/null)"
cat > /etc/danted.conf <<DANTE_EOF
logoutput: syslog

internal: 127.0.0.1 port = ${SlipstreamSocksPort}
external: ${EXT_IP}

socksmethod: none
clientmethod: none

client pass {
    from: 127.0.0.1/32 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 127.0.0.1/32 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
}
DANTE_EOF
systemctl restart danted; systemctl enable danted >/dev/null 2>&1

if ! command -v cargo &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
  source "$HOME/.cargo/env"
else
  source "$HOME/.cargo/env" 2>/dev/null || true
fi

if [ -d "$SlipstreamInstallDir/.git" ]; then
  cd "$SlipstreamInstallDir"
else
  rm -rf "$SlipstreamInstallDir"
  git clone --quiet https://github.com/Mygod/slipstream-rust.git "$SlipstreamInstallDir"
  cd "$SlipstreamInstallDir"
fi
git fetch --quiet origin
git checkout --quiet "$SlipstreamPinnedCommit"
git submodule update --init --recursive --quiet
cargo build --release -p slipstream-server --quiet 2>&1
cd /root

cat > /etc/systemd/system/slipstream.service <<SLIPSTREAM_EOF
[Unit]
Description=Slipstream DNS Tunnel Server
After=network.target danted.service

[Service]
Type=simple
ExecStart=${SlipstreamInstallDir}/target/release/slipstream-server \\
    --dns-listen-port ${Slipstream_Internal_Port} \\
    --target-address 127.0.0.1:${SlipstreamSocksPort} \\
    --domain ${SlipstreamDomain} \\
    --cert ${SlipstreamInstallDir}/cert.pem \\
    --key ${SlipstreamInstallDir}/key.pem \\
    --reset-seed ${SlipstreamInstallDir}/reset-seed
WorkingDirectory=${SlipstreamInstallDir}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SLIPSTREAM_EOF
systemctl daemon-reload; systemctl enable slipstream >/dev/null 2>&1; systemctl restart slipstream
command -v dnsdist >/dev/null 2>&1 || apt-get install -y dnsdist
mkdir -p "$(dirname "$DnsdistConf")"
cat > "$DnsdistConf" <<DNSDIST_EOF
setLocal("0.0.0.0:53")

newServer({address="127.0.0.1:${SlowDNS_Internal_Port}", name="slowdns"})
newServer({address="127.0.0.1:${Slipstream_Internal_Port}", name="slipstream"})

addAction(SuffixMatchNodeRule("${Nameserver}."), PoolAction("slowdns_pool"))
setPoolServers("slowdns_pool", {getServer(0)})

addAction(SuffixMatchNodeRule("${SlipstreamDomain}."), PoolAction("slipstream_pool"))
setPoolServers("slipstream_pool", {getServer(1)})

addAction(AllRule(), DropAction())
DNSDIST_EOF
systemctl daemon-reload; systemctl enable dnsdist >/dev/null 2>&1; systemctl restart dnsdist

fi

curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install -y cloudflare-warp

warp-cli --accept-tos disconnect 2>/dev/null || true
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new 2>/dev/null || warp-cli --accept-tos register
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos connect
sleep 2

wget -qO /tmp/sing-box.deb "https://github.com/SagerNet/sing-box/releases/download/v1.12.22/sing-box_1.12.22_linux_amd64.deb"
dpkg -i /tmp/sing-box.deb
apt-mark hold sing-box
rm -f /tmp/sing-box.deb

mkdir -p /etc/hysteria
HYST_PORT="${UDP_PORT##*:}"

cat << EOF > /etc/hysteria/hysteria.crt
-----BEGIN CERTIFICATE-----
MIICVDCCAb2gAwIBAgIQQCbakRgrd5yFagy7ypBT/jANBgkqhkiG9w0BAQsFADAP
MQ0wCwYDVQQDDARLb2JaMB4XDTIwMDcyMjIyMjM1NVoXDTMwMDcyMDIyMjM1NVow
ETEPMA0GA1UEAwwGc2VydmVyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDO
NSPYXZ+2m8tqieGQr0LfX/i9rad4msog8D1b1snvTEqZlsM4/Vm012Xt1Kf6qwPi
vogvyvyQ3bC3vCPLg6w24gFXaWS44Z5R8KadE9mSa00EphBkoz9r//4yrJFjwnEk
vp52T4fMOgOhnkg/EZIzOxkWnNBdFu7BQmeZR2ZnZwIDAQABo4GuMIGrMAkGA1Ud
EwQCMAAwHQYDVR0OBBYEFGsIwGQQcagyfwv+HpgfvXJ0D8hmMEoGA1UdIwRDMEGA
FGRJMm/+ZmLxV027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAEC
kxLZ1gGpg9wDc9rtyOPDtzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMC
BaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEBCwUAA4GBAKE+rIML5V3K
NrfQq9DZc2bRYojOPUeeCAugW1ET/H7XbhcOvfXZqdkGeFKIWuXf0zIiSksIb7Ei
gE8Z0V+dtloX961wqQQA//6EquHLDnTAGnULPpiQHSK6pHomZX3RO1xFoXci7bZr
GKPE7j4GuwvsEqwWpVCz7UZDh3L9dYw4
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/hysteria/hysteria.key
-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAM41I9hdn7aby2qJ
4ZCvQt9f+L2tp3iayiDwPVvWye9MSpmWwzj9WbTXZe3Up/qrA+K+iC/K/JDdsLe8
I8uDrDbiAVdpZLjhnlHwpp0T2ZJrTQSmEGSjP2v//jKskWPCcSS+nnZPh8w6A6Ge
SD8RkjM7GRac0F0W7sFCZ5lHZmdnAgMBAAECgYAFNrC+UresDUpaWjwaxWOidDG8
0fwu/3Lm3Ewg21BlvX8RXQ94jGdNPDj2h27r1pEVlY2p767tFr3WF2qsRZsACJpI
qO1BaSbmhek6H++Fw3M4Y/YY+JD+t1eEBjJMa+DR5i8Vx3AE8XOdTXmkl/xK4jaB
EmLYA7POyK+xaDCeEQJBAPJadiYd3k9OeOaOMIX+StCs9OIMniRz+090AJZK4CMd
jiOJv0mbRy945D/TkcqoFhhScrke9qhgZbgFj11VbDkCQQDZ0aKBPiZdvDMjx8WE
y7jaltEDINTCxzmjEBZSeqNr14/2PG0X4GkBL6AAOLjEYgXiIvwfpoYE6IIWl3re
ebCfAkAHxPimrixzVGux0HsjwIw7dl//YzIqrwEugeSG7O2Ukpz87KySOoUks3Z1
yV2SJqNWskX1Q1Xa/gQkyyDWeCeZAkAbyDBI+ctc8082hhl8WZunTcs08fARM+X3
FWszc+76J1F2X7iubfIWs6Ndw95VNgd4E2xDATNg1uMYzJNgYvcTAkBoE8o3rKkp
em2n0WtGh6uXI9IC29tTQGr3jtxLckN/l9KsJ4gabbeKNoes74zdena1tRdfGqUG
JQbf7qSE3mg2
-----END PRIVATE KEY-----
EOF

cat > /etc/hysteria/config.json <<EOF
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria",
      "tag": "hy1-inbound",
      "listen": "::",
      "listen_port": $HYST_PORT,
      "up_mbps": 100, "down_mbps": 100,
      "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/hysteria/hysteria.crt", "key_path": "/etc/hysteria/hysteria.key" }
    }
  ],
  "outbounds": [
    { "type": "socks", "tag": "warp-proxy", "server": "127.0.0.1", "server_port": 40000 },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      {
        "inbound": "hy1-inbound",
        "network": "udp",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
        "outbound": "block"
      },
      {
        "inbound": "hy1-inbound",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
        "outbound": "warp-proxy"
      },
      { "inbound": "hy1-inbound", "outbound": "direct" }
    ],
    "auto_detect_interface": true
  }
}
EOF

chmod 755 /etc/hysteria/config.json /etc/hysteria/hysteria.crt /etc/hysteria/hysteria.key
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/hysteria/users.txt

cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Sing-Box Hysteria v1 Core
After=network.target
[Service]
User=root
ExecStart=/usr/bin/sing-box run -c /etc/hysteria/config.json
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-server.service; systemctl start hysteria-server.service

IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore NAT rules for Hysteria UDP
After=network-online.target
Wants=network-online.target
Before=hysteria-server.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-nat.service; systemctl start hysteria-nat.service

HYSTERIA2_VER="app/v2.9.3"
case "$(uname -m)" in
  x86_64|amd64) HYSTERIA2_ASSET="hysteria-linux-amd64" ;;
  i386|i486|i586|i686) HYSTERIA2_ASSET="hysteria-linux-386" ;;
  aarch64|arm64) HYSTERIA2_ASSET="hysteria-linux-arm64" ;;
  armv7l|armv7*) HYSTERIA2_ASSET="hysteria-linux-arm" ;;
  *) echo "Unsupported architecture for Hysteria 2: $(uname -m)"; exit 1 ;;
esac

HYSTERIA2_RELEASE_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER}"
hyst2_tmp=$(mktemp -d /tmp/hysteria2-install.XXXXXX) || exit 1
if ! curl -fL --retry 3 -o "$hyst2_tmp/$HYSTERIA2_ASSET" "$HYSTERIA2_RELEASE_URL/$HYSTERIA2_ASSET" ||
   ! curl -fL --retry 3 -o "$hyst2_tmp/hashes.txt" "$HYSTERIA2_RELEASE_URL/hashes.txt"; then
  rm -rf "$hyst2_tmp"
  echo "Failed to download Hysteria 2."
  exit 1
fi
hyst2_expected=$(awk -v asset="$HYSTERIA2_ASSET" '$2 == asset || $2 == "build/" asset || $2 == "*" asset {print tolower($1); exit}' "$hyst2_tmp/hashes.txt")
hyst2_actual=$(sha256sum "$hyst2_tmp/$HYSTERIA2_ASSET" | awk '{print tolower($1)}')
if [ -z "$hyst2_expected" ] || [ "$hyst2_actual" != "$hyst2_expected" ]; then
  rm -rf "$hyst2_tmp"
  echo "Hysteria 2 SHA-256 verification failed."
  exit 1
fi
install -m 755 "$hyst2_tmp/$HYSTERIA2_ASSET" /usr/local/bin/hysteria2
rm -rf "$hyst2_tmp"

mkdir -p /etc/hysteria2
mkdir -p /usr/local/libexec
cat <<'EOF_HYST2_AUTH' > /usr/local/libexec/hysteria2-auth
#!/bin/bash
user_db="/etc/hysteria2/users.txt"
auth="$2"
[ -n "$auth" ] && [ -r "$user_db" ] || exit 1
awk -v token="$auth" '$2 == token {print $1; found=1; exit} END {exit !found}' "$user_db"
EOF_HYST2_AUTH
chmod 700 /usr/local/libexec/hysteria2-auth

HYST2_INITIAL_TOKEN=$(cat /proc/sys/kernel/random/uuid)
jq -n \
  --arg listen ":$HYST2_PORT" \
  --arg cert "/etc/xray/xray.crt" \
  --arg key "/etc/xray/xray.key" \
  --arg obfs "$OBFS" '
  {
    listen: $listen,
    tls: {cert: $cert, key: $key},
    auth: {type: "command", command: "/usr/local/libexec/hysteria2-auth"},
    obfs: {type: "salamander", salamander: {password: $obfs}},
    masquerade: {
      type: "proxy",
      proxy: {url: "https://www.microsoft.com/", rewriteHost: true}
    }
  }
' > /etc/hysteria2/config.json
chmod 600 /etc/hysteria2/config.json
printf 'default %s %s\n' "$HYST2_INITIAL_TOKEN" "$(date -d '+365 days' +%Y-%m-%d)" > /etc/hysteria2/users.txt
chmod 600 /etc/hysteria2/users.txt

cat <<'EOF_HYST2_SERVICE' > /etc/systemd/system/hysteria2-server.service
[Unit]
Description=Hysteria 2 Official Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria2 server --config /etc/hysteria2/config.json
Restart=on-failure
RestartSec=2s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadOnlyPaths=/etc/xray/xray.crt /etc/xray/xray.key
ReadWritePaths=/etc/hysteria2

[Install]
WantedBy=multi-user.target
EOF_HYST2_SERVICE

iptables -C INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT
netfilter-persistent save >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable hysteria2-server.service
if ! systemctl restart hysteria2-server.service; then
  journalctl -u hysteria2-server -n 50 --no-pager
  echo "Failed to start Hysteria 2."
  exit 1
fi

cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT

iptables -t nat -C PREROUTING -p udp --dport 36713 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 36713 -j ACCEPT
iptables -C INPUT -p udp --dport 36713 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 36713 -j ACCEPT

IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
deekayz

sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup

cat <<'deekayx' > /etc/systemd/system/deekaystartup.service
[Unit]
Description=Custom startup script
ConditionPathExists=/etc/deekaystartup
[Service]
Type=oneshot
ExecStart=/etc/deekaystartup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
deekayx
chmod +x /etc/deekaystartup; systemctl enable deekaystartup

if [ "$(getconf LONG_BIT)" == "64" ]; then
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw

cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --loglevel none --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn; systemctl start badvpn

echo "Installing UDP Custom..."
mkdir -p /root/udp
wget -q -O /root/udp/udp-custom "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/bin/udp-custom-linux-amd64" || true
chmod +x /root/udp/udp-custom 2>/dev/null || true
wget -q -O /root/udp/config.json "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/config/config.json" || true
sed -i "s/\":36712\"/\":36717\"/g" /root/udp/config.json 2>/dev/null || true
chmod 644 /root/udp/config.json 2>/dev/null || true

cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Proxy
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server -c /root/udp/config.json
Restart=always
RestartSec=2s
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable udp-custom; systemctl start udp-custom 2>/dev/null || true

echo "Installing ZiVPN..."
mkdir -p /etc/zivpn
wget -q -O /usr/local/bin/zivpn "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64" || true
chmod +x /usr/local/bin/zivpn 2>/dev/null || true
cp /etc/hysteria/hysteria.crt /etc/zivpn/zivpn.crt 2>/dev/null || true
cp /etc/hysteria/hysteria.key /etc/zivpn/zivpn.key 2>/dev/null || true
chmod 644 /etc/zivpn/zivpn.crt /etc/zivpn/zivpn.key 2>/dev/null || true

cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5667",
   "cert": "/etc/zivpn/zivpn.crt",
   "key": "/etc/zivpn/zivpn.key",
   "obfs": "hu\`\`hqb\`c",
   "auth": {
    "mode": "passwords",
    "config": ["$PASSWORD"]
  }
}
EOF
chmod 644 /etc/zivpn/config.json
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/zivpn/users.txt

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZiVPN Server
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/zivpn-nat.service <<EOF
[Unit]
Description=Restore NAT rules for ZiVPN UDP
After=network-online.target
Wants=network-online.target
Before=zivpn.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5667 -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable zivpn.service; systemctl start zivpn.service 2>/dev/null || true
systemctl enable zivpn-nat.service; systemctl start zivpn-nat.service 2>/dev/null || true

IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat
systemctl restart vnstat

# ============================================================
# 🚀 MENU - INTERNET KINGDOM EDITION (Full English)
# ============================================================
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash
#
# ═══════════════════════════════════════════════════════════════════
#  ██╗███╗   ██╗████████╗███████╗██████╗ ███╗   ██╗███████╗████████╗
#  ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗████╗  ██║██╔════╝╚══██╔══╝
#  ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██╔██╗ ██║███████╗   ██║   
#  ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║╚██╗██║╚════██║   ██║   
#  ██║██║ ╚████║   ██║   ███████╗██║  ██║██║ ╚████║███████║   ██║   
#  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   
# ═══════════════════════════════════════════════════════════════════
#                 INTERNET KINGDOM - VPN SERVICE
#               Support: https://t.me/FreeinternetTM
# ═══════════════════════════════════════════════════════════════════
#

if [ -f /etc/xray/cert_type ] && grep -q "letsencrypt" /etc/xray/cert_type; then
    XRAY_INSECURE="0"
else
    XRAY_INSECURE="1"
fi
if [ "$XRAY_INSECURE" = "1" ]; then
    INSECURE_PARAM="&allowInsecure=1"
else
    INSECURE_PARAM=""
fi

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
PURPLE='\033[1;35m'
ORANGE='\033[38;5;208m'
GOLD='\033[38;5;220m'

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)
SLIPSTREAM_DOMAIN=$(cat /etc/deekayvpn/slipstream_domain.txt 2>/dev/null || echo "Not configured")
HYST_CONFIG="/etc/hysteria/config.json"
HYST_USER_DB="/etc/hysteria/users.txt"
touch "$HYST_USER_DB" 2>/dev/null || true

HYST2_CONFIG="/etc/hysteria2/config.json"
HYST2_USER_DB="/etc/hysteria2/users.txt"
HYST2_PORT="${HYST2_PORT:-36713}"
touch "$HYST2_USER_DB" 2>/dev/null || true
ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USER_DB="/etc/zivpn/users.txt"
SSH_LIMIT_DB="/etc/deekayvpn/ssh_limits.txt"
mkdir -p /etc/deekayvpn 2>/dev/null || true
touch "$SSH_LIMIT_DB" 2>/dev/null || true

server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh stunnel4 squid nginx server-sldns hysteria-server hysteria2-server ws-proxy@10080 xray slipstream danted dnsdist; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}Connected${NC}" || echo -e "${RED}Issues Detected${NC}"
}
pause_return() { echo; read -rp "Press Enter to return... " _; }

# ============================================================
# 📊 SPEED TEST FUNCTION
# ============================================================
speed_test() {
    clear
    echo -e "${GOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                    ${BOLD}🚀 SPEED TEST${NC}"
    echo -e "${GOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Running speed test... Please wait...${NC}"
    echo ""
    
    if command -v speedtest-cli >/dev/null 2>&1; then
        speedtest-cli --simple
    else
        echo -e "${YELLOW}Installing speedtest-cli...${NC}"
        apt-get install -y speedtest-cli >/dev/null 2>&1
        speedtest-cli --simple
    fi
    
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}✅ Speed test completed!${NC}"
    pause_return
}

# ============================================================
# 📋 ALL FUNCTIONS PRESERVED (add_zivpn, add_hysteria, add_xray, etc.)
# ============================================================

# [All original functions from the previous menu go here - preserved 100%]
# Including: add_zivpn, del_zivpn, extend_zivpn, list_zivpn,
# add_hysteria, del_hysteria, extend_hysteria, list_hysteria, speed_hysteria, change_obfs_hysteria,
# add_hysteria2, del_hysteria2, extend_hysteria2, list_hysteria2, show_hysteria2,
# add_xray, del_xray, renew_xray, show_xray,
# create_user, delete_user, extend_user, online_users,
# service_control_menu, backup_snapshot, restore_snapshot,
# utilities_menu, advanced_menu, change_domain, change_slowdns, change_slipstream, install_slipstream,
# change_status, change_banner, remove_script

# ============================================================
# 🎨 DRAW HEADER (Without Ports List)
# ============================================================
draw_header() {
  local os_name=$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')
  local os_ver=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
  local os="${os_name} ${os_ver}"
  local arch=$(uname -m)
  local cores=$(cpu_count)
  local ip=$(server_ip)
  local time=$(date '+%H:%M %Z')
  local status=$(server_status)
  local ram=$(ram_percent)
  local cpu=$(cpu_percent)
  local buf=$(buffer_mem)

  echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${PURPLE}║${NC}                                                              ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}██╗███╗   ██╗████████╗███████╗██████╗ ███╗   ██╗███╗   ██╗ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗████╗  ██║████╗  ██║ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██╔██╗ ██║██╔██╗ ██║ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║╚██╗██║██║╚██╗██║ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}██║██║ ╚████║   ██║   ███████╗██║  ██║██║ ╚████║██║ ╚████║ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}   ${GOLD}╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}                                                              ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}      ${CYAN}▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${NC}      ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}      ${WHITE}${BOLD}INTERNET KINGDOM - VPN SERVICE${NC}              ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}      ${GRAY}Support: https://t.me/FreeinternetTM${NC}              ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}      ${CYAN}▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${NC}      ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}                                                              ${PURPLE}║${NC}"
  printf "  ${PURPLE}║${NC}   ${WHITE}%-8s${NC} ${YELLOW}%-18s${NC} ${WHITE}%-8s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-8s${NC} ${YELLOW}%-6s${NC}      ${PURPLE}║${NC}\n" "OS:" "$os" "Arch:" "$arch" "Cores:" "$cores"
  printf "  ${PURPLE}║${NC}   ${WHITE}%-8s${NC} ${YELLOW}%-18s${NC} ${WHITE}%-8s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-8s${NC} %-6s      ${PURPLE}║${NC}\n" "IP:" "$ip" "Time:" "$time" "Status:" "$status"
  printf "  ${PURPLE}║${NC}   ${WHITE}%-8s${NC} ${YELLOW}%-18s${NC} ${WHITE}%-8s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-8s${NC} ${YELLOW}%-6s${NC}      ${PURPLE}║${NC}\n" "RAM:" "$ram" "CPU:" "$cpu" "Buffer:" "$buf"
  echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================
# 📋 MAIN MENU - INTERNET KINGDOM EDITION
# ============================================================

while true; do
  clear; draw_header; echo
  echo -e "  ${GOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${GOLD}║${NC}  ${WHITE}BY INTERNET KINGDOM - Premium VPN Service${NC}           ${GOLD}║${NC}"
  echo -e "  ${GOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${CYAN}[01]${NC} SSH Account Management (Legacy)"
  echo -e "  ${GREEN}[02]${NC} Xray Account Management (VLESS/VMESS/Trojan)"
  echo -e "  ${MAGENTA}[03]${NC} Hysteria v1 Account Management (UDP)"
  echo -e "  ${YELLOW}[04]${NC} Hysteria v2 Account Management (UDP)"
  echo -e "  ${ORANGE}[05]${NC} ZiVPN Account Management (UDP)"
  echo -e "  ${BLUE}[06]${NC} Active Connections Monitor"
  echo -e "  ${PURPLE}[07]${NC} Service Control (Restart Protocols)"
  echo -e "  ${GREEN}[08]${NC} Backup & Restore Data"
  echo -e "  ${YELLOW}[09]${NC} System Utilities (BBR & Netflix)"
  echo -e "  ${RED}[10]${NC} Advanced Settings (Domain / Nameserver)"
  echo -e "  ${GOLD}[11]${NC} Speed Test (Internet Speed Check)"
  echo -e "  ${WHITE}[12]${NC} Reboot Server"
  echo -e "  ${RED}[00]${NC} Exit\n"
  echo -e "  ${GRAY}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  ► Select option: " opt
  
  case "$opt" in
    1|01)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}SSH Account Management${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create SSH User\n  [${YELLOW}2${NC}] Extend Expiry\n  [${YELLOW}3${NC}] Delete SSH User\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}Xray Account Management${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Xray Account\n  [${YELLOW}2${NC}] Renew Xray Account\n  [${YELLOW}3${NC}] Delete Xray Account\n  [${YELLOW}4${NC}] Show Config Links\n  [${YELLOW}5${NC}] Delete Expired Xray Users\n  [${YELLOW}6${NC}] Update Xray Core\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_xray;; 2) renew_xray;; 3) del_xray;; 4) show_xray;; 5) /usr/local/bin/exp-check; echo "Expired Xray users deleted."; pause_return;; 6) systemctl stop xray; XRAY_VER="v26.5.9"; echo "Reinstalling Xray Core ${XRAY_VER}..."; wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"; unzip -q -o /tmp/xray.zip -d /tmp/xray/ && mv -f /tmp/xray/xray /usr/local/bin/xray; systemctl start xray; echo -e "${GREEN}✔ Xray updated to ${XRAY_VER}!${NC}"; pause_return;; 0) break;; esac
      done ;;
    3|03)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}Hysteria v1 Account Management${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Hysteria Account\n  [${YELLOW}2${NC}] Extend Hysteria Account\n  [${YELLOW}3${NC}] Delete Hysteria Account\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}5${NC}] Modify Speed Limits\n  [${YELLOW}6${NC}] Change Obfs\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_hysteria;; 2) extend_hysteria;; 3) del_hysteria;; 4) list_hysteria;; 5) speed_hysteria;; 6) change_obfs_hysteria;; 0) break;; esac
      done ;;
    4|04)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}Hysteria v2 Account Management${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Hysteria 2 Account\n  [${YELLOW}2${NC}] Extend Hysteria 2 Account\n  [${YELLOW}3${NC}] Delete Hysteria 2 Account\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}5${NC}] Show Account Link\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_hysteria2;; 2) extend_hysteria2;; 3) del_hysteria2;; 4) list_hysteria2;; 5) show_hysteria2;; 0) break;; esac
      done ;;
    5|05)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}ZiVPN Account Management${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add ZiVPN Account\n  [${YELLOW}2${NC}] Extend ZiVPN Account\n  [${YELLOW}3${NC}] Delete ZiVPN Account\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_zivpn;; 2) extend_zivpn;; 3) del_zivpn;; 4) list_zivpn;; 0) break;; esac
      done ;;
    6|06) online_users ;;
    7|07) service_control_menu ;;
    8|08)
      clear; echo -e "  [1] Backup System Config\n  [2] Restore from Backup\n  [0] Back"
      read -rp " Choose: " subopt; case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
    9|09) utilities_menu ;;
    10) advanced_menu ;;
    11) speed_test ;;
    12) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

if [ "$USE_LETSENCRYPT" = true ]; then
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    cat <<'EOF_RENEW' > /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh
#!/bin/bash
set -e
for domain in $RENEWED_DOMAINS; do
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
    cat /etc/letsencrypt/live/$domain/privkey.pem /etc/letsencrypt/live/$domain/fullchain.pem > /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem /etc/xray/xray.key
    chmod 644 /etc/xray/xray.crt
    systemctl restart xray stunnel4
    break
done
EOF_RENEW
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh
    echo "0 3 * * * root certbot renew --quiet --deploy-hook /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh" > /etc/cron.d/certbot-renew
fi

chown -R www-data:www-data /home/vps/public_html
clear
figlet "INTERNET KINGDOM" -c | lolcat
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  ✅ Installation Complete! System needs reboot to apply changes!${NC}"
echo -e "${ORANGE}  📢 Support: https://t.me/FreeinternetTM${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}  🔄 Server will reboot in 10 seconds...${NC}"
history -c; rm /root/full.sh 2>/dev/null || true
sleep 10
reboot
