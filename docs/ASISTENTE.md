# Asistente GestionAp (IA)

## Qué hace

- **Responde preguntas sobre tu cartera** («¿Quién me debe este mes?», «¿Qué contratos vencen pronto?»).
  Para hacerlo consulta tus pisos, cobros, contratos, incidencias y gastos con las herramientas de la API,
  y con tus mismos permisos: nunca ejecuta SQL ni ve datos de otros propietarios.
- **Prepara acciones que confirmas tú:** registrar un pago, crear una incidencia o un recordatorio de pago.
  No se hace nada hasta que pulsas «Confirmar» en la app. Entonces la app usa los mismos endpoints de
  siempre, con sus validaciones.
- **Lee la foto de una factura** y propone el gasto (proveedor, concepto, fecha, importe y categoría).
  Tú lo revisas antes de guardarlo.
- **Sugiere la categoría y la urgencia** de una incidencia nueva.
- **Explica el informe del mes** en pocas frases.

Cada consulta cuenta para un límite diario por usuario (40 por defecto, `gestionap.ia.limite-diario`) y
queda en Actividad, sin el texto de la conversación. Solo pueden usarlo el propietario y el administrador.

Modelo: **Claude Haiku 5.5** (`claude-haiku-5-5`), el más económico de la generación actual, que admite
herramientas e imágenes, con el SDK oficial de Java. Se cambia con la variable de entorno `ASISTENTE_MODELO`
(por ejemplo, `claude-sonnet-5-5` o `claude-opus-5-5` si alguna respuesta se queda corta). Si los filtros de
seguridad rechazan una petición, el asistente lo dice. En Sonnet 5.5 y Opus 5.5 la API reintenta antes con
otro modelo (*fallback* del servidor); Haiku 5.5 no tiene esa opción.

## Sin clave

Sin `ANTHROPIC_API_KEY` la API arranca igual y el asistente aparece desactivado con este mensaje:
«Falta la clave de la API de Claude en el servidor. Cuando se configure, podrás usarlo aquí».
Los tests usan un modelo simulado y no necesitan clave.

## Activarlo cuando tengas la clave

La clave **nunca** va en la app ni en el repositorio: solo en el servidor, como variable de entorno.

1. Crea la clave en [platform.claude.com](https://platform.claude.com) → API Keys. Pon un límite de gasto
   mensual en Billing → Limits (por ejemplo, 10 €).
2. Guárdala en un archivo fuera del repositorio, legible solo por ti:

   ```bash
   mkdir -p ~/.config/gestionap
   printf 'ANTHROPIC_API_KEY=%s\n' 'sk-ant-...tu-clave...' > ~/.config/gestionap/ia.env
   chmod 600 ~/.config/gestionap/ia.env
   ```

3. Arranca la API con esa variable cargada (en la misma pestaña de Terminal):

   ```bash
   cd ~/Desktop/gestionapro-mobile/api
   set -a; source ~/.config/gestionap/ia.env; set +a
   export JWT_SECRET=$(openssl rand -base64 48)
   mvn spring-boot:run -Dspring-boot.run.profiles=dev
   ```

   En el arranque debe salir `Asistente activo con el modelo claude-haiku-5-5`
   (si sale `Asistente desactivado: falta ANTHROPIC_API_KEY`, la variable no se ha cargado).

## Prueba real

Con la API arrancada y la app en el simulador, entra como propietario:

1. Más → Asistente. Debe decir «Pregúntame por tu cartera…» y «0 de 40 consultas hoy».
2. Pregunta «¿Quién me debe este mes?». La respuesta debe nombrar a los inquilinos que aparecen en
   Cobros → pendientes, con sus importes, y ningún dato de otro propietario.
3. Pregunta «Registra el pago de 450 € de Natalia de hoy». Debe aparecer una tarjeta «Registrar pago…»
   y Cobros **no** debe cambiar hasta que pulses «Confirmar». Después, el pago aparece con su recibo.
4. Pregunta «Explícame el informe del mes».
5. Gastos de un piso → Nuevo gasto → foto de una factura → «Rellenar con el asistente». Revisa los datos.
6. Nueva incidencia → escribe «Sale agua por debajo del lavabo» → «Sugerir categoría y urgencia».

## Coste aproximado

Precios oficiales de la API ([platform.claude.com/docs/en/about-claude/pricing](https://platform.claude.com/docs/en/about-claude/pricing),
consultados el 31-10-2026), en dólares por millón de tokens:

| Modelo | Entrada | Salida |
|---|---|---|
| Claude Haiku 5.5 (por defecto; prompts de hasta 100.000 tokens) | 0,10 $ | 0,50 $ |
| Claude Sonnet 5.5 | 2 $ | 10 $ |
| Claude Opus 5.5 | 4 $ | 20 $ |

Una consulta típica («¿Quién me debe este mes?») son unas 3 llamadas al modelo, porque pide una o dos
herramientas y luego responde. Cada llamada reenvía las instrucciones (unos 380 tokens), la definición de
las 8 herramientas (unos 700) y el texto que la API añade al usar herramientas (286 tokens en Haiku 5.5).
También reenvía lo que devolvieron las herramientas: entre 2,8 y 7,7 KB con los datos de demo, es decir,
unos 1.000-2.500 tokens cada una. En total, del orden de **12.000 tokens de entrada y 2.000 de salida**,
contando el razonamiento.

| | Haiku 5.5 | Sonnet 5.5 | Opus 5.5 |
|---|---|---|---|
| Una consulta | ≈ 0,002 $ (0,2 céntimos) | ≈ 0,04 $ | ≈ 0,09 $ |
| 1.000 consultas | ≈ 2 $ | ≈ 44 $ | ≈ 88 $ |
| Leer una factura (foto ≈ 1.700 tokens) | ≈ 0,0005 $ | ≈ 0,01 $ | ≈ 0,02 $ |
| Máximo de un usuario al día (límite de 40) | ≈ 0,09 $ | ≈ 1,8 $ | ≈ 3,5 $ |

Son estimaciones: el coste real de cada llamada sale en el `usage` de la respuesta y en la consola de
Anthropic. Con una cartera más grande, las respuestas de las herramientas crecen y la consulta cuesta más.

Comprobación sin la app:

```bash
TOKEN=$(curl -s localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@gestionap.com","password":"…"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s localhost:8080/api/asistente/estado -H "Authorization: Bearer $TOKEN"
curl -s localhost:8080/api/asistente/conversar -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"mensaje":"¿Quién me debe este mes?"}'
```

## Cómo está hecho

- `api/.../service/ia/ModeloIA.java`: la interfaz del modelo (conversar con herramientas y extraer datos
  con formato fijo).
- `ModeloClaude.java`: la implementación con la API de Claude. Lleva su propio bucle de herramientas y
  devuelve al modelo cada respuesta entera.
- `ModeloSimulado.java` (tests): ejecuta las herramientas que cada test le pide.
- `AsistenteService.java`: las instrucciones, las herramientas, las propuestas, el límite y la Actividad.
