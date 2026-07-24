#!/bin/bash
#
# حقوق النشر (c) 2026 KINDOM TUNNEL
# KINDOM TUNNEL | VPN | SERVICE
# بواسطة BILAL ACON SINKO
#
set -o pipefail
clear

export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
  ubuntu:26.04) SUPPORT_LEVEL="supported" ;;
  ubuntu:28.04) SUPPORT_LEVEL="supported" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "============================================================"
echo "              KINDOM TUNNEL | VPN | SERVICE"
echo "        (سكريبت آلي: SSH/Xray/Hysteria/ZiVPN/UDP Custom)"
echo "============================================================"
echo ""
echo "أنظمة التشغيل المدعومة:"
echo ""
echo "  ✔ دبيان 12              (موصى به)"
echo "  ✔ دبيان 11              (دعم قديم)"
echo "  ✔ أوبونتو 28.04           (مدعوم)"
echo "  ✔ أوبونتو 26.04           (مدعوم)"
echo "  ✔ أوبونتو 24.04           (مدعوم)"
echo "  ✔ أوبونتو 22.04           (موصى به)"
echo "  ✔ أوبونتو 20.04           (دعم قديم)"
echo ""
echo "============================================================"
echo "صنع بواسطة BILAL ACON SINKO"
echo "https://t.me/FreeinternetTM"
echo "============================================================"
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "هذا المثبت يدعم فقط أوبونتو 20.04/22.04/24.04/26.04/28.04 ودبيان 11/12."
  echo "تم الكشف: ${ID} ${VERSION_ID}"
  exit 1
fi

read -p "أدخل دومينك/ساب دومين لـ Xray (أو اضغط Enter لاستخدام الـ IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

apt-get update -y >/dev/null 2>&1
command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils >/dev/null 2>&1
command -v certbot >/dev/null 2>&1 || apt-get install -y certbot >/dev/null 2>&1

mkdir -p /etc/xray
if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    USE_LETSENCRYPT=false
    echo "سيتم استخدام شهادة موقعة ذاتيًا للـ IP $DOMAIN."
    echo "يجب على العملاء تفعيل 'allowInsecure' لـ TLS على المنفذ 443."
else
    USE_LETSENCRYPT=true
    echo "جاري التحقق من أن الدومين $DOMAIN يحل إلى IP الخادم..."
    SERVER_IP=$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')
    DOMAIN_IP=$(dig +short "$DOMAIN" @8.8.8.8 | tail -1)
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        echo "⚠️ تحذير: الدومين $DOMAIN لا يشير إلى IP $SERVER_IP."
        echo "⚠️ سيتم استخدام شهادة ذاتية بدلاً من Let's Encrypt."
        USE_LETSENCRYPT=false
        DOMAIN="$SERVER_IP"
        echo "✅ سيتم استخدام IP: $DOMAIN"
    else
        echo "تم التحقق من الدومين. جاري طلب شهادة Let's Encrypt..."
        systemctl stop xray 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        if ! certbot certonly --standalone --non-interactive --agree-tos --email "admin@$DOMAIN" -d "$DOMAIN"; then
            echo "⚠️ فشل الحصول على شهادة Let's Encrypt، سيتم استخدام شهادة ذاتية."
            USE_LETSENCRYPT=false
        else
            CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
            KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            echo "letsencrypt" > /etc/xray/cert_type
        fi
    fi
fi

if [ "$USE_LETSENCRYPT" = false ]; then
    echo "جاري إنشاء شهادة موقعة ذاتيًا للـ IP $DOMAIN..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/xray/xray.key \
      -out /etc/xray/xray.crt \
      -subj "/CN=${DOMAIN}/O=KINDOM-TUNNEL/C=US"
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

read -p "أدخل Nameserver لـ SlowDNS (أو اضغط Enter للافتراضي): " -e -i "ns-miami.apps.app" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

SlowDNS_Internal_Port='5301'
read -p "هل تريد تثبيت SlipStream (نفق DNS إضافي)؟ [y/N]: " -e -i "N" _install_slipstream
if [[ "$_install_slipstream" =~ ^[Yy]$ ]]; then
    InstallSlipstream="y"
    read -p "أدخل الدومين/nameserver لـ SlipStream (أو اضغط Enter للافتراضي): " -e -i "" SlipstreamDomain
    while [ "$SlipstreamDomain" = "$Nameserver" ]; do
        echo -e "\n\e[1;31m✘ دومين Slipstream لا يمكن أن يكون مساويًا لـ Nameserver الخاص بـ SlowDNS.\e[0m"
        echo -e "  dnsdist يوزع حسب الدومين؛ إذا تساويا، سيتوقف أحد النفقين عن العمل."
        echo -e "  استخدم دومينًا مختلفًا (مثال: ss.${Nameserver} بدلاً من ${Nameserver}).\n"
        read -p "أدخل دومينًا مختلفًا لـ SlipStream: " -e -i "ss.$Nameserver" SlipstreamDomain
    done
else
    InstallSlipstream="n"
    SlipstreamDomain=""
    echo -e "  تم تخطي SlipStream. يمكنك تثبيته لاحقًا من القائمة: إعدادات متقدمة > تثبيت SlipStream."
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
_default_obfs='KINGDOM'
_default_password='KIGDOM'

if [ -t 0 ]; then
  read -e -p "أدخل Hysteria/ZiVPN Obfuscation (obfs) [${_default_obfs}]: " -i "${_default_obfs}" _input_obfs
  OBFS="${_input_obfs:-${_default_obfs}}"
  read -e -p "أدخل كلمة المرور الافتراضية لـ UDP [${_default_password}]: " -i "${_default_password}" _input_pass
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
  cmake pkg-config libssl-dev dante-server dnsdist
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
echo "KINDOM TUNNEL | VPN | SERVICE"
echo "بواسطة BILAL ACON SINKO"
echo "اكتب 'menu' لعرض الأوامر"
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
<br><font color="#C12267">KINDOM TUNNEL | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x DDOS ممنوع<br></font>
<font color="#00cc00"> x ممنوع التورنت<br></font>
<font color="#ff1aff"> x ممنوع الإزعاج<br></font>
<font color="#A810FF"> x ممنوع القرصنة<br></font><br>
<font color="red">• صنع بواسطة <br></font><font color="#00cccc">https://t.me/FreeinternetTM<br></font>
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
            clientSocket.write('HTTP/1.1 101 <font color="yellow">KINDOM TUNNEL</font>\r\n\r\n');
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

echo "جاري تثبيت Xray Core الإصدار v26.3.27 المتوافق مع Hiddify..."
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
  *) echo "بنية غير مدعومة لـ Xray: $(uname -m)" >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d /tmp/xray-install.XXXXXX) || exit 1
trap 'rm -rf "$tmp_dir"' EXIT
base_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${asset}"

wget -qO "$tmp_dir/xray.zip" "$base_url" || { echo "فشل تحميل Xray." >&2; exit 1; }
wget -qO "$tmp_dir/xray.zip.dgst" "$base_url.dgst" || { echo "فشل تحميل digest Xray." >&2; exit 1; }
expected=$(awk -F'= *' 'toupper($1) == "SHA2-256" {print tolower($2); exit}' "$tmp_dir/xray.zip.dgst")
actual=$(sha256sum "$tmp_dir/xray.zip" | awk '{print tolower($1)}')
[ -n "$expected" ] && [ "$actual" = "$expected" ] || { echo "فشل التحقق من SHA-256 لـ Xray." >&2; exit 1; }

unzip -q "$tmp_dir/xray.zip" -d "$tmp_dir/unpacked" || exit 1
[ -f "$tmp_dir/unpacked/xray" ] || { echo "الملف الثنائي Xray غير موجود في الأرشيف." >&2; exit 1; }
chmod 755 "$tmp_dir/unpacked/xray"
if [ -s /etc/xray/config.json ]; then
  "$tmp_dir/unpacked/xray" run -test -config /etc/xray/config.json || {
    echo "الإصدار الذي تم تحميله من Xray رفض التهيئة الحالية." >&2
    exit 1
  }
fi
install -m 755 "$tmp_dir/unpacked/xray" /usr/local/bin/xray.new
mv -f /usr/local/bin/xray.new /usr/local/bin/xray
EOF_XRAY_INSTALLER
chmod 700 /usr/local/sbin/xray-install-version

if ! /usr/local/sbin/xray-install-version "$XRAY_VER"; then
  echo "تعذر تثبيت إصدار Xray Core ${XRAY_VER} الموثوق."
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
  echo "فشل التحقق من صحة تهيئة Xray. راجع الخطأ أعلاه."
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
  echo "فشل التحقق من صحة تهيئة HAProxy."
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
  echo "فشل التحقق من صحة موجه HTTP/2 الداخلي."
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
flock -w 30 9 || { logger -t xray-exp "انتهى وقت انتظار قفل تهيئة Xray"; exit 1; }

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
  logger -t xray-exp "رفض تحديث الانتهاء: فشل التحقق من صحة تهيئة Xray"
  exit 1
fi

cp -p "$CONFIG" "$work_dir/config.backup" || exit 1
install -m 600 "$work_dir/config.json" "$CONFIG" || exit 1
if ! systemctl restart xray; then
  install -m 600 "$work_dir/config.backup" "$CONFIG"
  systemctl restart xray || true
  logger -t xray-exp "تم التراجع عن تحديث الانتهاء لأن Xray فشل في إعادة التشغيل"
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
        send_telegram_message "الخدمة *$2* كانت غير متصلة أو فقدت المنفذ(ذ) *$3* على الخادم *${IPCOUNTRY}* ($server_ip). تم إعادة تشغيلها تلقائيًا في *${datenow}*."
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
# واصفات الملفات
fs.file-max = 1048576

# نواة الشبكة
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384

# إعدادات TCP
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# تحسين الحلقة المحلية SOCKS / WARP
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1

# حدود تتبع الاتصال (يمنع الإسقاط الصامت)
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
Description=خادم SlowDNS
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
Description=خادم نفق DNS Slipstream
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
Description=استعادة قواعد NAT لـ Hysteria UDP
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
  *) echo "بنية غير مدعومة لـ Hysteria 2: $(uname -m)"; exit 1 ;;
esac

HYSTERIA2_RELEASE_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER}"
hyst2_tmp=$(mktemp -d /tmp/hysteria2-install.XXXXXX) || exit 1
if ! curl -fL --retry 3 -o "$hyst2_tmp/$HYSTERIA2_ASSET" "$HYSTERIA2_RELEASE_URL/$HYSTERIA2_ASSET" ||
   ! curl -fL --retry 3 -o "$hyst2_tmp/hashes.txt" "$HYSTERIA2_RELEASE_URL/hashes.txt"; then
  rm -rf "$hyst2_tmp"
  echo "فشل تحميل Hysteria 2."
  exit 1
fi
hyst2_expected=$(awk -v asset="$HYSTERIA2_ASSET" '$2 == asset || $2 == "build/" asset || $2 == "*" asset {print tolower($1); exit}' "$hyst2_tmp/hashes.txt")
hyst2_actual=$(sha256sum "$hyst2_tmp/$HYSTERIA2_ASSET" | awk '{print tolower($1)}')
if [ -z "$hyst2_expected" ] || [ "$hyst2_actual" != "$hyst2_expected" ]; then
  rm -rf "$hyst2_tmp"
  echo "فشل التحقق من SHA-256 لـ Hysteria 2."
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
Description=خادم Hysteria 2 الرسمي
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
  echo "فشل تشغيل Hysteria 2."
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
Description=سكريبت بدء التشغيل المخصص
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
Description=خدمة badvpn tun2socks
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --loglevel none --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn; systemctl start badvpn

echo "جاري تثبيت UDP Custom..."
mkdir -p /root/udp
wget -q -O /root/udp/udp-custom "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/bin/udp-custom-linux-amd64" || true
chmod +x /root/udp/udp-custom 2>/dev/null || true
wget -q -O /root/udp/config.json "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/config/config.json" || true
sed -i "s/\":36712\"/\":36717\"/g" /root/udp/config.json 2>/dev/null || true
chmod 644 /root/udp/config.json 2>/dev/null || true

cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=وكيل UDP Custom
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

echo "جاري تثبيت ZiVPN..."
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
Description=خادم VPN ZiVPN
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
Description=استعادة قواعد NAT لـ ZiVPN UDP
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

mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash

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

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)
SLIPSTREAM_DOMAIN=$(cat /etc/deekayvpn/slipstream_domain.txt 2>/dev/null || echo "غير مهيأ")
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
  [ "$ok" -ge 4 ] && echo -e "${GREEN}متصل${NC}" || echo -e "${RED}مشاكل مكتشفة${NC}"
}
pause_return() { echo; read -rp "اضغط Enter للعودة... " _; }

add_zivpn() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}إنشاء مستخدم ZiVPN${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " أدخل كلمة المرور: " new_pass

    if grep -qw "^$new_pass" "$ZIVPN_USER_DB" 2>/dev/null; then
        echo -e "\n${RED}خطأ: كلمة المرور موجودة بالفعل!${NC}"
        pause_return; return
    fi
    read -rp " الصلاحية (أيام): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}رقم غير صحيح.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")

    jq ".auth.config += [\"$new_pass\"]" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    echo "$new_pass $exp_date" >> "$ZIVPN_USER_DB"
    systemctl restart zivpn.service

    OBFS_VAL=$(jq -r '.obfs' "$ZIVPN_CONFIG" 2>/dev/null || echo "hu\`\`hqb\`c")

    echo -e "\n${GREEN}✔ تم إنشاء المستخدم بنجاح!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
    echo -e " ${BOLD}الدومين:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
    echo -e " ${BOLD}منفذ النطاق:${NC}  ${YELLOW}6000-19999${NC}"
    echo -e " ${BOLD}المستخدم (كلمة المرور):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}تاريخ الانتهاء:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_zivpn() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}حذف مستخدم ZiVPN${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "لا يوجد مستخدمين."; pause_return; return; fi
    cat -n "$ZIVPN_USER_DB" | awk '{print " ["$1"] المستخدم: "$2" | الانتهاء: "$3}'
    echo ""
    read -rp " أدخل رقم ID المستخدم المراد حذفه: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID غير صحيح.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID غير موجود.${NC}"; pause_return; return; fi
    jq ".auth.config |= map(select(. != \"$del_pass\"))" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    sed -i "${del_id}d" "$ZIVPN_USER_DB"
    systemctl restart zivpn.service
    echo -e "\n${GREEN}✔ تم حذف المستخدم '$del_pass' بنجاح!${NC}"
    pause_return
}

extend_zivpn() {
    clear
      echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
      echo -e "                 ${BOLD}تمديد مستخدم ZiVPN${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "لا يوجد مستخدمين."; pause_return; return; fi

    cat -n "$ZIVPN_USER_DB" | awk '{print " ["$1"] المستخدم: "$2" | الانتهاء: "$3}'
    echo ""
    read -rp " أدخل رقم ID المستخدم المراد تمديده: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID غير صحيح.${NC}"; pause_return; return; fi

    ext_pass=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID غير موجود.${NC}"; pause_return; return; fi

    read -rp " إضافة صلاحية (أيام): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}رقم غير صحيح.${NC}"; pause_return; return; fi

    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$ZIVPN_USER_DB"

    echo -e "\n${GREEN}✔ تم تمديد المستخدم '$ext_pass' بنجاح!${NC}\nالانتهاء الجديد: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_zivpn() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}قائمة مستخدمي ZiVPN${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "\n لا يوجد مستخدمين نشطين.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "كلمة المرور" "تاريخ الانتهاء"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$ZIVPN_USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " إجمالي المستخدمين النشطين: ${YELLOW}$(wc -l < "$ZIVPN_USER_DB")${NC}"
    fi
    pause_return
}


add_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}إنشاء مستخدم Hysteria${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " أدخل كلمة المرور/سلسلة المصادقة: " new_pass

    if grep -qw "^$new_pass" "$HYST_USER_DB" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$HYST_CONFIG" >/dev/null; then
        echo -e "\n${RED}خطأ: المستخدم/كلمة المرور موجود بالفعل!${NC}"
        pause_return; return
    fi
    read -rp " الصلاحية (أيام): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}رقم غير صحيح.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")

    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    echo "$new_pass $exp_date" >> "$HYST_USER_DB"
    systemctl restart hysteria-server

    OBFS_VAL=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "KINGDOM")

    echo -e "\n${GREEN}✔ تم إنشاء المستخدم بنجاح!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
    echo -e " ${BOLD}الدومين:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
    echo -e " ${BOLD}نطاق المنافذ:${NC}  ${YELLOW}20000-50000 (-> 36712)${NC}"
    echo -e " ${BOLD}المستخدم (كلمة المرور):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${OBFS_VAL}${NC}"
    echo -e " ${BOLD}تاريخ الانتهاء:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_hysteria() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}حذف مستخدم Hysteria${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "لا يوجد مستخدمين."; pause_return; return; fi
    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] المستخدم: "$2" | الانتهاء: "$3}'
    echo ""
    read -rp " أدخل رقم ID المستخدم المراد حذفه: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID غير صحيح.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$HYST_USER_DB" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID غير موجود.${NC}"; pause_return; return; fi

    jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    sed -i "${del_id}d" "$HYST_USER_DB"
    systemctl restart hysteria-server
    echo -e "\n${GREEN}✔ تم حذف المستخدم '$del_pass' بنجاح!${NC}"
    pause_return
}

extend_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تمديد مستخدم Hysteria${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "لا يوجد مستخدمين."; pause_return; return; fi

    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] المستخدم: "$2" | الانتهاء: "$3}'
    echo ""
    read -rp " أدخل رقم ID المستخدم المراد تمديده: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID غير صحيح.${NC}"; pause_return; return; fi

    ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID غير موجود.${NC}"; pause_return; return; fi

    read -rp " أيام للإضافة: " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}رقم غير صحيح.${NC}"; pause_return; return; fi

    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB"

    echo -e "\n${GREEN}✔ تم تمديد المستخدم '$ext_pass' بنجاح!${NC}\nالانتهاء الجديد: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}قائمة مستخدمي Hysteria${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "\n لا يوجد مستخدمين نشطين.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "كلمة المرور" "تاريخ الانتهاء"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$HYST_USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " إجمالي المستخدمين النشطين: ${YELLOW}$(wc -l < "$HYST_USER_DB")${NC}"
    fi
    pause_return
}

speed_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تعديل سرعات الرفع/التحميل${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_up=$(jq -r '.inbounds[0].up_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    current_down=$(jq -r '.inbounds[0].down_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    echo -e " الرفع الحالي:    ${YELLOW}${current_up} Mbps${NC}"
    echo -e " التحميل الحالي:    ${YELLOW}${current_down} Mbps${NC}\n"
    read -rp " أدخل سرعة الرفع الجديدة (Mbps): " new_up
    read -rp " أدخل سرعة التحميل الجديدة (Mbps): " new_down
    if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
        jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
        systemctl restart hysteria-server
        echo -e "\n${GREEN}✔ تم تحديث السرعات بنجاح!${NC}"
    else echo -e "\n${RED}إدخال غير صحيح. الأرقام فقط.${NC}"; fi
    pause_return
}

change_obfs_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تغيير Obfs لـ Hysteria${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_obfs=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "KINGDOM")
    echo -e " Obfs الحالي: ${YELLOW}${current_obfs}${NC}\n"
    read -rp " أدخل Obfs الجديد: " new_obfs
    if [ -n "$new_obfs" ]; then
        jq ".inbounds[0].obfs = \"$new_obfs\"" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
        systemctl restart hysteria-server
        echo -e "\n${GREEN}✔ تم تحديث Obfs إلى: $new_obfs${NC}"
    else echo -e "\n${RED}تم الإلغاء.${NC}"; fi
    pause_return
}

print_hysteria2_link() {
  local user="$1" token="$2" encoded_token encoded_obfs insecure
  encoded_token=$(jq -nr --arg v "$token" '$v|@uri')
  encoded_obfs=$(jq -nr --arg v "$(jq -r '.obfs.salamander.password' "$HYST2_CONFIG")" '$v|@uri')
  insecure="1"
  echo "hysteria2://${encoded_token}@${DOMAIN}:${HYST2_PORT}?insecure=${insecure}&sni=${DOMAIN}&obfs=salamander&obfs-password=${encoded_obfs}#${user}-HY2"
}

add_hysteria2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}إنشاء حساب Hysteria 2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " المستخدم: " user
    [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || { echo -e "\n${RED}اسم مستخدم غير صحيح.${NC}"; pause_return; return; }
    if awk -v u="$user" '$1 == u {found=1} END {exit !found}' "$HYST2_USER_DB" 2>/dev/null; then
        echo -e "\n${RED}المستخدم موجود بالفعل.${NC}"; pause_return; return
    fi
    read -rp " الصلاحية (أيام): " days
    [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "\n${RED}صلاحية غير صحيحة.${NC}"; pause_return; return; }

    read -rp " هل تريد استخدام رمز/UUID مخصص؟ (y/N): " custom_token_prompt
    if [[ "$custom_token_prompt" =~ ^[Yy]$ ]]; then
        read -rp " أدخل الرمز/UUID المخصص: " token
        if [[ -z "$token" ]] || [[ "$token" =~ [[:space:]] ]]; then
            echo -e "\n${RED}رمز غير صحيح: لا يمكن أن يكون فارغًا أو يحتوي على مسافات.${NC}"; pause_return; return
        fi
        if awk -v t="$token" '$2 == t {found=1} END {exit !found}' "$HYST2_USER_DB" 2>/dev/null; then
            echo -e "\n${RED}هذا الرمز مستخدم بالفعل من قبل مستخدم آخر لـ Hysteria 2.${NC}"; pause_return; return
        fi
    else
        token=$(cat /proc/sys/kernel/random/uuid)
    fi

    exp=$(date -d "+${days} days" +%Y-%m-%d)
    printf '%s %s %s\n' "$user" "$token" "$exp" >> "$HYST2_USER_DB"
    chmod 600 "$HYST2_USER_DB"
    echo -e "\n${GREEN}✔ تم إنشاء حساب Hysteria 2.${NC}\nالمستخدم: $user\nالرمز: $token\nالانتهاء: $exp\n"
    print_hysteria2_link "$user" "$token"
    pause_return
}

del_hysteria2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}حذف مستخدم Hysteria 2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    [ -s "$HYST2_USER_DB" ] || { echo "لا يوجد مستخدمين Hysteria 2."; pause_return; return; }
    nl -w2 -s'. ' "$HYST2_USER_DB"
    read -rp " ID المستخدم المراد حذفه: " id
    [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "\n${RED}ID غير صحيح.${NC}"; pause_return; return; }
    user=$(sed -n "${id}p" "$HYST2_USER_DB" | awk '{print $1}')
    [ -n "$user" ] || { echo -e "\n${RED}ID غير موجود.${NC}"; pause_return; return; }
    sed -i "${id}d" "$HYST2_USER_DB"
    echo -e "\n${GREEN}✔ تم حذف مستخدم Hysteria 2 '$user'.${NC}"
    pause_return
}

extend_hysteria2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تمديد مستخدم Hysteria 2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    [ -s "$HYST2_USER_DB" ] || { echo "لا يوجد مستخدمين Hysteria 2."; pause_return; return; }
    nl -w2 -s'. ' "$HYST2_USER_DB"
    read -rp " ID المستخدم المراد تمديده: " id
    [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "\n${RED}ID غير صحيح.${NC}"; pause_return; return; }
    line=$(sed -n "${id}p" "$HYST2_USER_DB")
    user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line"); old_exp=$(awk '{print $3}' <<< "$line")
    [ -n "$user" ] || { echo -e "\n${RED}ID غير موجود.${NC}"; pause_return; return; }
    read -rp " أيام للإضافة: " days
    [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "\n${RED}صلاحية غير صحيحة.${NC}"; pause_return; return; }
    base="$old_exp"; [ "$old_exp" \< "$(date +%Y-%m-%d)" ] && base="$(date +%Y-%m-%d)"
    new_exp=$(date -d "$base +${days} days" +%Y-%m-%d)
    sed -i "${id}s/.*/$user $token $new_exp/" "$HYST2_USER_DB"
    echo -e "\n${GREEN}✔ تم تمديد مستخدم Hysteria 2 حتى $new_exp.${NC}"
    pause_return
}

list_hysteria2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}قائمة مستخدمي Hysteria 2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ -s "$HYST2_USER_DB" ]; then nl -w2 -s'. ' "$HYST2_USER_DB"; else echo "لا يوجد مستخدمين."; fi
    pause_return
}

show_hysteria2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}رابط Hysteria 2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    [ -s "$HYST2_USER_DB" ] || { echo "لا يوجد مستخدمين Hysteria 2."; pause_return; return; }
    nl -w2 -s'. ' "$HYST2_USER_DB"
    read -rp " ID المستخدم: " id
    line=$(sed -n "${id}p" "$HYST2_USER_DB")
    user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line")
    [ -n "$user" ] || { echo -e "\n${RED}ID غير موجود.${NC}"; pause_return; return; }
    echo
    print_hysteria2_link "$user" "$token"
    pause_return
}

add_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}إنشاء حساب Xray${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e " [1] VLESS (TCP, WS, XHTTP, HTTPUpgrade و gRPC)"
  echo -e " [2] VMESS (TCP, WS, XHTTP, HTTPUpgrade و gRPC)"
  echo -e " [3] TROJAN (TLS)"
  echo -e " [4] الكل-في-واحد (VLESS + VMESS + TROJAN)"
  read -rp " اختر البروتوكول: " prot
  read -rp " اسم المستخدم: " user

  if grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
    echo -e "${RED}اسم المستخدم موجود بالفعل!${NC}"; pause_return; return
  fi

  read -rp " الصلاحية (أيام): " masa
  exp=$(date -d "+${masa} days" +"%Y-%m-%d")

  read -rp " هل تريد استخدام UUID مخصص؟ (y/N): " custom_uuid_prompt
  if [[ "$custom_uuid_prompt" =~ ^[Yy]$ ]]; then
    read -rp " أدخل UUID المخصص: " uuid
  else
    uuid=$(cat /proc/sys/kernel/random/uuid)
  fi

  pass="KINGDOM${uuid:0:6}"

  VLESS_TAGS='["vless-tls-dispatcher","vless-tcp-http","vless-plain-public","vless-ws","vless-xhttp","vless-httpupgrade","vless-grpc"]'
  VMESS_TAGS='["vmess-tcp-http","vmess-ws","vmess-xhttp","vmess-httpupgrade","vmess-grpc"]'
  TROJAN_TAGS='["trojan-ws"]'

  if [ "$prot" == "1" ]; then
    jq --arg uuid "$uuid" --arg user "$user" --argjson tags "$VLESS_TAGS" \
      '(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"id": $uuid, "email": $user}]' \
      /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vless.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}تم إنشاء حساب VLESS${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "المستخدم  : $user\nالانتهاء   : $exp"
  echo -e "\n${YELLOW}[ VLESS TLS / منفذ مشترك 443 ]${NC}\n"
  echo -e "TCP HTTP:  vless://${uuid}@${DOMAIN}:443?type=tcp&headerType=http&security=tls&encryption=none&host=${DOMAIN}&path=%2Fvless-tcp&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-TCP\n"
  echo -e "WS:        vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-WS\n"
  echo -e "XHTTP:     vless://${uuid}@${DOMAIN}:443?type=xhttp&security=tls&encryption=none&path=%2Fxhttp&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}&mode=auto&alpn=h2%2Chttp%2F1.1#${user}-VLESS-XHTTP\n"
  echo -e "HTTPUp:    vless://${uuid}@${DOMAIN}:443?type=httpupgrade&security=tls&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-HTTPUp\n"
  echo -e "gRPC:      vless://${uuid}@${DOMAIN}:443?type=grpc&security=tls&encryption=none&serviceName=grpc-svc&sni=${DOMAIN}${INSECURE_PARAM}&alpn=h2#${user}-VLESS-gRPC\n"

  echo -e "${YELLOW}[ VLESS NTLS (80/8080/8880) ]${NC}\n"
  echo -e "TCP: vless://${uuid}@${DOMAIN}:80?type=tcp&headerType=http&security=none&encryption=none&path=%2Fvless-tcp&host=${DOMAIN}#${user}-VLESS-NTLS-TCP\n"
  echo -e "WS:  vless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}-VLESS-NTLS-WS\n"
  echo -e "HUP: vless://${uuid}@${DOMAIN}:80?type=httpupgrade&security=none&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}#${user}-VLESS-NTLS-HTTPUp\n"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"

  elif [ "$prot" == "2" ]; then
    jq --arg uuid "$uuid" --arg user "$user" --argjson tags "$VMESS_TAGS" \
      '(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"id": $uuid, "alterId": 0, "email": $user}]' \
      /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}تم إنشاء حساب VMESS${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "المستخدم: $user\nالانتهاء: $exp"
      echo -e "\n${YELLOW}[ VMESS TLS / المنفذ 443 ]${NC}"
VMESS_TCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "TCP:        vmess://$(echo -n "$VMESS_TCP_JSON" | base64 -w 0)"
VMESS_WS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "WS:         vmess://$(echo -n "$VMESS_WS_JSON" | base64 -w 0)"
VMESS_XHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "XHTTP:      vmess://$(echo -n "$VMESS_XHTTP_JSON" | base64 -w 0)"
VMESS_HUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "HTTPUp:     vmess://$(echo -n "$VMESS_HUP_JSON" | base64 -w 0)"
VMESS_GRPC_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-gRPC\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc-svc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "gRPC:       vmess://$(echo -n "$VMESS_GRPC_JSON" | base64 -w 0)"
echo -e "\n${YELLOW}[ VMESS NTLS / المنفذ 80 ]${NC}"
VMESS_NTCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"\"}"
echo -e "TCP:        vmess://$(echo -n "$VMESS_NTCP_JSON" | base64 -w 0)"
VMESS_NWS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
echo -e "WS:         vmess://$(echo -n "$VMESS_NWS_JSON" | base64 -w 0)"
VMESS_NHUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"\"}"
echo -e "HTTPUp:     vmess://$(echo -n "$VMESS_NHUP_JSON" | base64 -w 0)"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"

  elif [ "$prot" == "3" ]; then
    jq --arg pass "$pass" --arg user "$user" --argjson tags "$TROJAN_TAGS" \
      '(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"password": $pass, "email": $user}]' \
      /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $pass $exp" >> /etc/xray/trojan.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}تم إنشاء حساب TROJAN${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "المستخدم: $user\nكلمة المرور: $pass\nالانتهاء: $exp"
    echo -e "\n${YELLOW}TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"

  elif [ "$prot" == "4" ]; then
    jq --arg uuid "$uuid" --arg pass "$pass" --arg user "$user" \
      --argjson vtags "$VLESS_TAGS" --argjson mtags "$VMESS_TAGS" --argjson ttags "$TROJAN_TAGS" \
      '(.inbounds[] | select(.tag as $t | $vtags | index($t)) | .settings.clients) += [{"id": $uuid, "email": $user}]
       | (.inbounds[] | select(.tag as $t | $mtags | index($t)) | .settings.clients) += [{"id": $uuid, "alterId": 0, "email": $user}]
       | (.inbounds[] | select(.tag as $t | $ttags | index($t)) | .settings.clients) += [{"password": $pass, "email": $user}]' \
      /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json

    echo "$user $uuid $exp" >> /etc/xray/vless.txt
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
    echo "$user $pass $exp" >> /etc/xray/trojan.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}تم إنشاء حساب الكل-في-واحد${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "المستخدم: $user\nالانتهاء:   $exp"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"

      echo -e "\n${YELLOW}[ VLESS TLS / منفذ مشترك 443 ]${NC}\n"
  echo -e "TCP HTTP:  vless://${uuid}@${DOMAIN}:443?type=tcp&headerType=http&security=tls&encryption=none&host=${DOMAIN}&path=%2Fvless-tcp&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-TCP\n"
  echo -e "WS:        vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-WS\n"
  echo -e "XHTTP:     vless://${uuid}@${DOMAIN}:443?type=xhttp&security=tls&encryption=none&path=%2Fxhttp&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}&mode=auto&alpn=h2%2Chttp%2F1.1#${user}-VLESS-XHTTP\n"
  echo -e "HTTPUp:    vless://${uuid}@${DOMAIN}:443?type=httpupgrade&security=tls&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-HTTPUp\n"
  echo -e "gRPC:      vless://${uuid}@${DOMAIN}:443?type=grpc&security=tls&encryption=none&serviceName=grpc-svc&sni=${DOMAIN}${INSECURE_PARAM}&alpn=h2#${user}-VLESS-gRPC\n"

  echo -e "${YELLOW}[ VLESS NTLS (80/8080/8880) ]${NC}\n"
  echo -e "TCP: vless://${uuid}@${DOMAIN}:80?type=tcp&headerType=http&security=none&encryption=none&path=%2Fvless-tcp&host=${DOMAIN}#${user}-VLESS-NTLS-TCP\n"
  echo -e "WS:  vless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}-VLESS-NTLS-WS\n"
  echo -e "HUP: vless://${uuid}@${DOMAIN}:80?type=httpupgrade&security=none&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}#${user}-VLESS-NTLS-HTTPUp\n"

  echo -e "\n${YELLOW}[ VMESS TLS / المنفذ 443 ]${NC}"
VMESS_TCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "TCP:        vmess://$(echo -n "$VMESS_TCP_JSON" | base64 -w 0)"
VMESS_WS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "WS:         vmess://$(echo -n "$VMESS_WS_JSON" | base64 -w 0)"
VMESS_XHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "XHTTP:      vmess://$(echo -n "$VMESS_XHTTP_JSON" | base64 -w 0)"
VMESS_HUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "HTTPUp:     vmess://$(echo -n "$VMESS_HUP_JSON" | base64 -w 0)"
VMESS_GRPC_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-gRPC\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc-svc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "gRPC:       vmess://$(echo -n "$VMESS_GRPC_JSON" | base64 -w 0)"
echo -e "\n${YELLOW}[ VMESS NTLS / المنفذ 80 ]${NC}"
VMESS_NTCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"\"}"
echo -e "TCP:        vmess://$(echo -n "$VMESS_NTCP_JSON" | base64 -w 0)"
VMESS_NWS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
echo -e "WS:         vmess://$(echo -n "$VMESS_NWS_JSON" | base64 -w 0)"
VMESS_NHUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"\"}"
echo -e "HTTPUp:     vmess://$(echo -n "$VMESS_NHUP_JSON" | base64 -w 0)"

    echo -e "\n${YELLOW}[ TROJAN TLS (443) ]${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  fi
  systemctl restart xray
  pause_return
}

del_xray() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}حذف حساب Xray${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"

  mapfile -t users < <(cat /etc/xray/*.txt 2>/dev/null | awk '{print $1}' | sort -u)

  if [ ${#users[@]} -eq 0 ]; then
      echo -e "${YELLOW}لا يوجد مستخدمين Xray.${NC}"; pause_return; return
  fi
  for i in "${!users[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${users[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] إلغاء\n"

  read -rp "  اختر المستخدم المراد حذفه: " idx
  if [[ "$idx" == "00" || "$idx" == "0" ]]; then return; fi
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -le 0 ] || [ "$idx" -gt "${#users[@]}" ]; then
      echo -e "${RED}اختيار غير صحيح.${NC}"; pause_return; return
  fi

  user="${users[$((idx-1))]}"
  jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
  sed -i "/^$user /d" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null
  systemctl restart xray
  echo -e "\n${GREEN}✔ تم حذف المستخدم $user بنجاح.${NC}"
  pause_return
}

renew_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}تجديد حساب Xray${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " المستخدم المراد تجديده: " user

  if ! grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
    echo -e "${RED}المستخدم غير موجود.${NC}"; pause_return; return
  fi
  read -rp " أيام للإضافة: " days
  for proto in vless vmess trojan; do
    if grep -qw "^$user" "/etc/xray/${proto}.txt"; then
      current_exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
      new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
      sed -i "s/^$user .* $current_exp/$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $1 " " $2}') $new_exp/" "/etc/xray/${proto}.txt"
    fi
  done
  echo -e "\n${GREEN}✔ تم تجديد المستخدم '$user' بنجاح.${NC}\nالانتهاء الجديد: $new_exp"
  pause_return
}

show_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}عرض روابط تهيئة Xray${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " المستخدم المراد عرضه: " user
  local found=0
  if grep -qw "^$user" /etc/xray/vless.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vless.txt | awk '{print $2}')
    echo -e "${YELLOW}VLESS TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
    echo -e "\n${YELLOW}VLESS NTLS (80):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/vmess.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vmess.txt | awk '{print $2}')
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "${YELLOW}VMESS TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}VMESS NTLS (80):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/trojan.txt; then
    pass=$(grep -w "^$user" /etc/xray/trojan.txt | awk '{print $2}')
    echo -e "${YELLOW}TROJAN TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}\n"
    found=1
  fi
  if [ "$found" -eq 0 ]; then echo -e "${RED}المستخدم غير موجود في أي بروتوكول.${NC}"; fi
  pause_return
}

list_real_users() { awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null; }

select_user() {
  local purpose="$1"
  mapfile -t USERS < <(list_real_users)
  if [ "${#USERS[@]}" -eq 0 ]; then echo -e "${RED}لا توجد حسابات مستخدمين نشطة.${NC}"; return 1; fi
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!USERS[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${USERS[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] رجوع\n"
  read -rp "  اختر رقم الحساب: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return 1
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}" ]; then echo -e "${RED}  اختيار غير صحيح.${NC}"; return 1; fi
  SELECTED_USER="${USERS[$((idx-1))]}"
  return 0
}

create_user() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}إنشاء مستخدم SSH جديد${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${YELLOW}(اكتب 00 في أي حقل للإلغاء والعودة)${NC}\n"

  while true; do
    read -rp "  اسم المستخدم: " user
    user="$(echo -n "$user" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "$user" = "00" ] && return
    if [ -z "$user" ]; then echo -e "${RED}  خطأ: اسم المستخدم لا يمكن أن يكون فارغًا.${NC}\n"; continue; fi
    if ! [[ "$user" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]; then echo -e "${RED}  خطأ: اسم غير صحيح (حروف/أرقام/شرطات، بدون مسافات).${NC}\n"; continue; fi
    if id "$user" >/dev/null 2>&1; then echo -e "${RED}  خطأ: المستخدم '$user' موجود بالفعل.${NC}\n"; continue; fi
    break
  done

  while true; do
    read -rp "  كلمة المرور: " pass
    pass="$(echo -n "$pass" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "$pass" = "00" ] && return
    if [ -z "$pass" ]; then echo -e "${RED}  خطأ: كلمة المرور لا يمكن أن تكون فارغة.${NC}\n"; continue; fi
    if [[ "$pass" =~ [[:space:]] ]]; then echo -e "${RED}  خطأ: كلمة المرور لا يمكن أن تحتوي على مسافات.${NC}\n"; continue; fi
    break
  done

  while true; do
    read -rp "  الصلاحية (أيام): " days
    days="$(echo -n "$days" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "$days" = "00" ] && return
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -eq 0 ]; then echo -e "${RED}  خطأ: يجب أن يكون عدد أيام أكبر من 0.${NC}\n"; continue; fi
    break
  done

  while true; do
    read -rp "  حد الاتصالات المتزامنة (0 = بدون حد): " conn_limit
    conn_limit="$(echo -n "$conn_limit" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "$conn_limit" = "00" ] && return
    [ -z "$conn_limit" ] && conn_limit=0
    if ! [[ "$conn_limit" =~ ^[0-9]+$ ]]; then echo -e "${RED}  خطأ: يجب أن يكون رقمًا.${NC}\n"; continue; fi
    break
  done

  ua_err=$(useradd --badname -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" 2>&1 1>/dev/null)
  if [ $? -ne 0 ]; then
    echo -e "\n${RED}  خطأ: تعذر إنشاء المستخدم '$user'.${NC}"
    echo -e "  ${YELLOW}التفاصيل:${NC} ${ua_err:-غير معروف}"
    echo "$(date '+%F %T') create_user فشل useradd user=$user :: ${ua_err:-غير معروف}" >> /var/log/deekayvpn-menu-errors.log
    pause_return; return
  fi
  cp_err=$(echo "$user:$pass" | chpasswd 2>&1 1>/dev/null)
  if [ $? -ne 0 ]; then
    echo -e "\n${RED}  خطأ: تعذر تعيين كلمة المرور. جاري حذف الحساب غير المكتمل...${NC}"
    echo -e "  ${YELLOW}التفاصيل:${NC} ${cp_err:-غير معروف}"
    echo "$(date '+%F %T') create_user فشل chpasswd user=$user :: ${cp_err:-غير معروف}" >> /var/log/deekayvpn-menu-errors.log
    userdel -f "$user" 2>/dev/null
    pause_return; return
  fi

  sed -i "/^$user /d" "$SSH_LIMIT_DB" 2>/dev/null
  if [ "$conn_limit" -gt 0 ]; then echo "$user $conn_limit" >> "$SSH_LIMIT_DB"; fi

  IP=$(curl -s ipv4.icanhazip.com)
  CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')

  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}تم إنشاء الحساب بنجاح${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}الدومين/المضيف${NC}: ${YELLOW}$DOMAIN${NC}"
  echo -e "  ${BOLD}عنوان IP${NC} : ${YELLOW}$IP${NC}"
  echo -e "  ${BOLD}المستخدم${NC}   : ${YELLOW}$user${NC}"
  echo -e "  ${BOLD}كلمة المرور${NC}   : ${YELLOW}$pass${NC}"
  echo -e "  ${BOLD}الانتهاء${NC}     : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
  echo -e "  ${BOLD}حد الاتصالات${NC}: ${YELLOW}$([ "$conn_limit" -gt 0 ] && echo "$conn_limit" || echo "بدون حد")${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  منفذ SSH   : 22, 299"
  echo -e "  SSL/TLS    : 443"
  echo -e "  SSL/WS     : 443"
  echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086, 25"
  echo -e "  SlowDNS/SlipStream (dnsdist): 53"
  echo -e "  BadVPN     : 7300"
  echo -e "  UDP Custom : 1-65535"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}الحمولة HTTP     :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e ""
  echo -e "  ${BOLD}الحمولة المحسّنة :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-غير مهيأ}${NC}"
  echo -e "  ${BOLD}SlipStream ${NC}: ${YELLOW}${SLIPSTREAM_DOMAIN}${NC}"
  echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "حذف مستخدم SSH"; then pause_return; return; fi
  clear; echo -e "${RED}تحذير: أنت على وشك حذف المستخدم: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "هل أنت متأكد؟ [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    pkill -u "$SELECTED_USER" 2>/dev/null

    if userdel -r -f "$SELECTED_USER" 2>/dev/null || userdel -f "$SELECTED_USER" 2>/dev/null; then
        sed -i "/^$SELECTED_USER /d" "$SSH_LIMIT_DB" 2>/dev/null
        echo -e "${GREEN}تم حذف المستخدم $SELECTED_USER.${NC}"
    else
        echo -e "${RED}فشل حذف $SELECTED_USER. تحقق من الملفات المحجوبة.${NC}"
    fi
  fi
  pause_return
}

extend_user() {
  if ! select_user "تمديد صلاحية المستخدم"; then pause_return; return; fi
  clear; echo -e "جاري تمديد حساب: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "أدخل عدد الأيام للإضافة: " days
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}تنسيق رقم غير صحيح.${NC}"; pause_return; return; fi
  current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
  if [ "$current" = "never" ] || [ -z "$current" ]; then new_exp=$(date -d "+$days days" +%Y-%m-%d)
  else new_exp=$(date -d "$current +$days days" +%Y-%m-%d); fi
  chage -E "$new_exp" "$SELECTED_USER"
  echo -e "${GREEN}نجاح!${NC} تم تمديد الحساب.\nتاريخ الانتهاء الجديد: ${YELLOW}$new_exp${NC}"
  pause_return
}

online_users() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "               ${BOLD}مراقبة الجلسات النشطة${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

  echo -e "${YELLOW}--- SSH القديم ---${NC}"
  declare -A active_ssh
  mapfile -t USERS < <(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null)

  for user in "${USERS[@]}"; do
      ssh_count=$(ps -u "$user" 2>/dev/null | grep -c "sshd")
      total=$ssh_count
      if [ "$total" -gt 0 ]; then active_ssh["$user"]=$total; fi
  done

  if [ "${#active_ssh[@]}" -eq 0 ]; then
      echo -e "  لا يوجد مستخدمين SSH قديم موثقين حاليًا.\n"
  else
    printf "  %-25s %-15s\n" "اسم المستخدم" "الجلسات النشطة"
    echo -e "${CYAN}  ----------------------------------------------------------${NC}"
    for user in "${!active_ssh[@]}"; do
        if [ "${active_ssh[$user]}" -gt 1 ]; then
            printf "  %-25s ${RED}%-15s (دخول متعدد)${NC}\n" "$user" "${active_ssh[$user]}"
        else
            printf "  %-25s ${GREEN}%-15s${NC}\n" "$user" "${active_ssh[$user]}"
        fi
    done | sort
    echo
  fi

  echo -e "${YELLOW}--- جلسات Xray Core النشطة (عناوين IP فريدة حديثة) ---${NC}"
  if grep -q '"loglevel": "warning"' /etc/xray/config.json 2>/dev/null; then
      sed -i 's/"loglevel": "warning"/"loglevel": "info"/g' /etc/xray/config.json
      systemctl restart xray 2>/dev/null
      echo -e "  [ملاحظة النظام] تم تمكين تسجيل Xray. أعد اتصال المستخدمين لرؤية السجلات.\n"
  elif [ -f /var/log/xray/access.log ]; then
      active_xray=$(tail -n 10000 /var/log/xray/access.log 2>/dev/null | grep "accepted" | awk '{ user=""; for(i=1;i<=NF;i++) if($i=="email:") user=$(i+1); if(user!="") { split($3, a, ":"); print user " " a[1] } }' | sort -u | awk '{print $1}' | uniq -c | sort -nr)
      if [ -z "$active_xray" ]; then
          echo -e "  لم يتم العثور على مستخدمين نشطين لـ Xray في السجلات الحديثة.\n"
      else
          printf "  %-15s %-25s\n" "عناوين IP فريدة" "اسم المستخدم"
          echo -e "${CYAN}  ----------------------------------------------------------${NC}"
          while read -r count username; do
              if [ -n "$username" ]; then
                  if [ "$count" -gt 1 ]; then
                      printf "  ${RED}%-15s${NC} %-25s ${RED}(عنوان IP متعدد)${NC}\n" "$count" "$username"
                  else
                      printf "  %-15s %-25s\n" "$count" "$username"
                  fi
              fi
          done <<< "$active_xray"
      fi
  else echo -e "  سجل الوصول لـ Xray غير موجود.\n"; fi

  pause_return
}

restart_service() {
  local service_name="$1"
  local display_name="$2"
  echo -e "جاري إعادة تشغيل ${display_name}..."
  systemctl restart $service_name 2>/dev/null || true
  echo -e "${GREEN}✔ تم إعادة تشغيل ${display_name}.${NC}"
}

service_control_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}التحكم في الخدمات${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] إعادة تشغيل جميع الخدمات"
    echo -e "  [${YELLOW}02${NC}] إعادة تشغيل SSH"
    echo -e "  [${YELLOW}03${NC}] إعادة تشغيل وكلاء WebSocket الخاصة بـ Node"
    echo -e "  [${YELLOW}04${NC}] إعادة تشغيل Stunnel و Xray Core"
    echo -e "  [${YELLOW}05${NC}] إعادة تشغيل وكيل Squid و Nginx"
    echo -e "  [${YELLOW}06${NC}] إعادة تشغيل نواة UDP (SlowDNS / Hysteria / BadVPN)"
    echo -e "  [${YELLOW}07${NC}] إعادة تشغيل المضاعف (dnsdist / Slipstream / Dante)"
    echo -e "  [${YELLOW}00${NC}] رجوع\n"
    read -rp "  اختر خيارًا: " opt
    case "$opt" in
      1|01) restart_service "ssh stunnel4 sslh squid nginx server-sldns hysteria-server hysteria2-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray slipstream danted dnsdist" "جميع الخدمات"; pause_return ;;
      2|02) restart_service "ssh" "SSH"; pause_return ;;
      3|03) restart_service "ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086" "وكلاء WebSocket لـ Node"; pause_return ;;
      4|04) restart_service "stunnel4 xray" "Stunnel و Xray Core"; pause_return ;;
      5|05) restart_service "squid nginx" "وكيل Squid و Nginx"; pause_return ;;
      6|06) restart_service "server-sldns hysteria-server hysteria2-server badvpn" "خدمات UDP الأساسية"; pause_return ;;
      7|07) restart_service "dnsdist slipstream danted" "المضاعف (dnsdist/Slipstream/Dante)"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}خيار غير صحيح.${NC}"; sleep 1 ;;
    esac
  done
}

backup_snapshot() {
  clear; local out="/root/KINGDOM_tunnel_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo -e "جاري ضغط إعدادات الخادم..."
  tar -czf "$out" /etc/ssh /etc/stunnel /etc/squid /etc/hysteria /etc/hysteria2 /etc/deekayvpn /etc/systemd/system/ws-proxy@.service /etc/xray 2>/dev/null
  echo -e "\n${GREEN}✔ تم إنشاء النسخ الاحتياطي بنجاح!${NC}\nالموقع: ${YELLOW}$out${NC}"
  pause_return
}

restore_snapshot() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}استعادة التهيئة${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  shopt -s nullglob
  backups=(/root/hex_tunnel_backup_*.tar.gz)
  if [ ${#backups[@]} -eq 0 ]; then echo -e "${RED}  لا توجد ملفات نسخ احتياطي في /root/.${NC}"; pause_return; return; fi
  echo -e "  النسخ الاحتياطي المتاحة:\n"
  for i in "${!backups[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"; done
  echo -e "\n  [${YELLOW}00${NC}] إلغاء\n"
  read -rp "  اختر النسخة الاحتياطية للاستعادة: " sel
  if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
  idx=$((sel-1))
  if [ -n "${backups[$idx]}" ]; then
    echo -e "\nجاري استعادة ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
    tar -xzf "${backups[$idx]}" -C /
    systemctl daemon-reload; systemctl restart ssh stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray slipstream danted dnsdist 2>/dev/null || true
    echo -e "${GREEN}✔ تمت الاستعادة بنجاح!${NC}"
  else echo -e "${RED}اختيار غير صحيح.${NC}"; fi
  pause_return
}

utilities_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}أدوات النظام${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}1${NC}] تفعيل BBR الأصلي للنواة (سريع وصامت)"
    echo -e "  [${YELLOW}2${NC}] التحقق من فتح Netflix والبث (بالإنجليزية)"
    echo -e "  [${YELLOW}0${NC}] رجوع\n"
    read -rp "  اختر خيارًا: " subopt
    case "$subopt" in
      1)
         echo -e "\nجاري تفعيل BBR الأصلي للنواة..."
         sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
         sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
         echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
         echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
         sysctl -p >/dev/null 2>&1
         if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null)" == *"bbr"* ]]; then echo -e "${GREEN}✔ تم تفعيل BBR بنجاح!${NC}"
         else echo -e "${RED}✖ فشل تفعيل BBR (قد لا تدعمه النواة).${NC}"; fi
         pause_return
         ;;
      2)
         clear
         echo -e "${YELLOW}جاري تشغيل فحص القيود الإقليمية (بالإنجليزية)...${NC}\n"
         bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en
         echo ""
         pause_return
         ;;
      0) break ;;
      *) echo -e "${RED}خيار غير صحيح.${NC}"; sleep 1 ;;
    esac
  done
}

change_domain() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تغيير دومين الخادم${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_dom=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || echo "غير مهيأ")
    current_cert=$(cat /etc/xray/cert_type 2>/dev/null || echo "غير معروف")
    echo -e " الدومين/IP الحالي: ${YELLOW}$current_dom${NC}  (الشهادة: ${YELLOW}$current_cert${NC})\n"
    read -rp " أدخل الدومين/IP الجديد: " new_dom

    if [ -z "$new_dom" ]; then echo -e "\n${RED}تم الإلغاء.${NC}"; pause_return; return; fi
    if [ "$new_dom" = "$current_dom" ]; then echo -e "\n${RED}نفس الدومين/IP، لا تغييرات.${NC}"; pause_return; return; fi

    SERVER_IP=$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')

    if [[ "$new_dom" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${YELLOW}جاري إنشاء شهادة موقعة ذاتيًا للـ IP $new_dom...${NC}"
        systemctl stop xray 2>/dev/null || true
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
          -keyout /etc/xray/xray.key \
          -out /etc/xray/xray.crt \
          -subj "/CN=${new_dom}/O=KINGDOM/C=US"
        echo "selfsigned" > /etc/xray/cert_type
        rm -f /etc/cron.d/certbot-renew
        NEW_CERT_TYPE="selfsigned"
    else
        echo -e "\n${YELLOW}جاري التحقق من أن $new_dom يحل إلى $SERVER_IP...${NC}"
        command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils >/dev/null 2>&1
        DOMAIN_IP=$(dig +short "$new_dom" @8.8.8.8 | tail -1)
        if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
            echo -e "\n${RED}✘ خطأ: $new_dom لا يشير إلى $SERVER_IP بعد.${NC}"
            echo -e "  أنشئ/صحح سجل A في DNS وحاول مجددًا. لم يتغير شيء."
            pause_return; return
        fi
        echo -e "${GREEN}تم التحقق من الدومين. جاري طلب شهادة Let's Encrypt...${NC}"
        command -v certbot >/dev/null 2>&1 || apt-get install -y certbot >/dev/null 2>&1
        systemctl stop xray 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        if ! certbot certonly --standalone --non-interactive --agree-tos --email "admin@${new_dom}" -d "${new_dom}"; then
            echo -e "\n${RED}✘ فشل إصدار شهادة Let's Encrypt. لم يتغير الدومين.${NC}"
            systemctl start xray 2>/dev/null || true
            pause_return; return
        fi
        cp "/etc/letsencrypt/live/${new_dom}/fullchain.pem" /etc/xray/xray.crt
        cp "/etc/letsencrypt/live/${new_dom}/privkey.pem" /etc/xray/xray.key
        echo "letsencrypt" > /etc/xray/cert_type
        NEW_CERT_TYPE="letsencrypt"

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

    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem
    chown root:root /etc/stunnel/stunnel.pem

    echo "$new_dom" > /etc/deekayvpn/domain.txt
    DOMAIN="$new_dom"

    systemctl start xray 2>/dev/null || true
    if ! /usr/local/bin/xray run -test -config /etc/xray/config.json >/dev/null 2>&1; then
        echo -e "\n${RED}✘ تحذير: الشهادة الجديدة لم تجتاز التحقق من صحة Xray.${NC}"
    fi
    systemctl restart xray stunnel4 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true

    echo -e "\n${GREEN}✔ تم تحديث الدومين إلى: $new_dom${NC}"
    echo -e "${GREEN}✔ تم إعادة إنشاء الشهادة (${NEW_CERT_TYPE}) وإعادة تشغيل Xray/Stunnel.${NC}"
    echo -e "${YELLOW}ملاحظة: الروابط vless/vmess/trojan التي أعطيتها للمستخدمين كانت تستخدم الدومين/الشهادة القديمة.${NC}"
    echo -e "${YELLOW}أنشئ روابط جديدة من قائمة Xray (الخيار 4، عرض الروابط).${NC}"
    pause_return
}

change_slowdns() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}تغيير Nameserver لـ SlowDNS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    svc_file="/etc/systemd/system/server-sldns.service"
    if [ ! -f "$svc_file" ]; then echo -e "${RED}ملف خدمة SlowDNS غير موجود.${NC}"; pause_return; return; fi
    current_ns=$(grep 'ExecStart=' "$svc_file" | sed 's/.*server\.key \([^ ]*\) .*/\1/')
    echo -e " Nameserver الحالي: ${YELLOW}$current_ns${NC}\n"
    read -rp " أدخل Nameserver الجديد (مثال: ns1.dominio.com): " new_ns
    ss_dom=$(cat /etc/deekayvpn/slipstream_domain.txt 2>/dev/null || echo "")
    if [ -n "$new_ns" ] && [ "$new_ns" = "$ss_dom" ]; then
        echo -e "\n${RED}✘ هذا الدومين مستخدم بالفعل بواسطة Slipstream. لا يمكن أن يتساوى الدومين في dnsdist.${NC}"
        pause_return; return
    fi
    if [ -n "$new_ns" ] && [ "$new_ns" != "$current_ns" ]; then
        sed -i "s/$current_ns/$new_ns/g" "$svc_file"
        systemctl daemon-reload; systemctl restart server-sldns
        echo -e "\n${GREEN}✔ تم تحديث Nameserver لـ SlowDNS إلى: $new_ns${NC}"
    else echo -e "\n${RED}تم الإلغاء أو إدخال نفس NS.${NC}"; fi
    pause_return
}

change_slipstream() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}SLIPSTREAM${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    svc_file="/etc/systemd/system/slipstream.service"
    dnsdist_conf="/etc/dnsdist/dnsdist.conf"
    sldns_svc="/etc/systemd/system/server-sldns.service"

    if [ ! -f "$svc_file" ]; then
        echo -e " SlipStream غير مثبت على هذا الخادم."
        read -rp " هل تريد تثبيته الآن؟ [y/N]: " ans
        if ! [[ "$ans" =~ ^[Yy]$ ]]; then echo -e "\n${RED}تم الإلغاء.${NC}"; pause_return; return; fi
        install_slipstream
        return
    fi

    current_dom=$(cat /etc/deekayvpn/slipstream_domain.txt 2>/dev/null || echo "غير مهيأ")
    echo -e " الدومين الحالي: ${YELLOW}$current_dom${NC}\n"
    read -rp " أدخل الدومين الجديد (Enter للإبقاء على الحالي): " new_dom
    [ -z "$new_dom" ] && { echo -e "\n${RED}لا تغييرات.${NC}"; pause_return; return; }
    current_ns=$(grep 'ExecStart=' "$sldns_svc" 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')
    if [ "$new_dom" = "$current_ns" ]; then
        echo -e "\n${RED}✘ هذا الدومين مستخدم بالفعل بواسطة SlowDNS. لا يمكن أن يتساوى الدومين في dnsdist.${NC}"
        pause_return; return
    fi
    if [ "$new_dom" != "$current_dom" ]; then
        sed -i "s/--domain ${current_dom} /--domain ${new_dom} /" "$svc_file"
        [ -f "$dnsdist_conf" ] && sed -i "s/${current_dom}\./${new_dom}./g" "$dnsdist_conf"
        echo "$new_dom" > /etc/deekayvpn/slipstream_domain.txt
        systemctl daemon-reload; systemctl restart slipstream dnsdist
        echo -e "\n${GREEN}✔ تم تحديث دومين Slipstream إلى: $new_dom${NC}"
    else echo -e "\n${RED}تم إدخال نفس الدومين، لا تغييرات.${NC}"; fi
    pause_return
}

install_slipstream() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تثبيت SLIPSTREAM${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    sldns_svc="/etc/systemd/system/server-sldns.service"
    if [ ! -f "$sldns_svc" ]; then
        echo -e "${RED}لم يتم العثور على خدمة SlowDNS. هذا الخادم ليس لديه الأساس المطلوب.${NC}"
        pause_return; return
    fi
    current_ns=$(grep 'ExecStart=' "$sldns_svc" | sed 's/.*server\.key \([^ ]*\) .*/\1/')

    SlowDNS_Internal_Port='5301'
    Slipstream_Internal_Port='5300'
    SlipstreamSocksPort='1080'
    SlipstreamInstallDir='/opt/slipstream-rust'
    SlipstreamPinnedCommit='bc772dd07d9a136dbd7553b0da575526de207847'
    DnsdistConf='/etc/dnsdist/dnsdist.conf'

    read -rp " أدخل الدومين لـ SlipStream (مثال: ss.${current_ns}): " -e -i "ss.${current_ns}" SlipstreamDomain
    while [ "$SlipstreamDomain" = "$current_ns" ]; do
        echo -e "\n${RED}✘ لا يمكن أن يكون مساويًا لـ Nameserver الخاص بـ SlowDNS ($current_ns).${NC}"
        read -rp " أدخل دومينًا مختلفًا لـ SlipStream: " -e -i "ss.$current_ns" SlipstreamDomain
    done

    echo -e "\n${GREEN}جاري تثبيت التبعيات...${NC}"
    command -v danted >/dev/null 2>&1 || apt-get install -y dante-server
    command -v dnsdist >/dev/null 2>&1 || apt-get install -y dnsdist
    apt-get install -y cmake pkg-config libssl-dev build-essential git >/dev/null 2>&1

    echo -e "${GREEN}جاري نقل SlowDNS إلى المنفذ الداخلي ${SlowDNS_Internal_Port}...${NC}"
    sed -i "s|-udp [^ ]* -privkey-file|-udp 127.0.0.1:${SlowDNS_Internal_Port} -privkey-file|" "$sldns_svc"
    systemctl daemon-reload; systemctl restart server-sldns

    echo -e "${GREEN}جاري تهيئة Dante SOCKS...${NC}"
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

    echo -e "${GREEN}جاري تثبيت Rust (إذا لزم الأمر)...${NC}"
    if ! command -v cargo &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
        source "$HOME/.cargo/env"
    else
        source "$HOME/.cargo/env" 2>/dev/null || true
    fi

    echo -e "${GREEN}جاري استنساخ وبناء Slipstream (يستغرق دقائق)...${NC}"
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
Description=خادم نفق DNS Slipstream
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
    echo "$SlipstreamDomain" > /etc/deekayvpn/slipstream_domain.txt

    echo -e "${GREEN}جاري تهيئة dnsdist كمضاعف على المنفذ 53...${NC}"
    mkdir -p "$(dirname "$DnsdistConf")"
    cat > "$DnsdistConf" <<DNSDIST_EOF
setLocal("0.0.0.0:53")

newServer({address="127.0.0.1:${SlowDNS_Internal_Port}", name="slowdns"})
newServer({address="127.0.0.1:${Slipstream_Internal_Port}", name="slipstream"})

addAction(SuffixMatchNodeRule("${current_ns}."), PoolAction("slowdns_pool"))
setPoolServers("slowdns_pool", {getServer(0)})

addAction(SuffixMatchNodeRule("${SlipstreamDomain}."), PoolAction("slipstream_pool"))
setPoolServers("slipstream_pool", {getServer(1)})

addAction(AllRule(), DropAction())
DNSDIST_EOF
    systemctl daemon-reload; systemctl enable dnsdist >/dev/null 2>&1; systemctl restart dnsdist

    if systemctl is-active --quiet slipstream && systemctl is-active --quiet dnsdist && systemctl is-active --quiet danted; then
        echo -e "\n${GREEN}✔ تم تثبيت SlipStream ومضاعفته مع SlowDNS على المنفذ 53.${NC}"
        echo -e "  دومين SlipStream : ${YELLOW}${SlipstreamDomain}${NC}"
        echo -e "  SOCKS داخلي      : 127.0.0.1:${SlipstreamSocksPort}"
    else
        echo -e "\n${RED}شيء لم يعمل بشكل صحيح. تحقق من:${NC}"
        echo -e "  journalctl -u slipstream --no-pager -n 30"
        echo -e "  journalctl -u dnsdist --no-pager -n 30"
        echo -e "  journalctl -u danted --no-pager -n 30"
    fi
    pause_return
}

change_status() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "             ${BOLD}تغيير رسالة الحالة (WS)${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    proxy_file="/etc/socksproxy/proxy.js"
    if [ ! -f "$proxy_file" ]; then echo -e "${RED}ملف proxy.js غير موجود.${NC}"; pause_return; return; fi
    line_num=$(grep -n "clientSocket.write('HTTP/1.1 101" "$proxy_file" | head -n1 | cut -d: -f1)
    if [ -z "$line_num" ]; then echo -e "${RED}لم يتم العثور على سطر الحالة في proxy.js.${NC}"; pause_return; return; fi
    current_status=$(sed -n "${line_num}p" "$proxy_file" | sed 's/^[[:space:]]*//')
    echo -e " السطر الحالي:\n ${YELLOW}${current_status}${NC}\n"
    echo -e " اكتب الرسالة كاملة: نص عادي أو HTML"
    echo -e " (مثال: <font color=\"red\">نصي</font> <b>إضافي</b>)."
    echo -e " ملاحظة: لا تستخدم علامات التنصيص المفردة (') داخل الرسالة.\n"
    read -rp " رسالة الحالة الجديدة: " new_status
    if [ -n "$new_status" ]; then
        esc_msg=$(printf '%s' "$new_status" | sed "s/'/’/g")
        awk -v ln="$line_num" -v msg="$esc_msg" 'NR==ln{printf "            clientSocket.write(%cHTTP/1.1 101 %s\\r\\n\\r\\n%c);\n", 39, msg, 39; next} {print}' "$proxy_file" > "${proxy_file}.tmp" && mv "${proxy_file}.tmp" "$proxy_file"
        for u in $(systemctl list-units --all --type=service --no-legend 'ws-proxy@*' 2>/dev/null | awk '{print $1}'); do systemctl restart "$u"; done
        echo -e "\n${GREEN}✔ تم تحديث رسالة الحالة.${NC}"
    else echo -e "\n${RED}تم الإلغاء.${NC}"; fi
    pause_return
}

change_banner() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}تحرير البانر (SSH / Stunnel)${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e " سيتم فتح البانر في nano لتعديله حسب رغبتك."
    echo -e " احفظ بـ ${YELLOW}CTRL+O${NC} + ENTER واخرج بـ ${YELLOW}CTRL+X${NC}.\n"
    read -rp " اضغط Enter للمتابعة أو اكتب 0 للإلغاء: " conf
    if [ "$conf" = "0" ]; then echo -e "\n${RED}تم الإلغاء.${NC}"; pause_return; return; fi
    nano /etc/zorro-luffy
    systemctl restart ssh stunnel4 2>/dev/null
    echo -e "\n${GREEN}✔ تم تحديث البانر وإعادة تشغيل الخدمات.${NC}"
    pause_return
}

advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}إعدادات متقدمة${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] عرض JSON الخام لـ Hysteria"
    echo -e "  [${YELLOW}02${NC}] عرض سجلات الخدمات (Journalctl)"
    echo -e "  [${YELLOW}03${NC}] تغيير دومين/IP الخادم"
    echo -e "  [${YELLOW}04${NC}] تغيير Nameserver لـ SlowDNS (NS)"
    echo -e "  [${RED}05${NC}] إلغاء تثبيت السكريبت بالكامل (خطر)"
    echo -e "  [${YELLOW}06${NC}] تغيير رسالة الحالة (WS, HTML/نص حر)"
    echo -e "  [${YELLOW}07${NC}] تحرير البانر (SSH / Stunnel)"
    echo -e "  [${YELLOW}08${NC}] SlipStream (تثبيت / تغيير الدومين)"
    echo -e "  [${YELLOW}09${NC}] إعادة تشغيل نواة UDP (SlowDNS/Hysteria/ZiVPN/UDP-Custom)"
    echo -e "  [${YELLOW}00${NC}] رجوع\n"
    read -rp "  اختر خيارًا: " opt
    case "$opt" in
      1|01) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "غير موجود."; pause_return ;;
    2|02)
        clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Hysteria  [4] Stunnel  [5] SlowDNS  [6] Xray  [7] Slipstream  [8] dnsdist (مضاعف)  [9] Dante SOCKS  [10] Hysteria 2\n"
        read -rp "اختر السجل: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy@10080 -n 50 --no-pager ;;
          3) journalctl -u hysteria-server -n 50 --no-pager ;;
          4) journalctl -u stunnel4 -n 50 --no-pager ;;
          5) journalctl -u server-sldns -n 50 --no-pager ;;
          6) journalctl -u xray -n 50 --no-pager ;;
          7) journalctl -u slipstream -n 50 --no-pager ;;
          8) journalctl -u dnsdist -n 50 --no-pager ;;
          9) journalctl -u danted -n 50 --no-pager ;;
          10) journalctl -u hysteria2-server -n 50 --no-pager ;;
        esac; pause_return ;;
      3|03) change_domain ;;
      4|04) change_slowdns ;;
      8|08) change_slipstream ;;
      6|06) change_status ;;
      7|07) change_banner ;;
      9|09) restart_service "server-sldns hysteria-server hysteria2-server badvpn udp-custom zivpn" "خدمات UDP الأساسية"; pause_return ;;
      5|05) remove_script ;;
      0|00) break ;;
    esac
  done
}

remove_script() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                     ${BOLD}إلغاء التثبيت الكامل${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  هل أنت متأكد تمامًا؟ [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo -e "\nجاري إيقاف الخدمات..."
      systemctl stop ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server sslh stunnel4 squid nginx xray slipstream danted dnsdist 2>/dev/null || true
      systemctl disable ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server xray slipstream danted dnsdist 2>/dev/null || true
      echo "جاري حذف الملفات..."
      rm -f /etc/systemd/system/ws-proxy@.service /etc/systemd/system/server-sldns.service /etc/systemd/system/badvpn.service /etc/systemd/system/xray.service /etc/systemd/system/slipstream.service /etc/systemd/system/hysteria2-server.service
      rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/cron.d/xray-expiry /etc/cron.d/hysteria-expiry /etc/cron.d/hysteria2-expiry /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
      rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /etc/xray /etc/hysteria /etc/hysteria2 /usr/local/bin/hysteria2 /usr/local/libexec/hysteria2-auth /etc/dnsdist /etc/danted.conf /opt/slipstream-rust /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
      systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
      echo -e "${GREEN}✔ تم الحذف الكامل.${NC}"
  else echo "تم الإلغاء."; fi
  pause_return
}

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

  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}KINDOM TUNNEL${NC}${BLUE}  ✸  ${YELLOW}${BOLD}بواسطة BILAL ACON SINKO${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} ${YELLOW}%s${NC}\n" "نظام:" "$os" "معمار:" "$arch" "أنوية:" "$cores"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} %s\n" "IP:" "$ip" "وقت:" "$time" "الحالة:" "$status"
  echo -e "${CYAN}------------------------ ${BOLD}المنافذ المفتوحة${NC} ${CYAN}------------------------${NC}"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSH:" "22, 299" "DNS النظام:" "53"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WEB-Nginx:" "85" "SSL:" "443"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSL/PYTHON:" "443"  "Squid:" "3128, 8000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "80, 8080, 8880" "BadVPN:" "7300"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "2082, 2086, 25" "XRAY NTLS:" "80, 8080, 8880"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "XRAY TLS:" "443" "SlowDNS/SS:" "53 (dnsdist)"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SOCKS:" "127.0.0.1:1080" "Hysteria 1:" "20000-50000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Hysteria 2:" "36713/UDP" "UDPCustom:" "1-65535"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "ZiVPN:" "6000-19999"
  echo -e "${CYAN}----------------------- ${BOLD}موارد النظام${NC} ${CYAN}-----------------------${NC}"
  printf "  ${WHITE}%-10s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-10s${NC} ${YELLOW}%-10s${NC} ${WHITE}%-8s${NC} ${YELLOW}%s${NC}\n" "الرام:" "$ram" "المعالج:" "$cpu" "المخزن:" "$buf"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] إدارة حسابات SSH (قديم)"
  echo -e "  [${YELLOW}02${NC}] إدارة حسابات Xray (V2ray)"
  echo -e "  [${YELLOW}03${NC}] إدارة حسابات Hysteria (UDP)"
  echo -e "  [${YELLOW}04${NC}] إدارة حسابات Hysteria 2 (UDP)"
  echo -e "  [${YELLOW}05${NC}] إدارة حسابات ZiVPN (UDP)"
  echo -e "  [${YELLOW}06${NC}] مراقبة الاتصالات النشطة"
  echo -e "  [${YELLOW}07${NC}] التحكم في الخدمات (إعادة تشغيل البروتوكولات)"
  echo -e "  [${YELLOW}08${NC}] نسخ احتياطي واستعادة البيانات"
  echo -e "  [${YELLOW}09${NC}] أدوات النظام (BBR و Netflix)"
  echo -e "  [${YELLOW}10${NC}] إعدادات متقدمة (الدومين / Nameserver)"
  echo -e "  [${YELLOW}11${NC}] إعادة تشغيل الخادم"
  echo -e "  [${RED}00${NC}] خروج\n"
  read -rp "  ► اختر خيارًا: " opt
  case "$opt" in
    1|01)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}إدارة حسابات SSH${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] إنشاء مستخدم SSH\n  [${YELLOW}2${NC}] تمديد الصلاحية\n  [${YELLOW}3${NC}] حذف مستخدم SSH\n  [${YELLOW}4${NC}] عرض جميع الحسابات\n  [${YELLOW}0${NC}] رجوع\n"
        read -rp "  ► الخيار: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}إدارة حسابات Xray${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] إضافة حساب Xray\n  [${YELLOW}2${NC}] تجديد حساب Xray\n  [${YELLOW}3${NC}] حذف حساب Xray\n  [${YELLOW}4${NC}] عرض روابط التهيئة\n  [${YELLOW}5${NC}] حذف مستخدمي Xray منتهي الصلاحية\n  [${YELLOW}6${NC}] تحديث إصدار Xray Core\n  [${YELLOW}0${NC}] رجوع\n"
        read -rp "  ► الخيار: " sub; case "$sub" in 1) add_xray;; 2) renew_xray;; 3) del_xray;; 4) show_xray;; 5) /usr/local/bin/exp-check; echo "تم حذف مستخدمي Xray منتهي الصلاحية."; pause_return;; 6) systemctl stop xray; XRAY_VER="v26.5.9"; echo "جاري إعادة تثبيت Xray Core ${XRAY_VER}..."; wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"; unzip -q -o /tmp/xray.zip -d /tmp/xray/ && mv -f /tmp/xray/xray /usr/local/bin/xray; systemctl start xray; echo -e "${GREEN}✔ تم استعادة Xray إلى ${XRAY_VER}!${NC}"; pause_return;; 0) break;; esac
      done ;;
    3|03)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}إدارة حسابات Hysteria${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] إضافة حساب Hysteria\n  [${YELLOW}2${NC}] تمديد حساب Hysteria\n  [${YELLOW}3${NC}] حذف حساب Hysteria\n  [${YELLOW}4${NC}] عرض جميع الحسابات\n  [${YELLOW}5${NC}] تعديل سرعات الرفع/التحميل\n  [${YELLOW}6${NC}] تغيير Obfs\n  [${YELLOW}0${NC}] رجوع\n"
        read -rp "  ► الخيار: " sub; case "$sub" in 1) add_hysteria;; 2) extend_hysteria;; 3) del_hysteria;; 4) list_hysteria;; 5) speed_hysteria;; 6) change_obfs_hysteria;; 0) break;; esac
      done ;;
    4|04)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}إدارة حسابات Hysteria 2${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] إضافة حساب Hysteria 2\n  [${YELLOW}2${NC}] تمديد حساب Hysteria 2\n  [${YELLOW}3${NC}] حذف حساب Hysteria 2\n  [${YELLOW}4${NC}] عرض جميع الحسابات\n  [${YELLOW}5${NC}] عرض رابط الحساب\n  [${YELLOW}0${NC}] رجوع\n"
        read -rp "  ► الخيار: " sub; case "$sub" in 1) add_hysteria2;; 2) extend_hysteria2;; 3) del_hysteria2;; 4) list_hysteria2;; 5) show_hysteria2;; 0) break;; esac
      done ;;
      5|05)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}إدارة حسابات ZiVPN${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] إضافة حساب ZiVPN\n  [${YELLOW}2${NC}] تمديد حساب ZiVPN\n  [${YELLOW}3${NC}] حذف حساب ZiVPN\n  [${YELLOW}4${NC}] عرض جميع الحسابات\n  [${YELLOW}0${NC}] رجوع\n"
        read -rp "  ► الخيار: " sub; case "$sub" in 1) add_zivpn;; 2) extend_zivpn;; 3) del_zivpn;; 4) list_zivpn;; 0) break;; esac
      done ;;
    6|06) online_users ;;
    7|07) service_control_menu ;;
    8|08)
      clear; echo -e "  [1] نسخ احتياطي لإعدادات النظام\n  [2] استعادة من النسخ الاحتياطي\n  [0] رجوع"
      read -rp " اختر: " subopt; case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
    9|09) utilities_menu ;;
    10) advanced_menu ;;
    11) clear; read -rp "هل تريد إعادة تشغيل الخادم الآن؟ [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
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
figlet  Auto Script By KINGDOM -c | lolcat
echo "       تم التثبيت بنجاح! يحتاج النظام إلى إعادة تشغيل لتطبيق جميع التغييرات!"
history -c; rm /root/full.sh 2>/dev/null || true
echo "           سيتم إعادة تشغيل الخادم خلال 10 ثوانٍ!"
sleep 10
reboot
