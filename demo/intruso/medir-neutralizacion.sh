#!/usr/bin/env bash
# Mide el tiempo de neutralizacion (H5): cuanto tarda el EDGE en bloquear al INTRUSO desde que empieza a escanear.
# Uso, dentro de la estacion:  bash medir-neutralizacion.sh [args de nmap]
#   Sin argumentos usa el mismo escaneo de la demo: -Pn -sS -T4 --top-ports 100 203.0.113.2
#
# Dentro del INTRUSO corre un ping de fondo al EDGE (uno cada ~0,1 s) y lanza nmap. El tiempo de neutralizacion
# es lo que pasa desde que arranca nmap hasta el primer ping sin respuesta (el origen ya esta en «bloqueados» y la
# tabla raw lo descarta). Despues espera a que el ping vuelva, para medir cuanto dura el bloqueo.
# Los tiempos salen de /proc/uptime (centesimas de segundo): el date de busybox no da fracciones.
set -euo pipefail

EDGE="203.0.113.2"
if [[ $# -eq 0 ]]; then set -- -Pn -sS -T4 --top-ports 100 "$EDGE"; fi

docker run --rm -i --network intruso --ip 203.0.113.10 --hostname intruso goys/intruso:1 sh -s -- "$EDGE" "$@" <<'DENTRO'
EDGE="$1"; shift
ahora() { cut -d' ' -f1 /proc/uptime; }
log=/tmp/ping.log

if ! ping -c 2 -W 1 "$EDGE" >/dev/null 2>&1; then
  echo "El EDGE no responde al ping antes de empezar: ¿el INTRUSO sigue bloqueado de una prueba anterior?"
  exit 1
fi

( while :; do t=$(ahora); if ping -c 1 -W 1 "$EDGE" >/dev/null 2>&1; then echo "$t ok"; else echo "$t X"; fi; sleep 0.1; done ) > "$log" &
pinger=$!
sleep 1

t0=$(ahora)
echo "nmap $*"
nmap "$@" | sed -n '/scan report/,$p'
t1=$(ahora)
sleep 2

primera_x=$(awk -v t0="$t0" '$1 >= t0 && $2 == "X" { print $1; exit }' "$log")
if [ -z "$primera_x" ]; then
  kill "$pinger"
  awk -v a="$t0" -v b="$t1" 'BEGIN { printf "\nNO hubo bloqueo: el ping siguio respondiendo durante todo el escaneo (%.1f s).\n", b - a }'
  exit 0
fi
awk -v a="$t0" -v b="$primera_x" -v c="$t1" 'BEGIN { printf "\nTiempo de neutralizacion: %.2f s (desde el inicio de nmap hasta el primer ping sin respuesta)\nEl escaneo duro %.1f s\n", b - a, c - a }'

echo "Esperando a que venza el bloqueo..."
while ! awk -v x="$primera_x" '$1 > x && $2 == "ok" { f = 1 } END { exit !f }' "$log"; do sleep 1; done
kill "$pinger"
vuelta=$(awk -v x="$primera_x" '$1 > x && $2 == "ok" { print $1; exit }' "$log")
awk -v a="$primera_x" -v b="$vuelta" 'BEGIN { printf "Duracion del bloqueo: %.0f s (el ping volvio a responder)\n", b - a }'
DENTRO
