######################################################################################################################################################################
# Lab 05
######################################################################################################################################################################

# Configure BGP Monitoring
# Run on all VMs

terminal monitor

debug bgp keepalives
debug bgp neighbor-events
debug bgp updates in
debug bgp updates out


# Break the BGP connection between VM1 and VM2

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
router bgp 100
no neighbor 10.100.2.20 remote-as 200
neighbor 10.100.2.20 remote-as 500
exit
exit

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

terminal monitor bgp


########################################################
# VM 2 Private IP: 10.100.2.20
# FRR CONFIG

clear bgp *


# Break the BGP connection between VM1 and VM2 - **FIXED**

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
router bgp 100
no neighbor 10.100.2.20 remote-as 500
neighbor 10.100.2.20 remote-as 200
exit
exit

# Incorrect peer IP

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
router bgp 100
no neighbor 10.100.2.20 remote-as 200
neighbor 10.100.3.30 remote-as 200
neighbor 10.100.3.30 disable-connected-check
neighbor 10.100.3.30 solo
address-family ipv4 unicast
neighbor 10.100.3.30 soft-reconfiguration inbound
neighbor 10.100.3.30 activate
exit
exit
exit

# Incorrect peer IP - **FIXED**

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
router bgp 100
no neighbor 10.100.3.30 remote-as 200
no neighbor 10.100.3.30 disable-connected-check
no neighbor 10.100.3.30 solo
neighbor 10.100.2.20 remote-as 200
neighbor 10.100.2.20 disable-connected-check
neighbor 10.100.2.20 solo
address-family ipv4 unicast
no neighbor 10.100.3.30 soft-reconfiguration inbound
no neighbor 10.100.3.30 activate
neighbor 10.100.2.20 soft-reconfiguration inbound
neighbor 10.100.2.20 activate
exit
exit
exit
