# Evasión por DoH, VPN y proxy: investigación y diseño

Fecha: 2026-11-09. Estado: diseño pendiente de implementación y pruebas de integración. No se ha activado un bloqueo de VPN ni cambiado el firewall del PC.

## Conclusión
Cambiar los DNS del adaptador no obliga a todas las aplicaciones a utilizarlos. Para un modo estricto hacen falta políticas verificadas de navegador, control de conexiones en Windows y restricciones sobre qué aplicaciones pueden acceder a la red. Incluso así, permitir navegación HTTPS arbitraria permite proxies web y otros túneles dentro de aplicaciones autorizadas. No existe una regla de puerto que garantice bloquearlos todos sin limitar también usos legítimos.

El alcance realista es resistir evasiones habituales de un usuario estándar. Un administrador conserva mecanismos de recuperación y puede modificar el sistema. La espera de 24 horas controla las operaciones normales de SENTINEL; no constituye una frontera de seguridad contra el administrador.

## Capas propuestas
| Vía | Medida | Límite y verificación necesaria |
|---|---|---|
| DNS externo clásico | Filtros WFP para DNS externo TCP/UDP 53, IPv4 e IPv6; conservar loopback | Probar todas las interfaces, incluidas virtuales; no afectar al DoH ascendente del servicio |
| DoH del navegador | Política obligatoria que desactive el resolvedor propio y use el sistema | Verificar política efectiva en cada navegador, perfil e incógnito; escribir el registro no basta |
| Proxy configurado | Política obligatoria de conexión directa | No bloquea un proxy web que funciona como una página HTTPS |
| DoT/DoQ habituales | Restringir salidas TCP/UDP 853 | No cubre puertos alternativos ni túneles HTTPS |
| VPN y programas nuevos | Control de aplicaciones con acceso a red mediante WFP; aprobación explícita de aplicaciones | La identidad por ruta no demuestra firma ni integridad; proteger directorios y comprobar actualizaciones. Evitar listas de nombres de proceso fáciles de cambiar |
| Extensiones de proxy/VPN | Lista de extensiones permitidas en navegadores administrados | Debe probarse por navegador; no resuelve páginas proxy |
| Adaptador o política alterados | Vigilar cambios y marcar protección degradada; reparación con diario | No afirmar reparación antes de leer y probar el resultado |
| Proxy web y DoH en HTTPS arbitrario | Listas de destinos conocidos como mitigación; modo de destinos permitidos para mayor restricción | Listas incompletas, CDN compartidas y falsos positivos. Acceso web universal y prohibición universal de túneles son objetivos incompatibles en este diseño |

## Políticas documentadas
Edge permite `DnsOverHttpsMode=off` y `ProxySettings={"ProxyMode":"direct"}`. La política de proxy prevalece sobre opciones de línea de comandos. Firefox permite `DNSOverHTTPS.Enabled=false`, `Locked=true` y `Proxy.Mode=none`, `Locked=true`. Son políticas del navegador, no controles sobre otras aplicaciones.

El script de laboratorio ya contiene políticas DoH para Edge, Chrome y Firefox, pero no se ha aplicado ni validado en este equipo. Las políticas de proxy anteriores son una propuesta, todavía no añadida al instalador. Para Comet hace falta comprobar la clave y políticas realmente admitidas por su edición Windows; compartir Chromium no demuestra compatibilidad con las claves de Chrome. Hasta comprobarlo, Comet no debe figurar como navegador endurecido.

Fuentes primarias: [Edge DoH](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/DnsOverHttpsMode), [Edge ProxySettings](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/ProxySettings), [Firefox DoH](https://firefox-admin-docs.mozilla.org/reference/policies/dnsoverhttps/), [Firefox Proxy](https://firefox-admin-docs.mozilla.org/reference/policies/proxy/).

## Diseño del componente Windows
WFP ALE permite autorizar conexiones según aplicación y usuario. Propuesta: un componente administrativo pequeño instala filtros identificados como propiedad de SENTINEL mediante transacciones; el resolvedor sigue como LocalService. Registrar antes el estado y retirar únicamente los filtros propios. No cambiar el firewall global ni añadir un bloqueo general antes de verificar las excepciones necesarias para Windows y la recuperación.

La interfaz debe mostrar por separado motor DNS, políticas efectivas, control de conexiones y cobertura del navegador. Ante una comprobación ausente o fallida, mostrar cobertura parcial. El estado verde actual sólo acredita DNS, tal como indica la interfaz.

Fundamento: [Microsoft WFP ALE](https://learn.microsoft.com/en-us/windows/win32/fwp/application-layer-enforcement--ale-). DoH transporta consultas en HTTPS: [RFC 8484](https://www.rfc-editor.org/info/rfc8484/). La conclusión sobre no distinguir cualquier túnel únicamente por puerto es una inferencia de diseño, no una garantía del proveedor. No se propone interceptar TLS ni instalar certificados de inspección.

## Criterios antes de activar el modo estricto
1. Ensayo reversible con diario y recuperación comprobados antes de modificar conexiones reales.
2. Navegador normal e incógnito: dominio seguro de categoría bloqueada, `x.com`, `blocked.test` y control permitido; repetir con conexiones anteriores y caché.
3. Intentos con DNS externo, DoH propio, proxy manual/PAC, extensión, VPN ya conectada y VPN iniciada después. Distinguir cada resultado, sin generalizar una prueba a todas las VPN.
4. IPv4/IPv6, nuevo adaptador, Wi-Fi/Ethernet, reinicio, suspensión, caída del motor y actualización de navegador.
5. Confirmar navegación legítima, actualizaciones y restauración exacta; documentar los casos no cubiertos.
6. La retirada normal de filtros y políticas debe pasar por la misma espera persistente de 24 horas; recuperación administrativa excepcional visible y documentada.

Prioridad: validar políticas efectivas en los navegadores instalados; después implementar WFP con pruebas aisladas; finalmente evaluar una lista de aplicaciones permitidas. Ninguna de esas fases se considera completada por esta investigación.
