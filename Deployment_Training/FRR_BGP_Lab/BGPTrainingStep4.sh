######################################################################################################################################################################
# Lab 04
######################################################################################################################################################################

# 1. Tag Routes with Community Value


########################################################
# VM 3 Private IP: 10.100.3.30
# FRR CONFIG

configure
ip route 25.0.0.0/24 10.100.3.1
ip route 25.0.1.0/24 10.100.3.1
ip route 25.100.1.0/24 10.100.3.1
ip route 25.100.0.0/24 10.100.3.1
router bgp 300
address-family ipv4 unicast
network 25.0.0.0/24
network 25.0.1.0/24
network 25.100.0.0/24
network 25.100.1.0/24
ip prefix-list pl1234 seq 10 permit 25.0.0.0/24
ip prefix-list pl1234 seq 20 permit 25.0.1.0/24
ip prefix-list pl5678 seq 10 permit 25.100.1.0/24
ip prefix-list pl5678 seq 20 permit 25.100.0.0/24
ip prefix-list plUntagged seq 30 permit 10.100.3.0/24
route-map rmCommunities-out permit 10
match ip address prefix-list pl1234
set community 300:1234
route-map rmCommunities-out permit 20
match ip address prefix-list pl5678
set community 300:5678
route-map rmCommunities-out permit 30
match ip address prefix-list plUntagged
router bgp 300
address-family ipv4 unicast
neighbor 10.100.2.20 route-map rmCommunities-out out
no neighbor 10.100.2.20 default-originate route-map rmCommunities-out
exit
exit
exit

# 2. Filter Routes based on Community


########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure
bgp community-list standard list-Allow5678 permit 300:5678

route-map rmAllow5678 permit 10
match community list-Allow5678
set community 300:5678

router bgp 100
address-family ipv4 unicast
neighbor 10.100.2.20 route-map rmAllow5678 in
exit
exit
exit




########################################################
# VM 1 Private IP: 10.100.1.10
# FRR CONFIG

configure terminal

bgp community-list standard list-Deny1234 deny 300:1234
bgp community-list standard list-Deny1234 permit 0:0 65535:65535

route-map rmDeny1234 permit 10
match community list-Deny1234


router bgp 100
address-family ipv4 unicast
neighbor 10.100.2.20 route-map rmDeny1234 in
exit
exit
exit
