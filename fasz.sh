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
  curl -sL https://github.com/node-red/linux-installers/releases/latest/download/update-nodejs-and-nodered-deb | bash
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
"⚙️  Minden telepítése"  # Új menüpont
"❌ Kilépés"
)

poz=0

while true; do
  clear
  echo "=== Telepítő menü ==="
  echo "(↑ ↓ mozgat, Enter választ)"
  echo ""

  for i in "${!menu[@]}"; do
    blink=""
    reset=$(tput sgr0)

    case $i in
      0) service_installed apache2 || blink=$(tput blink) ;;
      1) service_installed ssh || blink=$(tput blink) ;;
      2) service_installed mariadb || blink=$(tput blink) ;;
      3) service_installed mosquitto || blink=$(tput blink) ;;
      4) service_installed nodered.service || blink=$(tput blink) ;;
    esac

    if [ $i -eq $poz ]; then
      echo "> ${blink}${menu[$i]}${reset}"
    else
      echo "  ${blink}${menu[$i]}${reset}"
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
        5) install_all ;;  # Az új menüpont kezelés
        6) break ;;
      esac
      read -p "Enter a visszalépéshez..."
      ;;
  esac

  if [ $poz -lt 0 ]; then poz=$((${#menu[@]}-1)); fi
  if [ $poz -ge ${#menu[@]} ]; then poz=0; fi
done

### VÉGELLENŐRZÉS ###

check_ok apache2
check_ok ssh
check_ok mariadb
check_ok mosquitto
check_ok nodered.service

if $all_ok; then
  french_civil_war
else
  echo "⚠️ Nem minden szolgáltatás fut – események nem jelennek meg"
fi
