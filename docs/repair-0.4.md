# Reparación de activación y caída DNS — 2026-11-13

Se reprodujo con el ejecutable instalado una caída SocketException 10054 en UdpClient.ReceiveAsync después de enviar respuestas a clientes UDP ya cerrados. Windows entrega ICMP de puerto inaccesible en una recepción posterior. La excepción escapaba del bucle y detenía el motor. El servicio instalado era de la compilación del 9 de noviembre.

El resolvedor ahora continúa recibiendo ante ConnectionReset. No oculta otros errores fatales; el servicio conserva la excepción en ProgramData/Sentinel/service-error.txt, sin registrar consultas. La regresión permanente está en scripts/test-udp-resilience.ps1.

Otro fallo comprobado: activate.ps1 salía con código 2 ante cualquier servicio existente, incluso detenido. Ahora repara o reinicia esa instalación, preservando reglas y espera; conserva copia de los binarios anteriores y restaura DNS antes de reemplazar el motor. La interfaz instalada también busca el script en su directorio padre.

Se añadió la tarea visible SentinelDnsRecovery bajo SYSTEM, independiente del servicio, con inicio al arrancar Windows. Consulta únicamente example.com cada 10 s después de un margen inicial de 30 s. Dos fallos consecutivos del motor/proveedor provocan la restauración del DNS guardado; no reactiva el filtro automáticamente. El usuario pierde el bloqueo DNS durante esa recuperación y la interfaz debe mostrar cobertura degradada. El registro último queda en guardian-status.txt. La retirada normal elimina también la tarea propia.

## Pruebas ejecutadas

- Compilación Release de cuatro proyectos, 17 pruebas del núcleo y publicación x64 correctas.
- Reproductor antiguo: 300 clientes UDP desconectados provocan caída 10054. Corregido: el proceso continúa y responde DNS después.
- Demo: 12 combinaciones UDP/TCP, IPv4/IPv6, dominio bloqueado/permitido/categoría; solicitud, cancelación y persistencia de espera correctas.
- Reparación administrativa del servicio instalado: correcta; tarea de recuperación ejecutándose.
- Prueba real autorizada: activar DNS temporal, detener servicio e invocar recuperación independiente. DNS anterior restaurado exactamente.
- Servicio instalado corregido: resiste 300 clientes DNS desconectados en puerto 53.
- Reactivación real: dominio oficial nudity.testcategory.com devuelve 0.0.0.0; x.com devuelve NXDOMAIN. Google y example.com responden HTTPS 200.
- Tras esperar otros 25 s: servicio ejecutándose y DNS del adaptador aún configurado en loopback. Se deja ese filtro activo por petición del propietario.

No se han acreditado en esta reparación VPN, DNS cifrado propio de navegadores ni proxies. Tampoco se ha ensayado reiniciar Windows o un fallo simultáneo del servicio y la tarea. La tarea puede tardar varias decenas de segundos en recuperar y no garantiza disponibilidad absoluta. No presentar estas pruebas DNS como cobertura de todo navegador.
