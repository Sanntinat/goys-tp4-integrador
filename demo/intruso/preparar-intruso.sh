#!/usr/bin/env bash
# Prepara el INTRUSO del TP4 (H4) dentro de la estacion.
# Uso, dentro de la VM (con Internet, despues de preparar-estacion.sh):  sudo bash preparar-intruso.sh
# Se puede correr mas de una vez: cada paso revisa si ya esta hecho.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
IMAGEN="goys/intruso:1"

if [[ $EUID -ne 0 ]]; then
  echo "Correlo con sudo: sudo bash $0" >&2
  exit 1
fi

if ! ip link show enp0s9 >/dev/null 2>&1; then
  echo "Falta la placa enp0s9: agregala con demo\\estacion\\agregar-placa-intruso.ps1 (VM apagada)." >&2
  exit 1
fi

echo "== 1/3 Placa del intruso (enp0s9) levantada y sin IP"
install -m 600 "$AQUI/61-intruso.yaml" /etc/netplan/61-intruso.yaml
netplan apply

echo "== 2/3 Imagen $IMAGEN (Alpine 3.20 + nmap 7.95), construida de antemano"
docker build -q -t "$IMAGEN" "$AQUI"

echo "== 3/3 Red Docker 'intruso': macvlan sobre enp0s9, 203.0.113.8/30, gateway ISP-1 (.9)"
if docker network inspect intruso >/dev/null 2>&1; then
  echo "   la red ya existe"
else
  docker network create -d macvlan --subnet 203.0.113.8/30 --gateway 203.0.113.9 \
    -o parent=enp0s9 intruso
fi

echo
echo "Listo. Probar con: bash ~/intruso.sh ping"
ip -br link show enp0s9
