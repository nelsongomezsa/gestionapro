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
- Actualización de renta (orientativa, el propietario confirma):
  - Índice recomendado por fecha: desde el 26-05-2023 (entrada en vigor de la Ley 12/2023), el IRAV, «Índice de Referencia de Arrendamientos de Vivienda» que publica el INE en cumplimiento de la disposición adicional undécima de la LAU (añadida por la Ley 12/2023); antes, el IPC, que es lo habitual en esas cláusulas. Si el contrato no prevé actualización, no se actualiza (LAU, art. 18). No se aplican los topes extraordinarios de 2023 (2 %) y 2024 (3 %), que solo afectaban a esas anualidades.
  - Datos en directo de la API oficial del INE (servicios.ine.es/wstempus): IRAV = serie IRAV1; IPC general, variación anual = IPC290750 (base 2025, desde enero de 2026) e IPC251856 (base 2021, hasta diciembre de 2025). Comprobado el 31-10-2026: IRAV de septiembre de 2026 = 2,54 % (igual que la web del INE), IPC de septiembre de 2026 = 4,9 %. Se guardan 12 horas en memoria; sin conexión, el propietario escribe el porcentaje y queda anotado como «introducido por el propietario».
  - Mes del dato: el último publicado en la fecha de la actualización (LAU, art. 18). El INE publica cada mes hacia mediados del siguiente, así que se usa el del mes anterior desde el día 15 y, antes, el de dos meses atrás.
  - El certificado de servicios.ine.es lo emite la FNMT, que no está en los certificados de Java: se incluye su raíz pública (SHA-256 EB:C5:57:0C:…:9B:93:FA, comprobada contra la de macOS) solo para ese cliente.
  - Tope: el art. 18.1 de la LAU, en la redacción del Real Decreto-ley 29/2026, de 6 de octubre (BOE-A-2026-20823), dice que «en todo caso» el incremento no puede superar el IRAV. Ese RDL extiende el límite a los contratos anteriores a la Ley 12/2023, pero lo liga a sus prórrogas y deja dudas; además, a 31-10-2026 hay que confirmar su convalidación (el RDL 26/2026, de contenido parecido, fue derogado por el Congreso). Por prudencia la API limita siempre al IRAV (nunca se propone más) y se puede desactivar con `gestionap.renta.tope-irav=false`. El propietario puede aplicar menos que el máximo.
  - Migración V5 aplicada a gestion_alquileres_pro el 31-10-2026 con copia previa.

## Avisos, datos de demo y capturas (31-10-2026)
- Avisos: cada uno se crea una sola vez por referencia (tipo + contrato, incidencia o habitación + periodo). La
  generación bloquea la fila del usuario, porque la lista y el contador se piden a la vez y duplicaban avisos.
  Las copias que ya hubiera (las creaba el escritorio cada día) se muestran una vez, cuentan una vez y se marcan
  leídas juntas; un script de datos borró las existentes. En la app se agrupan por tipo, y por mes los mensuales.
- Datos de demo: DNI 00000001R… (8 cifras y letra de control válida, para no romper validaciones del escritorio),
  emails @example.com (dominio reservado) y teléfonos 600 000 0NN.
- Fianzas: la entrega y el depósito proponen la fecha de inicio del contrato.
- Recibos: si al propietario le falta nombre o DNI, la app avisa antes de generarlo y ofrece completarlos.
- Capturas: el repositorio solo guarda el escaparate (docs/capturas/destacadas, comprimido) y el vídeo; las de
  trabajo van a docs/capturas-local/, ignorada por git. No se ha reescrito el historial: las capturas antiguas
  siguen en commits anteriores.

- Cobros atrasados: un mes anterior al actual sin ningún pago de un contrato vigente (el mismo criterio que el
  resumen mensual), hasta 12 meses atrás (máximo 24). El retraso se cuenta desde el día 5, fin del plazo habitual.
  Como los cobros se cuentan por la fecha del pago, Registrar propone el último día del mes adeudado (editable).
  Los contratos ya terminados salen, pero sin Registrar (la API solo acepta pagos de contratos activos).
  En Cobros se ven los 3 más antiguos y un enlace a la lista completa.
- Agrupar por piso: un único componente (selector «Por piso / Todos» que se recuerda por pantalla y bloques
  plegables con su resumen); por defecto «Todos», como estaba.
- Estadísticas del periodo: la ocupación se calcula con los días cubiertos por contratos sobre las habitaciones
  actuales (no hay historial de altas de habitaciones ni de mantenimiento) y sin contar días futuros; los meses
  que aún no han empezado no tienen ocupación. Morosidad: meses vencidos sin pago y pagos tras el día 5.
  El ranking de pisos va por resultado neto (ingresos − gastos reales del periodo). El PDF se genera en la app.
- Análisis de inversión guardados (V11): se guarda la entrada de la calculadora y el resultado se recalcula al
  leer (con los tipos de ITP vigentes). Cada usuario solo ve los suyos, también el admin; máximo 50.
- Simular desde un piso: la comunidad autónoma no se deduce de la ciudad; la calculadora propone Madrid.
- Inicio usa una ruta de navegación genérica (NavigationPath): con la ruta tipada `[DestinoInicio]`, los
  enlaces que empujan otros valores (pantallas del piso, contratos, incidencias) no abrían nada.
- La tarjeta «Cobrado» de Inicio usa el mismo resumen mensual que Cobros (GET /api/pagos/resumen): esperado =
  rentas de los contratos vigentes en el mes; pendiente = rentas de los contratos sin ningún pago en el mes. Antes
  usaba los contratos activos hoy y «esperado − cobrado», que divergían de Cobros (contrato que acaba a mitad de
  mes, atrasados cobrados este mes). Se puede ir a meses anteriores (no futuros) y al tocarla abre Cobros en ese mes.
- Porcentajes con redondeo comercial (1,625 → 1,63), como el HALF_UP de la API.
- Meses y fechas en el idioma de la app (español o inglés) con convenciones de España; la app rehace los nombres
  de mes a partir del aaaa-mm que manda la API, que los envía en español. Los importes siguen en formato español.
- Cifras auditadas con SQL directo (api/sql/auditoria/auditoria_numeros.sql) contra la API y la app.
- Alta de piso: el piso y sus habitaciones se crean en una sola petición (o todo o nada). Ciudades: tabla común;
  al dar de alta una que ya existe con otras mayúsculas o tildes, se devuelve la existente.
- Borrar piso: no se permite con contratos activos (se pide finalizarlos), con contratos o incidencias anteriores
  (historial que se conserva) ni con gastos (justificantes fiscales; en la base se borrarían en cascada). Si no hay
  nada de eso, se borran sus habitaciones y el piso. Doble confirmación en la app.
- Sin editar pagos ni contratos (ni en escritorio ni en API): un pago con recibo numerado se borra y se vuelve a
  registrar; un contrato se finaliza y se crea otro. Queda anotado como posible mejora (prórroga de contrato).

## Garajes y trasteros (V12, 2026-11-08)
- Una sola app: `Pisos.tipo` (vivienda, garajes, trasteros) y `Habitaciones.tipo` (habitación, plaza, trastero) con m², planta y vehículo; las tablas conservan su nombre por compatibilidad con el escritorio. Un garaje admite plazas y trasteros; una vivienda, solo habitaciones (máx. 50); garajes y trasteros, hasta 500 unidades.
- IVA por contrato solo en plazas y trasteros (desactivado por defecto, 21 % editable). `precio_mensual` es lo que paga el inquilino, IVA incluido, para no tocar cobros ni estadísticas; el recibo guarda base, % y cuota al emitirse.
- Contratos de plaza y trastero con plantilla propia (uso distinto de vivienda), duración libre y fianza opcional. Los PDF siguen en español.
