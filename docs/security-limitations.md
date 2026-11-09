> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Limitaciones y cobertura real

Un administrador puede retirar SENTINEL, alterar permisos y datos o arrancar en recuperación. No hay persistencia oculta, manipulación de Defender ni bloqueo de recuperación.

El prototipo no satisface todos los criterios de aceptación. No debe ser la única protección ni instalarse en el equipo habitual antes de las pruebas de VM.

- DNS clasifica dominios, no URLs, fotos o vídeos concretos. Las exclusiones locales no anulan bloqueos del proveedor.
- Las reglas se leen al iniciar; no existe actualización automática, firma de listas ni flujo UI para relajarlas. El administrador puede cambiarlas; falta aplicar el retraso a todos los cambios futuros de configuración.
- No hay WFP ni reglas de firewall. DNS alternativo, VPN, proxies, Tor y DoH arbitrario pueden eludirlo.
- Las políticas SafeSearch/YouTube sólo están preparadas para Edge/Chrome; Firefox sólo para DoH. No se ha probado su compatibilidad real ni precedencia con GPO/MDM.
- No se aplica a nuevos adaptadores automáticamente ni a interfaces VPN. El script inicial elige adaptadores físicos activos. Redes corporativas, nombres internos, portales cautivos y split DNS requieren diseño adicional.
- ACL limita acceso ordinario; no hay autenticación mutua criptográfica del pipe, firma de binarios, actualización segura ni secreto persistente.
- Contadores sólo de bloqueos locales y errores, reinician con el proceso. No cuentan categorías bloqueadas por Cloudflare ni equivalen a visitas.
- Última respuesta DNS es actividad observada, no prueba de eficacia de clasificación. No se ha implementado sondeo periódico de salud.
- El servicio local y el proveedor son puntos de fallo. DNS configurado a loopback falla si el servicio está caído; hay restauración explícita, no fallback sin filtrar.
- La espera no equivale todavía a 24 horas naturales. Se reinicia el origen monotónico al arrancar, conservando segundos restantes. Puede perderse progreso al fallar la persistencia o prolongarse con suspensión.
- Recuperación y restauración tienen código preparado, pero no se han probado en VM. El diario no sustituye una instantánea.
- Instalador gráfico de laboratorio sólo como fuente Inno; no es MSI de producción ni está firmado. Actualizaciones in-place aún no soportadas; el instalador de servicio rechaza instalaciones existentes.

No se almacenan dominios consultados, URLs, pantallas ni imágenes. Las reglas configuradas sí contienen dominios elegidos por el administrador y el proveedor externo recibe las consultas necesarias.
