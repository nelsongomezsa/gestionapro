# Decisiones

- **Identidad visual**: azul marino y azul eléctrico sustituyen al morado. Acento #1F5FE0 (claro) / #5C97FF (oscuro); botones rellenos siempre #1F5FE0 para que el texto blanco cumpla 4,5:1.
- **Apariencia**: por defecto sigue al iPhone; ajuste en Perfil (Automático, Oscuro, Claro).
- **Comparaciones justas**: la tendencia de Inicio compara con el mes anterior hasta el mismo día; la variación anual, con el año pasado hasta la misma fecha.
- **Actividad**: Inicio y "Ver todo" omiten los inicios de sesión; el historial del perfil los incluye.
- **Zona horaria**: la API usa la del servidor, igual que el escritorio (no se cambia pantalla a pantalla).
- **Navegación**: siempre por valor (`navigationDestination(for:)`); mezclarla con enlaces de vista rompía la navegación.

## Capturas y vídeo (31-10-2026)
- Capturas a mitad de resolución y comprimidas con pngquant (calidad 70-95): 47 MB → 12 MB sin diferencia visible.
- Vídeo del recorrido con `xcrun simctl io recordVideo` y ffmpeg (540 px, H.264, 30 fps): 1,3 MB para 69 s.
- Cobrado del año en Estadísticas: solo hasta hoy, para no mezclar pagos con fecha futura en la comparación.

