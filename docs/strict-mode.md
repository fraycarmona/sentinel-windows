# Modo estricto experimental — implementación 0.3

Esta entrega añade código ejecutable de configuración y restauración. No activa controles nuevos en el PC ni actualiza automáticamente el servicio instalado. No equivale a una protección completa como la anunciada por BlockerX.

## Implementado

| Capa | Código y alcance | Validación |
|---|---|---|
| Navegación privada | Políticas de Edge, Chrome y Firefox; invitado deshabilitado en Edge/Chrome | Plan y restauración probados con backend simulado; falta comprobar cada navegador |
| DNS propio y proxy | DoH desactivado y proxy directo obligatorio en esos tres navegadores | Lectura de valores tras escribir; política efectiva y tráfico aún pendientes |
| Navegadores incompatibles y emuladores | Reglas de firewall de salida por rutas exactas proporcionadas al comando | Motor simulado probado; no se ha bloqueado ningún programa del PC |
| Retirada normal | Desinstalación y restauración directa de DNS, políticas o modo estricto exigen Ready del servicio | Respuesta falsa, ausente o de tipo incorrecto rechazada; timeout de lectura de 3 s |
| Recuperación | Diario persistido antes de cada cambio, rollback, reintento y rechazo de conflictos | Pruebas de fallos antes/después de escritura, conflicto ajeno y recuperación interrumpida |
| Interfaz | Separa presencia del diario de efectividad; reconoce motores anteriores | Compilación; no convierte presencia de configuración en protección verificada |

El bloqueo por ejecutable restringe red, NO ejecución. Una copia en otra ruta, un proceso auxiliar, un proxy local o una red virtual pueden quedar fuera. Los emuladores que delegan tráfico a servicios o drivers necesitan identificar esos componentes y ensayarlos. No hay catálogo automático de todos los navegadores o emuladores. No se ha acreditado Comet: no se escribe una supuesta clave de Chrome para Comet.

No se modifica la acción predeterminada del firewall. Si está desactivado o una política empresarial rechaza reglas locales, el comando se detiene. Las reglas se crean en PersistentStore y se comprueba que aparecen en ActiveStore; esto no sustituye una prueba de conexiones. El control requiere Windows Firewall operativo y puede no cubrir tráfico delegado a otro proceso.

## Uso de laboratorio

Desde la raíz del paquete, obtener un plan sin modificar el equipo:

```powershell
./scripts/strict-lab.ps1 -Mode Plan
```

Para añadir un programa, proporcionar su ruta real con `-BlockedPrograms @('C:\ruta\navegador.exe','C:\ruta\emulador.exe')`. Las rutas deben existir, ser locales y no contener comodines. No usar rutas de componentes de Windows. El plan permite revisar exactamente qué se configurará.

Aplicación administrativa explícita: el mismo comando con `-Mode Apply -AcceptLabChanges`. Exige servicio Sentinel en ejecución y no sobrescribe políticas existentes, aunque tengan el mismo valor. No admite mezclar el diario antiguo de browser-lab con el nuevo. Rechaza una lista InPrivate de excepciones de Edge preexistente. Las claves vacías creadas pueden permanecer tras restaurar; sólo se retiran los valores propios.

`-Mode Status` consulta la configuración como administrador. Después deben comprobarse `edge://policy`, `chrome://policy` y `about:policies`, reiniciar los navegadores y ejecutar pruebas de tráfico. No registrar URLs privadas ni historial.

`-Mode Restore -AcceptLabChanges` exige la espera completada. La desinstalación normal restaura también esta capa antes de retirar el servicio. `-Mode Restore -Emergency -AcceptLabChanges` es una recuperación administrativa excepcional, no una operación normal ni protección contra el administrador.

La operación está serializada mediante un archivo abierto con acceso exclusivo dentro de ProgramData/Sentinel. El diario distingue cambios previstos, en curso, aplicados y restaurados; un cambio sólo previsto no se elimina al recuperar. Los conflictos conservan el diario para revisión, sin sobrescribir la configuración ajena. La recuperación no puede garantizarse frente a corrupción arbitraria o modificación administrativa concurrente.

## Filtrado VPN: siguiente componente, todavía NO implementado

Una interfaz TUN por sí sola no bloquea contenido: también hace falta procesar paquetes, decidir conexiones y asegurar las rutas. Tampoco revela el contenido cifrado dentro de otra VPN. No se presenta el actual DoH ascendente como una VPN.

Diseño propuesto:

1. Elegir y revisar licencia, mantenimiento y firma de un controlador TUN existente; evitar un controlador de kernel propio en esta fase. El instalador administrativo establece el adaptador; el servicio se inicia después sin UAC interactivo.
2. Separar el motor de decisiones del transporte. El motor DNS actual sigue resolviendo y bloqueando dominios; el transporte captura IPv4/IPv6 y requiere un reenviador TCP/UDP probado. No enviar todos los paquetes a un adaptador sin tener ese reenviador operativo.
3. Mantener una ruta de salida explícita para el transporte, evitando recapturar su propio tráfico; contemplar DHCP, redes locales, cambio Wi-Fi/Ethernet, portales cautivos y recuperación de conectividad.
4. Complementar con controles WFP por aplicación y restricciones de DoH/proxy. No confiar en puertos conocidos para detectar cualquier VPN sobre HTTPS. Evitar bloquear globalmente 443.
5. Definir qué sucede al fallar el transporte. Un modo que corte Internet debe declararlo claramente y disponer de recuperación administrativa local independiente de Internet. Nunca activar ese comportamiento por sorpresa.
6. Probar en entorno recuperable DNS, TCP/UDP, IPv4/IPv6, VPN concurrente, reinicio, suspensión, fallo del servicio, rutas y retirada. Sólo entonces integrar la activación en la interfaz.

Para impedir ejecutar navegadores/emuladores no aprobados, la fase posterior debe evaluar AppLocker/App Control en modo auditoría antes de aplicar restricciones. Una regla de firewall por ruta no se vende como una lista universal de aplicaciones permitidas. Mantener actualizaciones y herramientas de recuperación accesibles.

## Fuentes primarias

- [Edge: InPrivate](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/InPrivateModeAvailability), [invitado](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/BrowserGuestModeEnabled), [proxy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/ProxySettings).
- [Catálogo Chrome Enterprise](https://chromeenterprise.google/policies/).
- [Firefox: navegación privada](https://firefox-admin-docs.mozilla.org/reference/policies/disableprivatebrowsing/), [DoH](https://firefox-admin-docs.mozilla.org/reference/policies/dnsoverhttps/), [proxy](https://firefox-admin-docs.mozilla.org/reference/policies/proxy/).
- [Windows: New-NetFirewallRule](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule), [combinación de políticas](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/rules), [AppLocker](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/working-with-applocker-rules).

El diseño VPN es una propuesta de ingeniería, no una afirmación sobre los componentes internos de BlockerX.
