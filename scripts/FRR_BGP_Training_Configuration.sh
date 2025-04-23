#!/bin/bash

# update and install FRR
sudo apt update
sudo apt install frr -y

sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons

sudo systemctl restart frr

# Sets the base configurations file for the VM with hostname VM01
if [ "$(hostname)" = "VM01" ]; then

sudo tee /noConfig.sh > /dev/null << 'EOF'
NoConfig="frr version 10.2.1
frr defaults traditional
hostname VM01
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

echo "Removing configuration for VM01"
echo "$NoConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /noConfig.sh

# Save the script to /baseConfig.sh
sudo tee /baseConfig.sh > /dev/null << 'EOF'
#!/bin/bash

# Define base configurations
BaseConfig="frr version 10.2.1
frr defaults traditional
hostname VM01
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.100.2.20/32 10.100.1.1
!
router bgp 100
 bgp router-id 10.100.1.10
 no bgp ebgp-requires-policy
 neighbor 10.100.2.20 remote-as 200
 neighbor 10.100.2.20 description VM2
 neighbor 10.100.2.20 solo
 neighbor 10.100.2.20 disable-connected-check
 !
 address-family ipv4 unicast
    network 10.100.1.0/24
    neighbor 10.100.2.20 soft-reconfiguration inbound
 exit-address-family
exit
!"

echo "Applying base configuration for VM01"
echo "$BaseConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /baseConfig.sh

fi # End of the base configurations file for the VM with hostname VM01


# Sets the base configurations file for the VM with hostname VM02
if [ "$(hostname)" = "VM02" ]; then

sudo tee /noConfig.sh > /dev/null << 'EOF'
NoConfig="frr version 10.2.1
frr defaults traditional
hostname VM02
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

echo "Removing configuration for VM02"
echo "$NoConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /noConfig.sh

# Save the script to /baseConfig.sh
sudo tee /baseConfig.sh > /dev/null << 'EOF'
#!/bin/bash

# Define base configurations
BaseConfig="frr version 10.2.1
frr defaults traditional
hostname VM02
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.100.1.10/32 10.100.2.1
ip route 10.100.3.30/32 10.100.2.1
!
router bgp 200
 bgp router-id 10.100.2.20
 no bgp ebgp-requires-policy
 neighbor 10.100.1.10 remote-as 100
 neighbor 10.100.1.10 description VM1
 neighbor 10.100.1.10 solo
 neighbor 10.100.1.10 disable-connected-check
 neighbor 10.100.3.30 remote-as 300
 neighbor 10.100.3.30 description VM3
 neighbor 10.100.3.30 solo
 neighbor 10.100.3.30 disable-connected-check
 !
 address-family ipv4 unicast
  network 10.100.2.0/24
  neighbor 10.100.1.10 soft-reconfiguration inbound
  neighbor 10.100.3.30 soft-reconfiguration inbound
 exit-address-family
exit
!"

echo "Applying base configuration for VM02"
echo "$BaseConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /baseConfig.sh

fi # End of the base configurations file for the VM with hostname VM02


# Sets the base configurations file for the VM with hostname VM03
if [ "$(hostname)" = "VM03" ]; then

sudo tee /noConfig.sh > /dev/null << 'EOF'
NoConfig="frr version 10.2.1
frr defaults traditional
hostname VM03
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

echo "Removing configuration for VM03"
echo "$NoConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /noConfig.sh

# Save the script to /baseConfig.sh
sudo tee /baseConfig.sh > /dev/null << 'EOF'
#!/bin/bash

# Define base configurations
BaseConfig="frr version 10.2.1
frr defaults traditional
hostname VM03
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.100.2.20/32 10.100.3.1
!
router bgp 300
 bgp router-id 10.100.3.30
 no bgp ebgp-requires-policy
 neighbor 10.100.2.20 remote-as 200
 neighbor 10.100.2.20 description VM2
 neighbor 10.100.2.20 solo
 neighbor 10.100.2.20 disable-connected-check
 !
 address-family ipv4 unicast
  network 10.100.3.0/24
  neighbor 10.100.2.20 soft-reconfiguration inbound
 exit-address-family
exit
!"

echo "Applying base configuration for VM03"
echo "$BaseConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /baseConfig.sh

fi # End of the base configurations file for the VM with hostname VM03


# Sets the base configurations file for the VM with hostname VM04
if [ "$(hostname)" = "VM04" ]; then

sudo tee /noConfig.sh > /dev/null << 'EOF'
NoConfig="frr version 10.2.1
frr defaults traditional
hostname VM04
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

echo "Removing configuration for VM04"
echo "$NoConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /noConfig.sh

# Save the script to /baseConfig.sh
sudo tee /baseConfig.sh > /dev/null << 'EOF'
#!/bin/bash

# Define base configurations
BaseConfig="frr version 10.2.1
frr defaults traditional
hostname VM04
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

echo "Applying base configuration for VM04"
echo "$BaseConfig" | sudo tee /etc/frr/frr.conf

# Restart FRR to apply the new configuration
sudo systemctl restart frr
EOF

# Make the script executable
sudo chmod +x /baseConfig.sh

fi # End of the base configurations file for the VM with hostname VM04


# # Define the script content
# SCRIPT_CONTENT='#!/bin/bash
# if ! groups $USER | grep -q "\bsudo\b"; then
#     sudo usermod -aG sudo $USER
# fi'

# # Create the script in /etc/profile.d/
# echo "$SCRIPT_CONTENT" > /etc/profile.d/add_sudo.sh

# # Make the script executable
# chmod +x /etc/profile.d/add_sudo.sh

