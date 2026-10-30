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


## Fase 5: recibos y fianzas (31-10-2026)
- Recibos: serie por propietario y año en una tabla nueva (`Recibos`), no en `Pagos`, para no tocar el escritorio. El número se asigna al registrar el pago desde la API; un pago del escritorio lo recibe la primera vez que se pide su recibo (por eso la serie puede no seguir el orden de fechas en los pagos antiguos). La fila del propietario se bloquea durante la numeración y una clave única impide duplicados.
- Email del recibo: opcional, con spring-boot-starter-mail. Sin MAIL_HOST la API responde `enviado=false` y la app invita a compartir el PDF.
- Fianzas: "pendiente de devolver" es el importe entero mientras no se registra la devolución; lo que se retiene con motivo no cuenta como pendiente. El organismo de depósito es texto libre porque depende de la comunidad autónoma (no se fija ninguno ni sus plazos).
- Migraciones V3 y V4 aplicadas a gestion_alquileres_pro el 31-10-2026 con copia previa en ~/gestionap-backups/.
- Avisos de cobro: el día límite es el 7 porque la LAU (Ley 29/1994, art. 17.2, BOE-A-1994-26003) fija que, salvo pacto, la renta se paga en los siete primeros días del mes; se cambia con `gestionap.cobros.dia-limite`. Pasado el límite, «Cobro vencido» sustituye a «Pago pendiente» para no repetir el aviso. El email de recordatorio queda anotado como aviso del propietario, que sirve también para no repetirlo.

