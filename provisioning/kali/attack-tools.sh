#!/usr/bin/env bash
# =============================================================
# Kali (saldırgan) — keşif ve sızma araçları
# generic/debian12 düz geldiği için Rol 1'in ihtiyaç duyduğu
# araçlar burada kurulur. dnscat2 kurulumu ayrı script'te
# (setup-dnscat2.sh) yapılır; bu script keşif/sızma tarafıdır.
# =============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[+] Keşif/sızma araçları kuruluyor..."
apt-get update
apt-get install -y \
  dnsutils          `# dig, host (AXFR)` \
  nmap              `# port/servis taraması` \
  netcat-openbsd    `# reverse shell / bağlantı` \
  curl wget         `# web (8080) enumerasyon` \
  nfs-common        `# faz 3: NFS mount` \
  gobuster          `# web dizin taraması (varsa)` \
  python3

echo "[+] Araçlar hazır: dig, nmap, nc, curl, gobuster, mount.nfs"
echo "[i] Keşifi başlatmak için: cd /vagrant/red/recon && ./recon.sh"