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

Modelo: Claude Opus 5.5 (`claude-opus-5-5`, configurable en `gestionap.ia.modelo`), con el SDK oficial de
Java. Si los filtros de seguridad rechazan una petición, la API reintenta con otro modelo (*fallback* del
servidor). Si aun así no puede, el asistente lo dice.

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

   En el arranque debe salir `Asistente activo con el modelo claude-opus-5-5`
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

Coste orientativo: cada pregunta usa unos pocos miles de tokens (a 4 $ y 20 $ por millón de tokens de
entrada y salida en Claude Opus 5.5), es decir, céntimos por consulta.

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
