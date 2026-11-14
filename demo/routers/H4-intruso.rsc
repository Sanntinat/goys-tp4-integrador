# H4 Atacante: la red del INTRUSO (203.0.113.8/30) cuelga de ISP-1, como cualquier red de Internet.
# Se aplica SOLO en ISP-1, entrando con admin. Antes de aplicarlo: /export file=pre-H4
# En GNS3, ISP-1 Ethernet1 = ether2 en RouterOS (las placas se renombraron por MAC en el TP3).

# Antes de seguir, ether2 tiene que tener la marca R (running) con el cable a la nube INTRUSO
/interface print where name=ether2

# ISP-1 es el gateway del INTRUSO
/ip address add address=203.0.113.9/30 interface=ether2 comment="hacia INTRUSO (H4)"

# La red del INTRUSO se anuncia por BGP al EDGE (misma lista que el loopback del TP3)
/ip firewall address-list add address=203.0.113.8/30 list=anuncio-bgp comment="red del INTRUSO, se anuncia por BGP (H4)"
