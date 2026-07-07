#!/bin/bash

mkdir -p /home/user/.ssh
chmod 700 /home/user/.ssh

# Public anahtarı taşı 
mv /home/vagrant/id_rsa_nfs.pub /home/user/.ssh/id_rsa_nfs.pub

cat /home/user/.ssh/id_rsa_nfs.pub > /home/user/.ssh/authorized_keys

# İzin ayarları
chmod 600 /home/user/.ssh/authorized_keys
chown -R user:user /home/user/.ssh