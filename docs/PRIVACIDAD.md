# Política de privacidad de GestionAp

Última actualización: 1 de noviembre de 2026.

GestionAp es una app para gestionar alquileres de habitaciones. Esta política explica qué datos
trata la app, para qué y cómo puedes ejercer tus derechos.

## Quién es el responsable
El propietario o la empresa que te da acceso a GestionAp (quien gestiona tu alquiler) es el
responsable de los datos de su cartera. La app los guarda en su servidor.

## Qué datos se tratan
- **Cuenta:** nombre, email, contraseña (guardada con BCrypt; nunca en claro) y rol.
- **Propietarios:** DNI e IBAN, si los añades, para los recibos y el código QR de pago.
- **Inquilinos:** nombre, DNI, teléfono y email que registra el propietario; contratos, pagos,
  recibos, incidencias (con fotos, si las adjuntas) y mensajes.
- **Dispositivo:** el identificador de notificaciones del iPhone, solo si activas los avisos.
- **Asistente:** si el servidor tiene el asistente activado, tus preguntas y los datos necesarios
  para responderlas se envían a la API de Claude (Anthropic) para generar la respuesta; no se
  usan para entrenar modelos. Nunca se envían DNI, teléfonos ni emails como contexto de pantalla.

## Para qué
Gestionar contratos, cobros, recibos, gastos, incidencias y la comunicación entre propietario e
inquilino, y cumplir las obligaciones legales (por ejemplo, conservar contratos y pagos).

## Dónde se guardan
En el servidor del propietario. En el iPhone solo se guardan el token de sesión (en el llavero),
tus preferencias de la app y una copia temporal para el widget.

## Cuánto tiempo
Mientras tengas cuenta. Si la eliminas (Ajustes › Cuenta › Eliminar cuenta), se borran tu nombre,
email, DNI e IBAN al momento. Los contratos, pagos y recibos se conservan el tiempo que exige la
ley (normativa fiscal y de arrendamientos) y luego se eliminan.

## Tus derechos
Puedes acceder a tus datos, corregirlos, exportarlos (Ajustes › Datos), eliminar tu cuenta y
oponerte a su tratamiento escribiendo al responsable. También puedes reclamar ante la Agencia
Española de Protección de Datos (www.aepd.es).

## Seguridad
Conexión cifrada (HTTPS), contraseñas con BCrypt, límite de intentos de acceso, comprobación de
contraseñas filtradas y bloqueo opcional con Face ID.
