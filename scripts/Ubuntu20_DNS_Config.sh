#!/bin/bash

# Update package information and install BIND9
sudo apt update
sudo apt upgrade -y
sudo apt install bind9 bind9utils bind9-doc -y

sudo cat <<EOF > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    recursion yes; // Enable recursive queries
    allow-query { any; }; // Allow queries from any client

    forwarders {
        168.63.129.16; // Azure DNS forwarder
    };

    listen-on-v6 { any; };
};
EOF

# Configure DNS resolver to use the local BIND9 server
# sudo echo "nameserver 127.0.0.1" > /etc/resolv.conf

# Restart BIND9 to apply changes
sudo systemctl restart bind9

# Enable and start the BIND9 service on boot
# sudo systemctl enable bind9
