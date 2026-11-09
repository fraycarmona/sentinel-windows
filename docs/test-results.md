> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Resultados reales — 2026-11-09

Actualización posterior autorizada por el propietario: se ejecutó la demo en su PC y pasaron 12 combinaciones de DNS real, IPC y persistencia tras reiniciar el proceso. Ver [pruebas en el PC](host-testing.md). La prueba administrativa no se inició porque Windows notificó cancelación del aviso UAC.

Entorno anfitrión Windows x64, SDK .NET 10.0.403 descargado en work/dotnet. No se ha comprobado la versión del sistema como parte de la aceptación Windows 11. No se instaló el servicio ni se modificaron DNS, firewall, políticas o controles de seguridad del anfitrión.

## Ejecutado
- Compilación Release de Core, Service, UI y Tests: correcta, sin advertencias ni errores en la ejecución final registrada.
- 13 pruebas automatizadas del núcleo: superadas. Incluyen límites del contador, persistencia/cancelación, corrupción, versión de estado, reglas y exclusiones, IDN, parsing DNS, rechazo de compresión y fuzzing determinista de 10 000 entradas.
- Publicación autocontenida win-x64 de Service y UI: correcta; ejecutables disponibles en dist.
- Análisis sintáctico PowerShell de scripts: correcto. Esto no valida efectos ni compatibilidad en Windows PowerShell 5.1.

Registro: [build-results.txt](build-results.txt).

## Fallos encontrados durante desarrollo
La configuración NuGet del perfil no era accesible en el sandbox: se redirigieron directorios de desarrollo al workspace. Una referencia redundante de Pipes.AccessControl causó NU1510; se retiró. El test de persistencia inicialmente falló por permisos del directorio temporal; se repitió con TEMP/TMP dentro del workspace y pasó. No se omiten estos fallos ni se atribuyen a pruebas de integración.

## No ejecutado
Servicio bajo SCM, autoarranque/reinicio de Windows, políticas en navegadores, instalación/desinstalación/restauración, recuperación de emergencia, ACL frente a usuarios distintos, espera de 24 horas reales, cambios de reloj del sistema, suspensión, redes alternativas, VPN/Tor, benchmarks, inspección visual de WPF y compilación del proyecto Inno.

Estas pruebas requieren la VM Windows 11 con instantánea solicitada. No hay evidencia suficiente para marcar cumplidos los criterios de aceptación del producto. La entrega es código y binarios de un prototipo, no una protección validada para uso diario.
