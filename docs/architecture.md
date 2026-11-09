> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Arquitectura y decisiones

Fecha de investigación: 9 de noviembre de 2026. Diseño inicial, no certificación.

.NET 10 LTS permite una base mantenida para Windows 11; WPF reduce dependencias de despliegue. SCM mantiene el servicio independiente de la interfaz. LocalService es suficiente para sockets y escritura en el directorio concedido: no se ejecuta el resolvedor como administrador. Las modificaciones de adaptadores se hacen explícitamente durante instalación de laboratorio elevada. [Ciclo de soporte](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core).

## Flujo implementado
Cliente DNS → loopback UDP/TCP 53 → parser limitado a una pregunta IN → reglas locales → HTTPS con validación normal de certificado → Cloudflare Families. La demo usa 1053. Límites: 4096 bytes por consulta, 65535 por respuesta, 64 operaciones simultáneas y plazos acotados. Respuestas UDP mayores de 512 bytes anuncian truncamiento para repetir por TCP. Una conexión TCP procesa una consulta; no soporta pipelining. No se implementa caché ni DNSSEC propio.

Bootstrap HTTPS a IPs oficiales 1.1.1.3, 1.0.0.3, 2606:4700:4700::1113 y ::1003, conservando SNI family.cloudflare-dns.com y validación de certificado. Esto evita resolver el upstream a través del mismo proxy. No hay proxy HTTP del sistema en esta conexión. Probar alcance HTTPS de cada IP en VM antes de aceptar; la configuración oficial de Families se documenta en [Cloudflare](https://developers.cloudflare.com/1.1.1.1/setup/).

Sólo hay un proveedor lógico y un proceso local: siguen siendo puntos únicos de fallo. Si el upstream falla se devuelve SERVFAIL; no se deriva a DNS sin filtrar. SCM permite dos reinicios espaciados y luego deja de reiniciar. Si el servicio cae con DNS loopback aplicado, la resolución se interrumpe hasta recuperarlo o restaurar. No se promete ausencia de cortes.

## Módulos y contratos
| Módulo | Implementación actual | Próximo paso |
|---|---|---|
| CORE | Engine coordina tareas y falla si un listener termina | Extraer servicios y health checks por componente |
| DNS | DnsWire, DomainRules, proxy UDP/TCP + DoH | Caché acotada, pruebas de interoperabilidad y failover real |
| NETWORK | Scripts de DNS con diario por GUID/familia | Monitor de adaptadores, WFP, verificación de ruta |
| BROWSER | Script de políticas con rechazo de conflictos | Diagnóstico real Edge/Chrome/Firefox y reglas URL |
| GUARD | SCM recovery; estado degradado; contadores en memoria | Integridad, alarmas y reconciliación controlada |
| LOCK | LockState y LockStore; ACL del directorio | Reloj confiable y cuenta atrás natural entre reinicios |
| UI | WPF, estado, solicitud/cancelación | Configuración completa y exportación de diagnósticos |

Los módulos lógicos NETWORK/BROWSER/GUARD aún no son servicios completos. No se presentan como implementaciones terminadas.

## Datos y comunicación
ProgramData\Sentinel contiene estado JSON y reglas; ACL para SYSTEM/Administradores y modificación para LocalService. JSON pequeño con escritura temporal, flush y sustitución: SQLite se pospone por no existir historial ni transacciones de varias tablas. Sin firma/HMAC contra administradores: pueden editar los datos y restaurar versiones. La ACL limita a usuarios ordinarios. Un estado ausente/corrupto deshabilita la retirada normal y exige recuperación; no se reinicia automáticamente la espera.

Named pipe local con ACL para SID del instalador, Administradores y SYSTEM; denegación a Network. Comandos de un byte: 0 estado, 1 solicitud, 2 cancelación. No ejecuta rutas/comandos suministrados por cliente. Conexiones de control secuenciales con plazo de 3 s. Falta auditar resistencia a suplantación del servidor y denegación de servicio local. No hay comando IPC que cambie configuración de seguridad.

## Red de siguiente fase
WFP en modo usuario puede aplicar filtros en ALE sin driver propio para reglas por aplicación/dirección/puerto. No basta para entender contenido HTTPS ni VPN arbitraria. Windows Firewall simplifica mantenimiento, pero una regla global de bloqueo prevalece sobre permisos conflictivos: no crear “bloquear todo 53 + permitir proveedor” sin evaluar arbitraje. Diseñar rangos complementarios o filtros WFP explícitos y probar rollback antes de adoptar. [WFP](https://learn.microsoft.com/en-us/windows/win32/fwp/windows-filtering-platform-start-page), [arbitraje](https://learn.microsoft.com/en-us/windows/win32/fwp/filter-arbitration).

Sin driver de kernel, sin raíz TLS propia, sin inspección de imágenes ni capturas. ONNX y extensiones quedan para fase 2 de producto, con corpus consentido, falsos positivos y consumo medidos.

## Espera
Estado solicitado UTC informativo + segundos restantes. Stopwatch aporta tiempo dentro de proceso; se acredita un máximo de 2 s por tick para no otorgar tiempo dormido. Persistencia conserva lo acreditado; fallos pueden prolongar la espera, nunca deben adelantarla. Actualmente se escribe cada segundo: optimizar a checkpoints y transiciones antes de despliegue para reducir E/S. Adelantar/atrasar UTC no altera el contador. No se utiliza una referencia externa: HTTPS Date no garantiza por sí mismo un reloj seguro ni disponibilidad. La salida de emergencia evita depender indefinidamente del contador.
