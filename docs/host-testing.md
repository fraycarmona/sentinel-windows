> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Pruebas autorizadas en el PC del propietario

El propietario sustituyó el requisito inicial de VM por la instrucción «prueba en mi pc». La prueba local inicia sólo la demo en loopback:1053 y la detiene al finalizar; la prueba administrativa instala temporalmente el servicio y restaura la configuración de DNS antes de retirarlo. No se reinicia Windows ni se alteran firewall, Defender o políticas de navegador.

## Demo: ejecutado y superado
- Arranque y comunicación por named pipe.
- Doce combinaciones DNS: UDP/TCP × IPv4/IPv6 × dominio local bloqueado/resolución real de example.com/dominio oficial nudity.testcategory.com mediante Cloudflare Families.
- El dominio oficial del filtro devuelve exclusivamente 0.0.0.0 en las cuatro combinaciones. example.com devuelve direcciones válidas no nulas. Se consultó sólo DNS, sin abrir páginas de contenido adulto. Referencia: [pruebas oficiales de Cloudflare](https://developers.cloudflare.com/1.1.1.1/setup/#test-1111-for-families).
- Solicitud de retirada y avance del contador sin desbloqueo anticipado.
- Persistencia tras terminar y volver a iniciar el proceso.
- Cancelación de solicitud.
- Muestra puntual de la última ejecución: 33 853 440 bytes de working set y 0,203125 segundos de CPU del proceso reiniciado. No es una medición de reposo ni un benchmark.

Registro: [host-test-results.txt](host-test-results.txt). La primera tentativa dentro del sandbox no pudo acceder al named pipe; la repetición fuera del aislamiento pasó. Se cerró el proceso de prueba al terminar.

## Herramientas reproducibles
`scripts/test-local.ps1 -Data <directorio_nuevo>` ejecuta estas comprobaciones y limpia el proceso en finally. Necesita PowerShell 7 y Python.

`scripts/test-host-admin.ps1 -Evidence <directorio>` requiere elevación UAC y una instalación inexistente. Guarda las direcciones DNS originales, verifica el resolvedor antes de aplicar cambios, programa un proceso independiente de restauración a los 45 segundos y restaura en finally. Conserva evidencias fuera de la instalación. No utilizarlo sobre una instalación existente ni mientras otro proceso use el puerto 53.

## Prueba administrativa: no iniciada
Se intentó iniciar la prueba mediante UAC. Windows devolvió «El usuario ha cancelado la operación». No se instaló el servicio, no se crearon los directorios de instalación y no se cambiaron los DNS del adaptador. No se volvió a solicitar elevación.

Las pruebas de instalación/retirada, reinicio completo, suspensión, 24 horas reales, eficacia sobre un corpus de contenido, políticas en navegador, anti-evasión y rendimiento siguen pendientes. El dominio de prueba del proveedor sólo acredita esa comprobación concreta.
