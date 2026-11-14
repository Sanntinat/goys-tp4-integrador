# Runbook — Defensa activa en el EDGE (H5)

- **Hito:** H5 Defensa (Santiago y Tomás)
- **Reglas:** Santiago ([`H5-defensa.rsc`](../routers/H5-defensa.rsc))
- **Pruebas desde el INTRUSO y medición:** Tomás Martin, 14/11/2026, en su laboratorio
- **Pendiente:** la corrida completa de la demo, juntos, en la laptop de Santiago (EDGE con H3)
- **Resultado:** un escaneo de puertos desde el INTRUSO queda bloqueado en **menos de 0,2 s**; el bloqueo dura 2 minutos; BGP, la gestión y los hosts no se ven afectados

---

## Las reglas

Están en [`H5-defensa.rsc`](../routers/H5-defensa.rsc) y se aplican solo en el EDGE, con `admin` (antes, `/export file=pre-H5`). El script se puede pegar más de una vez: primero borra lo que dejó una corrida anterior, y no agrega la detección si no encuentra la regla «input: todo lo demas» del TP3.

| Pieza | Qué hace |
|---|---|
| Lista `confianza` | ISP-1 (`203.0.113.1`), ISP-2 (`203.0.113.5`) y la red de gestión (`10.20.0.0/24`) quedan fuera de la detección |
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
| 5 | Falso positivo desde la estación | nmap `-T4` a 100 puertos de `10.255.255.1` desde un container en la red de la estación (sale como `10.20.0.101`) | **No se bloquea** (`10.20.0.0/24` está en `confianza`); la estación sigue llegando al EDGE (3/3). Desde gestión se ve abierto el 22 (SSH), que el TP3 permite desde ahí |
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

## Observaciones

- **El bloqueo duró 237 s en la primera corrida**, casi el doble de los 120 s configurados; las tres corridas siguientes dieron 121, 124 y 125 s. No encontramos la causa. Una hipótesis es el reloj de los routers emulados, que en el TP3 se atrasó más de 2 horas en una sesión (memoria del TP3, §8), pero no explica por qué las otras tres corridas dieron bien. Conviene repetir la prueba en la laptop de Santiago antes de la feria.
- **nmap no se entera del bloqueo:** igual informa los puertos como `filtered`, porque sin la defensa el firewall del TP3 ya los descartaba. Lo que muestra el bloqueo es el ping del INTRUSO al EDGE, que deja de responder (por eso el script lo usa para medir), y en el EDGE la lista `bloqueados` y los contadores de `raw`.
- **En la demo**, el INTRUSO queda bloqueado 2 minutos. Para repetir el escaneo con otro visitante hay que esperar o sacarlo a mano en el EDGE: `/ip firewall address-list remove [find list=bloqueados]`.
