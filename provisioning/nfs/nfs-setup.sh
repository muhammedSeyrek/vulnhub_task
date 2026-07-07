#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# 1. Doğru paket adıyla NFS sunucusunu kur
apt-get update
apt-get install -y nfs-kernel-server

# 2. Paylaşıma açılacak ortak klasörü oluştur ve izinlerini ayarla
mkdir -p /var/nfs/ortak
chown nobody:nogroup /var/nfs/ortak
chmod 777 /var/nfs/ortak

# 3. EN KRİTİK NOKTA: Klasörü Web sunucusuna 'no_root_squash' ile export et
# (Burada sadece Web sunucusunun IP'sine [192.168.57.3] izin veriyoruz)
echo "/var/nfs/ortak 192.168.57.3(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports

# 4. Değişiklikleri kaydet ve NFS servisini yeniden başlat
exportfs -a
systemctl restart nfs-kernel-server