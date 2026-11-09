> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Plan de validación

Ejecutado: pruebas unitarias del núcleo y compilación; ver test-results.md. No confundir tests puros del contador con 24 horas reales, suspensión real o reinicio de Windows.

## Automatización disponible
`scripts/build.ps1 -Publish` compila todos los proyectos, ejecuta Sentinel.Tests y publica UI/servicio. `scripts/dns-smoke.py` comprueba DNS UDP/TCP sobre ambos loopbacks en la demo; reservado para VM, no ejecutado aquí. Los scripts PowerShell se analizan sintácticamente sin ejecutarlos.

## Matriz VM obligatoria
| Área | Procedimiento | Criterio |
|---|---|---|
| Arranque | Instalar, reiniciar, no abrir UI | SCM running y DNS responde |
| DNS | UDP/TCP v4/v6; A/AAAA; truncamiento | Respuestas correctas, dominio local bloqueado |
| Proveedor | Dominio autorizado de test y controles legítimos | Categoría bloqueada sin interrumpir controles |
| Adaptadores | Ethernet/Wi-Fi; quitar y reconectar; nuevo adaptador | Registrar huecos actuales; no declarar cobertura automática |
| Fallos | Sin Internet, upstream inaccesible, detener servicio | SERVFAIL/plazos acotados y recuperación clara |
| Espera | Solicitar, cancelar, reiniciar, ±48 h reloj, suspensión | Sin adelanto por reloj; progreso persistente; documentar demora offline |
| Navegadores | Edge/Chrome/Firefox normal/privado | Políticas efectivas visibles, DoH y SafeSearch verificados por navegador |
| Evasión | DNS alternativo, 853, DoH propio, VPN/proxy controlados | Registrar bypass esperados; no falsear éxito |
| Restauración | DHCP/estático por familia, conflicto posterior, adaptador ausente | Conserva original y cambios ajenos; reintento seguro |
| Seguridad | Usuario distinto, pipe remoto, mensajes truncados, archivos inaccesibles | Sin cambios privilegiados ni desbloqueo inadvertido |
| Instalación | Fallo en cada etapa, disco lleno, puerto ocupado | Recuperación documentada; sin pérdida de configuración |
| Rendimiento | 10 min reposo + 1000 consultas y conexión lenta | Medir CPU, working set, latencia p50/p95, arranque y escritura; aún sin objetivos certificados |

La recuperación excepcional debe ejecutarse y verificarse tras cada escenario destructivo. Usar instantáneas separadas para productos competidores. No se habilitan en el anfitrión estos escenarios de integración.
