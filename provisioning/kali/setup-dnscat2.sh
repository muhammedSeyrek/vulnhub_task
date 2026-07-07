#!/bin/bash
# ==========================================
# dnscat2 KURULUM SCRIPT'İ (kali - saldırgan makine)
# ==========================================
# generic/debian12 kutusu düz Debian olduğu için hiçbir pentest aracı
# hazır gelmiyor. Bu script hem dnscat2 SUNUCUSUNU (Ruby, bundler ile)
# hem de dnscat2 CLIENT'ını (C, make ile) kaynak koddan kurar.
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[+] Gerekli paketler kuruluyor..."
apt-get update
apt-get install -y \
    ruby ruby-dev \
    build-essential \
    git \
    libssl-dev \
    libffi-dev \
    screen \
    make \
    gcc

echo "[+] dnscat2 deposu klonlanıyor..."
if [ ! -d /opt/dnscat2 ]; then
    git clone https://github.com/iagox86/dnscat2.git /opt/dnscat2
else
    echo "    /opt/dnscat2 zaten mevcut, atlanıyor."
fi

echo "[+] Sunucu (Ruby) bağımlılıkları kuruluyor..."
cd /opt/dnscat2/server
gem install bundler --no-document
bundle install

echo "[+] Client (C) derleniyor..."
cd /opt/dnscat2/client
make

echo "[+] systemd servisi oluşturuluyor (dnscat2 sunucusu, screen içinde arka planda)..."
printf '%s\n' \
  '[Unit]' \
  'Description=dnscat2 C2 server (screen icinde, arka planda)' \
  'After=network.target' \
  '' \
  '[Service]' \
  'Type=forking' \
  'WorkingDirectory=/opt/dnscat2/server' \
  'ExecStart=/usr/bin/screen -dmS dnscat2 ruby ./dnscat2.rb --dns host=0.0.0.0,port=53,domain=altay.insecure --no-cache' \
  'ExecStop=/usr/bin/screen -S dnscat2 -X quit' \
  'Restart=on-failure' \
  'RemainAfterExit=yes' \
  '' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/dnscat2.service

systemctl daemon-reload
systemctl enable dnscat2
systemctl restart dnscat2

echo "[+] Tamamlandı. Client binary: /opt/dnscat2/client/dnscat"
echo "[+] Sunucu konsoluna bağlanmak için: sudo screen -x dnscat2"
