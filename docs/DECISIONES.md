# Decisiones

- **Identidad visual**: azul marino y azul eléctrico sustituyen al morado. Acento #1F5FE0 (claro) / #5C97FF (oscuro); botones rellenos siempre #1F5FE0 para que el texto blanco cumpla 4,5:1.
- **Apariencia**: por defecto sigue al iPhone; ajuste en Perfil (Automático, Oscuro, Claro).
- **Comparaciones justas**: la tendencia de Inicio compara con el mes anterior hasta el mismo día; la variación anual, con el año pasado hasta la misma fecha.
- **Actividad**: Inicio y "Ver todo" omiten los inicios de sesión; el historial del perfil los incluye.
- **Zona horaria**: la API usa la del servidor, igual que el escritorio (no se cambia pantalla a pantalla).
- **Navegación**: siempre por valor (`navigationDestination(for:)`); mezclarla con enlaces de vista rompía la navegación.
