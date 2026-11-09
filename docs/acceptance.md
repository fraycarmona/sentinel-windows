> Estado actualizado de implementación y pruebas: [versión 0.2](release-0.2.md). Este documento conserva contexto de la iteración inicial.

# Estado de aceptación 0.1

| Criterio original | Estado y evidencia |
|---|---|
| 1. Compila y ejecuta en Windows 11 | Compila x64; prueba de arranque en VM pendiente |
| 2. Servicio sin interfaz | Código SCM independiente; ejecución real pendiente |
| 3. DNS IPv4/IPv6 comprobado | Listeners implementados; prueba de red pendiente |
| 4. Navegadores verificables | Scripts de políticas; verificación en navegador pendiente |
| 5. Reinicio no desactiva | Servicio auto configurado por script; pendiente probar |
| 6. Retirada de 24 h | Lógica probada; tiempo de servicio acumulado, no 24 h naturales |
| 7. Cuenta atrás sobrevive reinicio | Serialización/recarga probada; reinicio Windows pendiente |
| 8. Instalador/desinstalador | Scripts y proyecto Inno; integración producción pendiente |
| 9. Conectividad/estabilidad | No validado; fallo de servicio puede cortar DNS |
| 10. Recuperación segura probada | Documentada e implementada en scripts; pendiente VM |
| 11. Limitaciones documentadas | Sí, docs/security-limitations.md y threat-model.md |
| 12. No simulaciones declaradas completas | UI siempre degradada; funciones futuras identificadas |

## Próxima iteración
1. Ejecutar y corregir instalación, sockets, políticas, restauración y recuperación en VM con instantánea.
2. Extraer monitor de adaptadores y comprobaciones de salud reales; reconciliar sin sobreescribir configuración ajena.
3. Implementar controles WFP probados con transacciones, identidad de filtros propia y retirada fiable.
4. Completar reloj entre reinicios y todos los flujos de relajación; integrar bloqueo normal en instalador de producción.
5. Medir consumo y compatibilidad; firmar binarios/instalador; diseñar actualizaciones con rollback.
