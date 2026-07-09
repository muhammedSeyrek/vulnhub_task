# Kör Nokta — Siber Tatbikat Laboratuvarı

Kapalı ve internetten izole bir Vagrant ortamında, DNS zafiyetlerini zincirleyerek
iç ağa sızmayı ve veriyi DNS tüneli ile dışarı kaçırmayı; karşısında da bu sızıntıyı
tespit edip engellemeyi konu alan bir Red Team / Blue Team tatbikatıdır.

> Yalnızca eğitim amaçlıdır. Tüm teknikler bu kapalı laboratuvar içindir; gerçek veya
> izinsiz sistemlerde kullanılamaz.

---

## Senaryo özeti

Dışarıdan yalnızca **Firewall** görünür (53/DNS ve 8080/web açık). Saldırgan:

1. **Keşif (AXFR):** Firewall'un 53'ü üzerinden Zone Transfer ile iç ağı haritalar.
2. **İlk erişim + privesc:** web servisindeki komut enjeksiyonuyla girer, `gdb`
   capability zafiyetiyle web'de root olur.
3. **Yanal geçiş:** SSH pivot + NFS `no_root_squash` ile NFS sunucusunda root olur, kritik
   veriyi (`/etc/shadow`) ele geçirir.
4. **Veri kaçırma:** dnscat2 ile veriyi DNS tüneli üzerinden firewall'ı aşarak dışarı sızdırır.
5. **Tespit + önleme (Blue):** Wazuh/SOC anomaliyi yakalar; Ansible ile açıklar kapatılır.

---

## Ağ mimarisi

```
   Dış ağ (192.168.56.0/24)              İç ağ (192.168.57.0/24)
   ┌───────────────┐                     ┌────────────────────────┐
   │ kali    .100  │                     │ int-dns .2  (BIND9/AXFR)│
   │ c2-dns  .200  │      ┌──────────┐   │ web     .3  (RCE+gdb)   │
   └───────┬───────┘      │ firewall │   │ nfs     .4  (no_root_sq)│
           └──────────────┤ .10/.254 ├───┤ (soc/wazuh — Blue)     │
       yalnız 53 & 8080   └──────────┘   └────────────────────────┘
```

İç makinelere doğrudan IP ile gidilmez; her erişim firewall + DNS + pivot üzerinden geçer.
Dışarı çıkışta yalnız 53/DNS açıktır — bu yüzden veri kaçırma DNS tüneline zorlanır.

| Makine | IP | Rol / Zafiyet |
|--------|-----|---------------|
| kali | 192.168.56.100 | Saldırgan başlangıç noktası |
| c2-dns | 192.168.56.200 | dnscat2 C2 / sim-internet DNS |
| firewall | 192.168.56.10 / 192.168.57.254 | İki bacaklı ağ geçidi (iptables) |
| int-dns | 192.168.57.2 | BIND9 — AXFR açık |
| web | 192.168.57.3 | Komut enjeksiyonu + gdb cap_setuid |
| nfs | 192.168.57.4 | NFS no_root_squash, kritik veri |

---

## Kurulum ve çalıştırma

**Ön koşullar:** VirtualBox veya VMware (tüm ekip **aynı** provider), Vagrant.
Windows'ta repo klasörünü Defender dışlamasına ekleyin ve `.sh` dosyalarını **LF** ile kaydedin.

```bash
git clone https://github.com/muhammedSeyrek/vulnhub_task.git
cd vulnhub_task
vagrant up
vagrant status        # tüm makineler "running" olmalı
```

Web hazır mı (kali'den):
```bash
vagrant ssh kali
curl -s http://192.168.56.10:8080/index.php     # nginx + php-fpm ayakta
```

Ayrıntılı adım adım akış ve uzaktan/dağıtık çalışma seçenekleri için: **[red/ROADMAP.md](red/ROADMAP.md)**

---

## Depo yapısı

```
Vagrantfile                 Tüm makinelerin tanımı ve provisioning'i
provisioning/
  firewall (inline)         iptables kuralları (segmentasyon + DNAT)
  int-dns/                  BIND9 + AXFR zone (altay.sec)
  c2-dns/                   dnscat2 forward zone (altay.insecure)
  kali/                     dnscat2 kurulumu + saldırı araçları
  web/                      nginx + php-fpm + shell + gdb cap zafiyeti
  nfs/                      NFS no_root_squash + SSH anahtarı
red/                        Red Team (Rol 1) çıktıları
  recon/recon.sh            Faz 1 otomatik keşif (AXFR + tarama)
  RAPOR.md                  Saldırı raporu (faz 1–3, delillerle)
  ROADMAP.md                Sunum / çalıştırma kılavuzu
  evidence/                 Ekran görüntüleri ve çıktılar
```

---

## Roller

| Rol | Takım | Sorumluluk |
|-----|-------|-----------|
| Rol 1 | Red | Keşif + sızma (faz 1–3) — `red/RAPOR.md` |
| Rol 2 | Red | dnscat2 ile DNS tüneli / veri kaçırma (faz 4) |
| Rol 3 | Blue | Ansible sıkılaştırma + DNSSEC (önleme) |
| Rol 4 | Blue | Wazuh/SOC + Pi-hole (tespit) |
| Koordinasyon | — | Entegrasyon, sunum, teslim |

---

## Notlar

- Provider birliği şarttır: `virtualbox__intnet` ayarını VMware yok sayar.
- Sorun giderme (Defender, NFS mount, shell.php 404 vb.) için ROADMAP'in son bölümüne bakın.
- Özel SSH anahtarı repoda tutulmaktadır; izole lab için kabul edilebilir, üretimde asla.