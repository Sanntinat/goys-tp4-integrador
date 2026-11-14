# Runbook: automatización de la defensa con Ansible (H6)

- **Hito:** H6 Automatización (Lautaro)
- **Playbooks:** [`defensa.yml`](../ansible/defensa.yml) y [`defensa-quitar.yml`](../ansible/defensa-quitar.yml), en [`demo/ansible/`](../ansible/)
- **Qué aplican:** exactamente las reglas de H5 ([`H5-defensa.rsc`](../routers/H5-defensa.rsc)), con los mismos nombres y valores
- **Estado:** validados sin router (sintaxis, `ansible-lint` en perfil *production* y la lectura del EDGE con salidas simuladas). **Falta correrlos contra el EDGE del laboratorio** (sección «Pruebas»)

---

## Cómo funciona

Ansible corre en la estación (D-11) y entra al EDGE por SSH al loopback `10.255.255.1` con `admin`. El TP3 ya permite SSH desde `10.20.0.0/24` (lista `gestion` y `/ip service ssh`), así que no hay que tocar el firewall.

Los dos playbooks usan solo el módulo `community.routeros.command` por SSH. No usan la API: la API-SSL del EDGE la tiene el usuario `prometheus`, de solo lectura, y abrirla para escritura sumaba un acceso más (D-19).

`defensa.yml` primero lee el EDGE y después cambia solo lo que hace falta:

| Pieza | Cómo se reconoce | Cuándo se rehace |
|---|---|---|
| Lista `confianza` | Por dirección (`203.0.113.1`, `203.0.113.5`, `10.20.0.0/24`) | Agrega las que faltan y saca las que sobran |
| Bloqueo en `raw` | Comentario «defensa: descarta al origen bloqueado» | Si no está, está repetida, deshabilitada o con otros valores. Queda primera en `raw` |
| Detección en `input` | Comentario «defensa: detecta escaneo» | Igual que la anterior, y también si quedó después de «input: todo lo demas» |

Si el EDGE no tiene la regla «input: todo lo demas» del TP3, el playbook frena sin tocar nada. Al final vuelve a leer el EDGE, comprueba que todo quedó como se pidió y muestra las sesiones BGP.

Para comparar valores, el playbook busca en `print terse` cada parámetro esperado (`psd=21,3s,3,1`, `address-list-timeout=2m`, etc.). Si la regla está bien pero algún parámetro se imprime con otro formato, la segunda corrida rehace la regla en vez de dar `changed=0`; el mensaje «Mostrar que se va a cambiar» dice cuál. Es lo primero a mirar en la prueba 2.

`defensa-quitar.yml` borra todo lo que tenga comentario `defensa:` en `filter` y `raw`, la lista `confianza` y también la lista `bloqueados`, para que el INTRUSO pueda volver a escanear sin esperar los 2 minutos. Es el reinicio de la demo entre visitantes.

Los valores están en [`group_vars/edge/defensa.yml`](../ansible/group_vars/edge/defensa.yml). Si en el ensayo hay que ajustar el umbral, se cambia ahí y se vuelve a correr `defensa.yml`: rehace solo la regla de detección.

---

## Preparar la estación (una vez, con Internet)

**1. Copiar el repo a la VM** (si todavía no está) y entrar a la carpeta:

```bash
git clone https://github.com/Sanntinat/goys-tp4-integrador.git ~/goys-tp4-integrador
cd ~/goys-tp4-integrador/demo/ansible
```

**2. Instalar Ansible** ([`preparar-ansible.sh`](../ansible/preparar-ansible.sh)): paquete `ansible` de Ubuntu 24.04, que ya trae `community.routeros` y `ansible.netcommon`.

```bash
sudo bash preparar-ansible.sh
```

**3. Aceptar la llave SSH del EDGE.** Con GNS3 y los routers prendidos, entrar una vez a mano y comparar la huella con la del router (`/ip ssh print` en la consola del EDGE). Ansible deja `host_key_checking` activo, así que sin este paso no conecta.

```bash
ssh admin@10.255.255.1 "/system identity print"
```

**4. Crear el vault con la clave de `admin`.** La clave está en la base `.kdbx`; la contraseña del vault va a la misma base como «ansible-vault (H6)». `vault.yml` está en `.gitignore`.

```bash
cp group_vars/edge/vault.yml.ejemplo group_vars/edge/vault.yml
nano group_vars/edge/vault.yml          # reemplazar <CLAVE_ADMIN>
ansible-vault encrypt group_vars/edge/vault.yml
```

**5. Probar la conexión** sin cambiar nada:

```bash
ansible-playbook defensa.yml --ask-vault-pass --check
```

Tiene que mostrar qué agregaría y terminar sin errores.

---

## En la demo

Desde `~/goys-tp4-integrador/demo/ansible`:

```bash
ansible-playbook defensa.yml --ask-vault-pass          # paso 3 de la demo: despliega la defensa
ansible-playbook defensa-quitar.yml --ask-vault-pass   # entre visitantes: el EDGE vuelve al TP3
```

El recap de la primera corrida muestra `changed` mayor a 0; si se corre otra vez, `changed=0`. Eso es lo que se le muestra al visitante para explicar la idempotencia.

---

## Pruebas (`capturas/H6/`)

Pendientes, en el laboratorio con H3 y H4 aplicados. Antes, en el EDGE: `/export file=pre-H6`.

| # | Prueba | Cómo | Resultado esperado |
|:-:|---|---|---|
| 1 | Primera aplicación | EDGE sin defensa → `defensa.yml` | `changed` > 0, la verificación da «Defensa aplicada y verificada», BGP con las dos sesiones |
| 2 | Idempotencia | `defensa.yml` otra vez | `changed=0` |
| 3 | Equivale a H5 | `/ip firewall filter print terse where chain=input`, `/ip firewall raw print terse` y `/ip firewall address-list print where list=confianza` en el EDGE | Lo mismo que deja `H5-defensa.rsc`: detección antes de «input: todo lo demas», `raw` y las tres direcciones |
| 4 | La defensa funciona | `bash ~/medir-neutralizacion.sh` desde la estación (runbook H5) | Neutralización < 0,2 s, como en H5 |
| 5 | Corrige una regla tocada a mano | En el EDGE, `/ip firewall filter set [find comment="defensa: detecta escaneo"] psd=30,3s,3,1` → `defensa.yml` | Rehace solo la detección (`changed=1`) y la verificación da ok |
| 6 | Vuelta atrás | `defensa-quitar.yml` con el INTRUSO bloqueado | Borra todo, el ping del INTRUSO al EDGE vuelve enseguida; segunda corrida con `changed=0` |
| 7 | Sin regla del TP3 | `ansible-playbook defensa.yml --ask-vault-pass -e 'defensa_comentario_final=no-existe'` (simula que falta, sin tocar el EDGE) | Frena en «Frenar si no esta la regla final» y no cambia nada |

---

## Problemas conocidos

- **`changed` en todas las corridas:** un parámetro se imprime distinto de como lo espera el playbook (ver «Cómo funciona»). Ajustar la lista `tokens_deteccion` de [`tareas/estado.yml`](../ansible/tareas/estado.yml) al formato que muestra `print terse`.
- **`Authentication failed` o se cuelga al conectar:** probar `ssh admin@10.255.255.1` a mano. Si eso anda, revisar la clave del vault.
- **`command timeout triggered`:** con los 7 CHR prendidos el EDGE puede tardar; los tiempos están en [`ansible.cfg`](../ansible/ansible.cfg) (`command_timeout = 30`).
