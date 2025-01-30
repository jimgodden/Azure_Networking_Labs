#!/bin/bash

# add GPG key
curl -s https://deb.frrouting.org/frr/keys.gpg | sudo tee /usr/share/keyrings/frrouting.gpg > /dev/null

# possible values for FRRVER: 
frr-6 frr-7 frr-8 frr-9.0 frr-9.1 frr-10 frr10.0 frr10.1 frr-stable
# frr-stable will be the latest official stable release
FRRVER="frr-stable"
echo deb '[signed-by=/usr/share/keyrings/frrouting.gpg]' https://deb.frrouting.org/frr \
     $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
sudo apt update
sudo apt install frr -y

sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons

sudo systemctl restart frr

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

sudo sysctl -p

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# configure ssh to listen on both ports 22 and 2022
sudo sed -i '/^Port 22/a Port 2022' /etc/ssh/sshd_config && sudo systemctl restart ssh
sudo ufw allow 2022/tcp
sudo ufw reload

# download scripts that will automate the configuration of FRR for each step of the lab
curl -o /step1.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/step1.sh
curl -o /step2.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/step2.sh
curl -o /step3.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/step3.sh
curl -o /step4.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/step4.sh
curl -o /step5.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/step5.sh

# make scripts executable
sudo chmod +x /step1.sh
sudo chmod +x /step2.sh
sudo chmod +x /step3.sh
sudo chmod +x /step4.sh
sudo chmod +x /step5.sh
