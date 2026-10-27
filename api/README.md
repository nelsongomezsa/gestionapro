# gestionapro-api

API REST de **GestionAp PRO** para la app iOS. Spring Boot 3.5 · Java 21 · Maven · MariaDB.

Comparte la base de datos `gestion_alquileres_pro` con la app de escritorio
(GestionAp, JavaFX): lo que se hace en una se ve en la otra.

## Antes del primer arranque: migración V1

La API valida al arrancar (`ddl-auto=validate`) que el esquema tenga lo que
necesita. Contra una base sin migrar **no arranca** (`Schema-validation: missing column [id_usuario]`).

La migración **se aplica a mano** y en este orden:

1. **Parche del escritorio** — `patches/escritorio-rol-inquilino.patch`.
   Sin él, en cuanto exista un usuario `inquilino` la pantalla *Gestión de
   usuarios* del escritorio deja de cargar (`Rol.valueOf("inquilino")` lanza
   excepción). El parche añade el rol al enum, impide que un inquilino entre en
   el escritorio y que se le cambie el rol.
   ```bash
   cd ~/Desktop/gestionAPPRO
   git apply ~/Desktop/gestionapro-mobile/api/patches/escritorio-rol-inquilino.patch
   mvn test        # 189 tests en verde con el parche aplicado
   ```
2. **Copia de seguridad**
   ```bash
   /Applications/XAMPP/xamppfiles/bin/mysqldump -u root gestion_alquileres_pro > backup_$(date +%Y%m%d).sql
   ```
3. **Migración** — `sql/V1__api_propietarios_inquilinos_invitaciones.sql`
   ```bash
   /Applications/XAMPP/xamppfiles/bin/mysql -u root gestion_alquileres_pro < sql/V1__api_propietarios_inquilinos_invitaciones.sql
   ```

Qué cambia (solo añade, no renombra nada):

| Cambio | Para qué |
|---|---|
| `Usuarios.rol` admite `'inquilino'` | Cuentas de inquilino de la app móvil |
| `Usuarios.dni` (opcional) | Datos del arrendador en el contrato PDF |
| `Pisos.id_propietario` (NOT NULL) | Los pisos existentes pasan a `admin@gestionap.com` |
| `Inquilinos.id_usuario` (único, opcional) | Enlaza el inquilino con su cuenta |
| Tabla `Invitaciones` | Códigos de un solo uso; se guarda su SHA-256 |

Los roles de la BD no se renombran; la API los traduce:
`admin` → `ADMIN`, `usuario` → `PROPIETARIO`, `inquilino` → `INQUILINO`.

## Arrancar

Requisitos: JDK 21+, Maven 3.9+, MariaDB de XAMPP en marcha.

```bash
cd api
export JWT_SECRET=$(openssl rand -base64 48)   # clave solo para tu máquina
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

- API: <http://localhost:8080>
- Swagger UI: <http://localhost:8080/swagger-ui.html> (pulsa *Authorize* y pega el token del login)

### Perfiles

No hay perfil por defecto: **la API no arranca sin un perfil activo explícito** (`--spring.profiles.active=...` o `SPRING_PROFILES_ACTIVE`). Así un despliegue no puede acabar usando por error la configuración de desarrollo. En `prod`, si falta `JWT_SECRET` o tiene menos de 32 caracteres, tampoco arranca.

| Perfil | Base de datos | Secretos |
|---|---|---|
| `dev` | `jdbc:mariadb://localhost:3306/gestion_alquileres_pro`, `root` sin contraseña (XAMPP) | `JWT_SECRET` desde variable de entorno (mínimo 32 caracteres); email sin configurar |
| `prod` | Variables de entorno | Variables de entorno; Swagger desactivado salvo `SWAGGER_ENABLED=true` |

Variables de `prod`:

| Variable | Obligatoria | |
|---|---|---|
| `DB_URL` | sí | p. ej. `jdbc:mariadb://db:3306/gestion_alquileres_pro` |
| `DB_USER`, `DB_PASS` | sí | |
| `JWT_SECRET` | sí | mínimo 32 caracteres (`openssl rand -base64 48`) |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USER`, `MAIL_PASS`, `MAIL_FROM` | no | sin `MAIL_HOST` no se envían emails (la API funciona igual) |
| `SWAGGER_ENABLED` | no | `false` por defecto |

```bash
java -jar target/gestionapro-api-0.1.0-SNAPSHOT.jar --spring.profiles.active=prod
```

### Tipos de ITP

`src/main/resources/itp-rates.yml` — los 19 tipos (17 CCAA + Ceuta y Melilla)
copiados del escritorio. **El año de referencia está sin verificar**: revísalos
contra la normativa vigente y edita el YAML; no hace falta tocar código.

## Endpoints

Todas las rutas salvo login y registro necesitan `Authorization: Bearer <token>`.

| Método | Ruta | Roles | Descripción |
|---|---|---|---|
| POST | `/api/auth/login` | público | Email + contraseña → JWT (8 h). Acepta hashes SHA-256 antiguos y los pasa a BCrypt |
| POST | `/api/auth/register-inquilino` | público | Código de invitación + email + contraseña → crea la cuenta y la enlaza con su ficha de inquilino |
| GET | `/api/me` | todos | Usuario autenticado (`idInquilino` si es inquilino) |
| GET | `/api/pisos` | PROPIETARIO, ADMIN | Pisos con ocupación, ingresos de contratos activos y métricas |
| GET | `/api/pisos/{id}` | PROPIETARIO, ADMIN | |
| POST | `/api/pisos` | PROPIETARIO, ADMIN | Crea un piso (propietario = usuario autenticado) con datos financieros opcionales |
| PUT | `/api/pisos/{id}` | PROPIETARIO, ADMIN | Si se omite `datosFinancieros`, se conservan los guardados |
| DELETE | `/api/pisos/{id}` | PROPIETARIO, ADMIN | 409 si tiene habitaciones |
| POST | `/api/inquilinos/{id}/invitaciones` | PROPIETARIO, ADMIN | Código de un solo uso, 7 días. Anula los anteriores. Se envía por email si está configurado |
| GET | `/api/contratos/{id}/pdf` | todos | Contrato en PDF (iText 7). ADMIN, propietario del piso o inquilino del contrato |
| POST | `/api/calculadora/rentabilidad` | PROPIETARIO, ADMIN | Pantalla *Rentabilidad* del escritorio |
| GET | `/api/calculadora/itp` | PROPIETARIO, ADMIN | Tipos de ITP por comunidad |

Visibilidad: un **PROPIETARIO** solo ve sus pisos y los inquilinos con
contrato en ellos; un **INQUILINO** solo su contrato; los recursos ajenos
responden **404** (no 403), para no revelar qué ids existen.

Métricas de un piso (`metricas`): `inversionTotal`, `cuotaMensualHipoteca`,
`gastosAnuales`, `rentabilidadBrutaPct`, `rentabilidadNetaPct`,
`calificacion`, `cashFlowMensual`, `cashOnCashPct`, `capitalPropio`,
`plusvaliaLatente`, `perAnios`. `cashOnCashPct` es lo que el escritorio
llamaba ROCE (cash flow anual / capital propio); el ROCE real está pendiente.

### Errores

Todos los errores, incluidos 401 y 403, tienen la misma forma:

```json
{
  "timestamp": "2026-10-22T08:52:20.514Z",
  "status": 400,
  "codigo": "VALIDACION",
  "mensaje": "Hay campos con valores no válidos",
  "path": "/api/pisos",
  "errores": [{ "campo": "direccion", "mensaje": "no debe estar vacío" }]
}
```

`codigo` es estable y la app puede usarlo para decidir qué mostrar:
`VALIDACION`, `JSON_INVALIDO`, `NO_AUTENTICADO`, `CREDENCIALES_INCORRECTAS`,
`ACCESO_DENEGADO`, `NO_ENCONTRADO`, `RUTA_NO_ENCONTRADA`,
`INVITACION_NO_VALIDA`, `INQUILINO_YA_REGISTRADO`, `EMAIL_EN_USO`,
`PISO_CON_HABITACIONES`, `CIUDAD_NO_EXISTE`, `COMUNIDAD_DESCONOCIDA`,
`CONFLICTO_DATOS`, `ERROR_INTERNO`.

### Ejemplo con curl

```bash
TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@gestionap.com","password":"TU_CONTRASEÑA"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')

curl -s localhost:8080/api/pisos -H "Authorization: Bearer $TOKEN"
```

## Tests

```bash
mvn test     # 83 tests, H2 en memoria; no necesita MariaDB
```

- `CalculadoraFinancieraPisoTest`: los tests del escritorio, con los mismos valores esperados.
- `CalculadoraRentabilidadTest`: valores obtenidos ejecutando el
  `RentabilidadController` real del escritorio (ver `tools/GoldenRentabilidad.java`);
  coinciden con delta 0.
- `ItpRatesTest`: `itp-rates.yml` = `ITP_MAP` del escritorio.
- `ArranqueTest`: sin perfil activo, o en prod sin `JWT_SECRET` válido, la API no arranca.
- Integración (MockMvc): login, JWT, aislamiento entre propietarios,
  invitaciones de un solo uso/caducadas, PDF por roles, errores JSON.

El esquema de test (`src/test/resources/schema.sql`) es el de producción tras
la migración V1. Las entidades se validaron contra MariaDB real con una copia
migrada de la base.

## Estructura

```
api/
├── patches/      parche para la app de escritorio (aplicar a mano)
├── sql/          migraciones (aplicar a mano)
├── tools/        utilidades fuera del build (valores de referencia)
└── src/main/java/com/gestionap/api/
    ├── config/      OpenAPI, tipos de ITP
    ├── security/    JWT, filtro, BCrypt + SHA-256 antiguo, errores 401/403
    ├── domain/      entidades JPA sobre las tablas del escritorio
    ├── repository/
    ├── service/     lógica (calculadoras migradas del escritorio, PDF, email...)
    └── web/         controladores, DTOs y manejo global de errores
```

## Licencia de iText

iText 7 es **AGPL**: servir PDFs generados con él desde una API obliga a
publicar el código fuente de la API, cosa que se cumple al ser un repositorio
público.
