# Face ID, widget y notificaciones (fase 8.2)

## Face ID
Perfil → «Entrar con Face ID». La app se bloquea al abrirse y al volver de segundo plano, y se desbloquea con
la cara o con el código del iPhone. El token de sesión sigue en el Keychain; esto protege la app abierta.
En el simulador: Features → Face ID → Enrolled, y Matching Face / Non-matching Face para probarlo.

## Widget «Cobros del mes»
Pequeño, mediano y de pantalla de bloqueo. Muestra lo cobrado este mes frente a lo esperado, cuántos
contratos no han pagado y las incidencias abiertas. La app guarda ese resumen en el App Group
`group.com.gestionap.GestionApPro` al cargar Inicio; el widget no tiene sesión ni hace peticiones. Al cerrar
sesión se borra. En el simulador: mantener pulsado el escritorio → «+» → GestionAp.

## Recordatorios en este iPhone (notificaciones locales)
Perfil → «Recordatorios en este iPhone». Funcionan sin cuenta de pago de Apple:
- Propietario: el día 8 de cada mes a las 9:00, revisar los cobros; y una semana antes de que termine un contrato.
- Inquilino: el día 4 de cada mes a las 9:00, recordar la renta (vence el día 7, LAU art. 17.2).

## Notificaciones push (preparadas, sin probar en real)
Necesitan una cuenta de pago de Apple Developer (99 $/año). Lo que ya está hecho:
- La app pide el token de APNs y lo envía a `POST /api/dispositivos` (tabla `Dispositivos`, migración V8).
- La API envía un push por cada aviso nuevo (cobro vencido, mensaje, recordatorio…) y, una vez al día a las
  9:00, genera los avisos de quien tiene un iPhone registrado. Sin credenciales no envía nada.

Para activarlas cuando haya cuenta:
1. En developer.apple.com: crear el identificador `com.gestionap.GestionApPro` con la capacidad Push Notifications
   y una clave APNs (.p8).
2. En `ios/project.yml`, añadir al target de la app el derecho `aps-environment: development` y el equipo de
   firma; regenerar con `xcodegen generate`.
3. En el servidor: `APNS_KEY_PATH=/ruta/AuthKey_XXXX.p8`, `APNS_KEY_ID=XXXX`, `APNS_TEAM_ID=YYYY` (y
   `APNS_PRODUCCION=true` para la App Store).

Probar cómo se ve un push en el simulador, sin cuenta (con los recordatorios activados para dar el permiso):

```bash
cat > /tmp/push.apns <<'JSON'
{"Simulator Target Bundle": "com.gestionap.GestionApPro",
 "aps": {"alert": {"title": "Cobro vencido", "body": "Natalia Castro López · 450,00 €"}, "sound": "default"}}
JSON
xcrun simctl push booted /tmp/push.apns
```
