# Despliegue en la nube (fase 8.1)

Preparación y comparación. **No se ha creado ninguna cuenta ni se ha contratado nada**: falta que Nelson
elija la opción. Precios y límites consultados el 31-10-2026 (cambian a menudo: confírmalos en la web de
cada proveedor antes de decidir).

## Lo que ya está preparado

| Pieza | Dónde | Qué hace |
|---|---|---|
| Imagen Docker | `api/Dockerfile`, `api/.dockerignore` | Compila con Maven y ejecuta solo el JRE 21 con un usuario sin privilegios; perfil `prod`; comprobación de salud. **No se ha podido construir aquí** (no hay Docker en este Mac): la primera construcción será en la plataforma o con Docker Desktop. |
| Perfil `prod` | `api/src/main/resources/application-prod.yml` | Todo por variables de entorno (no arranca si falta una obligatoria), Swagger apagado, `forward-headers-strategy: framework` para la IP real y el HTTPS detrás del proxy, carpeta de archivos en un volumen. |
| Salud | `GET /actuator/health` | Responde `{"status":"UP"}` sin sesión y sin detalles (test `SaludTest`); el resto de Actuator no está expuesto. |
| Esquema | `api/sql/esquema_completo.sql` | Las 21 tablas (escritorio + V1–V7) **sin datos**, para crear la base desde cero. |
| Datos | `mysqldump` de la base actual | Los datos de demo ya son ficticios (`demo_datos_ficticios.sql`): se pueden subir tal cual. |

### Variables de entorno

| Variable | Obligatoria | Ejemplo / nota |
|---|---|---|
| `DB_URL` | Sí | `jdbc:mariadb://host:3306/gestion_alquileres_pro?useSsl=true` |
| `DB_USER`, `DB_PASS` | Sí | Usuario propio de la API, no `root` |
| `JWT_SECRET` | Sí | `openssl rand -base64 48`; distinto del de desarrollo |
| `GESTIONAP_ARCHIVOS_DIR` | No | `/data/archivos` (montar un volumen persistente ahí) |
| `ANTHROPIC_API_KEY` | No | Activa el asistente (ver `docs/ASISTENTE.md`) |
| `ASISTENTE_MODELO` | No | Modelo del asistente; por defecto `claude-haiku-5-5`, el más económico |
| `MAIL_HOST`, `MAIL_USER`, `MAIL_PASS`, `MAIL_FROM` | No | Recibos y recordatorios por email |
| `SWAGGER_ENABLED` | No | `false` en producción |

### Migraciones

En una base nueva: `esquema_completo.sql` y, si se quieren los datos de demo, el volcado actual. En la base
existente, las `api/sql/Vn__*.sql` en orden y siempre con copia previa (`mysqldump`), como hasta ahora. La API
arranca con `ddl-auto=validate`: si falta una migración, no arranca y lo dice.

### HTTPS

Las tres opciones dan HTTPS con certificado automático (en la máquina virtual de Oracle, con Caddy y Let's
Encrypt). La app iOS en Release solo admite `https://`.

## Un punto que decide mucho: la app de escritorio

El escritorio se conecta **directamente a la base de datos** (no pasa por la API). Por eso:

- Con una base **compatible con MySQL/MariaDB**, el escritorio sigue funcionando cambiando solo su URL de
  conexión. Eso sí, la base tiene que aceptar conexiones desde fuera, con TLS y una contraseña fuerte, y
  limitada a tu IP si el proveedor lo permite.
- Con **PostgreSQL (Supabase)** habría que cambiar también el escritorio (driver y SQL de sus DAO), que no he
  podido revisar porque macOS me bloquea la carpeta.

## Las tres opciones

### 1. Railway: la más sencilla (≈ 5 $/mes)

- API desde el `Dockerfile` y **MySQL** en el mismo proyecto, con volumen para los archivos y HTTPS automático.
- Plan Hobby de 5 $/mes con 5 $ de uso incluidos; lo que pase de ahí se cobra por uso. No hay plan gratuito
  permanente: solo una prueba con crédito.
- Cambios en el código: ninguno. Escritorio: solo la URL (Railway da un acceso TCP público a la base).
- Contras: es de pago desde el primer mes y la factura depende del uso. Hay que poner un límite de gasto.

### 2. Oracle Cloud Always Free: gratis, pero con más trabajo (0 €)

- Una máquina virtual Arm (el máximo gratuito es ahora **2 OCPU y 12 GB** en total; Oracle lo redujo en 2026)
  con Docker y Caddy, más **MySQL HeatWave** gratuito (un nodo con 50 GB de datos y 50 GB de copias).
- Cambios en el código: ninguno; MySQL 8 es compatible con lo que usa la API (lo probaría con los tests
  contra un MySQL 8 local antes de migrar).
- Contras: hay que mantener la máquina (actualizaciones, cortafuegos, copias). El alta pide tarjeta, aunque
  no cobra si no se sale de lo gratuito. Si se supera el límite de Arm al acabar la prueba, Oracle desactiva
  las máquinas.

### 3. Supabase (PostgreSQL) + API en Render: gratis, pero obliga a migrar (0 €)

- Supabase gratis: base PostgreSQL de **500 MB**, 2 proyectos activos, y **se pausa tras una semana sin
  uso** (Pro, 25 $/mes, quita la pausa). La API iría en el plan gratuito de Render, que **se duerme tras
  15 minutos sin tráfico** (≈ 1 minuto en despertar) y no tiene disco persistente: las facturas, fotos y
  firmas tendrían que ir a Supabase Storage (1 GB gratis), es decir, cambiar `ArchivoService`.
- **Qué supondría pasar de MariaDB a PostgreSQL:**
  - **API:** 4 columnas `enum(...)` escritas para MySQL (rol, estado de incidencia, estado de habitación,
    método de pago); 1 consulta nativa (la numeración de recibos; su `LIMIT … FOR UPDATE` sí funciona en
    PostgreSQL); 21 tablas con mayúsculas en el nombre (`Pagos`, `Contratos`…), que PostgreSQL pasa a
    minúsculas si no van entre comillas (habría que activar los identificadores entre comillas o renombrar);
    tipos (`TINYINT(1)` → `boolean`, `DATETIME` → `timestamp`, `enum` → `text` con `CHECK`); orden
    alfabético en español (`utf8mb4_spanish_ci` → colación ICU `es-ES`); y los tests (H2 en modo MySQL →
    modo PostgreSQL).
  - **Datos:** convertir el volcado con una herramienta como pgloader y comprobarlo tabla a tabla.
  - **Escritorio:** driver de PostgreSQL y revisar el SQL de todos sus DAO (no revisable desde aquí).
  - Estimación: varios días de trabajo y riesgo de romper el escritorio, solo para ahorrarse unos euros.
- Alternativa gratuita que evita la migración: Render + una base **compatible con MySQL** gratuita, como
  TiDB Cloud Starter (5 GiB gratis, compatible con MySQL 5.7/8.0; hay que probar las migraciones) o Aiven
  for MySQL (1 GB gratis). Mantiene los contras de Render: se duerme y no tiene disco.

### Resumen

| | Railway | Oracle Always Free | Supabase + Render |
|---|---|---|---|
| Coste | ≈ 5 $/mes + uso | 0 € | 0 € (o 25 $/mes Supabase Pro) |
| Cambios en la API | Ninguno | Ninguno | Muchos (PostgreSQL y archivos) |
| Escritorio | Solo la URL | Solo la URL | Driver y SQL |
| Siempre encendido | Sí | Sí | No (Render duerme; Supabase pausa) |
| Archivos (fotos, facturas) | Volumen | Disco de la VM | Supabase Storage (cambiar código) |
| Mantenimiento | Mínimo | Alto (VM) | Bajo |

**Recomendación:** si el objetivo es enseñar la app en entrevistas con el mínimo trabajo, **Railway**. Si
tiene que ser gratis, **Oracle Always Free**. Supabase no compensa mientras el escritorio dependa de MariaDB.

## Siguiente paso (cuando elijas)

1. Crear la cuenta (lo haces tú) y poner un límite de gasto.
2. Base: crear la base y un usuario propio para la API; cargar `esquema_completo.sql` o el volcado.
3. API: desplegar desde `api/Dockerfile` con las variables de arriba y un volumen en `/data/archivos`.
4. Comprobar `https://<dominio>/actuator/health` y entrar desde la app (Release, `API_BASE_URL` con https).
5. Escritorio: cambiar su URL de conexión a la base nueva (con TLS).

## Fuentes

- Supabase: [supabase.com/pricing](https://supabase.com/pricing)
- Railway: [railway.com/pricing](https://railway.com/pricing) y [docs.railway.com/reference/pricing](https://docs.railway.com/reference/pricing)
- Oracle Always Free: [docs.oracle.com · Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), [oracle.com/mysql/free](https://www.oracle.com/mysql/free/) y la reducción de Arm en 2026 ([InfoQ](https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/))
- Render: [render.com/docs/free](https://render.com/docs/free)
- TiDB Cloud Starter: [docs.pingcap.com · límites](https://docs.pingcap.com/tidbcloud/serverless-limitations/)
- Aiven: [aiven.io · MySQL free tier](https://aiven.io/docs/products/mysql/concepts/mysql-free-tier)
