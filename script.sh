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
# Copyright (c) 2026 INTERNET KINGDOM. All rights reserved.
#
set -o pipefail
clear

export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

# ============================================================
# 📊 OS SUPPORT CHECK
# ============================================================
SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  rocky:9.*) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

# ============================================================
# 🎨 COLORS
# ============================================================
Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
OK="${Green}--->${FONT}"
ERROR="${RED}[ERROR]${FONT}"
GRAY="\e[1;30m"
NC='\e[0m'
red='\e[1;31m'
green='\e[0;32m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
stty erase ^? 2>/dev/null || true

TIMES="10"
NAMES=$(whoami)
IMP="wget -q -O"
LOCAL_DATE="/usr/bin/"
MYIP=$(wget -qO- ipinfo.io/ip)
CITY=$(wget -qO- ipinfo.io/city)
TIME=$(date '+1859745515 100 %Y')
RAMMS=$(free -m | awk 'NR==2 {print $2}')

OS=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
Date_list=$(date +"%Y-No such file or directory-1" -d "$dateFromServer")
source '/etc/os-release'

# ============================================================
# 📋 LOGO
# ============================================================
logo() {
    echo -e ""
    echo -e "    ┌───────────────────────────────────────────────┐"
    echo -e " ───│                                               │───"
    echo -e " ───│    $Green┌─┐┬ ┬┌┬┐┌─┐┌─┐┌─┐┬─┐┬┌─┐┌┬┐  ┬  ┬┌┬┐┌─┐$NC   │───"
    echo -e " ───│    $Green├─┤│ │ │ │ │└─┐│  ├┬┘│├─┘ │   │  │ │ ├┤ $NC   │───"
    echo -e " ───│    $Green┴ ┴└─┘ ┴ └─┘└─┘└─┘┴└─┴┴   ┴   ┴─┘┴ ┴ └─┘$NC   │───"
    echo -e "    │    ${YELLOW}Copyright${FONT} (C)${GRAY}https://t.me/FreeinternetTM$NC     │"
    echo -e "    └───────────────────────────────────────────────┘"
    echo -e "        "
}

cd "$(
cd "$(dirname "$0")" || exit
pwd
)" || exit

secs_to_human() {
    echo -e "${WB}Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds${NC}"
}

start=$(date +%s)

INS="sudo apt-get install -y"

ln -fs /usr/share/zoneinfo/Africa/Casablanca /etc/localtime

function print_ok() {
    echo -e "${OK} ${BLUE} $1 ${FONT}"
}

function print_error() {
    echo -e "${ERROR} ${REDBG} $1 ${FONT}"
}

function is_root() {
    if [[ 0 == "$UID" ]]; then
        print_ok "Root user Start installation process"
    else
        print_error "The current user is not the root user, please switch to the root user and run the script again"
    fi
}

msg() {
    if [[ 0 -eq $? ]]; then
        print_ok "$1 Complete... ${YELLOW}INTERNET KINGDOM${FONT}"
        sleep 1
    fi
}

check_vz() {
    if [ -f /proc/user_beancounters ]; then
        msg "OpenVZ VPS is not supported."
        exit
    fi
}

REPO="https://ssc.nexajs.com/"

# ============================================================
# 📁 MAKE XRAY FOLDERS
# ============================================================
function make_folder_xray() {
    rm -rf /etc/vmess/.vmess.db
    rm -rf /etc/vless/.vless.db
    rm -rf /etc/trojan/.trojan.db
    rm -rf /etc/shadowsocks/.shadowsocks.db
    rm -rf /etc/ssh/.ssh.db
    rm -rf /etc/xray/city
    rm -rf /etc/xray/isp
    mkdir -p /etc/xray
    mkdir -p /etc/vmess
    mkdir -p /etc/vless
    mkdir -p /etc/trojan
    mkdir -p /etc/shadowsocks
    mkdir -p /usr/bin/xray/
    mkdir -p /var/log/xray/
    mkdir -p /var/www/html
    chmod +x /var/log/xray
    touch /etc/xray/domain
    touch /var/log/xray/access.log
    touch /var/log/xray/error.log
    touch /etc/vmess/.vmess.db
    touch /etc/vless/.vless.db
    touch /etc/trojan/.trojan.db
    touch /etc/shadowsocks/.shadowsocks.db
    touch /etc/ssh/.ssh.db
    echo "& plughin Account" >>/etc/vmess/.vmess.db
    echo "& plughin Account" >>/etc/vless/.vless.db
    echo "& plughin Account" >>/etc/trojan/.trojan.db
    echo "& plughin Account" >>/etc/shadowsocks/.shadowsocks.db
    echo "& plughin Account" >>/etc/ssh/.ssh.db
}

# ============================================================
# 🌐 DOMAIN SETUP
# ============================================================
function add_domain() {
    read -p "Input Domain :  " domain
    if [[ ${domain} ]]; then
        echo $domain >/etc/xray/domain
    else
        echo -e " ${RED}Please input your Domain${FONT}"
        echo -e ""
        echo -e " Start again in 5 seconds"
        echo -e ""
        sleep 5

        rm -rf setup.sh
        exit 1
    fi
}

function check_ubuntu_version() {
    if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') != "ubuntu" ]]; then
        echo -e "${RED} Your OS Is Not Ubuntu ( ${YELLOW}$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')${NC} )"
        ask_reinstall
        return 1
    fi

    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)
    if [[ "$UBUNTU_VERSION" != "20.04" ]]; then
        echo -e "${RED} Your Ubuntu Version Is Not 20.04 ( ${YELLOW}$UBUNTU_VERSION${NC} )"
        ask_reinstall
        return 1
    fi

    print_ok "Ubuntu 20.04 detected. Continuing installation..."
    return 0
}

function ask_reinstall() {
    echo -e ""
    echo -e "${YELLOW}Recommended OS: Ubuntu 20.04${NC}"
    echo -e "${YELLOW}Do you want to reinstall with Ubuntu 20.04?${NC}"
    read -e -p "Type Y to reinstall or N to continue anyway [Y/n]: " reinstall_choice

    if [[ "$reinstall_choice" =~ ^[Yy]$ ]] || [[ -z "$reinstall_choice" ]]; then
        echo -e "${GREEN}Starting reinstallation with Ubuntu 20.04...${NC}"
        wget https://script.nexajs.com/reinstall.sh && chmod +x reinstall.sh && ./reinstall.sh ubuntu 20.04 && reboot
        exit 0
    else
        echo -e "${YELLOW}Continuing installation on current OS...${NC}"
        sleep 2
        return 0
    fi
}

# ============================================================
# 📦 PACKAGE FUNCTIONS
# ============================================================
packagesDebian() {
    print_ok "update repository python"
    apt install python3 python3-pip -y
    sudo apt-get install build-essential checkinstall -y
    sudo apt-get install -y libreadline-gplv2-dev libncursesw5-dev libssl-dev \
    libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev
    cd /opt
    sudo wget https://www.python.org/ftp/python/3.8.12/Python-3.8.12.tgz
    sudo tar xzf Python-3.8.12.tgz
    cd Python-3.8.12
    sudo ./configure --enable-optimizations
    sudo make altinstall
}

updatePackages() {
    apt update -y
    apt install sudo -y
    sudo apt-get clean all
    sudo apt-get autoremove -y
    sudo apt-get install -y debconf-utils
    sudo apt-get remove --purge exim4 -y
    sudo apt-get remove --purge ufw firewalld -y
    sudo apt-get install -y --no-install-recommends software-properties-common
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    sudo apt-get install -y speedtest-cli vnstat libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev flex bison make libnss3-tools libevent-dev bc rsyslog dos2unix zlib1g-dev libssl-dev libsqlite3-dev sed dirmngr libxml-parser-perl build-essential gcc g++ python htop lsof tar wget curl ruby zip unzip p7zip-full python3-pip libc6 util-linux build-essential msmtp-mta ca-certificates bsd-mailx iptables iptables-persistent netfilter-persistent net-tools openssl ca-certificates gnupg gnupg2 ca-certificates lsb-release gcc shc make cmake git screen socat xz-utils apt-transport-https gnupg1 dnsutils cron bash-completion ntpdate chrony jq openvpn easy-rsa
    /etc/init.d/vnstat restart
    wget -q https://humdi.net/vnstat/vnstat-2.6.tar.gz
    tar zxvf vnstat-2.6.tar.gz
    cd vnstat-2.6
    ./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
    cd
    vnstat -u -i $NET
    sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
    chown vnstat:vnstat /var/lib/vnstat -R
    systemctl enable vnstat
    /etc/init.d/vnstat restart
    rm -f /root/vnstat-2.6.tar.gz >/dev/null 2>&1
    rm -rf /root/vnstat-2.6 >/dev/null 2>&1
    ln -fs /usr/share/zoneinfo/Africa/Casablanca /etc/localtime
    if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "ubuntu" ]]; then
        msg "Setup Dependencies $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        sudo apt update -y
        apt-get install --no-install-recommends software-properties-common
        add-apt-repository ppa:vbernat/haproxy-2.0 -y
        apt-get -y install haproxy=2.0.\*
        packagesDebian
        elif [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "debian" ]]; then
        msg "Setup Dependencies For OS Is $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        curl https://haproxy.debian.net/bernat.debian.org.gpg |
        gpg --dearmor >/usr/share/keyrings/haproxy.debian.net.gpg
        echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" \
        http://haproxy.debian.net buster-backports-1.8 main \
        >/etc/apt/sources.list.d/haproxy.list
        sudo apt-get update
        apt-get -y install haproxy=1.8.\*
        packagesDebian
    else
        echo -e "${RED} Your OS Is Not Supported ( ${YELLOW}$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')${NC} )"
        exit 1
    fi
}

# ============================================================
# 📥 INSTALL DEPENDENCIES
# ============================================================
function insDepedency() {
    echo ""
    echo "Please wait to install Package..."
    apt-get update
    msg "Update configuration"

    msg "Installed openvpn easy-rsa"
    source <(curl -sL ${REPO}openvpn/openvpn)
    source <(curl -sL ${REPO}badvpn/ins-badvpn)

    msg "Installed itil vpn"
    wget -O /etc/pam.d/common-password "${REPO}openvpn/common-password" >/dev/null 2>&1
    chmod +x /etc/pam.d/common-password

    msg "Installed dropbear"
    apt-get install dropbear -y

}

# ============================================================
# 🔐 SSL CERTIFICATE
# ============================================================
function acme() {
    msg "installed successfully SSL certificate generation script"
    rm -rf /root/.acme.sh
    mkdir /root/.acme.sh
    systemctl stop haproxy
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/yha.pem
    chown www-data.www-data /etc/xray/xray.key
    chown www-data.www-data /etc/xray/xray.crt
    msg "Installed slowdns"
    wget -q -O /etc/nameserver "${REPO}slowdns/nameserver" && bash /etc/nameserver >/dev/null 2>&1

}

# ============================================================
# 🌐 NGINX
# ============================================================
function insNginx() {
    apt clean all && apt update
    ntpdate pool.ntp.org
    apt -y install chrony
    apt install curl pwgen chrony socat openssl netcat cron -y

    source <(curl -sL ${REPO}utility/bbr)
    if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "ubuntu" ]]; then
        msg "Setup nginx For OS Is $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        rm -f /etc/apt/sources.list.d/nginx.list
        sudo apt-get install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
        curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor |
        tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
        http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" |
        tee /etc/apt/sources.list.d/nginx.list
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" |
        tee /etc/apt/preferences.d/99nginx

        apt update -y
        sudo apt-get install -y nginx
        elif [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "debian" ]]; then
        msg "Setup nginx For OS Is $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        rm -f /etc/apt/sources.list.d/nginx.list
        sudo apt-get install -y curl gnupg2 ca-certificates lsb-release debian-archive-keyring
        curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor |
        tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
        http://nginx.org/packages/debian $(lsb_release -cs) nginx" |
        tee /etc/apt/sources.list.d/nginx.list
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" |
        tee /etc/apt/preferences.d/99nginx

        apt update -y
        sudo apt-get install -y nginx
    else
        echo -e "${RED} Your OS Is Not Supported ( ${YELLOW}$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')${NC} )"
        exit 1
    fi

    apt-get purge apache2 -y
    apt-get autoremove -y
}

function confNginx() {
    cd
    rm /etc/nginx/conf.d/default.conf
    wget -O /etc/nginx/nginx.conf "${REPO}nginx/nginx.conf" >/dev/null 2>&1

    msg "Configurasi Nginx Berhasil !"
}

# ============================================================
# ⚖️ HAPROXY
# ============================================================
function insHaproxy() {
    wget -O /usr/sbin/haproxy "${REPO}haproxy/haproxy" >/dev/null 2>&1
    chmod +x /usr/sbin/haproxy
cat >/lib/systemd/system/haproxy.service <<EOF
[Unit]
Description=INTERNET KINGDOM Load Balancer
Documentation=https://github.com/firdaus-rx
After=network-online.target rsyslog.service

[Service]
ExecStart=/usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p 18173
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    curl "${REPO}utility/download.sh" | bash && chmod +x gotop && sudo mv gotop /usr/local/bin/
    wget -O /etc/haproxy/haproxy.cfg "${REPO}haproxy/haproxy.cfg" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/xray.conf "${REPO}nginx/xray" >/dev/null 2>&1
}

# ============================================================
# ⚙️ CONFIGURATION
# ============================================================
function insConfig() {
    cd
    rm -rf *
    wget ${REPO}utility/menu.zip
    unzip menu.zip
    rm -f menu.zip
    chmod +x *
    mv * /usr/bin/

        cat >/root/.profile <<END
# ~/.profile: executed by Bourne-compatible login shells.
if [ "$BASH" ]; then
if [ -f ~/.bashrc ]; then
. ~/.bashrc
fi
fi
mesg n || true
menu
END

    cat >/etc/cron.d/xp_all <<-END
                SHELL=/bin/sh
                PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
                2 0 * * * root /usr/bin/xp
        END

    cat >/etc/cron.d/logclean <<-END
                SHELL=/bin/sh
                PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
                */59 * * * * root /usr/bin/logclean
        END
    chmod 644 /root/.profile

    cat >/etc/cron.d/daily_reboot <<-END
                SHELL=/bin/sh
                PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
                0 5 * * * root /sbin/reboot
        END

    service cron restart
        cat >/home/daily_reboot <<-END
                5
        END

    cat >/etc/cron.d/x_limp <<-END
                SHELL=/bin/sh
                PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
                */10 * * * * root /usr/bin/xraylimit
        END

        cat >/etc/systemd/system/rc-local.service <<-END
                [Unit]
                Description=/etc/rc.local
                ConditionPathExists=/etc/rc.local
                [Service]
                Type=forking
                ExecStart=/etc/rc.local start
                TimeoutSec=0
                StandardOutput=tty
                RemainAfterExit=yes
                SysVStartPriority=99
                [Install]
                WantedBy=multi-user.target
        END

    echo "/bin/false" >>/etc/shells
    echo "/usr/sbin/nologin" >>/etc/shells

        cat >/etc/rc.local <<-END
                #!/bin/sh -e
                # rc.local
                # By default this script does nothing.
                netfilter-persistent reload
        END
    chmod +x /etc/rc.local

    AUTOREB=$(cat /home/daily_reboot)

    SETT=11
    if [ $AUTOREB -gt $SETT ]; then
        TIME_DATE="PM"
    else
        TIME_DATE="AM"
    fi
}

# ============================================================
# 🦑 SQUID
# ============================================================
function inSquid() {
    apt install squid -y

    wget -q -O /etc/squid/squid.conf "${REPO}squid/squid.conf" >/dev/null 2>&1
    wget -q -O /etc/ssh/sshd_config "${REPO}squid/sshd" >/dev/null 2>&1
    wget -q -O /etc/default/dropbear "${REPO}dropbear/dropbear" >/dev/null 2>&1
    wget -q -O /etc/banner "${REPO}dropbear/banner" >/dev/null 2>&1

}

# ============================================================
# 🔌 WEBSOCKET
# ============================================================
function insWs() {
    wget -O /usr/bin/tun.conf "${REPO}websocket/tun.conf" >/dev/null 2>&1
    chmod 644 /usr/bin/tun.conf

    wget -O /usr/bin/ws.py "${REPO}websocket/ws.py" >/dev/null 2>&1
    chmod +x /usr/bin/ws.py

    wget -O /etc/systemd/system/ws.service "${REPO}websocket/socks.service" >/dev/null 2>&1
    chmod +x /etc/systemd/system/ws.service
}

# ============================================================
# ☢️ XRAY CORE
# ============================================================
function insXray() {
    msg "Core Xray 1.7.5 Version installed successfully"
    curl -s ipinfo.io/city >>/etc/xray/city
    curl -s ipinfo.io/org | cut -d " " -f 2-10 >>/etc/xray/isp
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.7.5

    wget -O /etc/xray/config.json "${REPO}xray/config.json" >/dev/null 2>&1

    wget -q -O /etc/ipserver "${REPO}utility/ipserver" && bash /etc/ipserver >/dev/null 2>&1
    wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" >/dev/null 2>&1
    wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" >/dev/null 2>&1

    rm -rf /etc/systemd/system/xray.service.d
cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=INTERNET KINGDOM Server Xray
Documentation=https://t.me/FreeinternetTM
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

EOF

}

# ============================================================
# 🚀 UDP CUSTOM
# ============================================================
insUdp() {
    wget -O /usr/bin/udp "${REPO}utility/udp-custom-linux-amd64" >/dev/null 2>&1

    chmod +x /usr/bin/udp

    cat >/usr/bin/config.json <<-END
{
    "listen": ":2100",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
    "mode": "passwords"
    }
}
END

    cat >/etc/systemd/system/udp.service <<EOF
[Unit]
Description=ePro Udp-Custom VPN Server By HC
After=network.target

[Service]
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server --config /usr/bin/config.json
Environment=HYSTERIA_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNPROC=10000
LimitNOFILE=1000000
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    chmod +x /usr/bin/runbot
    systemctl daemon-reload
    systemctl enable udp
    systemctl start udp
    systemctl restart udp
}

# ============================================================
# 🔄 RESTART SYSTEM
# ============================================================
function restart_system() {
    TIMEZONE=$(date +'%H:%M:%S')

    cp /etc/openvpn/*.ovpn /var/www/html/
    sed -i "s/xxx/${domain}/g" /var/www/html/index.html
    sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
    sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg
    sed -i "s/xxx/${MYIP}/g" /etc/squid/squid.conf
    source <(curl -sL ${REPO}xray/tunlp)
    systemctl daemon-reload
    systemctl enable client
    systemctl enable server
    systemctl enable netfilter-persistent
    systemctl enable ws
    systemctl enable haproxy
    print_ok "Processing restart service ..."
    systemctl start client
    systemctl start server
    systemctl start haproxy
    systemctl start netfilter-persistent
    systemctl restart nginx
    systemctl restart xray
    systemctl restart sshd
    systemctl restart rc-local
    systemctl restart client
    systemctl restart server
    systemctl restart dropbear
    systemctl restart ws
    systemctl restart openvpn
    systemctl restart cron
    systemctl restart haproxy
    systemctl restart netfilter-persistent
    systemctl restart ws
    systemctl restart udp
    clear
    echo "    ┌─────────────────────────────────────────────────────┐"
    echo "    │       >>> Service & Port                            │"
    echo "    │   - Open SSH                : 22                    │"
    echo "    │   - UDP SSH                 : 1-65535               │"
    echo "    │   - DNS (SLOWDNS)           : 443, 80, 53           │"
    echo "    │   - Dropbear                : 443, 109, 143         │"
    echo "    │   - Dropbear Websocket      : 443, 109              │"
    echo "    │   - SSH Websocket SSL       : 443                   │"
    echo "    │   - SSH Websocket           : 80                    │"
    echo "    │   - OpenVPN SSL             : 443                   │"
    echo "    │   - OpenVPN Websocket SSL   : 443                   │"
    echo "    │   - OpenVPN TCP             : 443, 1194             │"
    echo "    │   - OpenVPN UDP             : 2200                  │"
    echo "    │   - Nginx Webserver         : 443, 80, 81           │"
    echo "    │   - Haproxy Loadbalancer    : 443, 80               │"
    echo "    │   - DNS Server              : 443, 53               │"
    echo "    │   - DNS Client              : 443, 88               │"
    echo "    │   - XRAY (DNSTT/SLOWDNS)    : 443, 53               │"
    echo "    │   - XRAY Vmess TLS          : 443                   │"
    echo "    │   - XRAY Vmess gRPC         : 443                   │"
    echo "    │   - XRAY Vmess None TLS     : 80                    │"
    echo "    │   - XRAY Vless TLS          : 443                   │"
    echo "    │   - XRAY Vless gRPC         : 443                   │"
    echo "    │   - XRAY Vless None TLS     : 80                    │"
    echo "    │   - Trojan gRPC             : 443                   │"
    echo "    │   - Trojan WS               : 443                   │"
    echo "    │   - Shadowsocks WS          : 443                   │"
    echo "    │   - Shadowsocks gRPC        : 443                   │"
    echo "    │                                                     │"
    echo "    │      >>> Server Information & Other Features        │"
    echo "    │   - Timezone                : Africa/Casablanca (GMT +7) │"
    echo "    │   - Autoreboot On           : $AUTOREB:00 $TIME_DATE GMT +7        │"
    echo "    │   - Auto Delete Expired Account                     │"
    echo "    │   - Fully automatic script                          │"
    echo "    │   - VPS settings                                    │"
    echo "    │   - Admin Control                                   │"
    echo "    │   - Restore Data                                    │"
    echo "    │   - Simple BOT Telegram                             │"
    echo "    │   - Full Orders For Various Services                │"
    echo "    └─────────────────────────────────────────────────────┘"
    secs_to_human "$(($(date +%s) - ${start}))"
    read -e -p "         Please Reboot Your Vps [y/n] " -i "y" str
    if [ "$str" = "y" ]; then

        reboot

    fi
    menu
}

# ============================================================
# 🔧 INSTALL SCRIPT
# ============================================================
function install_sc() {
    insDepedency
    acme
    insNginx
    confNginx
    insHaproxy
    insConfig
    inSquid
    insWs
    insXray
    insUdp
    restart_system

}

# ============================================================
# 🚀 START INSTALLATION
# ============================================================
logo
make_folder_xray
add_domain
is_root
check_vz

# Check Ubuntu version before proceeding
check_ubuntu_version

updatePackages
install_sc
