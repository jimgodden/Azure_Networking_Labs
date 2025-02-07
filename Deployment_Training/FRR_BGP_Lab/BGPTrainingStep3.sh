######################################################################################################################################################################
# Lab 03
######################################################################################################################################################################

# 1. Establish eBGP Sessions


########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

sudo su
vtysh
configure terminal
ip route 10.100.4.40/32 10.100.1.1
router bgp 100
neighbor 10.100.4.40 remote-as 200
neighbor 10.100.4.40 disable-connected-check
neighbor 10.100.4.40 solo
neighbor 10.100.4.40 description VM4
address-family ipv4 unicast
neighbor 10.100.4.40 soft-reconfiguration inbound
neighbor 10.100.4.40 activate
exit-address-family
exit
exit


########################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

sudo su
vtysh
configure terminal
ip route 10.100.4.40/32 10.100.1.1
router bgp 300
neighbor 10.100.4.40 remote-as 200
neighbor 10.100.4.40 disable-connected-check
neighbor 10.100.4.40 solo
neighbor 10.100.4.40 description VM4
address-family ipv4 unicast
neighbor 10.100.4.40 soft-reconfiguration inbound
neighbor 10.100.4.40 activate
exit-address-family
exit
exit


########################################################
# VM4 Private IP: 10.100.4.40
# FRR CONFIG

sudo su
vtysh
configure terminal
ip route 10.100.1.10/32 10.100.4.1
ip route 10.100.3.30/32 10.100.4.1
router bgp 200
bgp router-id 10.100.4.40
no bgp ebgp-requires-policy
neighbor 10.100.1.10 remote-as 100
neighbor 10.100.1.10 disable-connected-check
neighbor 10.100.1.10 solo
neighbor 10.100.1.10 description VM1
neighbor 10.100.3.30 remote-as 300
neighbor 10.100.3.30 disable-connected-check
neighbor 10.100.3.30 solo
neighbor 10.100.3.30 description VM3
address-family ipv4 unicast
network 10.100.4.0/24
neighbor 10.100.1.10 soft-reconfiguration inbound
neighbor 10.100.1.10 activate
neighbor 10.100.3.30 soft-reconfiguration inbound
neighbor 10.100.3.30 activate
exit-address-family
exit
exit

#######################################################


# 3. AS PATH Prepending


########################################################
# VM2 Private IP: 10.100.2.20
# FRR CONFIG

configure
route-map asPath permit 10
set as-path prepend 12345 12345 12345
router bgp 200
neighbor 10.100.1.10 remote-as 100
neighbor 10.100.1.10 route-map asPath out
neighbor 10.100.3.30 remote-as 300
neighbor 10.100.3.30 route-map asPath out
exit
exit

# Undo the AS Path Prepending

########################################################
# VM2 Private IP: 10.100.2.20
# FRR CONFIG

configure
no route-map asPath permit 10
router bgp 200
no neighbor 10.100.1.10 route-map asPath out
no neighbor 10.100.3.30 route-map asPath out


# 4. Local Preference Attribute



########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
route-map setLocalPref permit 10
set local-preference 300
exit
router bgp 100
neighbor 10.100.2.20 remote-as 200
address-family ipv4 unicast
neighbor 10.100.2.20 route-map setLocalPref in
exit
exit
exit



########################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

configure
route-map setLocalPref permit 10
set local-preference 300
exit
router bgp 300
neighbor 10.100.2.20 remote-as 200
address-family ipv4 unicast
neighbor 10.100.2.20 route-map setLocalPref in
exit
exit
exit



# Undo the LocalPref

########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
no route-map setLocalPref permit 10
router bgp 100
neighbor 10.100.2.20 remote-as 200
address-family ipv4 unicast
no neighbor 10.100.2.20 route-map setLocalPref in
exit
exit
exit



########################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

configure
no route-map setLocalPref permit 10
router bgp 300
neighbor 10.100.2.20 remote-as 200
address-family ipv4 unicast
no neighbor 10.100.2.20 route-map setLocalPref in
exit
exit
exit




# 5. Route Weight Attribute


########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
route-map setWeight permit 10
set weight 100
exit
router bgp 100
address-family ipv4 unicast
neighbor 10.100.2.20 route-map setWeight in
exit
exit
exit



########################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

configure
route-map setWeight permit 10
set weight 100
exit
router bgp 300
address-family ipv4 unicast
neighbor 10.100.2.20 route-map setWeight in
exit
exit
exit
