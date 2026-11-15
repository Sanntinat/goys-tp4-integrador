#!/usr/bin/env bash
# H6: instala Ansible en la estacion (VM Ubuntu 24.04). Necesita Internet por la placa NAT: correrlo antes de la feria.
# Uso, dentro de la VM:  sudo bash preparar-ansible.sh
# Se puede correr mas de una vez.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Correlo con sudo: sudo bash $0" >&2
  exit 1
fi

echo "== 1/2 Ansible y paramiko desde los paquetes de Ubuntu"
# El paquete "ansible" de Ubuntu 24.04 trae ansible-core 2.16 y las colecciones
# community.routeros y ansible.netcommon, asi que no hace falta ansible-galaxy (ni Internet en la demo).
if ! command -v ansible-playbook >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq ansible python3-paramiko
else
  echo "   ansible ya instalado"
fi

echo "== 2/2 Colecciones que usan los playbooks"
for c in community.routeros ansible.netcommon; do
  if ! ansible-galaxy collection list "$c" 2>/dev/null | grep -q "^$c "; then
    echo "   falta $c" >&2
    exit 1
  fi
done
ansible --version | head -1
ansible-galaxy collection list community.routeros 2>/dev/null | grep '^community.routeros'
echo
echo "Listo. Seguir con el runbook: demo/runbooks/automatizacion.md"
