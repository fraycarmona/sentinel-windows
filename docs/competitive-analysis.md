> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Análisis competitivo documental

Consultado 2026-11-09. Sólo fuentes públicas oficiales. **No se han instalado ni medido estos productos**, realizado ingeniería inversa de binarios ni inspeccionado tráfico. No hay cifras comparativas de CPU/RAM/eficacia; cualquier evaluación siguiente deriva del alcance documentado, no de un benchmark. No se reutilizó código de terceros.

| Producto | Funciones documentadas | Límites / incógnitas | Oportunidad para SENTINEL |
|---|---|---|---|
| [Cold Turkey](https://getcoldturkey.com/features/) | Bloqueo de sitios/aplicaciones, horarios y bloqueos que restringen desactivación/extensión y desinstalación | Arquitectura interna y resistencia efectiva no verificadas; orientado también a distracciones | Flujo de autocontrol visible y recuperación documentada |
| [Plucky/Pluckeye](https://docs.pluckeye.net/delay) | Retrasos en cambios de configuración; [desinstalación](https://docs.pluckeye.net/how-to-uninstall) ligada a reducir el retraso | No se auditó internamente ni midieron compatibilidad/rendimiento | Modelo de relajación diferida aplicado de manera uniforme |
| [Freedom](https://freedom.to/freedom-for-windows) | App Windows en segundo plano y Locked Mode para sesiones | La página no permite concluir un mecanismo exacto de red o retirada | Servicio independiente de GUI y diagnóstico por capas |
| [Canopy](https://support.canopy.us/portal/en/kb/articles/what-is-canopy-and-how-does-it-work) | Publicita filtrado inteligente de contenido explícito | No se verifica ubicación de inferencia, falsos positivos, consumo ni implementación interna | Evaluar un clasificador local verificable en fase futura |
| [NextDNS](https://nextdns.io/) | Categorías, reglas, SafeSearch, YouTube Restricted Mode y configuración de registros | Servicio externo; revisar cuotas, privacidad y comportamiento del plan antes de integrar | Mejor personalización que un DNS familiar fijo; backend opcional futuro |
| [CleanBrowsing](https://cleanbrowsing.org/filters) | Filtros Family/Adult/Security y endpoints cifrados | Clasificación a nivel DNS; no identifica cada imagen en sitio permitido | Alternativa para SafeSearch y política familiar más amplia |
| [Cloudflare Families](https://developers.cloudflare.com/1.1.1.1/setup/) | DNS malware/adultos con IPv4/IPv6 y DNS cifrado | Sin listas particulares en el servicio gratuito fijo; fallos de clasificación posibles | Upstream inicial sencillo, complementado por reglas locales |
| [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) | Resolvedor local de red con listas; proyecto abierto GPL-3.0 | Revisada descripción/licencia, no auditoría del código; no es por sí solo un bloqueo antiadministrador | Referencia de diseño para caché/listas, sin incorporar código |

## Privacidad, estabilidad y coste operativo
Un proveedor DNS recibe los nombres resueltos aunque no guarde SENTINEL un historial. HTTPS protege el transporte, no oculta las consultas al resolvedor. La comparación de retención requiere revisar condiciones concretas y configuración del proveedor. No se infiere privacidad equivalente entre productos.

El proxy local da control de reglas, pero introduce un punto de fallo y trabajo de protocolo. Usar directamente DNS familiar reduce complejidad, pero no permite listas propias ni contadores. Elegimos proxy para el prototipo, manteniendo explícita la deuda de disponibilidad.

## Plan de caja negra pendiente
En snapshots Windows 11 separados y con licencias válidas: instalar cada producto, registrar procesos/servicios visibles y políticas, medir 10 min en reposo y navegación autorizada, reiniciar, probar DNS/DoH/IPv6 e incógnito, solicitar retirada, restaurar snapshot. No evadir DRM ni descompilar. Publicar versiones, equipo, tiempos y resultados antes de emitir comparativas cuantitativas.
