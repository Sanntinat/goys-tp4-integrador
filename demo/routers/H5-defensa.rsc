# H5 Defensa: deteccion de escaneos (psd) y bloqueo de 2 minutos en la tabla raw.
# Se aplica SOLO en el EDGE, entrando con admin, despues de H3. Antes de aplicarlo: /export file=pre-H5
# Se puede pegar mas de una vez (por ejemplo, al ajustar el umbral): primero borra lo que dejo la corrida anterior.
# Los nombres "bloqueados" y "defensa: descarta" los usan mktxp y la alerta IntrusoBloqueado (H3): no cambiarlos.

# 0. Limpieza de una corrida anterior (si no hay nada, no hace nada)
/ip firewall raw remove [find comment~"^defensa:"]
/ip firewall filter remove [find comment~"^defensa:"]
/ip firewall address-list remove [find list=confianza]

# 1. Lista de confianza: nunca entran en "bloqueados", aunque superen el umbral.
#    Proveedores (un falso positivo cortaria BGP) y red de gestion (la estacion: monitoreo y nmap de prueba).
/ip firewall address-list
add list=confianza address=203.0.113.1 comment="ISP-1 (vecino BGP)"
add list=confianza address=203.0.113.5 comment="ISP-2 (vecino BGP)"
add list=confianza address=10.20.0.0/24 comment="red de gestion (estacion)"

# 2. Deteccion en input, ANTES de "input: todo lo demas" (si fuera despues, el escaneo ya estaria descartado).
#    Solo ve paquetes TCP nuevos: lo establecido se acepta en la primera regla del TP3.
#    psd=21,3s,3,1: peso 21 en rafagas con menos de 3 s entre paquetes; puerto bajo (<1024) pesa 3, alto pesa 1.
#    El log deja la hora exacta del bloqueo (tiempo de neutralizacion): /log print where message~"H5-bloqueo"
:if ([:len [/ip firewall filter find comment="input: todo lo demas"]] = 1) do={
  /ip firewall filter add chain=input protocol=tcp psd=21,3s,3,1 src-address-list=!confianza \
    action=add-src-to-address-list address-list=bloqueados address-list-timeout=2m \
    log=yes log-prefix="H5-bloqueo" comment="defensa: detecta escaneo" \
    place-before=[find comment="input: todo lo demas"]
} else={ :put "FRENAR: no esta la regla \"input: todo lo demas\" del TP3; no se agrego la deteccion" }

# 3. Bloqueo: el origen en "bloqueados" se descarta en raw, antes del seguimiento de conexiones.
/ip firewall raw
add chain=prerouting src-address-list=bloqueados action=drop comment="defensa: descarta al origen bloqueado"

# 4. Verificacion inmediata (la deteccion tiene que quedar justo antes de "input: todo lo demas")
/ip firewall filter print terse where chain=input
/ip firewall raw print terse
/ip firewall address-list print where list=confianza

# Que no se rompa nada (despues de aplicar y despues de cada escaneo):
#   /routing bgp session print terse                 -> hacia-ISP-1 y hacia-ISP-2 established
#   /routing ospf neighbor print terse               -> CORE-1 y CORE-2 en Full
#   /ip firewall address-list print where list=bloqueados   -> solo el INTRUSO (203.0.113.10), nunca un ISP ni 10.20.0.x
#
# Vuelta atras: pegar solo el paso 0 (borra deteccion, bloqueo y confianza; "bloqueados" vence sola en 2 min).
