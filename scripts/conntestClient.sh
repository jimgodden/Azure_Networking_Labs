#!/bin/bash

hname=$(hostname)

curl -o /tmp/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x /tmp/conntest

mkdir /mnt/$4
if [ ! -d "/etc/smbcredentials" ]; then
mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/$3.cred" ]; then
    echo "username=$3" >> /etc/smbcredentials/$3.cred
    echo "password=$5" >> /etc/smbcredentials/$3.cred
fi
chmod 600 /etc/smbcredentials/$3.cred

echo "//$3.file.core.windows.net/$4 /mnt/$4 cifs nofail,credentials=/etc/smbcredentials/$3.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab
mount -t cifs //$3.file.core.windows.net/$4 /mnt/$4 -o credentials=/etc/smbcredentials/$3.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

directory="/mnt/$4/$2"

if [ ! -d $directory ]; then
    mkdir -p $directory
fi

chmod 600 $directory


nohup tcpdump -w /mnt/$4/$2/$hname-trace-%m-%d-%H-%M-%S.pcap host $1 -G 3800 -C 500M -s 120 -K -n &

nohup /tmp/conntest -c $1 -p 5001 &





















