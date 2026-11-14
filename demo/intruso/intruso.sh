#!/usr/bin/env bash
# Corre el INTRUSO (203.0.113.10, del lado de ISP-1) contra el EDGE.
# Uso, dentro de la estacion:
#   bash intruso.sh ping                 ping al EDGE (203.0.113.2)
#   bash intruso.sh traza                traceroute ICMP al EDGE: tiene que pasar por ISP-1 (203.0.113.9)
#   bash intruso.sh escanear             nmap SYN a los 100 puertos mas comunes del EDGE
#   bash intruso.sh escanear <args nmap> nmap con otros argumentos (por ejemplo: -p 1-1024 203.0.113.2)
#   bash intruso.sh shell                consola dentro del INTRUSO
set -euo pipefail

IMAGEN="goys/intruso:1"
EDGE="203.0.113.2"
CORRER=(docker run --rm --network intruso --ip 203.0.113.10 --hostname intruso)

caso="${1:-}"
[[ $# -gt 0 ]] && shift

case "$caso" in
  ping)     exec "${CORRER[@]}" "$IMAGEN" ping -c 4 "$EDGE" ;;
  traza)    exec "${CORRER[@]}" "$IMAGEN" traceroute -I -n -w 2 "$EDGE" ;;
  escanear)
    if [[ $# -eq 0 ]]; then set -- -Pn -sS -T4 --top-ports 100 "$EDGE"; fi
    exec "${CORRER[@]}" "$IMAGEN" nmap "$@" ;;
  shell)    exec "${CORRER[@]}" -it "$IMAGEN" sh ;;
  *)        sed -n '2,8p' "$0"; exit 1 ;;
esac
