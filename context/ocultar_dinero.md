Requisitos Funcionales
Ubicación del Botón:
El botón debe estar ubicado en un lugar visible y accesible en el dashboard, preferiblemente en la parte superior derecha.
Debe estar también accesible desde la barra lateral para permitir un acceso rápido.
Estado del Botón:
El botón debe tener dos estados: "Mostrar Dinero" y "Ocultar Dinero".
El estado inicial del botón será "Mostrar Dinero".
Funcionalidad del Botón:
Al hacer clic en "Ocultar Dinero", todos los valores monetarios en el dashboard y la barra lateral deben ser reemplazados por asteriscos o un texto genérico como "".
Al hacer clic en "Mostrar Dinero", los valores monetarios deben volver a ser visibles.
Persistencia del Estado:
El estado del botón debe persistir entre sesiones del usuario. Si un usuario oculta el dinero y cierra la sesión, al volver a iniciar sesión, el dinero debe seguir oculto.
Accesibilidad:
El botón debe ser accesible mediante teclado y cumplir con las pautas de accesibilidad web (WCAG).
Indicadores Visuales:
Debe haber un indicador visual claro del estado actual (por ejemplo, un cambio de color o icono en el botón).
Compatibilidad:
La funcionalidad debe ser compatible con todos los navegadores modernos y dispositivos móviles.
Consideraciones Técnicas
Frontend:
Utilizar TailwindCSS para el estilo del botón, asegurándose de seguir las guías de diseño del sistema.
Implementar la funcionalidad utilizando StimulusJS para manejar los eventos de clic y el cambio de estado.
Backend:
Almacenar el estado del botón en la base de datos del usuario para asegurar la persistencia entre sesiones.
Seguridad:
Asegurarse de que la funcionalidad no exponga datos sensibles a través de errores de implementación.
Pruebas
Pruebas Unitarias:
Verificar que el botón cambia de estado correctamente.
Verificar que los valores monetarios se ocultan y muestran según el estado del botón.
Pruebas de Integración:
Asegurar que la funcionalidad persiste entre sesiones.
Probar la funcionalidad en diferentes navegadores y dispositivos.