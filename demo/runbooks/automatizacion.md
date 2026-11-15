# Runbook: automatización de la defensa con Ansible (H6)

- **Hito:** H6 Automatización (Lautaro)
- **Playbooks:** [`defensa.yml`](../ansible/defensa.yml) y [`defensa-quitar.yml`](../ansible/defensa-quitar.yml), en [`demo/ansible/`](../ansible/)
- **Qué aplican:** exactamente las reglas de H5 ([`H5-defensa.rsc`](../routers/H5-defensa.rsc)), con los mismos nombres y valores
- **Estado:** probados contra un CHR 7.21.5 aislado (sección «Prueba en un CHR aislado», evidencia en `capturas/H6/`). **Falta una corrida en el laboratorio de GNS3** con BGP y el INTRUSO (sección «Pruebas en el laboratorio»)

---

## Cómo funciona

Ansible corre en la estación (D-11) y entra al EDGE por SSH al loopback `10.255.255.1` con `admin`. El TP3 ya permite SSH desde `10.20.0.0/24` (lista `gestion` y `/ip service ssh`), así que no hay que tocar el firewall.

Los dos playbooks usan solo el módulo `community.routeros.command` por SSH. No usan la API: la API-SSL del EDGE la tiene el usuario `prometheus`, de solo lectura, y abrirla para escritura sumaba un acceso más (D-20).

`defensa.yml` primero lee el EDGE y después cambia solo lo que hace falta:

| Pieza | Cómo se reconoce | Cuándo se rehace |
|---|---|---|
| Lista `confianza` | Por dirección (`203.0.113.1`, `203.0.113.5`, `10.20.0.101`) | Agrega las que faltan y saca las que sobran |
| Bloqueo en `raw` | Comentario «defensa: descarta al origen bloqueado» | Si no está, está repetida, deshabilitada o con otros valores. Queda primera en `raw` |
| Detección en `input` | Comentario «defensa: detecta escaneo» | Igual que la anterior, y también si quedó después de «input: todo lo demas» |

Si el EDGE no tiene la regla «input: todo lo demas» del TP3, el playbook frena sin tocar nada. Al final vuelve a leer el EDGE, comprueba que todo quedó como se pidió y muestra las sesiones BGP.

Para comparar valores, el playbook busca en `print terse` cada parámetro esperado (`psd=21,3s,3,1`, `address-list-timeout=2m`, etc.). En RouterOS 7.21.5 el formato coincide (prueba aislada 2). Si una versión futura imprimiera alguno distinto, la segunda corrida rehace la regla en vez de dar `changed=0`, y el mensaje «Mostrar que se va a cambiar» dice cuál.

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

## Prueba en un CHR aislado (`capturas/H6/`)

Lautaro, 14/11/2026. Sin acceso al laboratorio de GNS3, los playbooks se probaron contra un solo router: un **CHR 7.21.5 ARM64** (la misma versión del laboratorio) en QEMU, en una Mac, con el firewall del EDGE del TP3 y la regla de API-SSL de H3. Ansible 2.16 corrió en la Mac, no en la estación.

Diferencias con el laboratorio, solo para esta prueba:

- QEMU emula la CPU (`-accel tcg -cpu cortex-a72`). En Apple Silicon, con virtualización (`hvf`), RouterOS no arranca: *Kernel panic, No working init found*.
- Ansible entra por un puerto redirigido (`-e ansible_host=127.0.0.1 -e ansible_port=2222`) y desde la red de QEMU (`10.0.2.0/24`), que se sumó a `gestion` para que el TP3 deje pasar el SSH.
- `ANSIBLE_HOST_KEY_CHECKING=False` y el vault con `--vault-password-file`, porque el router se crea y se descarta en la prueba.
- No hay ISP, BGP ni INTRUSO: las sesiones BGP salen vacías y no se puede medir la neutralización.
- La prueba se hizo antes de D-19, con `10.20.0.0/24` en `confianza`; por eso esa dirección aparece en las salidas. El cambio a `10.20.0.101` es solo un valor de `group_vars`: si el EDGE todavía tiene la red entera, `defensa.yml` la saca y agrega la estación, como en la prueba 4.

| # | Prueba | Resultado | Captura |
|:-:|---|---|---|
| 1 | Primera aplicación, EDGE solo con el TP3 | Agrega las 3 direcciones de `confianza`, la regla de `raw` y la de detección (`changed=3`, una por tarea). La verificación da «Defensa aplicada y verificada» | `H6-01` |
| 2 | Idempotencia | `changed=0`; «deteccion: ok», «bloqueo: ok» | `H6-02` |
| 3 | Equivale a H5 | La detección queda justo antes de «input: todo lo demas» (y después de la regla de API-SSL de H3), `raw` con la regla de bloqueo y las tres direcciones en `confianza` | `H6-03` |
| 4 | Corrige cambios a mano | Con `psd=30,3s,3,1`, sin ISP-2 en `confianza` y con una dirección de más: rehace solo la detección, agrega ISP-2 y saca la sobrante (`changed=3`); verificación ok | `H6-04` |
| 5 | Regla fuera de lugar y `--check` | Con la detección movida después de «input: todo lo demas», `--check` informa «rehacer (fuera de lugar)» y no cambia nada (`changed=0`); la corrida normal la vuelve a poner en su lugar (`changed=1`) | `H6-05` |
| 6 | Vuelta atrás | Con `203.0.113.10` en `bloqueados` (simulado): borra detección, bloqueo, `confianza` y `bloqueados` (`changed=4`); la segunda corrida da `changed=0`; en el EDGE queda solo el firewall del TP3 | `H6-06` |
| 7 | Sin la regla final del TP3 | `-e defensa_comentario_final=no-existe`: frena en «Frenar si no esta la regla final» sin cambiar nada | `H6-07` |

Las salidas completas, en texto, están en `capturas/H6/salidas/`. Las imágenes son esas mismas salidas pasadas a PNG.

**Error encontrado y corregido en esta prueba:** la primera corrida aplicaba bien las reglas, pero la verificación no las encontraba. En RouterOS 7, `disabled` es una marca, y `print where ... disabled=no` no devuelve nada; la forma correcta es `!disabled` (y `!dynamic` para la lista). Ya está corregido en [`tareas/estado.yml`](../ansible/tareas/estado.yml) y en `defensa.yml`.

---

## Pruebas en el laboratorio

Falta una sola corrida en el laboratorio con H3 y H4, para lo que la prueba aislada no cubre. Antes, en el EDGE: `/export file=pre-H6`.

| # | Prueba | Cómo | Resultado esperado |
|:-:|---|---|---|
| 1 | Conexión desde la estación | Pasos 1 a 5 de «Preparar la estación» | `--check` sin errores |
| 2 | Aplicación con la red completa | `defensa.yml` | Verificación ok y las dos sesiones BGP en la salida |
| 3 | La defensa funciona | `bash ~/medir-neutralizacion.sh` (runbook H5) | Neutralización < 0,2 s, como en H5 |
| 4 | Reinicio entre visitantes | `defensa-quitar.yml` con el INTRUSO bloqueado | El ping del INTRUSO al EDGE vuelve enseguida |

---

## Problemas conocidos

- **`changed` en todas las corridas:** un parámetro se imprime distinto de como lo espera el playbook (no pasa en 7.21.5; ver «Cómo funciona»). Ajustar la lista `tokens_deteccion` de [`tareas/estado.yml`](../ansible/tareas/estado.yml) al formato que muestra `print terse`.
- **`Authentication failed` o se cuelga al conectar:** probar `ssh admin@10.255.255.1` a mano. Si eso anda, revisar la clave del vault.
- **`command timeout triggered`:** con los 7 CHR prendidos el EDGE puede tardar; los tiempos están en [`ansible.cfg`](../ansible/ansible.cfg) (`command_timeout = 30`).
