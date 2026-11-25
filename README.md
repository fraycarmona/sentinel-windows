# SENTINEL 0.5 — filtro DNS para Windows

Servicio LocalService y panel WPF de autocontrol. [Cambios, fuentes y límites de 0.5](docs/release-0.5.md). La aplicación exige **24 horas acumuladas de servicio activo** antes de la retirada normal. Apagar o suspender prolonga esa espera. No ofrece resistencia absoluta contra el administrador de Windows.

## Ejecutable y arranque

Ejecuta `Sentinel-Setup.exe` con una cuenta administradora de Windows 11 x64 o ARM64. El archivo incluye el servicio, el panel y sus runtimes. El instalador activa el filtrado, configura el servicio para iniciar con Windows y registra el guardián y el panel.

Cerrar el panel no detiene el servicio. La parada ordinaria se rechaza antes de completar la espera. El guardián intenta reiniciar el motor, concilia adaptadores físicos DHCP y comprueba el filtrado. La configuración de arranque se distingue de una prueba real de reinicio de Windows.

## Protección y estado

- **FILTRADO DNS ACTIVO**: motor y pruebas IPv4/IPv6 correctos; los adaptadores comprobados usan loopback.
- **PROTECCIÓN DEGRADADA / INACTIVA**: la cobertura local no está verificada. No asumir que abrir el panel activa el filtro.
- El panel comprueba 18 valores de políticas y el registro de arranque. Eso no demuestra que cada navegador haya cargado las políticas.

Cloudflare Families por HTTPS, reglas locales de Twitter/X y el dominio adulto indicado por el propietario, SafeSearch de Google .com/.es y Bing, YouTube restringido, hosts residual, políticas Edge/Chrome/Firefox, bloqueo de endpoints DNS conocidos y puerto 853.

No hay bloqueo universal de DoH/VPN/proxy, navegadores portables, Comet o emuladores, ni análisis de imágenes dentro de plataformas permitidas. Hosts sólo cubre nombres exactos y www. El respaldo filtrado de categoría mantiene conectividad si pasa las pruebas, pero no reescribe SafeSearch como el motor local.

## Instalación

El instalador admite instalaciones nuevas. Si detecta una instalación o restauración pendiente, conserva su estado y detiene la instalación. Consulta los [requisitos y el proceso de compilación](docs/installation.md).

Se admiten adaptadores físicos activos con DNS automático. Configuraciones estáticas, personalizadas o en conflicto se rechazan sin sobrescribirlas. Reiniciar navegadores después de aplicar políticas; páginas almacenadas y conexiones abiertas pueden continuar.

## Retirada y recuperación

Solicita la retirada en el panel o desde **Configuración > Aplicaciones > Aplicaciones instaladas**. Tras 24 horas acumuladas, usa **Finalizar retirada** en el panel. Todos los flujos normales de restauración de DNS, hosts y políticas consultan el servicio autenticado. No se confía en el reloj civil para adelantar la espera.

La [recuperación administrativa excepcional](docs/recovery.md) permanece documentada para no bloquear permanentemente el PC. Tener administración total permite eludir controles locales: no se promete que esperar sea la única salida posible para un administrador.

## Compilar y verificar

GitHub Actions compila y prueba el instalador. Una etiqueta `vMAJOR.MINOR.PATCH` publica el mismo archivo en GitHub Releases si pasan las comprobaciones. Las pruebas de integración de laboratorio usan exclusivamente el puerto 1053 y un directorio nuevo; el servicio instalado usa 53.

Ver [informe 0.5](docs/release-0.5.md) para pruebas ejecutadas y pendientes. El [informe de auditoría](docs/audit-2026-11-13.md) describe la base 0.4, no el estado posterior a esta actualización.
