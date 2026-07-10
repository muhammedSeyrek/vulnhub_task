#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Gerekli paketleri kur (GDB eklendi, python3 whois sunucusu yerine nginx+php-fpm)
apt-get update
apt-get install -y libcap2-bin whois gdb nfs-common nginx php-fpm

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

echo "Sistem yöneticisi bu anahtar nfs.altay.sec makinesindeki user kullanıcısına ait..." >> /root/.ssh/BENIOKU

# -------------------------------------------------------------
# C. NGINX + PHP-FPM KURULUMU
# -------------------------------------------------------------
# Debian 12'de PHP sürümü paket adına göre değişebilir (örn. 8.2),
# bu yüzden kurulu pool.d dizinini dinamik olarak buluyoruz.
PHP_POOL_DIR=$(find /etc/php -maxdepth 2 -type d -name "fpm" | head -n1)
PHP_FPM_SERVICE=$(systemctl list-unit-files | grep -oP 'php[0-9.]*-fpm(?=\.service)' | head -n1)

mkdir -p /run/php
mkdir -p /var/www/html

# index.php test dosyasını yerleştir
cp /tmp/index.php /var/www/html/index.php
chown -R www-data:www-data /var/www/html

# PHP-FPM pool config'ini yerleştir (unix socket: /run/php/php-fpm.sock)
cp /tmp/php-fpm-pool.conf "$PHP_POOL_DIR/pool.d/www.conf"

# Nginx site config'ini yerleştir (8080 portu -> firewall'daki DNAT kuralıyla eşleşiyor)
cp /tmp/nginx-site.conf /etc/nginx/sites-available/web
ln -sf /etc/nginx/sites-available/web /etc/nginx/sites-enabled/web
rm -f /etc/nginx/sites-enabled/default

# -------------------------------------------------------------
# NOT: p0wny-shell.php (ya da başka bir shell dosyası) burada
# OLUŞTURULMUYOR. Bu script sadece /var/www/html dizinini ve
# web sunucusu altyapısını hazırlar. Shell dosyasını manuel
# olarak /provisioning/web/ altına koyup Vagrantfile'a bir
# "file" provisioner satırı eklemeniz yeterli:
#
#   web.vm.provision "file",
#     source: "provisioning/web/p0wny-shell.php",
#     destination: "/home/vagrant/p0wny-shell.php"
#
# ve bu script'in sonuna:
   mv /home/vagrant/shell.php /var/www/html/shell.php
   chown www-data:www-data /var/www/html/shell.php
# -------------------------------------------------------------

systemctl restart "$PHP_FPM_SERVICE"
systemctl enable "$PHP_FPM_SERVICE"
systemctl restart nginx
systemctl enable nginx
