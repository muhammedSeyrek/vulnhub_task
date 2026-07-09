#!/usr/bin/env bash
# =============================================================
# Rol 1 — Faz 1: Keşif ve Ağ Haritalama
# Kali (192.168.56.100) üzerinden çalıştırılır. Dışarıdan yalnızca
# firewall (192.168.56.10) görünür; iç makineler AXFR ile ortaya çıkar.
#
# Kullanım:
#   ./recon.sh [FIREWALL_IP] [ZONE]
#   ./recon.sh 192.168.56.10 altay.sec
# =============================================================
set -uo pipefail

FIREWALL_IP="${1:-192.168.56.10}"
ZONE="${2:-altay.sec}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$(dirname "$0")/../evidence/recon_${STAMP}"
mkdir -p "$OUT"

echo "[+] Sınır (firewall): $FIREWALL_IP"
echo "[+] Zone            : $ZONE"
echo "[+] Delil klasörü   : $OUT"
echo

# 1) Firewall yüzeyi — hangi portlar açık?
echo "[*] (1/3) Port taraması: 53 ve 8080..."
if command -v nmap >/dev/null 2>&1; then
  nmap -Pn -p 53,8080 "$FIREWALL_IP"       | tee "$OUT/nmap_tcp.txt"
  # UDP/53 için root gerekir; yoksa atlanır.
  if [ "$(id -u)" -eq 0 ]; then
    nmap -Pn -sU -p 53 "$FIREWALL_IP"      | tee "$OUT/nmap_udp53.txt"
  else
    echo "    [i] UDP taraması için 'sudo' ile çalıştır."
  fi
else
  echo "    [!] nmap yok. Kur: sudo apt-get install -y nmap"
fi
echo

# 2) Zone Transfer (AXFR) — asıl vuruş
echo "[*] (2/3) AXFR deneniyor (TCP/53)..."
dig +time=5 +tcp axfr "$ZONE" @"$FIREWALL_IP" | tee "$OUT/axfr_raw.txt"
echo

# 3) A kayıtlarını temiz bir host haritasına çevir
echo "[*] (3/3) Host haritası çıkarılıyor..."
awk '$4=="A" {printf "%-16s %s\n", $5, $1}' "$OUT/axfr_raw.txt" \
  | sort -u | tee "$OUT/hosts_map.txt"

COUNT="$(wc -l < "$OUT/hosts_map.txt" | tr -d ' ')"
echo
if [ "$COUNT" -gt 0 ]; then
  echo "[+] Faz 1 tamam — $COUNT iç makine haritalandı: $OUT/hosts_map.txt"
  echo "[i] Sıradaki hedefler: web (8080/RCE) -> root -> nfs (no_root_squash)."
else
  echo "[!] AXFR boş döndü. Kontrol: zone adı doğru mu, int-dns ayakta mı,"
  echo "    firewall 53'ü int-dns'e DNAT'lıyor mu?"
fi