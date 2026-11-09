> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Instalación y desarrollo

## Estado
Paquete de laboratorio autocontenido Windows x64, sin firma. **Primera integración exclusivamente en VM Windows 11 con instantánea.** Los scripts modificadores no se ejecutaron en el anfitrión. El SDK se descargó localmente; no hay instalación global de herramientas.

## Compilación
Desde la raíz: `powershell -File scripts/build.ps1 -Publish` con SDK .NET 10. Los tests fallan el proceso si falla cualquier aserción. NuGet.Config fija origen oficial. Revise docs/build-results.txt.

## Piloto VM
1. Crear instantánea y registrar DNS DHCP/estático de IPv4/IPv6, rutas y políticas antes de empezar.
2. Copiar el repositorio con dist a la VM. Probar `scripts/demo.ps1` y `dist/UI/SENTINEL.exe --demo` sin elevación; ejecutar `python scripts/dns-smoke.py`.
3. Con autorización del propietario, PowerShell administrador: `scripts/install-lab.ps1 -AcceptLabChanges`. Copia a Program Files, prepara ACL ProgramData y servicio LocalService automático. No cambia la red todavía.
4. Ejecutar `scripts/network-lab.ps1 -Apply -AcceptLabChanges`. Guarda DHCP/estático por GUID/familia antes de cambiar DNS a loopback. No lo ejecutar si hay otros servicios escuchando en 53. Comprobar que el proceso tiene los cuatro listeners antes de aplicar.
5. Opcional: `scripts/browser-lab.ps1 -Apply -AcceptLabChanges`. Rechaza valores previamente existentes en lugar de sobreescribir políticas organizativas. Reiniciar navegadores y revisar edge://policy, chrome://policy, about:policies.
6. Abrir `C:\Program Files\Sentinel\UI\SENTINEL.exe`. El usuario de control es el SID del administrador instalador; no soporta aún instalación con credenciales de un usuario diferente al destinatario.
7. Validar navegación legítima y dominio autorizado de prueba del proveedor. Solicitar retirada en UI; tras esperar, `scripts/remove-lab.ps1 -AcceptLabChanges`. Recuperación excepcional: `-Emergency`.

Si falla aplicación de red, conservar diario y ejecutar Restore. La restauración no sobrescribe DNS que otro actor haya cambiado después. Adaptadores ausentes mantienen la recuperación pendiente; reconectarlos. La retirada restaura antes de parar el servicio.

## Instalador gráfico
`ISCC installer/Sentinel.iss` con Inno Setup instalado por separado produce un EXE de laboratorio. No compilado aquí. Instala el paquete en LocalAppData y aparece en Aplicaciones instaladas; no configura protección ni instala el servicio automáticamente. Su desinstalador sólo elimina ese paquete. La futura distribución de producción debe integrar servicio, configuración guiada, rollback y el mismo flujo de 24 h para UI y Aplicaciones instaladas; es un requisito pendiente, no resuelto con este empaquetador.

## Actualizaciones
No hay canal automático ni actualización sobre una instalación existente. Antes de implementar: firma Authenticode, manifiesto/versiones firmadas, verificación antes de ejecutar, backup de esquema y rollback de servicio. No retirar e instalar para eludir una espera pendiente. Para iteración de laboratorio usar instantáneas.
