# Caso de estudio: GestionAp PRO móvil

Pensado para contarlo en una entrevista de banca o consultoría en 5–10 minutos: el problema, cómo lo
abordé, qué decidí y por qué, y qué aprendí. Los datos son de demostración (ficticios).

## 1. El contexto

Una aplicación de escritorio (JavaFX + MariaDB) gestionaba alquileres de habitaciones: pisos, inquilinos,
contratos, cobros e incidencias. Funcionaba, pero:

- solo se podía usar delante del ordenador;
- el inquilino no tenía acceso a nada;
- no respondía a preguntas que un propietario se hace cada mes: ¿quién no ha pagado?, ¿cuánto puedo subir
  la renta este año?, ¿cuánto gano de verdad con este piso después de gastos e impuestos?

**Objetivo:** llevarla al móvil sin reescribirla ni romperla, y añadir lo que un usuario espera de un
producto comercial (comparable a Rentila o Rentger).

## 2. Restricciones (lo que hizo el problema interesante)

| Restricción | Consecuencia |
|---|---|
| La base de datos es compartida con el escritorio, que sigue en uso | Ninguna migración puede romperlo: solo tablas nuevas o columnas opcionales; copia de seguridad antes de cada cambio |
| Datos de personas (DNI, IBAN, contratos) | Seguridad por roles desde el diseño; cada usuario ve solo lo suyo |
| Normativa que cambia (Ley de Vivienda, índices de actualización, IRPF) | Nada de cifras inventadas: fuentes oficiales y parámetros configurables |
| Un solo desarrollador y presupuesto cero | Herramientas gratuitas, nada de proveedores de pago sin decidirlo antes |

## 3. Qué construí

- **API REST** (Spring Boot 3.5, Java 21): 100 endpoints, JWT y tres roles, con 199 tests automáticos.
- **App iOS** nativa (SwiftUI, Swift 6) para propietario e inquilino, con un sistema de diseño propio y 79 tests.
- Funciones nuevas sobre lo que ya hacía el escritorio:
  - Recibos numerados y fianzas.
  - Actualización de renta con índices oficiales.
  - Gastos reales con factura y resumen fiscal orientativo.
  - Conciliación bancaria y firma de contratos.
  - Mensajería y un asistente con IA.

## 4. Decisiones clave (y alternativas descartadas)

**a) Convivir con el sistema antiguo en lugar de sustituirlo.**
Reescribir el escritorio habría sido más «limpio», pero arriesgado y sin valor para el usuario. Decidí que la
API se adapta a la base existente: valida el esquema al arrancar, traduce los roles antiguos y solo añade
tablas. Es el mismo problema que una entidad financiera con un *core* heredado: se construyen capas nuevas
alrededor sin tocar lo que funciona.

**b) La regulación, como un requisito más.**
- **La actualización anual de la renta:** depende de la fecha del contrato (Ley 12/2023) y, desde octubre
  de 2026, de un tope del índice IRAV (art. 18.1 de la LAU en la redacción del RDL 29/2026).
- **Cómo la resolví:** la API lee el IRAV y el IPC en directo de la API oficial del INE, cita la fuente en
  cada propuesta y aplica el tope de forma configurable, porque el decreto aún podía no convalidarse.
- **Quién decide:** el propietario revisa y confirma, y queda trazado en un historial.

Es la lógica de un banco con un cambio normativo: dato oficial, trazabilidad y decisión humana.

**c) Seguridad y control de acceso medibles.**
- **Quién ve qué:** cada servicio comprueba si el usuario puede ver el recurso, y un recurso ajeno
  responde 404, para no revelar qué existe.
- **Probado, no supuesto:** cada módulo tiene tests de aislamiento (otro propietario no ve nada; el
  inquilino solo lo suyo).
- **Archivos subidos:** se valida el formato real, no la extensión.
- **Secretos:** nunca en el repositorio.

**d) Integridad de los datos con concurrencia.**
Dos pagos registrados a la vez no pueden tomar el mismo número de recibo. Lo resolví con un bloqueo de fila y
una clave única. El primer intento tenía un fallo sutil: con el aislamiento REPEATABLE READ de MariaDB, la
consulta podía leer una «foto» anterior al bloqueo. Lo detectó la revisión cruzada y lo corregí con una
lectura bloqueante.

**e) IA con límites claros.**
- **Qué hace:** el asistente responde sobre la cartera usando las herramientas de la API, con los permisos
  del usuario y sin generar SQL.
- **Qué no hace:** no ejecuta acciones; las propone, y el usuario las confirma con los endpoints normales.
- **Coste y control:**
  - límite diario por usuario y registro en Actividad;
  - modelo configurable, por defecto el más económico (≈ 0,2 céntimos por consulta);
  - tests con un modelo simulado.

Es el patrón *human-in-the-loop* que piden los equipos de riesgo para usar IA en procesos con impacto económico.

**f) La nube: comparar antes de elegir.**
Comparé tres opciones (Railway, Oracle Always Free y Supabase). Migrar a PostgreSQL (Supabase) obligaba a
cambiar también el escritorio, así que lo descarté. La decisión final queda documentada y pendiente, sin
crear cuentas ni gastar.

## 5. Cómo trabajé

- **Fases cortas**, cada una con sus tests, capturas en modo claro y oscuro, documentación, revisión de
  secretos y su commit (76+ commits en la rama principal).
- **Revisión de código en cada bloque:** ningún bloque se integró sin revisión de código; los módulos más
  grandes se desarrollaron en una rama aparte y se revisaron antes de integrarlos.
  - **Resultados de la revisión:** de unas 70 observaciones de revisión, se corrigieron cerca de dos
    tercios. Las demás se descartaron por escrito, con su motivo.
  - **Lo que se aprende:** la revisión sistemática detecta mucho, pero las decisiones (qué riesgo aceptar, qué norma aplicar,
    qué no automatizar) siguen siendo del responsable del producto.
- **Datos y privacidad:** antes de publicar, los datos de demostración se anonimizaron (DNI ficticios,
  dominios `@example.com`).

## 6. Resultados

| Indicador | Valor |
|---|---|
| Código | ≈ 11.000 líneas de Java y ≈ 11.500 de Swift |
| Tests | 199 en la API y 79 en iOS, en CI con GitHub Actions |
| Migraciones de base | 8, todas aditivas; el escritorio sigue funcionando |
| Repositorio | Capturas de trabajo fuera del repositorio: los archivos versionados pasaron de 18,5 a 5,6 MB |
| Coste de la IA | ≈ 0,002 $ por consulta con Claude Haiku 5.5 (estimación con precios oficiales) |

## 7. Qué haría distinto

- **Migraciones:** Flyway desde el principio, en lugar de scripts SQL aplicados a mano.
- **Escritorio:** consumir la API en lugar de la base de datos directamente. Así se podría cambiar de
  motor de base de datos y centralizar la seguridad.
- **Legal:** contrastar antes las reglas legales con un profesional; aquí son orientativas y están marcadas así.
- **Usuarios:** medir con propietarios reales qué funciones usan antes de añadir más.

## 8. Preguntas que pueden hacerme

- **«¿Cómo garantizas que un propietario no ve datos de otro?»** Con control de acceso en cada servicio, 404
  para lo ajeno y tests de aislamiento en cada módulo, que se ejecutan en cada push.
- **«¿Qué pasa si cambia la ley?»** Los índices se leen de la fuente oficial, el tope es configurable y cada
  decisión cita su norma en `docs/DECISIONES.md`. La propuesta es orientativa y la confirma una persona.
- **«¿Cómo controlas el riesgo de la IA?»** No ejecuta nada: propone y el usuario confirma. Solo accede a datos
  a través de las herramientas, con sus permisos. Tiene un límite de uso, registro de auditoría y tests
  sin llamar al modelo real.
- **«¿Por qué no PostgreSQL / microservicios?»** Porque el valor estaba en no romper un sistema en uso. Un
  monolito por capas, bien probado, es más fácil de operar para un equipo pequeño.
- **«¿Qué decidiste tú?»** El producto y las reglas: la arquitectura, la priorización,
  la revisión de cada bloque y las decisiones de riesgo. Por ejemplo, qué norma aplicar, qué no automatizar
  y qué hallazgos de la revisión aceptar o descartar, y por qué.
