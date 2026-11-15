# Bitácora del grupo — TP4

> Registrar acá el avance: qué hizo cada integrante, decisiones tomadas y pendientes.
> Esto ayuda a coordinar el trabajo y deja evidencia de la participación de todos.

---

## 👥 Integrantes

| Nombre | Usuario de GitHub | Rol en el grupo |
|--------|-------------------|-----------------|
| Santiago Natalichio Bestosini | `Sanntinat` | H1 Laboratorio, H2 Conectividad, H5 Defensa (con Tomás) |
| Juan Bautista Cuenca | `baucuenca` | H3 Tablero |
| Tomás Martin | `TomasMartin2004` | H4 Atacante, H5 Defensa (con Santiago) |
| Lautaro Aubert | `LauAubert` | H6 Automatización |

## 🎯 Proyecto

- **Modalidad:** A — Desarrollo
- **Tema:** Sistema Inmune: la red del TP3 que se cura y se defiende sola (monitoreo con Prometheus/Grafana, bloqueo de escaneos en el EDGE y despliegue con Ansible). Ver [`propuesta.md`](propuesta.md).
- **Problema/objetivo:** la red del TP3 se recupera sola, pero nadie se entera de una falla mientras pasa y el firewall no reacciona ante un atacante. Queremos que avise y se defienda, y medir cuánto tarda en recuperarse y en neutralizar un ataque.

## 🗓️ Registro de avance

| Fecha | Qué se hizo | Quién | Commit |
|-------|-------------|-------|--------|
| 07/11/2026 | Propuesta del proyecto (`propuesta.md` y figura de la topología) | Santiago | `75771e9` |
| 12/11/2026 | **H1 Laboratorio:** copia `TP4-SistemaInmune` del proyecto GNS3; el del TP3 queda intacto (mismo SHA-256) | Santiago | ver `git log` |
| 12/11/2026 | **H2 Conectividad:** estación como VM Ubuntu + Docker conectada a SW-SERVERS por túnel UDP; un container le hace ping al EDGE (5/5). Runbook en [`demo/runbooks/preparar-estacion.md`](demo/runbooks/preparar-estacion.md) | Santiago | ver `git log` |
| 14/11/2026 | **H3 Tablero:** usuario de solo lectura y API-SSL en los 5 routers; stack Prometheus + mktxp + blackbox + Grafana en la estación; tablero «Sistema Inmune» y 4 alertas, probadas con cortes en GNS3 (enlace, ISP-1, ISP-2). Tiempo de recuperación ante corte del enlace EDGE–CORE-1: ~1 s | Juan Bautista | ver `git log` |
| 14/11/2026 | **H4 Atacante:** INTRUSO como container (Alpine + nmap) de la estación, unido a ISP-1 por un segundo túnel UDP (nube `INTRUSO`); ISP-1 anuncia `203.0.113.8/30` por BGP. Ping y *traceroute* al EDGE por ISP-1; nmap a 100 puertos en 11 s, todos `filtered`; sin llegada a las LAN. Runbook en [`demo/runbooks/intruso.md`](demo/runbooks/intruso.md) | Tomás | ver `git log` |
| 14/11/2026 | **H5 Defensa (pruebas, parte de Tomás):** con las reglas de detección (`psd`) y bloqueo (`raw`) en el EDGE de su laboratorio, pruebas desde el INTRUSO y script de medición. Neutralización < 0,2 s (tres corridas); bloqueo de ~2 min; el escaneo de un puerto cada 4 s no se detecta (D-18); la estación y BGP no se ven afectados. Falta la corrida completa en la laptop de Santiago. Runbook en [`demo/runbooks/defensa.md`](demo/runbooks/defensa.md) | Tomás | ver `git log` |
| 14/11/2026 | **H6 Automatización (código):** `defensa.yml` (lee el EDGE y aplica solo lo que falta de la defensa de H5) y `defensa-quitar.yml` (borra la defensa y vacía `bloqueados`), por SSH con `admin` y la clave en Ansible Vault (D-20). Probados contra un CHR 7.21.5 aislado en QEMU: aplicación, segunda corrida con `changed=0`, corrección de cambios a mano, `--check`, vuelta atrás y freno sin la regla del TP3; la prueba encontró y corrigió un filtro que no anda en RouterOS 7 (`disabled=no`). Falta una corrida en el laboratorio de GNS3 con BGP y el INTRUSO. Runbook en [`demo/runbooks/automatizacion.md`](demo/runbooks/automatizacion.md) | Lautaro | ver `git log` |
| 15/11/2026 | **H5 Defensa (corrida completa en la laptop de la feria):** montados H3 y H4 en la laptop y seguido el guion de la demo (falla, ataque sin defensa, defensa, ataque con defensa). Neutralización 2,72 s, 0,66 s y 0,24 s; bloqueo de 130, 130 y 124 s (no se repitió el de 237 s); BGP, OSPF y el monitoreo siguen arriba durante el bloqueo, el tablero dispara `IntrusoBloqueado` y un nmap desde la estación no la bloquea. La laptop queda al límite de RAM y la estación corre en modo NEM (Hyper-V activo): para revisar en H7 | Santiago | ver `git log` |

## 🚧 Pendientes / decisiones

- [x] Definir tema definitivo
- [x] Elegir modalidad (A, B o C)
- [x] Asignar roles (por hito, tabla 5 de la propuesta)
- [x] H3 Tablero
- [x] H4 Atacante
- [x] H5 Defensa
- [ ] H6 Automatización · H7 Ensayo

**Decisión (12/11, H2):** la estación no es la laptop con un nodo *Cloud* sobre una placa de loopback, como decía la propuesta. En Windows 11 25H2, Windows descarta lo que Npcap le inyecta a esa placa. Queda como **VM Ubuntu en VirtualBox** unida a GNS3 por un **túnel UDP** (nube `ESTACION`). Consecuencias:

- **H3:** Prometheus y Grafana corren en Docker dentro de la VM. Grafana se ve desde Windows en `http://127.0.0.1:3000`.
- **H6:** Ansible corre en la VM, sin WSL.

Detalle y evidencia en el runbook.

## 📝 Notas

- La laptop de la demo tiene 7,4 GB de RAM (no 16 GB como dice la tabla de riesgos): 7 CHR ≈ 1,8 GB + VM 2 GB. Vigilar memoria en H3.
- Para trabajar: abrir `TP4-SistemaInmune` en GNS3, iniciar los nodos y después `demo/estacion/iniciar-estacion.ps1`.
