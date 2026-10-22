# GestionAp PRO móvil

Versión iOS de [GestionAp PRO](https://github.com/nelsongomezsa/gestionAPPRO), la app de
escritorio (JavaFX) para gestionar el alquiler de habitaciones en pisos compartidos.

| Carpeta | Qué es |
|---|---|
| [`api/`](api/README.md) | API REST (Spring Boot 3.5, Java 21). Comparte la base de datos MariaDB con la app de escritorio |
| `ios/` | App iOS **GestionApPro** (SwiftUI, iOS 17+, Swift 6), cliente de la API |

## Estado de la app iOS

| Comprobación | Estado |
|---|---|
| Compila para el simulador en **Debug** y **Release** (`xcodebuild`) | ✅ Hecho, sin warnings del código |
| ATS: excepción solo en Debug; Release sin excepciones y con URL HTTPS | ✅ Comprobado en los Info.plist compilados |
| Los tests compilan (`build-for-testing`) | ✅ Hecho |
| **Ejecutar los tests** (`xcodebuild test`) | ⏳ **Pendiente**: falta instalar el runtime del simulador de iOS |
| **Probar la app en el simulador** (login del admin, 8 pisos, capturas) | ⏳ **Pendiente**: ídem |

Hasta que se ejecuten, los tests y la app en el simulador **no están verificados**.

## Requisitos

- macOS con **Xcode 16 o posterior** y un simulador de iPhone con iOS 17+
  (Xcode → Settings → Components, o `xcodebuild -downloadPlatform iOS`).
- **XcodeGen**: `brew install xcodegen`.
- La API en marcha en `localhost:8080` (ver [`api/README.md`](api/README.md)):
  ```bash
  cd api
  mvn spring-boot:run -Dspring-boot.run.profiles=dev
  ```

## Abrir y ejecutar la app iOS

El `.xcodeproj` **no se versiona**: se genera desde `ios/project.yml`.

```bash
cd ios
xcodegen generate
open GestionApPro.xcodeproj
```

En Xcode, elige el esquema **GestionApPro**, un simulador de iPhone y pulsa ▶︎ (⌘R).
Inicia sesión con un usuario de la base de datos (por ejemplo, el administrador).

Desde la terminal:

```bash
cd ios
xcodegen generate
xcodebuild -scheme GestionApPro -destination 'platform=iOS Simulator,name=iPhone 17' build   # compilar
xcodebuild -scheme GestionApPro -destination 'platform=iOS Simulator,name=iPhone 17' test    # tests
```

(Cambia `iPhone 17` por un simulador que tengas: `xcrun simctl list devices available`.)

Cada vez que añadas o borres archivos, vuelve a ejecutar `xcodegen generate`.

### URL de la API

| Configuración | URL | Transporte |
|---|---|---|
| Debug | `http://localhost:8080` (`ios/Config/Debug.xcconfig`) | Excepción ATS **solo** para red local (`ios/Config/Info-Debug.plist`) |
| Release | `https://…` (`ios/Config/Release.xcconfig`, cámbiala por la real) | Sin excepciones ATS; la app no arranca si la URL no es HTTPS |

En el simulador, `localhost` es el propio Mac. En un iPhone físico habría que usar la IP
del Mac en la red local.

### Qué hace (fase actual)

- **Login** con email y contraseña. El token JWT se guarda en el **Keychain**; la sesión
  se mantiene al reabrir la app. Un 401 (token caducado) devuelve al login.
- **Pestañas según el rol** (`GET /api/me`):
  - Propietario / administrador: **Mis Pisos**, **Calculadora**, **Perfil**.
  - Inquilino: **Perfil** (el resto, próximamente).
- **Mis Pisos**: lista con semáforo de rentabilidad (verde > 7 %, ámbar ≥ 5 %, rojo por
  debajo; gris sin datos) y cash flow mensual. Pull-to-refresh y estados de carga, vacío y error.
- **Detalle de piso**: rentabilidad bruta y neta, cash-on-cash, PER, cash flow, inversión,
  capital propio, plusvalía y ocupación, en formato es_ES.
- **Calculadora**: el formulario de la pantalla *Rentabilidad* del escritorio, con ITP por
  comunidad autónoma, desglose del resultado y gráfico (Swift Charts).
- Modo claro y oscuro automáticos.

### Estructura

```
ios/
├── project.yml                 definición del proyecto (XcodeGen)
├── Config/                     .xcconfig e Info.plist por configuración
├── GestionApPro/
│   ├── App/                    arranque, configuración, vista raíz y pestañas
│   ├── Models/                 Codable con los nombres de campo de la API
│   ├── Networking/             APIClient (async/await), errores, endpoints, Keychain
│   ├── Session/                estado de sesión
│   └── Features/               una carpeta por pantalla (vista + view model)
└── GestionApProTests/          decodificación con JSON reales de la API, APIClient
                                con URLProtocol simulado y sesión
```

Sin dependencias externas: solo frameworks de Apple.
