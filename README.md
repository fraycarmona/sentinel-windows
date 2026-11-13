# SENTINEL 0.5 — filtro DNS para Windows

Servicio LocalService y panel WPF de autocontrol. [Cambios, fuentes y límites de 0.5](docs/release-0.5.md). La aplicación exige **24 horas acumuladas de servicio activo** antes de la retirada normal. Apagar o suspender prolonga esa espera. No ofrece resistencia absoluta contra el administrador de Windows.

## Ejecutable y arranque

Abrir `SENTINEL.exe` conservando las carpetas del paquete. El servicio se configura Automatic, el guardián como tarea SYSTEM al arrancar y la ventana para la sesión del usuario. El arranque normal no pide UAC; instalación, actualización y retirada sí.

Cerrar el panel no detiene el servicio. La parada ordinaria se rechaza antes de completar la espera. El guardián intenta reiniciar el motor, concilia adaptadores físicos DHCP y comprueba el filtrado. La configuración de arranque se distingue de una prueba real de reinicio de Windows.

## Protección y estado

- **FILTRADO DNS ACTIVO**: motor y pruebas IPv4/IPv6 correctos; los adaptadores comprobados usan loopback.
- **PROTECCIÓN DEGRADADA / INACTIVA**: la cobertura local no está verificada. No asumir que abrir el panel activa el filtro.
- El panel comprueba 18 valores de políticas y el registro de arranque. Eso no demuestra que cada navegador haya cargado las políticas.

Cloudflare Families por HTTPS, reglas locales de Twitter/X y el dominio adulto indicado por el propietario, SafeSearch de Google .com/.es y Bing, YouTube restringido, hosts residual, políticas Edge/Chrome/Firefox, bloqueo de endpoints DNS conocidos y puerto 853.

No hay bloqueo universal de DoH/VPN/proxy, navegadores portables, Comet o emuladores, ni análisis de imágenes dentro de plataformas permitidas. Hosts sólo cubre nombres exactos y www. El respaldo filtrado de categoría mantiene conectividad si pasa las pruebas, pero no reescribe SafeSearch como el motor local.

## Instalar o actualizar

Usar el botón de activación del paquete. Actualizaciones conservan reglas y espera. Para una comprobación administrativa detallada: `scripts/upgrade-verify.ps1 -Evidence <carpeta-local>`.

Se admiten adaptadores físicos activos con DNS automático. Configuraciones estáticas, personalizadas o en conflicto se rechazan sin sobrescribirlas. Reiniciar navegadores después de aplicar políticas; páginas almacenadas y conexiones abiertas pueden continuar.

## Retirada y recuperación

Solicitar retirada en la interfaz; tras 24 horas acumuladas, usar **Finalizar retirada**. Todos los flujos normales de restauración de DNS, hosts y políticas consultan el servicio autenticado. No se confía en el reloj civil para adelantar la espera.

La [recuperación administrativa excepcional](docs/recovery.md) permanece documentada para no bloquear permanentemente el PC. Tener administración total permite eludir controles locales: no se promete que esperar sea la única salida posible para un administrador.

## Compilar y verificar

SDK .NET 10 x64 y PowerShell. `scripts/build.ps1 -Publish`, después `scripts/publish-ui.ps1`. Las pruebas de integración de laboratorio usan exclusivamente el puerto 1053 y un directorio nuevo; el servicio instalado usa 53.

Ver [informe 0.5](docs/release-0.5.md) para pruebas ejecutadas y pendientes. El [informe de auditoría](docs/audit-2026-11-13.md) describe la base 0.4, no el estado posterior a esta actualización.
