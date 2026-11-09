# Estado verificado de la versión 0.2

Fecha: 2026-11-09. Este informe actualiza los documentos de diseño y resultados de 0.1; no los convierte en garantías de cobertura completa.

## Interfaz y ejecutable
WPF en español. Ejecutable autocontenido x64 de aproximadamente 65 MB. Se abrió en el PC y se comprobó por accesibilidad que muestra PROTECCIÓN INACTIVA, motor detenido/no accesible, DNS sin verificar y Twitter/X no activo al no existir un servicio instalado. Se actualiza cada cinco segundos. El verde verifica adaptadores y pruebas DNS del proveedor; no equivale a inspeccionar el tráfico del navegador.

Las comprobaciones periódicas de la interfaz consultan exclusivamente dominios de diagnóstico (dominio oficial del proveedor y un dominio de control); no acceden al historial privado. La ausencia de interfaz no detiene el servicio. La activación usa PowerShell de Windows y UAC; sólo se habilita con el paquete completo presente.

## Pruebas ejecutadas
| Prueba | Resultado |
|---|---|
| Core/Service/UI/Tests en Release | Compilan sin advertencias ni errores en la última ejecución |
| Pruebas unitarias del núcleo | 17 superadas, con 20 000 entradas de fuzzing en total |
| DNS demo UDP/TCP e IPv4/IPv6 | 12 combinaciones superadas con dominio local, dominio permitido y dominio oficial filtrado |
| Servicio real LocalService | Arranque y comunicación IPC correctos |
| Espera | Solicitud, cancelación y persistencia tras reiniciar servicio correctas; no prueba de 24 h reales |
| Adaptador del PC autorizado | Resolución usando SENTINEL y restauración exacta del listado DNS original verificadas |
| Retirada de prueba | Servicio eliminado y directorios temporales de instalación retirados |
| Restauración aislada en PowerShell 5.1 | Regresión del JSON, ambas familias y marcado de diario comprobados con cmdlets simulados |
| Comet normal, x.com | DNS_PROBE_FINISHED_NXDOMAIN durante el filtro temporal |
| Comet, página de prueba previamente abierta | Siguió visible/accesible: posible caché o conexión previa; no se afirma bloqueo inmediato |
| Comet incógnito nuevo, nudity.testcategory.com | ERR_ADDRESS_INVALID durante el filtro temporal |
| Comet incógnito, control legítimo | Página permitida cargó |
| UI sin servicio | Muestra inactivo correctamente |

Referencia del dominio seguro de pruebas: [Cloudflare Families](https://developers.cloudflare.com/1.1.1.1/setup/#test-1111-for-families). No se abrió contenido adulto real para estas comprobaciones.

## Incidente y corrección
El primer lanzamiento administrativo mediante el PowerShell empaquetado de Codex no elevó; Windows notificó cancelación aunque el propietario indicó que no vio aviso. El PowerShell de Windows sí permitió elevación. No se atribuye el fallo al usuario.

La primera restauración real falló porque en Windows PowerShell 5.1 un array devuelto por ConvertFrom-Json quedó anidado por @(...). La comprobación `$row.Done` veía un array no vacío y omitía filas. El test detectó DNS loopback residual. Se restauró inmediatamente el DNS automático original y se comprobó resolución legítima.

Se quitó el envoltorio del array, se añadió una prueba de regresión en PowerShell 5.1 y una lectura posterior de DNS para abortar si sigue en loopback. Las siguientes dos pruebas administrativas terminaron con Success=true, Cleanup=true y comparación exacta del DNS original. Un proceso de vigilancia independiente acompaña el ensayo administrativo; la activación normal dispone de rollback en su flujo, no de ese watchdog de prueba.

La revisión automática rechazó inicialmente repetir cambios de red mientras la corrección no estaba validada. Tras aportar la prueba aislada y la verificación adicional de restauración, permitió las nuevas pruebas. No queda ese bloqueo pendiente.

El reset de DNS puede afectar ambas familias del adaptador. Para acotar riesgo, la activación 0.2 rechaza configuraciones estáticas o mixtas; su soporte requiere pruebas adicionales. No reutilizar el empaquetado inicial 0.1 para instalaciones.

## Estado final del equipo
Las pruebas administrativas fueron temporales y restauraron DNS y retiraron el servicio. En una comprobación posterior al preparar la entrega se observó una instalación activa: servicio Sentinel Running/Automatic y DNS IPv4/IPv6 loopback. Se conservó esa instalación, sin volver a modificar la red. Resolve-DnsName permitió example.com, devolvió NXDOMAIN para x.com y 0.0.0.0 para nudity.testcategory.com. No se atribuye esta activación a las pruebas temporales ni se presupone que el binario instalado sea la última compilación de la carpeta de entrega.

El acceso directo de escritorio apunta al ejecutable actualizado con icono de escudo. No se modificaron firewall, Defender ni políticas de navegador durante esta investigación. No se reinició Windows. El análisis y el plan contra VPN/DoH/proxy están en [anti-evasion-research.md](anti-evasion-research.md); todavía no se han implementado esas capas.

## Pendientes
Arranque tras reinicio real, suspensión real, corrupción bajo SCM, recuperación frente a cortes de energía, pruebas de usuarios diferentes, browser DoH/DoT/VPN y túneles, benchmarks, listas firmadas, instalación estándar y retiro diferido desde Aplicaciones instaladas. La espera cuenta servicio activo, no tiempo natural desconectado. La seguridad total del producto no está validada.
