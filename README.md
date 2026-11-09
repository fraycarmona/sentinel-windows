# SENTINEL 0.2 — prototipo para Windows

Servicio DNS local y panel WPF para autocontrol voluntario. No ofrece protección absoluta ni resistencia frente al administrador del equipo.

## Ejecutable
En el paquete distribuible, abrir **SENTINEL.exe** desde la raíz, conservando `dist`, `scripts` y `config` junto al ejecutable. Es autocontenido x64 y no requiere instalar .NET.

- **PROTECCIÓN INACTIVA**: no se puede consultar el servicio; abrir la ventana no activa ningún bloqueo.
- **PROTECCIÓN DEGRADADA**: el motor está ejecutándose, pero no se verifica el DNS del equipo.
- **FILTRADO DNS ACTIVO**: los adaptadores activos Ethernet/Wi-Fi usan loopback y las consultas de comprobación IPv4/IPv6 pasan. No verifica las rutas privadas de cada aplicación, VPN ni DNS cifrado propio del navegador.

El botón **Instalar y activar DNS** solicita elevación UAC, instala el servicio LocalService y cambia temporalmente durante la instalación los DNS a loopback. Si termina correctamente, el servicio queda instalado y activo hasta retirarlo; cerrar la ventana no lo detiene. Esta versión sólo admite adaptadores físicos activos con DNS automático en ambas familias. Rechaza DNS estático antes de modificarlo.

Reiniciar el navegador después de activar: páginas en caché o conexiones ya abiertas pueden seguir accesibles. Las pruebas realizadas no garantizan cobertura de todas las páginas ni métodos de evasión.

## Bloqueo incluido
Cloudflare Families por HTTPS para categorías del proveedor. Reglas locales para `x.com`, `twitter.com`, `twimg.com` y `t.co`, incluidos subdominios. Las reglas se cargan al arrancar el servicio; no se registra historial de consultas. `blocked.test` se reserva para tests locales.

## Pruebas reales
17 tests de núcleo superados, incluyendo dos lotes de 10 000 entradas aleatorias. Demo UDP/TCP × IPv4/IPv6 comprobada. En el PC autorizado: servicio LocalService, persistencia tras reinicio del servicio, cambio DNS, restauración exacta y retirada verificados. En Comet: Twitter bloqueado; dominio oficial de filtro adulto bloqueado en una ventana nueva de incógnito; sitio permitido accesible. Una página abierta antes del cambio siguió accesible en la ventana normal.

Se encontró y corrigió un fallo de restauración de arrays JSON en Windows PowerShell 5.1. No se oculta el incidente: [informe actualizado](docs/release-0.2.md).

## Compilar
SDK .NET 10 x64 + PowerShell: `./scripts/build.ps1 -Publish`.
Para generar el ejecutable único de la interfaz: `./scripts/publish-ui.ps1`.
Para probar sin cambiar DNS: `./scripts/demo.ps1`, seguido de `./dist/UI/SENTINEL.exe --demo`.

## Retirada y recuperación
Solicitar retirada en la interfaz. Tras **24 horas acumuladas de servicio activo**, usar Finalizar retirada o ejecutar `scripts/remove-lab.ps1 -AcceptLabChanges` como administrador. No son todavía 24 horas naturales: apagado y suspensión prolongan la espera.

El instalador registra el servicio con inicio automático, el panel al iniciar sesión y una entrada en Aplicaciones instaladas que abre la solicitud de retirada. El arranque normal no solicita UAC; la instalación y retirada sí. El reinicio completo y el flujo de Aplicaciones instaladas siguen pendientes de prueba.

Recuperación excepcional: `scripts/remove-lab.ps1 -Emergency -AcceptLabChanges` como administrador. Restaura antes de detener el resolvedor y conserva datos para diagnóstico. Véase [recuperación](docs/recovery.md).

## Pendiente antes de producto final
La [investigación de evasión por DNS cifrado, VPN y proxy](docs/anti-evasion-research.md) define las medidas y pruebas para un modo estricto. Es diseño pendiente, no una protección ya aplicada.

WFP/firewall, reconciliación de nuevos adaptadores, políticas verificadas en todos los navegadores, bloqueo universal de DoH/VPN, instalador de producción firmado con retirada integrada, actualización segura y pruebas de reinicio completo de Windows. El proyecto Inno es un empaquetador de laboratorio, no ese instalador de producción.

Código: `src/Sentinel.Core`, `src/Sentinel.Service`, `src/Sentinel.UI`, `src/Sentinel.Tests`. Documentación histórica de diseño en `docs`; el estado vigente está en `docs/release-0.2.md`.
