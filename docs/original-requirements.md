# PROYECTO: SENTINEL — Sistema de protección contra contenido adulto para Windows 11

## 1. ROL Y MISIÓN

Actúa como un equipo senior de ingeniería de software compuesto por:

- Arquitecto de software especializado en Windows 11.
- Ingeniero de ciberseguridad y redes.
- Especialista en Windows Filtering Platform (WFP).
- Ingeniero de servicios Windows y aplicaciones .NET.
- Experto en DNS, DoH, DoT, VPN y filtrado de contenido web.
- Especialista en ingeniería inversa legítima y análisis competitivo.
- Ingeniero de calidad, automatización de pruebas y seguridad defensiva.

**OBJETIVO PRINCIPAL:**

Diseñar, implementar, probar y empaquetar una aplicación nativa y ejecutable para Windows 11 denominada provisionalmente SENTINEL.

La aplicación debe bloquear el acceso a contenido pornográfico y explícitamente sexual desde el ordenador, empleando múltiples capas de protección independientes.

El programa está destinado al autocontrol voluntario de un usuario adulto que es propietario y administrador de su ordenador.

No quiero simplemente un bloqueador DNS. Quiero desarrollar un sistema profesional, robusto, transparente y resistente a los procedimientos habituales de evasión.

El sistema debe funcionar sin crear otra cuenta de Windows, sin requerir un servidor externo propio y con un procedimiento ordinario de desinstalación diferido 24 horas.

## 2. REQUISITOS NO NEGOCIABLES

1. Compatibilidad con Windows 11 x64.
2. Instalación sencilla mediante ejecutable o MSI.
3. Funcionamiento automático después de cada reinicio.
4. Protección operativa aunque la interfaz gráfica esté cerrada.
5. Filtrado de contenido adulto en todas las conexiones y navegadores compatibles.
6. Protección DNS para IPv4 e IPv6.
7. Detección y mitigación de métodos habituales para eludir el DNS filtrado.
8. Resistencia a cambios accidentales o deliberados de la configuración ordinaria.
9. Desinstalación normal con espera de 24 horas.
10. Persistencia del plazo durante reinicios y cierres de sesión.
11. Sin creación de usuarios adicionales de Windows.
12. Consumo mínimo de CPU, RAM y batería.
13. Protección de la privacidad del usuario.
14. Instalador y desinstalador seguros y documentados.
15. Código mantenible y pruebas automatizadas.
16. Recuperación administrativa de emergencia documentada.

La aplicación no debe introducir mecanismos ocultos de persistencia, elevación de privilegios no autorizada, manipulación de Microsoft Defender, bloqueo del sistema operativo ni técnicas destinadas a impedir la recuperación legítima del equipo.

**RESTRICCIÓN DE DISEÑO FUNDAMENTAL:**

Reconoce explícitamente que un usuario con permisos de administrador puede modificar o retirar software instalado. Diseña para aumentar la resistencia frente a métodos cotidianos de evasión, no para prometer invulnerabilidad frente al propietario administrador.

No simules funciones de seguridad que no puedas garantizar técnicamente.

## 3. INVESTIGACIÓN E INGENIERÍA INVERSA

Antes de seleccionar la arquitectura definitiva, investiga los siguientes productos y tecnologías:

- Cold Turkey Blocker.
- Pluckeye.
- Freedom.
- Canopy.
- NextDNS.
- CleanBrowsing.
- Cloudflare for Families.
- Otros proyectos de código abierto relevantes.

OBJETIVOS DE INVESTIGACIÓN:

A. Analizar sus funcionalidades, documentación técnica, modelos de filtrado, mecanismos de protección, persistencia, bloqueo y desinstalación.

B. Examinar su comportamiento observable mediante pruebas de caja negra legalmente permitidas, sin vulnerar licencias, DRM ni mecanismos de protección.

C. Revisar código fuente únicamente cuando esté disponible bajo una licencia que permita su estudio y reutilización.

D. Comparar arquitectura, eficacia, consumo de recursos, facilidad de evasión, privacidad y estabilidad.

E. Identificar funcionalidades que puedan desarrollarse de forma independiente y mejorarse.

F. Elaborar una matriz comparativa con ventajas, limitaciones y oportunidades de SENTINEL.

No copies código propietario ni dependas de técnicas de descompilación no autorizadas.

Si un producto no permite determinar su funcionamiento interno, identifica las hipótesis como tales.

Entrega el resultado en `docs/competitive-analysis.md`.

## 4. ARQUITECTURA PROPUESTA

Evalúa y selecciona la mejor arquitectura para Windows 11.

Considera especialmente:

- C# con .NET LTS para la lógica principal.
- Windows Service para la protección permanente.
- WPF o WinUI 3 para la interfaz.
- Windows Filtering Platform para filtrado de red.
- Windows Firewall cuando sea suficiente.
- SQLite para configuración y registros locales.
- Windows Installer/MSI o instalador equivalente.
- Extensiones de navegador cuando aporten capacidades adicionales justificadas.

Prioriza APIs oficiales de Microsoft.

Evita desarrollar drivers de kernel salvo que una necesidad técnica demostrada lo justifique. Si se necesitan, documenta requisitos de firma, compatibilidad, mantenimiento y riesgos.

La solución debe dividirse en módulos:

**A. SENTINEL CORE**

Servicio principal de Windows que administra el estado de protección y coordina los componentes.

**B. SENTINEL DNS**

Motor de filtrado DNS.

**C. SENTINEL NETWORK**

Controles de red y mitigación de mecanismos de evasión.

**D. SENTINEL BROWSER**

Protecciones específicas de los navegadores compatibles.

**E. SENTINEL GUARD**

Supervisión de integridad, disponibilidad y configuración del sistema.

**F. SENTINEL LOCK**

Gestión del bloqueo de configuración y del procedimiento de desinstalación diferida.

**G. SENTINEL UI**

Interfaz gráfica de administración, estado y diagnóstico.

Cada componente debe tener responsabilidades claras, pruebas propias y una interfaz bien definida.

## 5. FILTRADO DNS MULTICAPA

Implementa protección DNS usando inicialmente:

Cloudflare Families:

- DNS primario IPv4: 1.1.1.3
- DNS secundario IPv4: 1.0.0.3
- IPv6: utilizar las direcciones oficiales correspondientes.

Investiga también CleanBrowsing y NextDNS para evaluar si permiten una configuración más completa.

REQUISITOS:

1. Configurar los adaptadores de red pertinentes.
2. Gestionar Ethernet, Wi-Fi y nuevos adaptadores.
3. Controlar IPv4 e IPv6.
4. Detectar cambios de DNS.
5. Comprobar periódicamente que el filtrado funciona.
6. Disponer de listas de dominios bloqueados actualizables.
7. Permitir listas de exclusiones justificadas.
8. Mantener compatibilidad con redes legítimas.
9. Registrar incidencias sin almacenar el historial privado de navegación de forma innecesaria.

Evalúa la utilidad de un resolvedor DNS local administrado por el servicio, frente a utilizar directamente los proveedores externos.

Si el resolvedor local aporta mayor control, implementa una arquitectura que permita bloquear categorías adicionales y actualizar reglas.

Evita puntos únicos de fallo y documenta la política ante problemas de conectividad.

## 6. PROTECCIÓN FRENTE A EVASIONES

Analiza los siguientes escenarios:

- Cambiar manualmente los servidores DNS.
- Utilizar DNS público alternativo.
- Activar DNS-over-HTTPS.
- Utilizar DNS-over-TLS.
- Activar IPv6.
- Utilizar navegadores diferentes.
- Utilizar navegación privada o incógnito.
- Abrir enlaces mediante aplicaciones externas.
- Conectarse mediante otra red Wi-Fi.
- Utilizar un punto de acceso móvil.
- Utilizar aplicaciones con resolvedores DNS propios.
- Utilizar proxies, VPN y Tor.
- Acceder mediante direcciones IP cuando sea viable.
- Modificar archivos de configuración ordinarios.
- Cerrar la interfaz de la aplicación.

Diseña mitigaciones compatibles con Windows y documentadas.

Para el tráfico DNS considera WFP y reglas de firewall sobre conexiones DNS no autorizadas, evitando interrupciones innecesarias de servicios legítimos.

Para DNS cifrado, prioriza directivas oficiales de navegador y proveedores filtrados compatibles.

No presupongas que bloquear el puerto 53 impide todas las consultas DNS cifradas.

No implementes interceptación TLS mediante certificados raíz propios ni inspección indiscriminada del tráfico HTTPS.

Para VPN, proxies, Tor y técnicas de tunelización:

- Investiga qué puede detectarse o restringirse mediante interfaces oficiales.
- Presenta las limitaciones inevitables.
- Permite un modo de protección estricta cuando sea técnicamente viable.
- No bloquees funciones esenciales de Windows sin necesidad.

Crea una matriz técnica que distinga:

- Evasión mitigada.
- Evasión parcialmente mitigada.
- Evasión no mitigable bajo las restricciones del proyecto.

## 7. FILTRADO DEL CONTENIDO DENTRO DE PLATAFORMAS

El bloqueo DNS no puede identificar individualmente todas las fotografías o vídeos alojados en dominios permitidos.

Por ello, estudia una segunda capa específica para contenido dentro de sitios legítimos.

Implementa cuando sea viable:

- SafeSearch en buscadores compatibles.
- Restricted Mode de YouTube.
- Filtros por URL en navegadores.
- Reglas para páginas y subdominios.
- Bloqueo configurable de plataformas con elevado riesgo de contenido adulto.
- Integración con extensiones de navegador cuando aporte protección verificable.

Considera para una segunda fase un clasificador local de imágenes o texto con modelos ONNX u otros equivalentes.

Condiciones:

- Procesamiento local cuando sea posible.
- Sin subir imágenes personales a servidores externos.
- Medición de falsos positivos.
- Consumo de recursos razonable.
- Sin capturas indiscriminadas de pantalla.
- No prometer que la clasificación visual es infalible.

## 8. INICIO AUTOMÁTICO Y SUPERVISIÓN

La protección no debe depender de que el usuario abra manualmente la aplicación.

Implementa un servicio Windows configurado para inicio automático.

La interfaz gráfica puede abrirse al iniciar sesión, pero el motor de filtrado debe ejecutarse independientemente.

Requisitos de supervisión:

- Detectar errores de funcionamiento.
- Reiniciar componentes cuando proceda.
- Comprobar la integridad de la configuración.
- Emitir alertas cuando la protección no esté activa.
- Registrar errores técnicos.
- Evitar bucles de reinicio.
- Mantener la seguridad y estabilidad del sistema.

Utiliza los mecanismos de recuperación de servicios disponibles oficialmente en Windows.

Cualquier mecanismo de supervisión debe ser visible, documentado y desinstalable mediante los procedimientos autorizados.

## 9. SISTEMA DE DESINSTALACIÓN DIFERIDA DE 24 HORAS

Esta es una funcionalidad central.

**COMPORTAMIENTO DESEADO:**

Cuando el usuario solicite desinstalar SENTINEL mediante su interfaz normal:

1. Registrar la solicitud.
2. Mantener activa la protección.
3. Iniciar una cuenta atrás de 24 horas.
4. Mostrar la fecha y hora previstas de desbloqueo.
5. Impedir que el flujo ordinario de la aplicación complete la desinstalación antes de finalizar el plazo.
6. Mantener el estado después de reiniciar Windows.
7. Permitir cancelar la solicitud si el usuario lo desea.
8. Al finalizar las 24 horas, habilitar la desinstalación ordinaria.
9. Restaurar de forma segura los cambios de DNS, firewall y políticas realizados por SENTINEL.

El retraso debe aplicarse igualmente a la desactivación normal del filtrado o al cambio hacia un modo sustancialmente menos restrictivo.

REQUISITOS TÉCNICOS:

- Almacenamiento persistente del estado.
- Integridad de los datos.
- Protección razonable contra manipulación accidental.
- Tratamiento de cambios del reloj del sistema.
- Gestión de suspensiones y reinicios.
- Pruebas de persistencia.
- Recuperación ante corrupción de datos.

Estudia si una referencia horaria externa mejora la detección de manipulación del reloj y define el comportamiento sin conexión.

Evita configuraciones que puedan impedir indefinidamente la recuperación del programa.

**IMPORTANTE:**

La espera de 24 horas se implementará como política de autocontrol voluntario dentro de la aplicación, no mediante técnicas de secuestro del sistema.

Debe existir una recuperación administrativa excepcional, claramente documentada y verificable, que permita restaurar el funcionamiento seguro del ordenador ante fallos graves.

No ocultes el servicio, el instalador ni el procedimiento de recuperación.

## 10. RESISTENCIA A LA MANIPULACIÓN

Implementa protección de configuración y controles de integridad compatibles con el modelo de seguridad de Windows.

Evalúa:

- Permisos adecuados sobre archivos y configuración.
- Separación entre servicio privilegiado e interfaz sin privilegios.
- Comunicación local autenticada entre componentes.
- Comprobaciones de integridad.
- Protección de secretos mediante mecanismos oficiales de Windows.
- Detección de alteraciones de parámetros.
- Registro de errores y cambios relevantes.
- Recuperación ante fallos.

No desarrolles escaladas de privilegios, componentes encubiertos, autorreinstalación oculta ni mecanismos que interfieran con herramientas de recuperación del sistema.

El servicio debe utilizar únicamente los privilegios estrictamente necesarios.

Documenta qué acciones siguen siendo posibles para un administrador del equipo.

## 11. INTERFAZ GRÁFICA

Diseña una interfaz moderna, sencilla y en español.

Pantalla principal:

- Estado de protección: ACTIVA / DEGRADADA / INACTIVA.
- Estado del servicio.
- Estado del filtrado DNS.
- Estado de los navegadores compatibles.
- Última comprobación de seguridad.
- Número agregado de intentos bloqueados.
- Diagnóstico de conectividad.

Pantalla de configuración:

- Intensidad de protección.
- Categorías bloqueadas.
- Proveedores DNS.
- Lista de dominios permitidos.
- Configuración de navegadores.
- Actualizaciones.

Pantalla de desinstalación:

- Solicitar desinstalación.
- Mostrar cuenta atrás de 24 horas.
- Cancelar solicitud.
- Finalizar desinstalación cuando corresponda.

Pantalla de diagnóstico:

- Estado de componentes.
- Pruebas DNS.
- Comprobaciones IPv4/IPv6.
- Incidencias.
- Exportación de registros técnicos.
- Información sobre limitaciones de seguridad.

La interfaz no debe mostrar detalles innecesarios de la actividad personal del usuario.

## 12. INSTALACIÓN EN WINDOWS 11

El resultado debe ser distribuible y ejecutable.

Requisitos:

- Instalador gráfico.
- Solicitud explícita de permisos de administrador únicamente cuando sea necesario.
- Instalación del servicio Windows.
- Configuración inicial guiada.
- Inicio automático de la protección.
- Comprobación posterior a la instalación.
- Integración con Aplicaciones instaladas de Windows.
- Desinstalador estándar sujeto al flujo de desinstalación diferida, sin ocultar ni impedir la recuperación administrativa.
- Restauración de configuración anterior al desinstalar.
- Soporte para actualizaciones.

No crear usuarios adicionales.

No modificar Microsoft Defender, UAC, BitLocker ni las funciones de recuperación de Windows.

No instalar cambios de red en el ordenador real durante el desarrollo sin confirmación explícita.

## 13. PERMISOS Y AUTONOMÍA DE CODEX

Dispones de autorización para desarrollar el código dentro del proyecto.

Puedes:

- Crear y modificar archivos del repositorio.
- Consultar documentación técnica.
- Instalar dependencias de desarrollo confiables en el entorno autorizado.
- Ejecutar compilaciones.
- Crear pruebas.
- Ejecutar analizadores estáticos.
- Preparar el instalador.
- Investigar proyectos abiertos.
- Refactorizar cuando sea necesario.
- Elaborar documentación técnica.

Para operaciones que alteren la configuración de seguridad del sistema anfitrión, instalen servicios reales, modifiquen su firewall o requieran permisos de administrador, solicita autorización explícita antes de ejecutarlas.

Realiza las primeras pruebas de integración en una máquina virtual Windows 11 con posibilidad de restauración.

No solicites privilegios adicionales si no son necesarios.

## 14. PRUEBAS OBLIGATORIAS

Crea una batería automatizada de pruebas.

PRUEBAS FUNCIONALES:

- Inicio después de reinicio.
- Protección sin interfaz gráfica.
- Filtro DNS IPv4.
- Filtro DNS IPv6.
- Cambio de adaptador.
- Desconexión y reconexión.
- Suspensión y reanudación.
- Reinicio del servicio.
- Funcionamiento en Edge, Chrome y Firefox.
- Compatibilidad con SafeSearch.
- Actualización de listas.
- Restauración de configuración.

PRUEBAS DE RESISTENCIA:

- Cambio ordinario de DNS.
- Intentos de usar otros resolvedores.
- DNS-over-HTTPS en navegadores compatibles.
- DNS-over-TLS.
- Uso de modo incógnito.
- Nuevos adaptadores.
- Redes alternativas.
- Uso de VPN y proxies en escenarios controlados.
- Cambios de hora.
- Reinicios durante la cuenta atrás.
- Solicitud de desinstalación y cancelación.

PRUEBAS DE SEGURIDAD:

- Privilegios mínimos.
- Protección de archivos de configuración.
- Comunicación entre servicios.
- Inyección de entradas inválidas.
- Persistencia de datos.
- Recuperación tras fallos.
- Ausencia de almacenamiento innecesario de datos personales.

PRUEBAS DE RENDIMIENTO:

- CPU en reposo.
- RAM en reposo.
- Impacto en navegación.
- Tiempo de arranque.
- Comportamiento con conexión deficiente.

Utiliza dominios de prueba autorizados y casos reproducibles.

No afirmes que una prueba ha sido superada si no se ha ejecutado.

## 15. ENTREGABLES

Crea en el repositorio:

- Código fuente completo.
- Archivo `AGENTS.md` con instrucciones permanentes y concisas para Codex.
- `README.md`.
- `docs/architecture.md`.
- `docs/competitive-analysis.md`.
- `docs/threat-model.md`.
- `docs/security-limitations.md`.
- `docs/testing.md`.
- `docs/installation.md`.
- `docs/recovery.md`.
- Scripts de compilación y pruebas.
- Proyecto de instalador.
- Aplicación ejecutable cuando el entorno permita compilarla.
- Informe de resultados reales de las pruebas.

Todo el proyecto debe quedar preparado para futuras ampliaciones.

## 16. PLAN DE EJECUCIÓN

Organiza el trabajo por fases.

**FASE 1 — Investigación y arquitectura**

Investiga las alternativas existentes, APIs oficiales y limitaciones.

Elabora la matriz de amenazas y define la arquitectura.

**FASE 2 — Prototipo funcional**

Implementa el servicio Windows, el filtrado DNS inicial, la interfaz básica y el autoinicio.

**FASE 3 — Protección multicapa**

Integra controles de red, políticas de navegador, comprobaciones de integridad y protección frente a los métodos ordinarios de evasión identificados.

**FASE 4 — Desinstalación diferida**

Implementa la cuenta atrás, persistencia, recuperación y pruebas de cambio de hora y reinicio.

**FASE 5 — Validación**

Ejecuta pruebas unitarias, integración, seguridad, compatibilidad y rendimiento.

**FASE 6 — Producto distribuible**

Genera instalador, documentación, mecanismo de actualización y paquete listo para instalación.

## 17. CRITERIOS DE ACEPTACIÓN

El proyecto solo podrá considerarse funcional cuando:

1. La aplicación compile y se ejecute en Windows 11.
2. El servicio funcione sin abrir la interfaz.
3. El filtrado DNS opere con IPv4 e IPv6 en los escenarios comprobados.
4. Los controles sobre navegadores soportados sean verificables.
5. El reinicio no desactive la protección.
6. La solicitud ordinaria de desinstalación mantenga el plazo de 24 horas.
7. La cuenta atrás sobreviva a un reinicio.
8. El instalador y desinstalador funcionen correctamente.
9. Las medidas de seguridad no dañen la conectividad ni la estabilidad del sistema.
10. Existe un procedimiento administrativo de recuperación seguro y probado.
11. Todas las limitaciones relevantes estén documentadas.
12. No existan funcionalidades declaradas como completas que sean únicamente simulaciones.

## 18. INSTRUCCIÓN FINAL PARA CODEX

No te limites a entregar una explicación teórica o un plan genérico.

Quiero que actúes como ingeniero responsable del producto y avances en la implementación real.

Empieza inspeccionando el entorno de desarrollo y las herramientas disponibles.

Investiga las tecnologías y productos indicados.

Selecciona la arquitectura técnicamente más adecuada y explica brevemente las decisiones críticas.

Después crea el repositorio y desarrolla la primera versión funcional.

Compila, prueba, corrige y documenta.

Trabaja iterativamente, priorizando una base estable sobre funcionalidades numerosas pero incompletas.

Si encuentras una limitación técnica, indícala claramente, propone alternativas y continúa con la mejor solución viable.

No prometas seguridad absoluta.

Prioriza la robustez, la privacidad, la estabilidad de Windows 11 y la verificabilidad del resultado.

**COMIENZA AHORA POR LA INVESTIGACIÓN TÉCNICA, EL DISEÑO DE ARQUITECTURA Y LA IMPLEMENTACIÓN DEL PRIMER PROTOTIPO.**