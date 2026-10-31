# Paridad escritorio → iOS

Cada función de la app de escritorio (`~/Desktop/gestionAPPRO`: controladores, FXML y DAOs),
el endpoint de la API que necesita y la pantalla de la app iOS donde va.

- **API**: ✔︎ ya existe · ✚ hay que crearlo (con tests de integración y control de rol).
- **Estado**: ✅ hecho y probado en el simulador · ⏳ pendiente · ➖ no aplica en móvil (explicado).
- **Fase**: la del plan (4A–4F).

Regla de acceso de todos los endpoints: el **ADMIN** ve todo, un **PROPIETARIO** solo lo de sus
pisos y un **INQUILINO** solo lo suyo. Lo ajeno responde 404.

## Acceso y sesión

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Login con email y contraseña (`LoginController`) | `POST /api/auth/login` | ✔︎ | Login | — | ✅ |
| Cerrar sesión | — (borra el token del Keychain) | ✔︎ | Más → Perfil | — | ✅ |
| Rehash SHA-256 → BCrypt al entrar | (en el login) | ✔︎ | — | — | ✅ |
| Registro de inquilino con invitación *(solo móvil)* | `POST /api/auth/register-inquilino` | ✔︎ | Login → "Soy inquilino y tengo un código" | 4F | ✅ |

## Navegación (`MainController`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Menú lateral con 12 secciones | — | | Pestañas Inicio · Pisos · Cobros · Incidencias · Más | 4A | ✅ |
| Usuarios visible solo para admin | `GET /api/me` | ✔︎ | Más → Usuarios (solo admin) | 4A | ✅ |
| Búsqueda global | ✚ `GET /api/buscar?q=` | ✚ | Inicio → lupa (abre piso, inquilino, contrato o incidencia) | 4F | ✅ |
| Campana de notificaciones con contador | `GET /api/notificaciones` y `/no-leidas` | ✔︎ | Inicio → campana | 4D | ✅ |
| Tema claro / oscuro | — | | Automático (sistema) | 4A | ✅ |
| Atrás / historial (`HistorialNavegacion`) | — | | Navegación nativa de iOS | 4A | ➖ |

## Dashboard (`DashboardController`, `DashboardDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| KPIs: habitaciones, alquiladas, disponibles, mantenimiento, ocupación | `GET /api/dashboard` | ✔︎ | Inicio | 4D | ✅ |
| KPIs: inquilinos, contratos activos, incidencias pendientes, cobrado este mes | `GET /api/dashboard` | ✔︎ | Inicio | 4D | ✅ |
| Gráfico de ingresos cobrados, últimos 6 meses | `GET /api/dashboard` | ✔︎ | Inicio (Swift Charts) | 4D | ✅ |
| Alertas (baja ocupación, incidencias, «sistema saludable») | `GET /api/dashboard` | ✔︎ | Inicio | 4D | ✅ |
| Próximos vencimientos (30 días) | `GET /api/dashboard` | ✔︎ | Inicio | 4D | ✅ |
| Últimas actividades | `GET /api/actividad` | ✔︎ | Inicio | 4D | ✅ |
| Informe del mes en PDF (en el Escritorio) | `GET /api/informes/mensual` | ✔︎ | Inicio → visor PDF con compartir/imprimir | 4D | ✅ |

## Mis Pisos (`AnalisisPisosController`, `AnalisisPisoDAO`, `DatosPisoDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista de pisos con métricas, semáforo y cash flow | `GET /api/pisos` | ✔︎ | Pisos (tarjetas, buscador, filtro por ciudad, orden) | 4A | ✅ |
| Resumen de la cartera | — (se calcula en el móvil con `GET /api/pisos`) | ✔︎ | Pisos e Inicio (cabecera) | 4A | ✅ |
| Editar datos financieros del piso | `PUT /api/pisos/{id}` | ✔︎ | Detalle de piso → Editar datos financieros | 4E | ✅ |
| Mapa con todos los pisos *(mejora móvil)* | — (se sitúan en el móvil) | | Pisos → Mapa (MapKit) | 4E | ✅ |

## Detalle de piso (`DetallePisoController`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| KPIs y métricas del piso | `GET /api/pisos/{id}` | ✔︎ | Detalle de piso | — | ✅ |
| Habitaciones del piso | `GET /api/habitaciones?piso=` | ✔︎ | Detalle de piso → Habitaciones | 4B | ✅ |
| Contratos del piso | `GET /api/contratos?piso=` | ✔︎ | Detalle de piso | 4E | ✅ |
| Últimos pagos del piso | `GET /api/pagos?piso=` | ✔︎ | Detalle de piso | 4E | ✅ |
| Incidencias del piso | `GET /api/incidencias?piso=` | ✔︎ | Detalle de piso | 4E | ✅ |
| Gráfico de ingresos últimos 12 meses | `GET /api/pisos/{id}/ingresos` | ✔︎ | Detalle de piso (Swift Charts) | 4E | ✅ |
| Exportar PDF del piso | `GET /api/pisos/{id}/pdf` | ✔︎ | Detalle de piso → visor PDF | 4E | ✅ |

## Habitaciones (`HabitacionesController`, `HabitacionDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista con filtro por estado y buscador | `GET /api/habitaciones` | ✔︎ | Detalle de piso → Habitaciones | 4B | ✅ |
| Añadir, editar y eliminar habitación | `POST/PUT/DELETE /api/habitaciones` | ✔︎ | Habitaciones (deslizar para editar/borrar) | 4B | ✅ |
| Cambiar estado (disponible / alquilada / mantenimiento) | `PATCH /api/habitaciones/{id}/estado` | ✔︎ | Habitaciones | 4B | ✅ |
| Ver en el mapa (Google Maps) | — | | Mapa del piso (MapKit) | 4B | ✅ |
| Exportar la lista a PDF | — (se genera en el móvil) | | Habitaciones → visor PDF | 4B | ✅ |

## Inquilinos (`InquilinosController`, `InquilinoDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista con buscador | `GET /api/inquilinos` | ✔︎ | Más → Inquilinos | 4B | ✅ |
| Añadir, editar y eliminar | `POST/PUT/DELETE /api/inquilinos` | ✔︎ | Inquilinos (deslizar para editar/borrar) | 4B | ✅ |
| Ver su contrato y pagos *(en escritorio, en pantallas aparte)* | `GET /api/inquilinos/{id}` | ✔︎ | Ficha del inquilino | 4B | ✅ |
| QR de pago SEPA | `GET /api/inquilinos/{id}/qr-pago` | ✔︎ | Ficha → QR en pantalla y compartir | 4B | ✅ |
| Enviar email (JavaMail) | — | | Ficha → llamar, email o WhatsApp (hoja de Compartir) | 4B | ✅ |
| Exportar la lista a PDF | — (se genera en el móvil) | | Inquilinos → visor PDF | 4B | ✅ |
| Invitar a la app *(solo móvil)* | `POST /api/inquilinos/{id}/invitaciones` | ✔︎ | Ficha → Invitar a la app | 4B | ✅ |

## Contratos (`ContratosController`, `ContratoDAO`, `VencimientoContrato`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista con filtro (todos / activos) y nivel de vencimiento (crítico ≤ 7 días) | `GET /api/contratos` | ✔︎ | Más → Contratos | 4C | ✅ |
| Nuevo contrato reservando la habitación en la misma transacción | `POST /api/contratos` | ✔︎ | Contratos → Nuevo | 4C | ✅ |
| Finalizar contrato y liberar la habitación | `POST /api/contratos/{id}/finalizar` | ✔︎ | Contratos (deslizar) | 4C | ✅ |
| Generar contrato LAU en PDF | `GET /api/contratos/{id}/pdf` | ✔︎ | Contrato → visor PDF con compartir/imprimir | 4C | ✅ |
| Recordatorio por email | — | | Contrato → hoja de Compartir | 4C | ✅ |
| Ver en el mapa | — | | Contrato → mapa (MapKit) | 4C | ✅ |
| Exportar la lista a PDF | — (se genera en el móvil) | | Contratos → visor PDF | 4C | ✅ |

## Pagos (`PagosController`, `PagoDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista con filtro por inquilino y buscador | `GET /api/pagos` | ✔︎ | Cobros | 4C | ✅ |
| Filtro por mes *(mejora pedida)* | `GET /api/pagos?mes=` | ✔︎ | Cobros | 4C | ✅ |
| Registrar pago | `POST /api/pagos` | ✔︎ | Cobros → Nuevo | 4C | ✅ |
| Eliminar pago | `DELETE /api/pagos/{id}` | ✔︎ | Cobros (deslizar) | 4C | ✅ |
| Totales: total y este mes | `GET /api/pagos/resumen` | ✔︎ | Cobros (cabecera) | 4C | ✅ |
| Pendientes del mes | `GET /api/pagos/resumen` | ✔︎ | Cobros (cabecera) | 4C | ✅ |

## Calendario (`CalendarioController`, `CalendarioDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Vista mensual: esperado, pagado, vencido sin cobrar | `GET /api/calendario?mes=` | ✔︎ | Más → Calendario | 4D | ✅ |
| Totales del mes (esperado, cobrado, pendiente) | `GET /api/calendario?mes=` | ✔︎ | Calendario | 4D | ✅ |
| Detalle del día *(mejora pedida)* | `GET /api/calendario?mes=` | ✔︎ | Calendario → día | 4D | ✅ |

## Estadísticas (`EstadisticasController`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Evolución de ingresos 12 meses (líneas) | `GET /api/estadisticas` | ✔︎ | Más → Estadísticas | 4D | ✅ |
| Habitaciones por estado (tarta) | `GET /api/estadisticas` | ✔︎ | Estadísticas | 4D | ✅ |
| Incidencias por mes, 6 meses (barras) | `GET /api/estadisticas` | ✔︎ | Estadísticas | 4D | ✅ |
| Ingresos año actual / anterior, variación, ocupación | `GET /api/estadisticas` | ✔︎ | Estadísticas | 4D | ✅ |

En escritorio estas consultas son globales y los meses dependen del idioma del servidor
(`DATE_FORMAT '%b'`); en la API se filtran por propietario y los meses van siempre en español.

## Notificaciones (`NotificacionDAO`, `RutasNotificacion`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Generar avisos: contrato que vence, pago pendiente, incidencia antigua, mantenimiento largo | (al pedir la lista) | ✔︎ | — | 4D | ✅ |
| Lista, contador de no leídas | `GET /api/notificaciones` | ✔︎ | Inicio → campana | 4D | ✅ |
| Marcar como leída / todas leídas | `POST /api/notificaciones/{id}/leida` y `/leidas` | ✔︎ | Notificaciones | 4D | ✅ |
| Al tocar, ir a su pantalla (`RutasNotificacion`) | — | | Contratos / Incidencias / Habitaciones | 4D | ✅ |

## Incidencias (`IncidenciasController`, `IncidenciaDAO`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista con filtro por estado | `GET /api/incidencias` | ✔︎ | Incidencias | 4E | ✅ |
| Nueva incidencia | `POST /api/incidencias` | ✔︎ | Incidencias → Nueva | 4E | ✅ |
| Avanzar estado (pendiente → en proceso → resuelta) | `PATCH /api/incidencias/{id}/estado` | ✔︎ | Incidencias (deslizar) | 4E | ✅ |
| Coste de reparación | `PATCH /api/incidencias/{id}` | ✔︎ | Detalle de incidencia | 4E | ✅ |
| Eliminar | `DELETE /api/incidencias/{id}` | ✔︎ | Incidencias (deslizar) | 4E | ✅ |

## Calculadora de rentabilidad (`RentabilidadController`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Cálculo con ITP por comunidad, hipoteca, gastos y revalorización | `POST /api/calculadora/rentabilidad` | ✔︎ | Más → Calculadora | — | ✅ |
| Resumen que se actualiza al escribir *(mejora pedida)* | `POST /api/calculadora/rentabilidad` | ✔︎ | Calculadora (cabecera) | 4A | ✅ |
| Limpiar formulario | — | | Calculadora | 4A | ✅ |
| Exportar a PDF | — (se genera en el móvil) | | Resultado → visor PDF | 4E | ✅ |

## Perfil (`PerfilController`)

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Información de la cuenta | `GET /api/me` | ✔︎ | Más → Perfil (avatar con iniciales) | 4A | ✅ |
| Editar nombre y email | ✚ `PATCH /api/me` | ✚ | Perfil → Editar nombre y email | 4F | ✅ |
| Cambiar contraseña | ✚ `PUT /api/me/password` | ✚ | Perfil → Cambiar contraseña | 4F | ✅ |
| Mis estadísticas (contratos, pagos, incidencias) | `GET /api/dashboard` (reutilizado) | ✔︎ | Perfil → Mis estadísticas | 4F | ✅ |
| Historial de actividad reciente | ✚ `GET /api/actividad?soloMia=true` | ✚ | Perfil → Historial de actividad | 4F | ✅ |
| IBAN para el QR de pago *(nuevo, ver 4B)* | `PATCH /api/me` | ✔︎ | Perfil → Datos de cobro | 4B | ✅ |

## Usuarios (`UsuariosController`, `UsuarioDAO`) — solo admin

| Escritorio | API | | Pantalla iOS | Fase | Estado |
|---|---|---|---|---|---|
| Lista de usuarios | ✚ `GET /api/usuarios` | ✚ | Más → Usuarios | 4F | ✅ |
| Nuevo usuario | ✚ `POST /api/usuarios` | ✚ | Usuarios → + | 4F | ✅ |
| Activar / desactivar | ✚ `PATCH /api/usuarios/{id}/activo` | ✚ | Usuarios (deslizar o mantener pulsado; no a uno mismo) | 4F | ✅ |
| Cambiar rol (un inquilino no puede ascender) | ✚ `PATCH /api/usuarios/{id}/rol` | ✚ | Usuarios (mantener pulsado) | 4F | ✅ |

## Lo que no se traslada tal cual

| Escritorio | Por qué | Equivalente en iOS |
|---|---|---|
| Configuración SMTP y envío de emails desde la app | En iOS no se guardan credenciales de correo; el sistema ya tiene Mail | Hoja de Compartir (Mail, WhatsApp, Mensajes…) |
| PDFs guardados en el Escritorio | En iOS no hay un Escritorio | Visor de PDF con compartir, guardar en Archivos e imprimir |
| Google Maps en el navegador | — | MapKit dentro de la app |
| Atajos de teclado | No hay teclado físico | Gestos: deslizar para editar o borrar |
| Exportación XML (`xml/`) | No forma parte de la interfaz de escritorio | — |

## Más allá del escritorio (fase 5 en adelante)

Funciones nuevas de la API y la app que el escritorio no tiene. Solo usan tablas nuevas
(migraciones `api/sql/V3…` en adelante), así que el escritorio sigue funcionando igual.

| Función | API | iOS | Migración |
|---|---|---|---|
| Recibos PDF numerados por propietario y año (2026-0001…) | `GET /api/pagos/{id}/recibo`, `POST /api/pagos/{id}/recibo/enviar` | Cobros: tocar un pago abre su recibo; menú para enviarlo por email. «Mi alquiler»: el inquilino abre los suyos | V3 |
| Fianzas: importe, entrega, depósito en el organismo autonómico y devolución (con motivo si se retiene algo) | `GET/PUT /api/contratos/{id}/fianza`, `POST …/fianza/devolucion`, `GET /api/fianzas` | Sección «Fianza» en el detalle del contrato (editar y devolver) y en «Mi alquiler» (solo lectura) | V4 |
| Avisos de cobro: «Cobro vencido» al propietario pasado el día límite (7, LAU art. 17.2; configurable) y, al inquilino, recordatorio 3 días antes y aviso si se pasa. Email de recordatorio diario a las 9:00 si hay email configurado | Se generan al consultar `/api/notificaciones`; `RecordatoriosPago` (tarea diaria) | Campana en «Mi alquiler» para el inquilino; iconos nuevos en Notificaciones | — |
| Actualización anual de la renta con el índice oficial: IRAV del INE para contratos desde el 26-05-2023 e IPC para los anteriores (se puede cambiar o poner un porcentaje pactado); el propietario revisa y confirma, y queda en el historial | `GET/POST /api/contratos/{id}/actualizacion-renta`, `GET …/actualizaciones-renta` (datos en directo de la API del INE) | Sección «Actualización de renta» en el contrato (propuesta, revisión e historial) y en «Mi alquiler» (historial) | V5 |
| Conciliación bancaria por CSV (formato genérico y extractos habituales de Santander, BBVA, CaixaBank, Sabadell e ING): propone el contrato de cada ingreso con su confianza y el propietario confirma | `POST /api/conciliacion/analizar`, `POST /api/conciliacion/confirmar` (ver docs/CONCILIACION.md) | Cobros → ••• → Conciliar con el banco | — |
| Firma de contratos en pantalla (firma electrónica simple, preparada para un proveedor con validez reforzada) con hoja de firmas en el PDF | `GET /api/contratos/{id}/firmas`, `POST …/firmas/{parte}`, `GET …/pdf-firmado` (ver docs/FIRMA.md) | Sección «Firma» en el contrato y en «Mi alquiler» | V7 |
| Mensajería propietario ↔ inquilino por contrato o incidencia, con aviso al otro lado | `GET /api/conversaciones`, `GET/POST /api/contratos/{id}/mensajes`, `GET/POST /api/incidencias/{id}/mensajes` | Más → Mensajes, pestaña Mensajes del inquilino, botones en contrato e incidencia | V7 |

