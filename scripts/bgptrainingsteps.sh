# 2. Configure BGP


sudo su
vtysh
configure terminal


########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

sudo su
vtysh
configure terminal
router bgp 100
bgp router-id 10.100.1.10
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


########################################################
# VM2 Private IP: 10.100.2.20
# FRR CONFIG

sudo su
vtysh
configure terminal
router bgp 200
bgp router-id 10.100.2.20
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
neighbor 10.100.1.10 soft-reconfiguration inbound
neighbor 10.100.1.10 activate
neighbor 10.100.3.30 soft-reconfiguration inbound
neighbor 10.100.3.30 activate
exit-address-family
exit
exit

#######################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

sudo su
vtysh
configure terminal
router bgp 300
bgp router-id 10.100.3.30
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

########################################################


# 3. Confirm BGP Session Establishment
show ip bgp summary


# 4. Advertise a Route

# VM1
show ip bgp neighbors 10.100.2.20 advertised-routes
show ip bgp neighbors 10.100.2.20 received-routes

# VM2
show ip bgp neighbors 10.100.1.10 advertised-routes
show ip bgp neighbors 10.100.1.10 received-routes
show ip bgp neighbors 10.100.3.30 advertised-routes
show ip bgp neighbors 10.100.3.30 received-routes

# VM3
show ip bgp neighbors 10.100.2.20 advertised-routes
show ip bgp neighbors 10.100.2.20 received-routes


# VM1
configure terminal
router bgp 100
address-family ipv4 unicast
network 10.100.1.0/24
exit-address-family
exit
exit
show ip bgp neighbors 10.100.2.20 advertised-routes
show ip bgp neighbors 10.100.2.20 received-routes



# 5. Complete baseline configuration


# VM2
configure terminal
router bgp 200
address-family ipv4 unicast
network 10.100.2.0/24
exit-address-family
exit
exit


# VM3
configure terminal
router bgp 300
address-family ipv4 unicast
network 10.100.3.0/24
exit-address-family
exit
exit
