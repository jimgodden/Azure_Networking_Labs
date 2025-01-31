#!/bin/bash

# Get the hostname of the computer
hostname=$(hostname)

# Define configurations
VM01Config="frr version 10.2.1
frr defaults traditional
hostname VM01
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

VM02Config="frr version 10.2.1
frr defaults traditional
hostname VM02
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

VM03Config="frr version 10.2.1
frr defaults traditional
hostname VM03
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config"

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
