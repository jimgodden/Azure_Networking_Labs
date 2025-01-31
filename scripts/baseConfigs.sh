#!/bin/bash

# Get the hostname of the computer
hostname=$(hostname)

# Define configurations
VM01Config="frr version 10.2.1
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

VM02Config="frr version 10.2.1
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

VM03Config="frr version 10.2.1
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

VM04Config="frr version 10.2.1
frr defaults traditional
hostname VM04
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

# Apply configuration based on hostname
case $hostname in
  "VM01")
    echo "Applying configuration for VM01"
    echo "$VM01Config" | sudo tee /etc/frr/frr.conf
    ;;
  "VM02")
    echo "Applying configuration for VM02"
    echo "$VM02Config" | sudo tee /etc/frr/frr.conf
    ;;
  "VM03")
    echo "Applying configuration for VM03"
    echo "$VM03Config" | sudo tee /etc/frr/frr.conf
    ;;
  "VM04")
    echo "Applying configuration for VM04"
    echo "$VM04Config" | sudo tee /etc/frr/frr.conf
    ;;
  *)
    echo "Hostname not recognized. No configuration applied."
    ;;
esac

# Restart FRR to apply the new configuration
sudo systemctl restart frr
