netsh interface ipv4 set dns "Ethernet 1" static 94.140.14.14
netsh interface ipv4 add dns "Ethernet 1" 94.140.15.15 index=2
netsh interface ipv6 set dns "Ethernet 1" static 2a10:50c0::ad1:ff
netsh interface ipv6 add dns "Ethernet 1" 2a10:50c0::ad2:ff index=2
