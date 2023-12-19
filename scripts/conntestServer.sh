#!/bin/bash

hname=$(hostname)

curl -o /tmp/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x /tmp/conntest

mkdir /mnt/$3
if [ ! -d "/etc/smbcredentials" ]; then
mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/$2.cred" ]; then
    echo "username=$2" >> /etc/smbcredentials/$2.cred
    echo "password=$4" >> /etc/smbcredentials/$2.cred
fi
chmod 600 /etc/smbcredentials/$2.cred

echo "//$2.file.core.windows.net/$3 /mnt/$3 cifs nofail,credentials=/etc/smbcredentials/$2.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab
mount -t cifs //$2.file.core.windows.net/$3 /mnt/$3 -o credentials=/etc/smbcredentials/$2.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

directory="/mnt/$3/$1"

if [ ! -d $directory ]; then
    mkdir -p $directory
fi

chmod 600 $directory

nohup tcpdump -w /mnt/$3/$1/$hname-trace-%m-%d-%H-%M-%S.pcap port 5001 -G 3800 -C 500M -s 120 -K -n &

nohup /tmp/conntest -s -p 5001 &




















