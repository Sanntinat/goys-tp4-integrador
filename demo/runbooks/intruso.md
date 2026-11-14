# Runbook — El INTRUSO del lado de ISP-1 (H4)

- **Hito:** H4 Atacante
- **Responsable:** Tomás Martin
- **Fecha:** 14/11/2026
- **Resultado:** un container con nmap (`203.0.113.10`), del lado de ISP-1, le hace ping y escanea la IP pública del EDGE (`203.0.113.2`) pasando por ISP-1, y no llega a las LAN de la empresa.

---

## Diseño

El INTRUSO es un **container de la estación** colgado de una **tercera placa** que va por un túnel UDP a una nube `INTRUSO` de GNS3, cableada a ISP-1. Para la red es un equipo más en «Internet». El porqué está en [decisiones.md, D-16](../../decisiones.md#d-16).

```
VirtualBox: ESTACION-TP4                                   GNS3: TP4-SistemaInmune
+--------------------------------------+                   +------------------------------------+
| enp0s3 10.20.0.101  (placa 1) -------+-- UDP 45001<->45000 -- nube ESTACION -- SW-SERVERS e3  |
| enp0s8 NAT          (placa 2) -------+-- Internet / SSH |                                    |
| enp0s9 sin IP       (placa 3) -------+-- UDP 45003<->45002 -- nube INTRUSO --- ISP-1 e1       |
|   └─ macvlan "intruso"               |                   |                     (ether2)       |
|        └─ container goys/intruso:1  |                   +------------------------------------+
|           203.0.113.10/30, gw .9    |
+--------------------------------------+
```

| Elemento | Valor |
|---|---|
| Red del INTRUSO | `203.0.113.8/30` (ISP-1 `.9`, INTRUSO `.10`), anunciada por ISP-1 por BGP |
| Imagen | `goys/intruso:1` = Alpine 3.20 + nmap 7.95, construida en la estación ([`Dockerfile`](../intruso/Dockerfile)) |
| Red Docker | `intruso`, *macvlan* sobre `enp0s9` |
| Router | Solo ISP-1 cambia ([`H4-intruso.rsc`](../routers/H4-intruso.rsc)); el EDGE no se toca en H4 |

---

## Paso a paso (sobre un laboratorio que ya tiene H1 y H2)

**1. Placa 3 de la estación** (PowerShell en Windows, con la VM **apagada**). Si la VM se creó con el `crear-vm.ps1` actual ya la tiene y este paso se saltea:

```powershell
powershell -ExecutionPolicy Bypass -File demo\estacion\agregar-placa-intruso.ps1
```

**2. Nube INTRUSO en GNS3** (proyecto `TP4-SistemaInmune`):

- Agregar un nodo **Cloud** llamado `INTRUSO`, al lado de ISP-1.
- En **Configure → UDP tunnels**: name `intruso`, local port `45002`, remote host `127.0.0.1`, remote port `45003`.
- Cablear `INTRUSO (intruso)` ↔ `ISP-1 Ethernet1`.
- Guardar el proyecto (**Ctrl+S**).

**3. Arrancar** los nodos en GNS3 y, recién después, la estación (el orden importa: la nube tiene que existir antes que el túnel de la VM).

**4. Preparar el INTRUSO** en la estación (necesita Internet: construye la imagen):

```powershell
scp -i $env:USERPROFILE\.ssh\goys_estacion -P 2222 demo\intruso\Dockerfile demo\intruso\61-intruso.yaml demo\intruso\preparar-intruso.sh demo\intruso\intruso.sh goys@127.0.0.1:
ssh -t -i $env:USERPROFILE\.ssh\goys_estacion -p 2222 goys@127.0.0.1 "sudo bash ~/preparar-intruso.sh"
```

[`preparar-intruso.sh`](../intruso/preparar-intruso.sh) levanta `enp0s9` sin IP, construye `goys/intruso:1` y crea la red Docker `intruso`. Se puede correr más de una vez.

**5. ISP-1** (consola de GNS3, con `admin`): pegar [`H4-intruso.rsc`](../routers/H4-intruso.rsc). Antes, `/export file=pre-H4`. Después de `/interface print where name=ether2` la placa tiene que tener la marca **R**; si no la tiene, frenar: es el problema del orden de las placas del TP3.

---

## Uso

Dentro de la estación, [`intruso.sh`](../intruso/intruso.sh):

| Comando | Qué hace |
|---|---|
| `bash ~/intruso.sh ping` | 4 pings al EDGE (`203.0.113.2`) |
| `bash ~/intruso.sh traza` | *traceroute* ICMP al EDGE: tiene que pasar por ISP-1 |
| `bash ~/intruso.sh escanear` | nmap SYN a los 100 puertos más comunes del EDGE (`-Pn -sS -T4 --top-ports 100`) |
| `bash ~/intruso.sh escanear -p 1-1024 203.0.113.2` | nmap con otros argumentos |
| `bash ~/intruso.sh shell` | consola dentro del INTRUSO |

---

## Verificación (`capturas/H4/`)

En el laboratorio de Tomás, con la configuración del TP3 en el EDGE (sin la defensa de H5):

| Prueba | Comando | Resultado |
|---|---|---|
| ISP-1 | `/interface print where name=ether2` | `ether2` con **R**, MAC `0C:20:F1:1E:00:01` (segunda placa, la del cable al INTRUSO) |
| Ping al EDGE | `bash ~/intruso.sh ping` | 4/4, ~2,7 ms, TTL 63 (un salto: ISP-1) |
| Camino | `bash ~/intruso.sh traza` | `203.0.113.9` (ISP-1) → `203.0.113.2` (EDGE) |
| **Escaneo (entregable H4)** | `bash ~/intruso.sh escanear` | Termina en 11 s: 100 puertos `filtered`. El firewall del EDGE del TP3 descarta todo lo que entra desde un proveedor, salvo BGP desde las IP de los ISP |
| Segmentación | ping del INTRUSO a `10.20.0.100`, `10.10.0.100` y `10.20.0.101` | 0 respuestas: la regla de `forward` del EDGE «nada nuevo desde los ISP» lo frena |

Este escaneo es el que H5 tiene que detectar y bloquear: hoy termina sin obstáculos.

---

## Problemas conocidos

- **El INTRUSO tiene red solo con GNS3 abierto**, los nodos arrancados y la nube `INTRUSO` cableada a `ISP-1 Ethernet1`.
- **Si la estación no llega a `10.20.0.1` o el INTRUSO no llega al EDGE**, revisar que ningún programa de Windows ocupe un puerto del rango UDP de GNS3. En una PC con la app de NVIDIA, `nvcontainer` toma `127.0.0.1:10030` y se come el tráfico del cable que GNS3 le asigne a ese puerto. Solución: rango UDP de GNS3 en 20000–30000 ([D-17](../../decisiones.md#d-17)). Para revisarlo:

  ```powershell
  Get-NetUDPEndpoint | Where-Object { $_.LocalPort -ge 10000 -and $_.LocalPort -le 30000 } | ForEach-Object { "{0}:{1} {2}" -f $_.LocalAddress, $_.LocalPort, (Get-Process -Id $_.OwningProcess).ProcessName }
  ```

- **`docker network create` falla con «parent interface not found»:** falta la placa 3 (paso 1) o la VM arrancó antes de agregarla.
- **La nube agarra placas de la PC** (Ethernet, Wi-Fi) además del túnel: no molestan mientras no tengan cable.
