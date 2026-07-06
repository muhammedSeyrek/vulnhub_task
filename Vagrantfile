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

# BIND9 Şirket ağı DNS Sunucusu

  config.vm.define "int-dns" do |dns|
    dns.vm.hostname = "int-dns"
    dns.vm.network "private_network",
      ip: "192.168.57.2",
      virtualbox__intnet: INT_NET
    dns.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end
    dns.vm.provision "shell", inline: "apt-get update"
    dns.vm.provision "shell", inline: internal_routing_script
  end

# Web Makinesi

  config.vm.define "web" do |web|
    web.vm.hostname = "web-server"
    web.vm.network "private_network",
      ip: "192.168.57.3",
      virtualbox__intnet: INT_NET
    web.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end
    web.vm.provision "shell", inline: "apt-get update"
    web.vm.provision "shell", inline: internal_routing_script
  end

# NFS Makinesi

  config.vm.define "nfs" do |nfs|
    nfs.vm.hostname = "nfs-server"
    nfs.vm.network "private_network",
      ip: "192.168.57.4",
      virtualbox__intnet: INT_NET
    nfs.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
    end
    nfs.vm.provision "shell", inline: "apt-get update"
    nfs.vm.provision "shell", inline: internal_routing_script
  end

end
