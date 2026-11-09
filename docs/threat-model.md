> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Modelo de amenazas

Activo: reducir acceso voluntariamente a contenido adulto. Actor principal: propietario adulto con administrador, capaz de cambiar reloj, detener servicios, editar registro, recuperar offline o desinstalar. No puede garantizarse resistencia contra él. Actor secundario: proceso local sin privilegios; no debe obtener ejecución elevada mediante IPC ni editar estado protegido.

Límites de confianza: UI → pipe → servicio LocalService; servicio → archivos con ACL; DNS → proveedor HTTPS; scripts administrativos → registro y adaptadores. Instalador/código no firmados aún; verificar procedencia. Malware administrador, acceso físico y cambios offline quedan fuera.

| Escenario | Situación del prototipo | Mitigación prevista / límite |
|---|---|---|
| Cerrar UI | Mitigada por diseño SCM, pendiente integración | Servicio independiente |
| DNS ordinario en adaptador configurado | Parcial, no validado en VM | Loopback ambos protocolos |
| Cambiar DNS / resolvedor propio puerto 53 | No mitigada actualmente | WFP + reconciliación futura |
| IPv6 | Listener implementado, sin validación extremo a extremo | Configurar por familia sin deshabilitar IPv6 |
| DoH Edge/Chrome/Firefox | Parcial: scripts de políticas pendientes de validar | Directiva oficial; comprobar política efectiva |
| DoH arbitrario por 443 | No mitigable universalmente bajo este alcance | Allowlist de apps reduciría superficie, con coste de compatibilidad |
| DoT / DoQ | No mitigada actualmente | Bloquear TCP/UDP 853 en modo estricto futuro |
| VPN / proxy / Tor / túnel personalizado | No mitigada | Se pueden restringir apps conocidas, no todos los túneles HTTPS |
| Incógnito | DNS del sistema sigue aplicando si lo usa; no probado | Validar políticas en modo privado |
| Nuevo adaptador / Wi-Fi / hotspot | Parcial; sólo interfaces elegidas en instalación | Supervisor de cambios futuro |
| App externa / IP directa / caché DNS previa | Parcial/no mitigada | Filtrado DNS no cubre todas las rutas |
| Administrador detiene/modifica servicio o archivos | No mitigable de forma absoluta | ACL y recuperación visible; sin autorreinstalación |
| Cambio de hora | Mitigado en lógica de espera probada | Tiempo monotónico; no cuenta apagado |
| Corrupción estado | Detectada en tests; recuperación VM pendiente | No desbloquear en silencio |
| Imágenes adultas en sitio permitido | No mitigada | Bloqueo de plataforma o clasificador local futuro |

No existen controles declarados activos basados únicamente en presencia de archivos. La UI nunca presenta ACTIVA en esta versión.
