# Instalar SENTINEL en Windows 11

1. Descarga `Sentinel-Setup.exe` desde [GitHub Releases](https://github.com/fraycarmona/sentinel-windows/releases).
2. Ejecuta el archivo desde la cuenta administradora que utilizará el panel y acepta el aviso de UAC. Se admiten Windows 11 x64 y ARM64. El paquete incorpora .NET y WPF. El filtrado requiere conexión con Cloudflare Families.
3. Al finalizar, abre SENTINEL y comprueba que muestre **FILTRADO DNS ACTIVO**. Reinicia los navegadores para que lean sus políticas.

El instalador configura el servicio LocalService para arrancar con Windows, una tarea SYSTEM de recuperación y un acceso directo de inicio para el panel. Todos los cambios de DNS, hosts, políticas y reglas de firewall se registran antes de aplicarse. La red debe tener un adaptador físico activo con DNS automático. El instalador conserva las configuraciones previas si detecta un conflicto. El ejecutable carece de firma Authenticode.

Si falla la activación, se intenta restaurar la configuración anterior. Consulta `%ProgramData%\Sentinel\setup-error.txt` y la [recuperación administrativa](recovery.md). Después de una restauración correcta puedes retirar el paquete desde la carpeta de instalación con `unins000.exe`. Para instalaciones ya presentes o recuperaciones pendientes, el instalador conserva los archivos y el contador existentes.

## Retirada ordinaria

1. En el panel selecciona **Solicitar retirada (24 h)**. La opción **Desinstalar** en Aplicaciones instaladas abre el panel y registra la misma solicitud.
2. Tras 24 horas acumuladas de servicio activo, selecciona **Finalizar retirada** y acepta UAC.
3. El desinstalador consulta al servicio autenticado, restaura los cambios registrados y retira el servicio, la tarea, el acceso de inicio y el paquete. Si la restauración requiere intervención, conserva el material de recuperación.

## Compilar y publicar

En Windows x64, instala el SDK .NET 10 e Inno Setup 7.1.1. Ejecuta desde la raíz del repositorio:

```powershell
.\scripts\build.ps1 -Publish -InstallerPayload
ISCC.exe .\installer\Sentinel.iss
```

El resultado queda en `dist\Installer\Sentinel-Setup.exe`. GitHub Actions crea ese artefacto al compilar. Si se envía una etiqueta `vMAJOR.MINOR.PATCH`, el flujo publica el ejecutable en GitHub Releases una vez aprobadas las pruebas.

## Verificar en una VM

Ejecuta `installer\test-setup.ps1 -Setup <ruta-al-exe>` desde PowerShell de Windows como administrador, en una VM Windows 11 sin SENTINEL y con instantánea. El script prueba la activación, el sondeo IPv4/IPv6, el arranque configurado, el rechazo de la retirada anticipada y la restauración. Utiliza la recuperación administrativa para limpiar la VM al terminar.

Para verificar el arranque real, instala sobre una instantánea limpia, registra `(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')`, reinicia y ejecuta `scripts\verify-startup.ps1 -PreviousBootUtc <valor>` desde la carpeta instalada. Comprueba también que el panel aparezca al iniciar sesión. La prueba automática de CI comprueba el registro de arranque y el trabajo del guardián durante la sesión actual. La prueba de retirada anticipada conserva la espera original de 24 horas.
