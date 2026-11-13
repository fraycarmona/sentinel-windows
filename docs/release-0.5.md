# SENTINEL 0.5: endurecimiento y alcance verificable

La espera normal de retirada sigue siendo **24 horas acumuladas con el servicio activo**. Apagar, suspender o cambiar el reloj no adelanta la espera. Cerrar el panel no detiene el motor. La recuperación administrativa sigue existiendo: el producto no puede garantizar resistencia absoluta al administrador de Windows.

## Cambios por hallazgo de la auditoría

| Hallazgo | Implementación en 0.5 | Límite restante |
|---|---|---|
| A01: DoH propio | Políticas de DNS/proxy/privado/invitado en Edge, Chrome y Firefox; cuatro reglas de firewall para resolvedores públicos conocidos y puerto 853; dominios DoH conocidos en DNS/hosts | HTTPS a resolvedores desconocidos, direcciones alternativas y otros navegadores. No es un bloqueo universal |
| A02: VPN/proxy | Proxy directo en navegadores compatibles y restricciones de algunos endpoints DNS | No hay VPN de SENTINEL, controlador WFP propio, lista de aplicaciones permitidas ni bloqueo general de túneles |
| A03: contenido en dominios permitidos | SafeSearch por DNS en Google .com/.es y Bing; YouTube Restricted; políticas complementarias de búsqueda | No analiza imágenes/publicaciones ni cubre todos los buscadores y plataformas. No se instaló una extensión de inspección |
| A04: fallo/saturación | Presupuesto TCP independiente de UDP; respaldo Cloudflare Families verificado antes de cambiar DNS; hosts residual; reinicio del motor por guardián | Una saturación UDP sostenida sigue siendo posible. Si tampoco responde el respaldo filtrado, se informa de degradación y no se restaura automáticamente DNS sin filtro |
| A05: espera y administrador | La parada SCM ordinaria se rechaza antes de completar la espera. Los flujos de retirada de DNS, hosts y políticas usan IPC autenticado. Reparación conserva espera/reglas y usa respaldo filtrado | Un administrador puede usar recuperación, cambiar Windows o reemplazar binarios. El mantenimiento explícito administrativo no es una frontera de seguridad |
| A06: interfaces nuevas | Guardián concilia adaptadores físicos activos con DNS automático, conservando diario anterior; informa de conflictos con DNS ajeno | DNS estático, VPN y adaptadores virtuales necesitan revisión. No se sobrescriben configuraciones ajenas |
| A07: aplicaciones portables | Se conserva el bloqueo experimental por ruta exacta; controles de red conocidos no dependen de la ruta del navegador | Sin control universal de aplicaciones/firmas ni garantía para Comet o emuladores |
| A08: caché/conexiones previas | Se limpia caché DNS tras cambios y se indica reiniciar navegadores | Sin eliminación de contenido descargado ni inspección de sesiones HTTPS abiertas |
| A09: suplantación IPC | PID del servidor del pipe debe coincidir con PID Running de SCM; rechazo si no se puede comprobar. Primera instancia exclusiva | No protege frente a un administrador que reconfigure SCM o inyecte en el servicio |
| A10: LocalService compartido | SID NT SERVICE/Sentinel; configuración y diarios sólo escribibles por SYSTEM/administradores; estado mutable separado en runtime | El propio motor necesita modificar su contador. No es almacenamiento remoto ni atestación |
| A11: actualización | Se conservan copia anterior y diagnóstico; el paquete es compilado y distribuido con hash | **Pendiente firma de producción y ancla de confianza externa**. Un hash distribuido junto al paquete no sustituye una firma |

El respaldo de categoría no mantiene la reescritura SafeSearch del resolvedor local. Hosts conserva sólo nombres exactos y su variante www de la lista configurada, no todos los subdominios. La interfaz mantiene el término «filtrado DNS»; no afirma protección integral.

## Referencias de implementación y licencias

Se revisaron fuentes públicas; la implementación C#/PowerShell es propia. No se incorporaron archivos, modelos ni listas de terceros al ejecutable y no se copiaron módulos GPL. No se importaron dependencias de esos proyectos.

- **Sanctum (GPL-3.0)**: arquitectura de DNS + protección residual hosts y reescritura exacta SafeSearch. Revisados [safesearch.rs](https://github.com/wgravel855-lang/sanctum/blob/main/crates/sanctum-core/src/safesearch.rs) (blob a54a8be31acf18fd2d90631700c7a61eaaeffde8) y [hostsfile.rs](https://github.com/wgravel855-lang/sanctum/blob/main/crates/sanctum-service/src/hostsfile.rs) (8bf07a06d0f7a3fb58c68934e88ff4722e3a21b0). SENTINEL añade diario, conservación de bytes y detección de conflictos en su implementación.
- **Oath Light (GPL-3.0)**: [friction.rs](https://github.com/Xeno-legit/Oath-Light/blob/main/desktop-app/src-tauri/src/friction.rs), referencia para aplicar fricción a debilitamientos. SENTINEL conserva el contador monotónico ya existente y protege su almacenamiento; no adopta el marcador de desinstalación editable por el usuario identificado en la investigación.
- **BlockNSFW (MIT en el repositorio público)**: [unsafe-search.js](https://github.com/codepurse/BlockNSFW/blob/main/shared/unsafe-search.js) (5382c72439531c649539095c203fbbe6a1fa1612). Su separación entre buscadores cubiertos y contenido dentro de sitios motiva declarar cobertura por nombre exacto. Se implementa SafeSearch, no se copia su lista ni se atribuye a SENTINEL su análisis local de imágenes.
- **SafeNet-Family (GPL-3.0)**: [Install.ps1](https://github.com/saago/SafeNet-Family/blob/main/Install.ps1) (297e0731ce3f0470eb75b572a054715d0cb0fc35). Referencia para reconciliación al arrancar. SENTINEL usa tarea protegida, comprobación de salud y diarios sin sobrescribir cambios ajenos.
- **Simple Productivity Blocker (MIT)**: [app_blocker.py](https://github.com/nvusdev/simple-productivity-blocker/blob/main/blockers/app_blocker.py). Se adopta el principio de precomprobaciones y protección de componentes esenciales; no se copian bloqueos exclusivos de archivos ni se bloquean herramientas de recuperación de Windows.

Fuentes de plataforma: [SafeSearch administrado de Google](https://support.google.com/websearch/answer/186669?hl=en), [política Bing estricta](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/forcebingsafesearch), [PID del servidor de pipe](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeserverprocessid), [estado/PID de servicio](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatusex).

## Verificación reproducible

- `build.ps1 -Publish`: 20 pruebas de núcleo, incluidos parser, reloj, persistencia, SafeSearch y rechazo de pipe ajeno; dos lotes de 10.000 entradas aleatorias.
- `test-local.ps1`: 12 combinaciones DNS UDP/TCP, IPv4/IPv6, permitido/bloqueado; persistencia de solicitud al reiniciar proceso; separación UDP con 80 conexiones TCP abiertas y cuatro destinos SafeSearch sin pistas HTTPS/SVCB alternativas.
- `test-udp-resilience.ps1`: 300 clientes UDP cerrados; motor continúa respondiendo.
- `test-strict.ps1`: 17 casos de aplicación/rollback/conflicto con backend simulado.
- `test-recovery.ps1`: 8 casos, hosts en archivos temporales y DNS simulado, incluida conservación de cambios ajenos y de diarios cuando falta un adaptador.
- `upgrade-verify.ps1`: prueba administrativa real de instalación, conectividad, retirada anticipada y recuperación; resultados en la carpeta de evidencia indicada. No simula 24 h cumplidas sobre la instalación real.
- `verify-startup.ps1 -PreviousBootUtc ...`: rechaza dar por probado un reinicio si Windows sigue en el arranque anterior. Comprueba recibo del guardián del nuevo arranque y filtro real. Se debe observar también la apertura del panel en la sesión del usuario.

### Estado de pruebas de equipo

Las pruebas de laboratorio anteriores se ejecutaron satisfactoriamente el 2026-11-13. La actualización administrativa quedó **activa** con el motor nuevo. El reinicio real se observó después: Windows pasó del arranque 2026-10-18T18:59:33Z al 2026-11-13T19:07:29Z. El servicio arrancó en modo Automatic con PID nuevo; el guardián dejó un recibo SYSTEM del mismo arranque y el sondeo filtrado pasó. Wi-Fi mantuvo 127.0.0.1 y ::1; example.com y Google HTTPS funcionaron y el dominio de diagnóstico adulto devolvió 0.0.0.0. La entrada del panel en HKCU Run existe y se observó su proceso abierto después de iniciar sesión; el momento exacto de apertura automática del panel no se midió.

El verificador del PC guardó la evidencia local en `work/upgrade05-evidence`. Pasaron: IPC autenticado y espera preservada, DNS local IPv4/IPv6 con bloqueo de categoría, Google/example.com HTTPS 200, endpoint conocido Google DoH inaccesible, hosts residual para X y el dominio configurado, 18 políticas y 4 reglas firewall leídas, parada y retirada anticipadas rechazadas, respaldo filtrado con el motor parado, recuperación del guardián al motor local, ACL sin permiso genérico LocalService, y servicio/tarea de arranque configurados. Se corrigieron dos fallos encontrados durante la actualización: compatibilidad de Add-Type con PowerShell 5.1 y ausencia de la entrada antigua de desinstalación. Una comprobación de hosts inicialmente no interpretaba el error NoData de Windows como bloqueo; se corrigió y la prueba real posterior pasó.

No se verificó Comet visualmente a petición del propietario. No se completó una espera real de 24 horas; se comprobó su lógica y el rechazo anticipado.

