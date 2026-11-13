# Validación 0.3 experimental

Fecha: 2026-11-09.

- Core, Service, UI y Tests: compilación Release con cero advertencias y errores; Service y UI publicados autocontenidos x64.
- 17 pruebas del núcleo superadas, incluyendo 20 000 entradas aleatorias de analizadores DNS.
- 16 pruebas del modo estricto en Windows PowerShell 5.1 superadas. Registro y firewall simulados: aplicación, retirada, política previa, fallo antes y después de escribir, conflicto, reintento, diario alterado, lectura incorrecta, regla por ejecutable, conservación de entradas nunca aplicadas y validación de espera.
- Regresión de restauración DNS con ambas familias superada usando cmdlets simulados.
- Análisis de sintaxis PowerShell sin errores.

Durante el desarrollo, el sandbox impidió File.Replace sobre archivos temporales; las pruebas de diario se ejecutaron fuera del sandbox, sin elevar a administrador ni modificar registro/firewall. Se corrigió además el formato nulo de la API .NET en PowerShell 5.1 y la serialización del diario manipulado por las pruebas.

No se instaló este nuevo servicio encima del activo ni se aplicaron las políticas o reglas nuevas al PC. No se ensayó bloqueo real de incógnito, emuladores, otra VPN o Comet con esta versión. Las pruebas DNS reales de la versión anterior permanecen documentadas en [0.2](release-0.2.md), sin atribuirlas a las nuevas capas.

El ejecutable y paquete de entrega son 0.3. La instalación que ya existía en el PC no se actualiza por abrir el nuevo panel. Si informa que el motor no proporciona el estado de controles adicionales, se trata de compatibilidad con el servicio anterior, no de una confirmación de protección.

Cambios, comandos y limitaciones: [modo estricto](strict-mode.md). El filtrado VPN y el bloqueo de ejecución universal siguen pendientes.
