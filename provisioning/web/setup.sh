#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Gerekli paketleri kur (GDB eklendi)
apt-get update
apt-get install -y python3 libcap2-bin whois gdb nfs-common

# -------------------------------------------------------------
# A. GDB İLE CAPABILITIES (HAK YÜKSELTME ZAFİYETİ)
# -------------------------------------------------------------
setcap cap_setuid+ep /usr/bin/gdb

# -------------------------------------------------------------
# B. KULLANICI VE SSH ANAHTARI HAZIRLIĞI
# -------------------------------------------------------------
# Hedef klasörü oluştur ve izinlerini ayarla
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Geçici yüklenen anahtarları root dizinine taşı
mv /home/vagrant/id_rsa_nfs /root/.ssh/id_rsa_nfs

# Sahipliklerini root yap
chown root:root /root/.ssh/id_rsa_nfs*
# SSH kuralları gereği izinleri sıkılaştır (Private: 600, Public: 644)
chmod 600 /root/.ssh/id_rsa_nfs
