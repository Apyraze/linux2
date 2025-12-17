#!/bin/bash

set +e

### ROOT ELLENŐRZÉS ###
if [[ $EUID -ne 0 ]]; then
  echo "❌ Root jogosultság szükséges"
  exit 1
fi

### GLOBÁLIS ÁLLAPOT ###
all_ok=true

### SEGÉDFÜGGVÉNYEK ###

ask_yes_no() {
  while true; do
    read -rp "$1 (i/n): " yn
    case $yn in
      [Ii]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "i vagy n";;
    esac
  done
}

is_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

confirm_reinstall() {
  local pkg="$1"
  local name="$2"

  if is_installed "$pkg"; then
    echo "⚠️  $name már telepítve van!"
    ask_yes_no "Biztosan újratelepíted?" || return 1
  fi
  return 0
}

service_installed() {
  systemctl list-unit-files | grep -q "^$1"
}

check_ok() {
  systemctl is-active --quiet "$1" || all_ok=false
}

### TELEPÍTŐ FÜGGVÉNYEK ###

install_apache() {
  confirm_reinstall apache2 "Apache2" || return
  apt install -y apache2 libapache2-mod-php
  systemctl enable apache2
  systemctl start apache2
}

install_php() {
  confirm_reinstall php "PHP" || return
  apt install -y php php-mbstring php-zip php-gd php-json php-curl php-mysql
}

install_ssh() {
  confirm_reinstall openssh-server "SSH" || return
  apt install -y openssh-server
  systemctl enable ssh
  systemctl start ssh
}

install_mariadb() {
  confirm_reinstall mariadb-server "MariaDB" || return
  apt install -y mariadb-server
  systemctl enable mariadb
  systemctl start mariadb
}

install_mosquitto() {
  confirm_reinstall mosquitto "Mosquitto MQTT" || return
  apt install -y mosquitto mosquitto-clients
  systemctl enable mosquitto
  systemctl start mosquitto
}

install_node_red() {
  if ! command -v curl >/dev/null; then
    apt install -y curl
  fi
  confirm_reinstall nodered "Node-RED" || return

  # Telepítjük a Node.js-t és a Node-RED-et
  curl -sL https://deb.nodesource.com/setup_16.x | bash -  # Választható 16.x vagy 18.x
  apt install -y nodejs

  # Frissítjük az npm csomagkezelőt
  npm install -g npm@latest
  
  # Telepítjük a Node-RED-et a legújabb verzióval
  npm install -g --unsafe-perm node-red

  # Létrehozzuk a systemd szolgáltatást
  echo "[Unit]
Description=Node-RED
After=network.target

[Service]
ExecStart=/usr/local/bin/node-red
WorkingDirectory=/root
User=root
Group=root
Restart=always
Environment=\"NODE_OPTIONS=--max_old_space_size=256\"

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/nodered.service

  # Engedélyezés és indítás
  systemctl daemon-reload
  systemctl enable nodered.service
  systemctl start nodered.service
}

### ÚJ FUNKCIÓ: MINDEN TELEPÍTÉSE ###

install_all() {
  install_apache
  install_php
  install_ssh
  install_mariadb
  install_mosquitto
  install_node_red
}

### FRANCIA FORRADALOM KIÍRÁSA ###

french_civil_war() {
  clear
  echo "🇫🇷 A francia polgárháború / forradalom fő eseményei"
  echo "================================================="
  echo
  echo "1789 – A Bastille ostroma"
  echo "• A forradalom kezdete"
  echo
  echo "1789 – Emberi és Polgári Jogok Nyilatkozata"
  echo "• Szabadság, egyenlőség"
  echo
  echo "1791 – Alkotmányos monarchia"
  echo
  echo "1792 – Köztársaság kikiáltása"
  echo
  echo "1793 – XVI. Lajos kivégzése"
  echo
  echo "1793–1794 – A terror korszaka"
  echo
  echo "1794 – Robespierre bukása"
  echo
  echo "1799 – Napóleon hatalomra jutása"
  echo
  echo "================================================="
  echo "✔ Minden szolgáltatás sikeresen fut"
}

### MENÜ ###

menu=(
"🌐 Apache + PHP"
"🔐 SSH"
"🛢 MariaDB"
"📡 Mosquitto MQTT"
"🧠 Node-RED"
"⚙️  Minden telepítése"
"❌ Kilépés"
)

poz=0

# Színek és stílusok
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
BOLD=$(tput bold)

# A szolgáltatások állapotának ellenőrzése
check_all_installed() {
  installed=true
  for i in apache2 openssh-server mariadb-server mosquitto nodered.service; do
    if ! service_installed $i; then
      installed=false
      break
    fi
  done
  echo $installed
}

# A menü frissítése minden ciklusban
while true; do
  clear
  echo "${BOLD}${BLUE}=== Telepítő menü ===${RESET}"
  echo "(↑ ↓ mozgat, Enter választ)"
  echo ""

  # Ellenőrizzük, hogy minden szolgáltatás telepítve van-e (kivéve a "Minden telepítése" és "Kilépés" menüpontokat)
  menu=(
    "🌐 Apache + PHP"
    "🔐 SSH"
    "🛢 MariaDB"
    "📡 Mosquitto MQTT"
    "🧠 Node-RED"
    "⚙️  Minden telepítése"
    "❌ Kilépés"
  )

  # Ha minden telepítve van, hozzáadjuk az "✨ Extra" menüpontot
  if $(check_all_installed); then
    menu+=("✨ Extra")
  fi

  for i in "${!menu[@]}"; do
    blink=""
    status=""
    reset=$(tput sgr0)

    case $i in
      0) service_installed apache2 && status="${RED}TELEPÍTVE${RESET}" || blink=$(tput blink) ;;
      1) service_installed ssh && status="${RED}TELEPÍTVE${RESET}" || blink=$(tput blink) ;;
      2) service_installed mariadb && status="${RED}TELEPÍTVE${RESET}" || blink=$(tput blink) ;;
      3) service_installed mosquitto && status="${RED}TELEPÍTVE${RESET}" || blink=$(tput blink) ;;
      4) service_installed nodered.service && status="${RED}TELEPÍTVE${RESET}" || blink=$(tput blink) ;;
    esac

    if [ $i -eq $poz ]; then
      echo "> ${blink}${menu[$i]} ${status}${reset}"
    else
      echo "  ${blink}${menu[$i]} ${status}${reset}"
    fi
  done

  read -s -n1 key
  case "$key" in
    $'\x1b')
      read -s -n2 key
      case "$key" in
        "[A") ((poz--)) ;;
        "[B") ((poz++)) ;;
      esac
      ;;
    "")
      clear
      case $poz in
        0) install_apache; install_php ;;
        1) install_ssh ;;
        2) install_mariadb ;;
        3) install_mosquitto ;;
        4) install_node_red ;;
        5) install_all ;;
        6) break ;;
        7) french_civil_war ;;  # Extra menüpont: Francia forradalom kiírása
      esac
      ;;
  esac

  if [ $poz -lt 0 ]; then poz=$((${#menu[@]}-1)); fi
  if [ $poz -ge ${#menu[@]} ]; then poz=0; fi
done
