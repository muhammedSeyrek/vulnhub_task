Vagrant.configure("2") do |config|
  # Genel ayarlar: Tüm makineler için geçerli ortak kutu
  config.vm.box = "generic/debian12"

  # ==========================================
  # ÖNEMLİ DÜZELTME
  # ==========================================
  # Önceki sürümde "private_network" kullanılıyordu. Bu, VirtualBox'ta
  # HOST-ONLY network oluşturur ve HOST makinenizin kendisi de bu ağa
  # bir arayüzle (vboxnetX) dahil olur. Eğer host'ta IP forwarding
  # açıksa (ip_forward=1), host, dış ağ (192.168.56.x) ile iç ağ
  # (192.168.57.x) arasında paketleri KENDİSİ yönlendirir ve firewall
  # VM'ini tamamen atlar. Ping'in firewall kurallarına rağmen
  # ulaşmasının sebebi tam olarak buydu.
  #
  # Çözüm: "virtualbox__intnet" ile INTERNAL NETWORK kullanmak.
  # Internal network'te host'a hiçbir arayüz verilmez; sadece aynı
  # intnet ismine sahip VM'ler birbirini görebilir. Böylece iki ağ
  # arasındaki TEK yol firewall VM'i üzerinden geçmek zorunda kalır.
  # ==========================================

  EXT_NET = "dis-ag"   # 192.168.56.0/24 (Dış / İnternet tarafı)
  INT_NET = "ic-ag"    # 192.168.57.0/24 (İç şirket ağı)

  # ==========================================
  # 1. DIŞ AĞ (İNTERNET) MAKİNELERİ (192.168.56.x)
  # ==========================================

  config.vm.define "kali" do |kali|
    kali.vm.hostname = "kali-attacker"
    kali.vm.network "private_network",
      ip: "192.168.56.100",
      virtualbox__intnet: EXT_NET
    kali.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.linked_clone = true
    end
      # ==========================================
      # dnscat2 SUNUCUSU (Saldırganın kendi C2 altyapısı)
      # ==========================================
      # generic/debian12 düz Debian olduğu için hiçbir araç hazır gelmiyor.
      # Kurulumun tamamı gerçek bir script dosyasında:
      #   provisioning/kali/setup-dnscat2.sh
      # int-dns/c2-dns'te olduğu gibi: host'taki script /tmp altına
      # kopyalanıyor, sonra shell provisioner ile çalıştırılıyor.
      kali.vm.provision "file",
        source: "provisioning/kali/setup-dnscat2.sh",
        destination: "/tmp/setup-dnscat2.sh"
  
      kali.vm.provision "shell", inline: <<-SHELL
        chmod +x /tmp/setup-dnscat2.sh
        /tmp/setup-dnscat2.sh
      SHELL
    end

  config.vm.define "c2-dns" do |c2|
    c2.vm.hostname = "c2-server"
    c2.vm.network "private_network",
      ip: "192.168.56.200",
      virtualbox__intnet: EXT_NET
    c2.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end
 
    # ==========================================
    # "SİMÜLE İNTERNET DNS" — sadece yönlendirme yapar
    # ==========================================
    # Bu makine gerçek dünyadaki genel internet DNS altyapısını temsil
    # eder. Kendi başına hiçbir zafiyet ya da C2 barındırmaz; sadece
    # "altay.insecure" domainine gelen sorguları, o domainin gerçek
    # sahibine (kali, 192.168.56.100) yönlendirir — tıpkı bir kök/TLD
    # sunucusunun bir domainin NS kaydına bakıp doğru sunucuya
    # yönlendirmesi gibi.
    #
    # int-dns'te olduğu gibi: config dosyaları host'ta gerçek dosyalar
    # olarak duruyor (provisioning/c2-dns/), file provisioner ile /tmp
    # altına kopyalanıp shell provisioner'da /etc/bind altına taşınıyor.
    c2.vm.provision "file",
      source: "provisioning/c2-dns/named.conf.local",
      destination: "/tmp/named.conf.local"
    c2.vm.provision "file",
      source: "provisioning/c2-dns/named.conf.options",
      destination: "/tmp/named.conf.options"
 
    c2.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y bind9 bind9utils dnsutils
 
      cp /tmp/named.conf.local    /etc/bind/named.conf.local
      cp /tmp/named.conf.options  /etc/bind/named.conf.options
 
      named-checkconf
      systemctl restart named
      systemctl enable named
    SHELL
  end

  # ==========================================
  # 2. FIREWALL (AĞ GEÇİDİ - 2 BACAKLI)
  # ==========================================
  config.vm.define "firewall" do |fw|
    fw.vm.hostname = "firewall-gateway"
    fw.vm.network "private_network",
      ip: "192.168.56.10",
      virtualbox__intnet: EXT_NET       # eth1: Dış Ağ
    fw.vm.network "private_network",
      ip: "192.168.57.254",
      virtualbox__intnet: INT_NET      # eth2: İç Ağ

    fw.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end

    fw.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y iptables-persistent

      echo 1 > /proc/sys/net/ipv4/ip_forward
      sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

      # 1. ESKİ HER ŞEYİ TEMİZLE
      iptables -F
      iptables -X
      iptables -t nat -F

      # 2. VARSAYILAN POLİTİKALARI 'YASAK' OLARAK BELİRLE (Katı Kurallar)
      iptables -P INPUT DROP
      iptables -P FORWARD DROP
      iptables -P OUTPUT ACCEPT

      # ==========================================
      # 3. INPUT ZİNCİRİ (Firewall'un Kendisine Gelen Trafik)
      # ==========================================
      # Vagrant'ın SSH yapabilmesi için eth0 (NAT) arayüzüne izin ver (Zorunlu)
      iptables -A INPUT -i eth0 -j ACCEPT
      # Makinenin kendi iç döngüsüne (localhost) izin ver
      iptables -A INPUT -i lo -j ACCEPT
      # Daha önce başlamış, güvenilir bağlantıların cevaplarına izin ver
      iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      # DIŞARIDAN GELEN DİĞER HER ŞEY (Ping dahil) DROP POLİTİKASINA TAKILIP ÇÖPE GİDECEK!

      # ==========================================
      # 4. YÖNLENDİRME (Port Forwarding & NAT)
      # ==========================================
      iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 8080 -j DNAT --to-destination 192.168.57.3:8080
      iptables -t nat -A PREROUTING -i eth1 -p udp --dport 53 -j DNAT --to-destination 192.168.57.2:53
      iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 53 -j DNAT --to-destination 192.168.57.2:53
      iptables -t nat -A POSTROUTING -o eth1 -s 192.168.57.0/24 -j MASQUERADE

      # ==========================================
      # 5. FORWARD ZİNCİRİ (Firewall'un İçinden Geçen Trafik)
      # ==========================================
      iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

      # DIŞARIDAN (eth1) İÇERİYE (eth2) SADECE YÖNLENDİRİLEN PORTLARA İZİN VER
      iptables -A FORWARD -i eth1 -o eth2 -p tcp -d 192.168.57.3 --dport 8080 -j ACCEPT
      iptables -A FORWARD -i eth1 -o eth2 -p udp -d 192.168.57.2 --dport 53 -j ACCEPT
      iptables -A FORWARD -i eth1 -o eth2 -p tcp -d 192.168.57.2 --dport 53 -j ACCEPT

      # PING (ICMP) TRAFİĞİNİ KESİNLİKLE YASAKLA (Açık kapı bırakmamak için ekstra kural)
      iptables -A FORWARD -p icmp -j DROP

      # İÇERİDEN (eth2) DIŞARIYA (eth1) SADECE 53 (DNS) PORTUNA İZİN VER
      iptables -A FORWARD -i eth2 -o eth1 -p udp --dport 53 -j ACCEPT
      iptables -A FORWARD -i eth2 -o eth1 -p tcp --dport 53 -j ACCEPT

      # Kuralları kalıcı olarak kaydet
      iptables-save > /etc/iptables/rules.v4
    SHELL
  end

  # ==========================================
  # 3. İÇ AĞ (ŞİRKET) MAKİNELERİ (192.168.57.x)
  # ==========================================

  internal_routing_script = <<-SHELL
    ip route del default
    ip route add default via 192.168.57.254

    # Kalıcılık: Bu rotayı /etc/network/interfaces.d/ altına yazarak
    # reboot / vagrant reload sonrasında da korunmasını sağla.
    printf '%s\\n' \
      'up ip route del default 2>/dev/null || true' \
      'up ip route add default via 192.168.57.254' \
      > /etc/network/interfaces.d/60-default-route
  SHELL

  # Tüm iç ağ makinelerinin DNS'ini bizim DNS sunucusuna sabitleyen script
  dns_fix_script = <<-SHELL
    echo "nameserver 192.168.57.2" > /etc/resolv.conf
  SHELL

  # Bu, dosyaları /tmp altına kopyaladıktan sonra doğru yerlerine taşıyıp
  # BIND9'u kuran/başlatan kısa betik. Asıl içerik artık gerçek dosyalarda:
  #   provisioning/int-dns/db.altay.sec
  #   provisioning/int-dns/named.conf.local
  #   provisioning/int-dns/named.conf.options
  bind9_install_script = <<-SHELL
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y bind9 bind9utils dnsutils

    cp /tmp/db.altay.sec        /etc/bind/db.altay.sec
    cp /tmp/named.conf.local    /etc/bind/named.conf.local
    cp /tmp/named.conf.options  /etc/bind/named.conf.options

    named-checkzone altay.sec /etc/bind/db.altay.sec
    named-checkconf
    systemctl restart named
    systemctl enable named 
  SHELL

  config.vm.define "int-dns" do |dns|
    dns.vm.hostname = "int-dns"
    dns.vm.network "private_network",
      ip: "192.168.57.2",
      virtualbox__intnet: INT_NET
    dns.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end

    # 1) Host'taki gerçek dosyaları VM'e kopyala (vagrant kullanıcısının
    #    yazabildiği /tmp altına — /etc/bind'a direkt yazma izni yok).
    dns.vm.provision "file",
      source: "provisioning/int-dns/db.altay.sec",
      destination: "/tmp/db.altay.sec"
    dns.vm.provision "file",
      source: "provisioning/int-dns/named.conf.local",
      destination: "/tmp/named.conf.local"
    dns.vm.provision "file",
      source: "provisioning/int-dns/named.conf.options",
      destination: "/tmp/named.conf.options"

    # 2) BIND9'u kur, dosyaları /etc/bind altına taşı, servisi başlat.
    #    Internet gerektirdiği için route firewall'a çevrilmeden ÖNCE çalışmalı.
    dns.vm.provision "shell", inline: bind9_install_script

    # 3) Son olarak default route'u firewall'a çevir (kalıcı).
    dns.vm.provision "shell", inline: internal_routing_script
    dns.vm.provision "shell", inline: dns_fix_script
  end

  config.vm.define "web" do |web|
    web.vm.hostname = "web-server"
    web.vm.network "private_network",
      ip: "192.168.57.3",
      virtualbox__intnet: INT_NET
    web.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end

    # 1. Host makinedeki Private Key'i VM'e aktar
    web.vm.provision "file", source: "provisioning/web/id_rsa_nfs", destination: "/home/vagrant/id_rsa_nfs"

    # 2. Python uygulamasını bilgisayarımızdan Sanal Makineye kopyala
    web.vm.provision "file", source: "provisioning/web/whois_app.py", destination: "/home/vagrant/whois_app.py"

    # 1. Kurulum ve Zafiyet Yapılandırma Betiğini (bash script) çalıştır
    web.vm.provision "shell", path: "provisioning/web/setup.sh"
    
    # 3. Ortak Ağ Geçidi Scripti (Firewall Yönlendirmesi)
    web.vm.provision "shell", inline: internal_routing_script
    web.vm.provision "shell", inline: dns_fix_script
    # -------------------------------------------------------------
    # C. WEB SERVİSİNİ BAŞLATMA
    # -------------------------------------------------------------
    web.vm.provision "shell", inline: "nohup /usr/bin/python3 /home/vagrant/whois_app.py > /home/vagrant/web.log 2>&1 &"

  end

  config.vm.define "nfs" do |nfs|
    nfs.vm.hostname = "nfs-server"
    nfs.vm.network "private_network",
      ip: "192.168.57.4",
      virtualbox__intnet: INT_NET
    nfs.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end

    # 1. Düşük yetkili kullanıcı oluşturma 
    nfs.vm.provision "shell", inline: "useradd -m -s /bin/bash user"
    # 2. Host makinedeki Public Key'i VM'e aktar
    nfs.vm.provision "file", source: "provisioning/nfs/id_rsa_nfs.pub", destination: "/home/vagrant/id_rsa_nfs.pub"
    # SSH anahtar kurulumu
    nfs.vm.provision "shell", path: "provisioning/nfs/ssh.sh"
    # NFS Sunucu kurulumu
    nfs.vm.provision "shell", path: "provisioning/nfs/nfs-setup.sh"
    # Firewall Yönlendirmesi
    nfs.vm.provision "shell", inline: internal_routing_script
    nfs.vm.provision "shell", inline: dns_fix_script
  end
end
