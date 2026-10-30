# Capturas de la app iOS

Una carpeta por fase del plan, con las mismas pantallas en `claro/` y `oscuro/`.
Hechas en el simulador **iPhone 18 Pro (iOS 27)** contra la API en `dev`, con los datos de demo.

| Fase | Pantallas |
|---|---|
| [4A](4A/) | Login, Inicio, Pisos, detalle de piso, Más, calculadora y su desglose, perfil |
| [4B](4B/) | Habitaciones (lista, deslizar, alta), mapa del piso, inquilinos, ficha, QR de pago, invitación, datos de cobro |
| [4C](4C/) | Cobros (resumen del mes, pendientes, registrar pago, mes anterior), contratos (filtros, finalizar deslizando, detalle, PDF, recordatorio, nuevo) y «Mi alquiler» del inquilino |
| [4D](4D/) | Inicio (KPIs con tendencia, gráfico, alertas, vencimientos, actividad), informe mensual en PDF, notificaciones y su destino, calendario con detalle del día, estadísticas |
| [4E](4E/) | Incidencias (lista, avanzar deslizando, detalle, nueva), detalle de piso con gráfico, contratos, pagos e incidencias, datos financieros, ficha y calculadora en PDF, mapa de todos los pisos, incidencias del inquilino |

## Cómo regenerarlas

Las genera un recorrido de UI (`ios/GestionApProUITests/CapturasUITests.swift`) que inicia
sesión, navega por la app y guarda cada pantalla. Con la API en marcha:

```bash
CAPTURAS_EMAIL=<email> CAPTURAS_PASSWORD=<contraseña> ios/scripts/capturas.sh 4A
# o, si la API está en otro puerto:
CAPTURAS_EMAIL=<email> CAPTURAS_PASSWORD=<contraseña> ios/scripts/capturas.sh 4A http://localhost:8081
```

Las credenciales solo se pasan por variables de entorno; no se guardan en el repositorio.
El script fija la barra de estado (9:41, batería llena) y repite el recorrido en modo oscuro.
