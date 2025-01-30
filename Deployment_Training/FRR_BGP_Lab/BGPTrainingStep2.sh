########################################################
# VM2 Private IP: 10.100.2.20
# FRR CONFIG

sudo su
vtysh
configure terminal
ip route 10.100.4.40/32 10.100.2.1
router bgp 200
neighbor 10.100.4.40 remote-as 200
neighbor 10.100.4.40 disable-connected-check
neighbor 10.100.4.40 solo
neighbor 10.100.4.40 description VM4
address-family ipv4 unicast
neighbor 10.100.4.40 next-hop-self
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
ip route 10.100.2.20/32 10.100.4.1
router bgp 200
bgp router-id 10.100.4.40
no bgp ebgp-requires-policy
neighbor 10.100.2.20 remote-as 200
neighbor 10.100.2.20 disable-connected-check
neighbor 10.100.2.20 solo
neighbor 10.100.2.20 description VM2
address-family ipv4 unicast
neighbor 10.100.2.20 soft-reconfiguration inbound
neighbor 10.100.2.20 activate
exit-address-family
exit
exit


show ip bgp neighbors 10.100.2.20 advertised-routes
show ip bgp neighbors 10.100.2.20 received-routes



########################################################
# Baseline Configuration
########################################################


########################################################
# VM1 Private IP: 10.100.1.10
# FRR CONFIG




########################################################
# VM2 Private IP: 10.100.2.20
# FRR CONFIG



########################################################
# VM3 Private IP: 10.100.3.30
# FRR CONFIG



########################################################
# VM4 Private IP: 10.100.4.40
# FRR CONFIG