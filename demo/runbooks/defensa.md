# Runbook — Defensa activa en el EDGE (H5)

- **Hito:** H5 Defensa (Santiago y Tomás)
- **Reglas:** Santiago ([`H5-defensa.rsc`](../routers/H5-defensa.rsc))
- **Pruebas desde el INTRUSO y medición:** Tomás Martin, 14/11/2026, en su laboratorio
- **Corrida completa de la demo:** Santiago, 15/11/2026, en su laptop (la de la feria), con H3 y H4 montados
- **Resultado:** un escaneo de puertos desde el INTRUSO queda bloqueado en **menos de 0,2 s** en el laboratorio de Tomás y **entre 0,24 y 2,72 s** en la laptop de la feria; el bloqueo dura 2 minutos; BGP, OSPF, la gestión, el monitoreo y los hosts no se ven afectados, y el tablero dispara `IntrusoBloqueado`

---

## Las reglas

Están en [`H5-defensa.rsc`](../routers/H5-defensa.rsc) y se aplican solo en el EDGE, con `admin` (antes, `/export file=pre-H5`). El script se puede pegar más de una vez: primero borra lo que dejó una corrida anterior, y no agrega la detección si no encuentra la regla «input: todo lo demas» del TP3.

| Pieza | Qué hace |
|---|---|
| Lista `confianza` | ISP-1 (`203.0.113.1`), ISP-2 (`203.0.113.5`) y la estación (`10.20.0.101`) quedan fuera de la detección. Hasta el 15/11 entraba toda la LAN SERVERS (`10.20.0.0/24`); se achicó a la estación para que un equipo infectado de esa red sí pueda terminar bloqueado ([D-19](../../decisiones.md#d-19)) |
| `filter input`, «defensa: detecta escaneo» | `psd=21,3s,3,1`: suma 3 por cada puerto bajo (<1024) y 1 por cada puerto alto; si un mismo origen llega a 21 sin dejar pasar más de 3 s entre intentos, entra en `bloqueados` por 2 minutos. Va **antes** de «input: todo lo demas». Deja una línea en el log con el prefijo `H5-bloqueo` (`/log print where message~"H5-bloqueo"`) |
| `raw prerouting`, «defensa: descarta al origen bloqueado» | Descarta todo lo que llega de `bloqueados` antes del seguimiento de conexiones, incluido el ping |

Cómo se interpreta `psd` está en [decisiones.md, D-18](../../decisiones.md#d-18): los 3 s son la pausa máxima entre intentos, no una ventana.

---

## Cómo se mide

[`medir-neutralizacion.sh`](../intruso/medir-neutralizacion.sh), dentro de la estación (copiarlo junto a `intruso.sh`):

```bash
bash ~/medir-neutralizacion.sh                       # el escaneo de la demo: -Pn -sS -T4 --top-ports 100 203.0.113.2
bash ~/medir-neutralizacion.sh <argumentos de nmap>  # otro escaneo
```

Dentro del INTRUSO corre un ping de fondo al EDGE (uno cada ~0,1 s) y lanza nmap:

- **Tiempo de neutralización:** desde que arranca nmap hasta el primer ping sin respuesta. La resolución es la del ping de fondo (~0,1 s).
- **Duración del bloqueo:** desde el primer ping sin respuesta hasta que vuelve a responder.

Los tiempos salen de `/proc/uptime` (centésimas de segundo), porque el `date` de busybox no da fracciones. Antes de empezar, el script verifica que el INTRUSO no esté bloqueado por una prueba anterior.

---

## Pruebas (`capturas/H5/`)

En el laboratorio de Tomás: EDGE con la configuración del TP3 más las mismas reglas de detección, bloqueo y confianza (sin H3 y sin el log, que no cambia cómo detecta ni cómo bloquea).

| # | Prueba | Cómo | Resultado |
|:-:|---|---|---|
| 1 | **Escaneo de la demo** | `bash ~/medir-neutralizacion.sh` | **Neutralización: 0,08 s, 0,09 s y 0,18 s** (tres corridas). Con los primeros SYN de nmap ya se pasa el umbral. nmap termina igual (11 s, 100 puertos `filtered`), pero el resto de sus paquetes ya cae en `raw` |
| 2 | Vencimiento del bloqueo (2 min) | La misma corrida espera a que el ping vuelva | **121 s, 124 s y 125 s.** Una primera corrida dio 237 s (ver observaciones) |
| 3 | Escaneo lento, un puerto por segundo | `-Pn -sS --scan-delay 1s --top-ports 20 203.0.113.2` | **También se bloquea**, a los 20 s: la pausa entre intentos (1 s) es menor que 3 s y los puntos se acumulan |
| 4 | Escaneo muy lento, un puerto cada 4 s | `-Pn -sS --scan-delay 4s --max-retries 0 --top-ports 15 203.0.113.2` | **No se detecta**: 15 puertos en 64 s, sin bloqueo. Es el límite de la defensa |
| 5 | Falso positivo desde la estación | nmap `-T4` a 100 puertos de `10.255.255.1` desde un container en la red de la estación (sale como `10.20.0.101`) | **No se bloquea** (la estación está en `confianza`; en esta prueba, con toda `10.20.0.0/24`); la estación sigue llegando al EDGE (3/3). Desde gestión se ve abierto el 22 (SSH), que el TP3 permite desde ahí |
| 6 | Efectos colaterales durante el bloqueo | Con el INTRUSO bloqueado: ping de PC-USER a los loopbacks de los ISP y de la estación al EDGE | **Sin efectos**: PC-USER llega a `198.51.100.1` y `198.51.100.2` (3/3 cada uno) y la estación al EDGE (3/3). Los ISP están en `confianza`, así que BGP no se toca |

| Captura | Qué muestra |
|---|---|
| `H5-01` | Las reglas en el EDGE: la de detección justo antes de «input: todo lo demas» y la lista `confianza` (la regla de `raw` se ve en `H5-03`) |
| `H5-02` | Prueba 1 y 2 desde el INTRUSO: tiempo de neutralización y duración del bloqueo |
| `H5-03` | Durante el bloqueo: `203.0.113.10` en `bloqueados` (dinámico, con su tiempo restante) y los paquetes descartados por la regla de `raw` |
| `H5-04` | Durante el bloqueo: PC-USER sigue llegando a los dos ISP |
| `H5-05` | Prueba 4: el escaneo de un puerto cada 4 s no se detecta |
| `H5-06` | Prueba 5: el escaneo desde la estación no la bloquea |

---

## Corrida completa en la laptop de la feria

El 15/11, en la laptop de Santiago (Lenovo, 7,4 GB de RAM, Windows 11 25H2). Antes hubo que montar ahí lo que faltaba: H4 (placa 3 de la estación, nube `INTRUSO`, `H4-intruso.rsc` en ISP-1 y `preparar-intruso.sh`) y H3 (`H3-monitoreo.rsc` en los 5 routers, claves en `mktxp.conf` y `.env`, `docker compose up -d`). Se siguió el orden del guion de la propuesta (§9). En esta corrida `confianza` todavía tenía toda `10.20.0.0/24`; el cambio de D-19 (solo la estación) es posterior y no cambia ninguna de estas pruebas, porque el único equipo de esa red que le habla TCP al EDGE es la estación. Queda verificarlo en el EDGE en el próximo encendido (H7):

| # | Paso de la demo | Resultado |
|:-:|---|---|
| 1 | **Falla:** se suspende en GNS3 el enlace EDGE–CORE-1 | El tablero marca los dos ISP en rojo y dispara `DestinoInalcanzable` (`critical`); OSPF sale por CORE-2 y el ping vuelve en **~10 s**, leído del tablero |
| 2 | **Ataque sin defensa:** `bash ~/intruso.sh escanear` | Ping del INTRUSO al EDGE 4/4; nmap revisa 100 puertos en 11,6 s, todos `filtered`, sin obstáculos |
| 3 | **Despliegue:** `H5-defensa.rsc` pegado en el EDGE | La detección queda justo antes de «input: todo lo demas» (y después de la regla de API-SSL de H3) |
| 4 | **Ataque con defensa:** `bash ~/medir-neutralizacion.sh`, tres corridas | **Neutralización: 2,72 s, 0,66 s y 0,24 s. Bloqueo: 130 s, 130 s y 124 s** |
| 5 | Mientras dura el bloqueo, en el EDGE | Solo `203.0.113.10` en `bloqueados`; la regla de `raw` descarta (243 paquetes en la corrida 1); las dos sesiones BGP siguen `established` sin reiniciarse (42 min de *uptime*) y los dos vecinos OSPF en `Full`; una sola línea `H5-bloqueo` en el log por cada bloqueo |
| 6 | Mientras dura el bloqueo, en el tablero | Se dispara **`IntrusoBloqueado`** (EDGE, `warning`), lo que faltaba probar con H3 |
| 7 | Falso positivo: nmap desde la estación a `10.255.255.1` | **No se bloquea**: 100 puertos en 2,8 s (abierto el 22, permitido desde gestión), la estación sigue llegando al EDGE (3/3), `bloqueados` vacía, los 3 *targets* de Prometheus en UP y sin alertas |

| Captura | Qué muestra |
|---|---|
| `H5-07` / `H5-08` | Paso 1: el tablero con el enlace cortado y después de la recuperación |
| `H5-09` | Paso 3: las reglas en el EDGE con H3 (detección, `raw` y `confianza`) |
| `H5-10` / `H5-11` | Pasos 4 y 5: `bloqueados` durante la corrida 1; `raw`, BGP y OSPF durante el bloqueo |
| `H5-12` | Paso 6: la alerta `IntrusoBloqueado` en el tablero |
| `H5-13` / `H5-15` | Paso 4: corrida 1, y corridas 2 y 3 |
| `H5-14` | Paso 5: el log con una línea `H5-bloqueo` por bloqueo |
| `H5-16` | Paso 7: el nmap desde la estación no la bloquea |

---

## Límites de la defensa

Lo que la defensa **no** cubre, para tener la respuesta lista en la feria (propuesta §10):

- **Un atacante que ya está adentro.** La detección está en `input` del EDGE: solo ve escaneos dirigidos al EDGE. La defensa protege el borde contra escaneos que vienen de Internet; un equipo comprometido dentro de la red no pasa por esta regla. Si un equipo de USERS escanea a los servidores, ese tráfico lo rutean DIST-1 y DIST-2, que tienen las dos LAN y no tienen firewall desde el TP3, y nunca llega al EDGE. Para detectarlo habría que aplicar lo mismo en `forward` de los DIST, coordinado con VRRP, y lo dejamos como trabajo futuro (sugerencia de Lautaro en la revisión de H5).
- **Escaneos lentos.** Un escaneo que deja pasar más de 3 s entre intentos no suma puntos y no se bloquea (prueba 4 y [D-18](../../decisiones.md#d-18)).
- **Escaneos UDP.** La regla solo mira TCP (`protocol=tcp`): un `nmap -sU` no suma puntos. No lo probamos.

---

## Observaciones

- **El bloqueo duró 237 s en la primera corrida de Tomás**, casi el doble de los 120 s configurados; las tres corridas siguientes dieron 121, 124 y 125 s. No encontramos la causa. Una hipótesis es el reloj de los routers emulados, que en el TP3 se atrasó más de 2 horas en una sesión (memoria del TP3, §8). **En la laptop de la feria no se repitió:** 130, 130 y 124 s.
- **En la laptop de la feria la neutralización es más lenta** (2,72 s, 0,66 s y 0,24 s, contra menos de 0,2 s en el laboratorio de Tomás) y baja de una corrida a la otra. La primera se hizo justo después de que la estación se trabara (ver abajo). Sigue siendo un bloqueo en segundos, que es lo que promete la propuesta, pero en el ensayo (H7) conviene medir de nuevo con la laptop descansada.
- **La laptop de la feria está al límite.** Los 7 routers (256 MB cada uno, emulados por software con `accel=tcg`), la estación (2 GB) y Windows llenan los 7,4 GB; con un navegador abierto las consolas de GNS3 dejaron de responder y hubo que cerrar GNS3. Para la corrida: cerrar el navegador y frenar los servicios que no se usan (en esta laptop, PostgreSQL), arrancar primero los routers, esperar a que booteen y recién después la estación.
- **La estación tarda ~9 min en arrancar y a veces se traba.** En esta laptop está activo Hyper-V, así que VirtualBox no puede usar AMD-V y corre en modo NEM (el log de la VM dice «AMD-V is not available… fall back to NEM»), que es mucho más lento. Durante la corrida el kernel de la estación tuvo dos *soft lockups* (un CPU trabado 128 s) y SSH dejó de responder un par de minutos; los containers siguieron andando. Bajar el refresco del tablero de 1 s a 5 s alivió la carga (Grafana usaba 23 % de CPU). Para la feria: prender la estación con 10 minutos de margen y evaluar en H7 si se apaga Hyper-V en la laptop o si la estación pasa a 1 CPU.
- **La alerta `IntrusoBloqueado` aparece dos veces en el tablero**, porque sus dos condiciones (descartes en `raw` y la lista `bloqueados` no vacía) se disparan juntas y el panel muestra una fila por cada una, con una columna `log` de más. No cambia lo que detecta; es un ajuste del panel para H3.
- **La recuperación ante el corte EDGE–CORE-1 tardó ~10 s** en la laptop, contra ~1 s en H3. Suspender el enlace en GNS3 no baja la interfaz del router, así que OSPF probablemente espera a que venza su temporizador. Queda para revisar en H7.
- **nmap no se entera del bloqueo:** igual informa los puertos como `filtered`, porque sin la defensa el firewall del TP3 ya los descartaba. Lo que muestra el bloqueo es el ping del INTRUSO al EDGE, que deja de responder (por eso el script lo usa para medir), y en el EDGE la lista `bloqueados` y los contadores de `raw`.
- **En la demo**, el INTRUSO queda bloqueado 2 minutos. Para repetir el escaneo con otro visitante hay que esperar o sacarlo a mano en el EDGE: `/ip firewall address-list remove [find list=bloqueados]`.
