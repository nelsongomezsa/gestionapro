# Capturas de la app iOS

Una carpeta por fase del plan, con las mismas pantallas en `claro/` y `oscuro/`.
Hechas en el simulador **iPhone 18 Pro (iOS 27)** contra la API en `dev`, con los datos de demo.

| Fase | Pantallas |
|---|---|
| [4A](4A/) | Login, Inicio, Pisos, detalle de piso, Más, calculadora y su desglose, perfil |
| [4B](4B/) | Habitaciones (lista, deslizar, alta), mapa del piso, inquilinos, ficha, QR de pago, invitación, datos de cobro |

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
