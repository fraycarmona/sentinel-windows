> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Recuperación administrativa excepcional

Procedimiento visible y deliberadamente accesible al propietario. **Preparado, no probado en VM aún.** Se evita depender del servicio o de un estado de espera válido. No requiere otra cuenta ni tocar Defender/UAC/BitLocker.

1. En PowerShell administrador, desde `C:\Program Files\Sentinel\scripts`, ejecutar `./remove-lab.ps1 -Emergency -AcceptLabChanges`.
2. Primero restaura DNS y políticas registradas. Después detiene y elimina el servicio. Si falla restaurar, conserva servicio/diario para diagnosticar; no se retiran archivos automáticamente.
3. Verificar resolución legítima, reinicio, políticas y ausencia del servicio. Sólo entonces borrar los directorios exactos de SENTINEL si se desea.

Si el script no funciona, consultar `C:\ProgramData\Sentinel\network-backup.json`. Restaurar cada interfaz por GUID y familia con Set-DnsClientServerAddress: usar ResetServerAddresses cuando Static esté vacío (DHCP); en otro caso usar las direcciones estáticas originales. No usar reset universal si antes existía DNS corporativo estático. No sobrescribir cambios posteriores sin revisar. [API Microsoft](https://learn.microsoft.com/en-us/powershell/module/dnsclient/set-dnsclientserveraddress).

El diario browser-backup.json contiene sólo valores que estaban ausentes antes del piloto; retirar esos valores si aún coinciden con lo escrito. No borrar ramas completas del registro. Después `Stop-Service Sentinel` y `sc.exe delete Sentinel`. Los ficheros se conservan para diagnóstico.

Si faltan los diarios, recuperar desde snapshot o datos de red originales. No adivinar configuración corporativa. El restablecimiento manual de DNS desde Configuración de Windows es una salida legítima, no una función que SENTINEL intente impedir.

Datos lock.json corruptos no autorizan retirada normal: usar recuperación excepcional. El estado no se resetea de forma automática ni se generan cuentas ocultas. En caso de instalación parcial, el instalador no sobrescribe archivos existentes; revisar y restaurar antes de reintentar.
