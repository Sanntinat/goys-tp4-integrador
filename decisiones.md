# Registro de decisiones técnicas — TP4 «Sistema Inmune»

> Cada decisión que cambia el diseño, o que alguien del grupo podría preguntarse «¿por qué está así?», queda acá.
> Formato: contexto → decisión → alternativas descartadas → consecuencias → evidencia.
> La [propuesta](propuesta.md) es el plan aprobado; cuando la implementación se aparta de ella, se explica en este registro.

| # | Fecha | Decisión | Quién | Estado |
|---|---|---|---|---|
| [D-01](#d-01) | 07/11 | La red del TP3 se reutiliza sin cambios de diseño | Grupo | Vigente |
| [D-02](#d-02) | 07/11 | Detección de escaneos con `psd` de RouterOS y bloqueo en `raw` | Grupo | Vigente |
| [D-03](#d-03) | 07/11 | La regla de detección va antes del drop final y la red de gestión entra en `confianza` | Tomás | Vigente |
| [D-04](#d-04) | 12/11 | El laboratorio del TP4 es una copia del proyecto GNS3, fuera de OneDrive | Santiago | Vigente |
| [D-05](#d-05) | 12/11 | La estación es una VM Ubuntu en VirtualBox, no la laptop con Windows | Santiago | Vigente (cambia la propuesta) |
| [D-06](#d-06) | 12/11 | La VM se une a GNS3 con un túnel UDP en una nube, no como nodo VirtualBox | Santiago | Vigente |
| [D-07](#d-07) | 12/11 | Red de la estación: IP fija de gestión, rutas solo al laboratorio, Internet por NAT | Santiago | Vigente |
| [D-08](#d-08) | 12/11 | Docker desde el repositorio oficial, con imágenes fijadas por versión y descargadas de antemano | Santiago | Vigente |
| [D-09](#d-09) | 12/11 | Acceso a la estación por llave SSH; ningún secreto en el repositorio | Santiago | Vigente |
| [D-10](#d-10) | 12/11 | Fin de línea LF forzado para scripts y configuraciones | Santiago | Vigente |
| [D-11](#d-11) | 12/11 | Ansible corre en la estación (Linux), no en WSL | Santiago | Vigente (cambia la propuesta) |
| [D-12](#d-12) | 12/11 | Una rama y un *pull request* por hito | Grupo | Vigente |
| [D-13](#d-13) | 14/11 | La API-SSL usa un certificado firmado por una CA local de cada router | Juan Bautista | Vigente |
| [D-14](#d-14) | 14/11 | mktxp fijado en 1.2.20 y limitado a interfaces, firewall y BGP | Juan Bautista | Vigente |
| [D-15](#d-15) | 14/11 | La caída de un proveedor se detecta por el ping, no por BGP | Juan Bautista | Vigente |
| [D-16](#d-16) | 14/11 | El INTRUSO es un container de la estación unido a ISP-1 por un segundo túnel UDP | Tomás | Vigente (cambia la propuesta) |
| [D-17](#d-17) | 14/11 | GNS3 usa el rango UDP 20000–30000 para sus enlaces | Tomás | Vigente |
| [D-18](#d-18) | 14/11 | En `psd`, los 3 s son la pausa máxima entre intentos, no una ventana | Tomás | Vigente (corrige la propuesta) |
| [D-19](#d-19) | 14/11 | Ansible entra al EDGE por SSH con `admin` y lee antes de escribir, en vez de usar la API | Lautaro | Vigente |

---

<a id="d-01"></a>
## D-01 — La red del TP3 se reutiliza sin cambios de diseño

- **Contexto:** el TP3 ya tiene 7 routers MikroTik CHR con eBGP, OSPF y VRRP, probados con 5 drills.
- **Decisión:** el TP4 se monta encima de esa red. Solo se agregan la estación, el INTRUSO y las reglas de defensa del EDGE.
- **Alternativa descartada:** armar una topología nueva. Perdía lo ya probado y sumaba riesgo para la feria.
- **Evidencia:** [propuesta §3.1](propuesta.md).

<a id="d-02"></a>
## D-02 — Detección con `psd` de RouterOS y bloqueo en la tabla `raw`

- **Contexto:** hace falta detectar un escaneo de puertos y cortar al origen sin intervención humana.
- **Decisión:**
  - El detector `psd` del firewall del EDGE agrega el origen a la lista `bloqueados` durante 2 minutos.
  - Una regla en `raw` descarta su tráfico antes del seguimiento de conexiones.
- **Alternativas descartadas:**
  - **Suricata o CrowdSec:** más piezas que tienen que andar en cadena durante la demo.
  - **Event-Driven Ansible:** suma latencia y un punto de falla.
- **Consecuencia:** detecta escaneos rápidos, no ataques lentos ni de fuerza bruta. Está declarado en la propuesta (§10).
- **Evidencia:** [propuesta §3.3 y §5](propuesta.md).

<a id="d-03"></a>
## D-03 — La regla de detección va antes del drop final, y la red de gestión entra en `confianza`

- **Contexto:** el `input` del EDGE (TP3) termina con «input: todo lo demas», que descarta todo lo no permitido.
- **Decisión:**
  - La regla `psd` se ubica antes de esa regla final (`place-before`). Agregada al final, nunca vería el escaneo.
  - La lista `confianza` incluye `10.20.0.0/24` además de los dos ISP. Así una prueba con `nmap` desde la estación no la bloquea a ella misma.
- **Evidencia:** commit `140bf63` (Tomás Martin).

<a id="d-04"></a>
## D-04 — El laboratorio del TP4 es una copia del proyecto GNS3, fuera de OneDrive

- **Contexto:** el proyecto del TP3 (`Failover-G11`) es la entrega de otro TP y no se debe modificar. Además está dentro de OneDrive, que intenta sincronizar los discos de los routers mientras corren.
- **Decisión:**
  - Copia con *File → Save project as…* a `GNS3\projects\TP4-SistemaInmune`, con los discos y los snapshots.
  - Es un `project_id` nuevo, así que GNS3 los trata como proyectos distintos.
- **Alternativa descartada:** copiar la carpeta a mano. Conserva el mismo `project_id` y GNS3 confunde los dos proyectos.
- **Evidencia:**
  - SHA-256 de `Failover-G11.gns3` idéntico antes y después de H1 y de H2: `c3d9be4d…`.
  - Capturas en `capturas/H1/` y [runbook H1](demo/runbooks/preparar-estacion.md#h1--copia-del-proyecto-gns3).

<a id="d-05"></a>
## D-05 — La estación es una VM Ubuntu en VirtualBox, no la laptop con Windows

- **Contexto:** la propuesta ponía la estación en la laptop, con Docker y un nodo *Cloud* de GNS3 sobre una placa de loopback de Windows (`10.20.0.101`).
- **Lo que pasó:**
  - En Windows 11 25H2, Windows **envía** por la placa pero **descarta lo que le llega** desde GNS3. Npcap inyecta los paquetes marcados como propios: no aprende la MAC del gateway ni responde el ARP de SRV.
  - Reiniciar la placa o la PC no lo arregló.
  - La opción de Npcap prevista para esto (`SendToRxAdapters`) colgó los envíos en esta máquina y se revirtió.
- **Decisión:**
  - **VM Ubuntu Server 24.04** en VirtualBox (`ESTACION-TP4`, 2 GB de RAM, 2 CPU, disco de 20 GB), con Docker.
  - **Placa 1:** al laboratorio.
  - **Placa 2:** NAT de VirtualBox, para Internet y para el acceso desde Windows.
- **Alternativas descartadas:**
  - Placa de loopback de Windows (no anda).
  - Placa *host-only* de VirtualBox como *Cloud* (mismo síntoma: Windows no envía ARP por ella).
  - Containers dentro de GNS3: exigen la GNS3 VM y mover todos los routers a ella.
- **Consecuencias:**
  - Prometheus, Grafana y los exporters (H3) corren en la VM.
  - Grafana se abre desde Windows en `http://127.0.0.1:3000`.
  - Docker Desktop ya no hace falta.
  - Suma 2 GB de RAM sobre una laptop de 7,4 GB.
- **Evidencia:** capturas `capturas/H2/H2-01*` y [runbook H2](demo/runbooks/preparar-estacion.md#por-qué-no-quedó-como-decía-la-propuesta).

<a id="d-06"></a>
## D-06 — La VM se une a GNS3 con un túnel UDP, no como nodo VirtualBox de GNS3

- **Contexto:** al agregar la VM como nodo VirtualBox, GNS3 desactiva todas las placas que no maneja (`nic2="none"`). La VM se quedó sin NAT, sin Internet y sin acceso desde Windows.
- **Decisión:**
  - VirtualBox maneja la VM (`iniciar-estacion.ps1`, sin ventana).
  - Su placa 1 es un túnel UDP (`127.0.0.1`, puerto local `45001` → `45000`) hacia una nube `ESTACION` de GNS3, configurada con un *UDP tunnel* y cableada a `SW-SERVERS e3`.
  - Es el mismo mecanismo que usa GNS3 por dentro con las VMs, y no pasa por Npcap.
- **Consecuencia:** la red del laboratorio de la estación funciona solo con el proyecto abierto y los nodos arrancados. Los puertos `45000/45001` quedan fuera del rango que GNS3 usa para sus propios enlaces.
- **Evidencia:** `capturas/H2/H2-02` a `H2-04`.

<a id="d-07"></a>
## D-07 — Red de la estación: IP fija de gestión, rutas solo al laboratorio, Internet por NAT

- **Decisión:**
  - `enp0s3` = `10.20.0.101/24` fija ([`60-laboratorio.yaml`](demo/estacion/60-laboratorio.yaml)), en la LAN SERVERS. Es la red de gestión del TP3, desde la que los routers ya aceptan SSH y Winbox.
  - **Sin ruta por defecto por el laboratorio:** solo `10.0.0.0/24`, `10.10.0.0/24`, `10.255.255.0/24`, `203.0.113.0/24`, `198.51.100.0/24` y `192.0.2.0/24` van por el gateway VRRP `10.20.0.1`. Internet sale por `enp0s8` (NAT).
  - Los accesos desde Windows (SSH `2222`, Grafana `3000`, Prometheus `9090`) se publican **solo en `127.0.0.1`**, no en la red de la casa o de la facultad.
- **Consecuencias:**
  - Los containers salen por el NAT de Docker, así que llegan a la red como `10.20.0.101`. Es la IP que el EDGE va a habilitar para la API-SSL de solo lectura (H3).
  - Si cae el master VRRP, la estación sigue usando `10.20.0.1`, igual que los hosts del TP3.
- **Evidencia:** `capturas/H2/H2-03` (rutas) y `H2-05` (origen `10.20.0.101` en `tcpdump`).

<a id="d-08"></a>
## D-08 — Docker desde el repositorio oficial, con imágenes fijadas y descargadas de antemano

- **Decisión:**
  - Docker Engine desde `download.docker.com`, no el *snap* que ofrece el instalador de Ubuntu.
  - Las imágenes se fijan por versión (por ejemplo `alpine:3.20`, nunca `latest`) y se descargan al preparar la estación.
- **Por qué:**
  - La feria es sin Internet.
  - Con `latest`, dos compañeros pueden terminar con versiones distintas.
- **Evidencia:** [`preparar-estacion.sh`](demo/estacion/preparar-estacion.sh).

<a id="d-09"></a>
## D-09 — Acceso a la estación por llave SSH; ningún secreto en el repositorio

- **Decisión:**
  - Se entra a la VM con una llave `ed25519` propia de cada uno (`~/.ssh/goys_estacion`).
  - Las contraseñas de la VM y de los routers no se escriben en el repo: se pasan por privado.
  - Las credenciales del monitoreo (H3) irán en `.env` (ya ignorado por `.gitignore`) o en Ansible Vault (H6).
- **Evidencia:** `.gitignore` y la [propuesta §6](propuesta.md).

<a id="d-10"></a>
## D-10 — Fin de línea LF forzado para scripts y configuraciones

- **Contexto:** con `core.autocrlf=true` (lo normal en Windows), Git convierte los `.sh` a CRLF al hacer el *checkout*, y en Linux fallan con `$'\r': command not found`.
- **Decisión:** [`.gitattributes`](.gitattributes) fuerza LF en `*.sh`, `*.yaml`, `*.yml` y `*.rsc`.

<a id="d-11"></a>
## D-11 — Ansible corre en la estación, no en WSL

- **Contexto:** la propuesta (figura 1) ponía Ansible en WSL. Con D-05, la estación ya es un Linux con acceso a la red de gestión.
- **Decisión:** el playbook `defensa.yml` (H6) se ejecuta desde la VM estación. Llega a los routers por SSH desde `10.20.0.101`, que ya está permitido por la lista `gestion` del TP3.
- **Consecuencia:** no hace falta instalar WSL ni una distribución extra en la laptop.

<a id="d-12"></a>
## D-12 — Una rama y un *pull request* por hito

- **Contexto:** el README de la cátedra pide no pushear a `main` sin revisión y usar PRs para el documento y las decisiones grandes.
- **Decisión:**
  - Cada hito se trabaja en una rama (`h1-h2-laboratorio-estacion`, `h3-tablero`, …) y entra a `main` por *pull request*.
  - Lo revisa otro integrante antes del *merge*.
- **Consecuencia:** cada PR deja registrado quién hizo qué y quién lo revisó. Eso sirve como evidencia de participación.

<a id="d-13"></a>
## D-13 — La API-SSL usa un certificado firmado por una CA local de cada router

- **Contexto:** la guía de H3 creaba un certificado `tls-server` y lo autofirmaba con `/certificate sign api-ssl`. En RouterOS 7.21.5 eso falla con `failure: CA not found`.
- **Decisión:** en cada router se crea primero una CA local (`ca-local`, `key-cert-sign,crl-sign`) y con ella se firma `api-ssl` (`/certificate sign api-ssl ca=ca-local`). Queda en [`demo/routers/H3-monitoreo.rsc`](demo/routers/H3-monitoreo.rsc).
- **Alternativa descartada:** `no_ssl_certificate = True` en mktxp (API-SSL sin certificado). Funciona, pero el tráfico queda cifrado sin certificado y se pierde la evidencia de quién responde.
- **Consecuencia:** mktxp no verifica el certificado (`ssl_certificate_verify = False`), porque es de una CA privada. La protección real es la restricción de origen (`10.20.0.101/32`) en el servicio, en el usuario y, en el EDGE, en el firewall.
- **Evidencia:** `capturas/H3/H3-01` a `H3-03`. Desde la estación, `openssl s_client` muestra `CN=<router>` emitido por `CN=CA-<router>` en los 5 routers.

<a id="d-14"></a>
## D-14 — mktxp fijado en 1.2.20 y limitado a interfaces, firewall y BGP

- **Contexto:** la versión más nueva de mktxp (2.x) cambió el formato y la ubicación de la configuración respecto de la que documenta la guía. Además, con todos los colectores encendidos, leer los 5 CHR emulados tardaba más de 4 s y Prometheus cortaba el *scrape* de 5 s (`context deadline exceeded`).
- **Decisión:**
  - Imagen `ghcr.io/akpw/mktxp:1.2.20`, la última 1.x, con la configuración montada en `/etc/mktxp`.
  - Solo quedan encendidos `interface`, `firewall`, `address_list = bloqueados` y `bgp`, que son los que usan el tablero y las alertas. Los 5 routers se leen en paralelo.
  - Ante una falla de conexión, mktxp reintenta a los 10 s (máximo 30 s) en lugar de 120 s, para que un router que vuelve aparezca enseguida en el tablero.
- **Consecuencia:** el *scrape* de mktxp baja a menos de 1 s. Para agregar métricas (por ejemplo `monitor`, que consulta placa por placa), hay que medir antes el tiempo del *scrape*.
- **Evidencia:** `capturas/H3/H3-04` (los 3 *targets* en UP).

<a id="d-15"></a>
## D-15 — La caída de un proveedor se detecta por el ping, no por BGP

- **Contexto:** en la prueba de H3, al apagar ISP-2, `DestinoInalcanzable` saltó en 2 s, pero la sesión BGP siguió *established* durante el *hold time* (unos 3 minutos) hasta que el EDGE la dio por caída.
- **Decisión:** se mantienen las dos alertas. `DestinoInalcanzable` es la que avisa la falla; `SesionBGPCaida` confirma después el estado del enrutamiento. No se acortan los *timers* de BGP del TP3 (D-01).
- **Consecuencia:** en la demo, para mostrar `SesionBGPCaida` hay que esperar unos 3 minutos con el proveedor apagado. Es un buen ejemplo de por qué se combina el monitoreo de caja negra con el interno (propuesta §3.3).
- **Evidencia:** `capturas/H3/H3-06` y `H3-08`.

<a id="d-16"></a>
## D-16 — El INTRUSO es un container de la estación unido a ISP-1 por un segundo túnel UDP

- **Contexto:** la propuesta pone al INTRUSO como «un Linux con nmap del lado de ISP-1». GNS3 corre sin la GNS3 VM (D-05), así que no admite containers dentro de la topología, y una VM aparte suma RAM sobre una laptop de 7,4 GB.
- **Decisión:**
  - La estación suma una **placa 3** (`enp0s9`): un túnel UDP (`127.0.0.1`, puerto local `45003` → `45002`) hacia una nube `INTRUSO` de GNS3, cableada a `ISP-1 Ethernet1` (`ether2`). Es el mismo mecanismo que la placa de la estación (D-06), en promiscuo para que lleguen las tramas dirigidas al container.
  - La estación no usa esa placa: la deja levantada y sin IP ([`61-intruso.yaml`](demo/intruso/61-intruso.yaml)).
  - El INTRUSO es un container `goys/intruso:1` (Alpine 3.20 + nmap 7.95, [`Dockerfile`](demo/intruso/Dockerfile)) en una red Docker *macvlan* sobre `enp0s9`, con IP `203.0.113.10/30` y gateway ISP-1 (`203.0.113.9`). Tiene su propia MAC y su propio *network namespace*: para la red es un equipo más en «Internet».
  - ISP-1 recibe `203.0.113.9/30` en `ether2` y anuncia `203.0.113.8/30` por BGP ([`H4-intruso.rsc`](demo/routers/H4-intruso.rsc)).
- **Alternativas descartadas:**
  - **VM Linux aparte en VirtualBox:** suma otra VM y RAM.
  - **Appliance QEMU dentro de GNS3:** para instalarle nmap hace falta darle Internet, y el nodo NAT de GNS3 en Windows exige la GNS3 VM.
  - **Octavo router MikroTik con un script que pruebe puertos:** no es un escaneo real y la demo pierde claridad.
- **Consecuencias:**
  - No suma RAM: la imagen ocupa 33 MB y el container vive lo que dura cada prueba.
  - El INTRUSO y el monitoreo comparten la VM pero no la red: desde el INTRUSO no hay llegada a las LAN ni a la estación (lo frena el firewall del EDGE del TP3).
  - El INTRUSO tiene red solo con GNS3 abierto y la nube `INTRUSO` cableada, igual que la estación.
- **Evidencia:** [runbook H4](demo/runbooks/intruso.md) y `capturas/H4/`.

<a id="d-17"></a>
## D-17 — GNS3 usa el rango UDP 20000–30000 para sus enlaces

- **Contexto:** al replicar el laboratorio en la PC de Tomás, la estación no recibía nada por `enp0s3`. GNS3 le había asignado al cable `ESTACION`–`SW-SERVERS` el puerto UDP `10030`, que el servicio `nvcontainer` de la app de NVIDIA tiene tomado en `127.0.0.1:10030`. Como esa es una asignación más específica que la de GNS3 (`0.0.0.0:10030`), Windows le entregaba a NVIDIA el tráfico que el switch le mandaba a la nube.
- **Decisión:** en `%APPDATA%\GNS3\2.2\gns3_server.ini`, `udp_start_port_range = 20000` y `udp_end_port_range = 30000` (por defecto: 10000–20000). Se cambia con GNS3 cerrado, porque lo reescribe al salir.
- **Alternativa descartada:** cerrar o reconfigurar el servicio de NVIDIA: toca el sistema y el problema vuelve con cada actualización.
- **Consecuencias:**
  - Vale para cualquier PC con la app de NVIDIA. Síntoma: la estación no llega a `10.20.0.1` y `Get-NetUDPEndpoint` muestra `nvcontainer` en un puerto del rango de GNS3.
  - El cambio es por PC y no viaja con el proyecto. En la laptop de la demo hay que revisarlo antes de la feria.
- **Evidencia:** [runbook H4, problemas conocidos](demo/runbooks/intruso.md#problemas-conocidos).

<a id="d-18"></a>
## D-18 — En `psd`, los 3 s son la pausa máxima entre intentos, no una ventana

- **Contexto:** la propuesta (§3.3) y el documento explican la regla de detección como «un origen que prueba muchos puertos en 3 segundos». En las pruebas de H5, un escaneo de un puerto por segundo, que en 3 s suma como mucho 9 puntos, igual quedó bloqueado a los 20 s.
- **Qué hace en realidad `psd=21,3s,3,1`:** suma 3 puntos por cada puerto bajo y 1 por cada puerto alto mientras el mismo origen no deje pasar **más de 3 s entre un intento y el siguiente**. Si la cadena llega a 21, el origen entra en `bloqueados`. No importa cuánto dure el escaneo, sino la pausa entre intentos.
- **Decisión:** se mantienen los valores (`21,3s,3,1`) y se corrige la explicación en el runbook y en el documento final.
- **Consecuencias:**
  - La defensa detecta cualquier escaneo con pausas menores a 3 s, rápido o lento: el de la demo, en menos de 0,2 s; uno de un puerto por segundo, a los 20 s.
  - Se le escapa un escaneo con pausas mayores a 3 s: uno de un puerto cada 4 s revisó 15 puertos en 64 s sin bloqueo. Ese es el límite que hay que declarar (propuesta §10).
- **Evidencia:** [runbook H5](demo/runbooks/defensa.md), pruebas 3 y 4; `capturas/H5/H5-05`.

<a id="d-19"></a>
## D-19 — Ansible entra al EDGE por SSH con `admin` y lee antes de escribir, en vez de usar la API

- **Contexto:** la propuesta (§7.2) pide un `defensa.yml` idempotente y un `defensa-quitar.yml` que deje el EDGE como estaba. La colección `community.routeros` ofrece dos caminos: módulos por API (`api_modify`, que ya es idempotente) o el módulo `command` por SSH, que solo manda órdenes y siempre informa «changed».
- **Decisión:**
  - **SSH con el módulo `command`.** Cada playbook primero lee el EDGE (posición de la detección dentro de `input`, cada regla con `print terse`, las direcciones de `confianza`) y después manda solo las órdenes que faltan, con `changed_when` puesto a mano. Una regla que está pero difiere se borra y se vuelve a crear en su lugar.
  - **Usuario `admin`,** el único con permiso de escritura desde el TP3. La clave va en `group_vars/edge/vault.yml`, cifrado con Ansible Vault y además fuera de Git.
  - **`host_key_checking` activo:** la llave del EDGE se acepta una vez a mano comparando la huella.
  - **Ansible del paquete de Ubuntu 24.04** (`ansible` 9, `ansible-core` 2.16), que trae las colecciones: la estación no necesita Internet en la demo.
- **Alternativas descartadas:**
  - **`api_modify` por API-SSL:** habría que darle escritura a un usuario por la API, que hoy solo usa `prometheus` en modo lectura (H3), y el orden de las reglas de `filter` obliga a manejar la cadena entera.
  - **Mandar el `.rsc` de H5 tal cual:** funciona, pero siempre rehace todo y no se puede mostrar la idempotencia.
  - **Un usuario `ansible` aparte:** suma otra clave para un único equipo; queda como mejora.
- **Consecuencias:**
  - La comparación de parámetros depende de cómo RouterOS 7.21 los imprime en `print terse`. Si alguno no coincide, el playbook rehace la regla en cada corrida (no rompe nada, pero `changed` no llega a 0). Se verifica en la prueba 2 del runbook.
  - `defensa-quitar.yml` también vacía `bloqueados`, así la demo se reinicia sin esperar los 2 minutos.
- **Evidencia:** [runbook H6](demo/runbooks/automatizacion.md).
