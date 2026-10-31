# GestionAp PRO frente a Rentila y Rentger (nota sincera)

Escrita el 31-10-2026. De Rentila y Rentger solo se afirma lo que figura en sus fichas públicas
([Rentger en Appvizer](https://www.appvizer.es/organizacion-planificacion/gestion-alquiler/rentger),
[Rentger en Softwaredoit](https://www.softwaredoit.es/rentger/rentger.html),
[Idealista compra Rentger](https://www.idealista.com/news/node/788552),
[Rentila en Softwaredoit](https://www.softwaredoit.es/rentila/rentila.html),
[Rentila en el App Store](https://apps.apple.com/mx/app/rentila/id403695251)). No he podido usar ninguno de los dos.

## Lo que son ellos

- **Rentger:** SaaS español del grupo Idealista. Cubre desde la comercialización hasta el fin del
  contrato, con integraciones bancarias, incidencias, inquilinos y habitaciones. Es gratis hasta 9
  inmuebles. Al adquirirlo Idealista gestionaba más de 10.000 activos.
- **Rentila:** software en la nube para propietarios particulares, con recibos automáticos cada mes y
  app para iPhone. Es gratis para un inmueble.

Los dos son **productos en producción**, con miles de usuarios, soporte, web y app, y años de casos reales.

## Dónde GestionAp está a la altura o por delante

- **Pensado para habitaciones**, con ocupación, rentabilidad por piso y calculadora con el ITP de cada comunidad.
- **Vista del inquilino** completa: contrato, recibos, fianza, historial de renta, inventarios, incidencias
  con fotos y mensajes.
- **Actualización de renta con el INE en directo** y el tope legal del IRAV, citando la fuente.
- **Resumen fiscal anual** orientativo con las reglas de la Agencia Tributaria (límite de gastos,
  amortización del 3 % y del mobiliario), en PDF y CSV.
- **Asistente con IA** que consulta la cartera y propone acciones que confirma el usuario. No he visto nada
  equivalente en sus fichas.
- **Calidad técnica comprobable:** 199 tests en la API y 79 en iOS, control de acceso probado módulo a
  módulo, diseño accesible en modo claro y oscuro.

## Dónde está por detrás (lo que faltaría para competir)

1. **No está en producción.** No hay servidor en la nube, ni usuarios reales, ni copias de seguridad
   automáticas, ni monitorización. Ellos sí.
2. **Sin web ni Android.** Solo iPhone, más un escritorio que depende de la base de datos.
3. **Banca:** solo conciliación por CSV. Rentger anuncia integraciones bancarias; aquí PSD2 está solo
   documentado.
4. **Firma legal:** la firma en pantalla es simple; para un contrato con plena validez haría falta un
   prestador de confianza (no integrado).
5. **Cobros:** no cobra la renta (domiciliación, pasarela de pago, remesas SEPA); solo los registra y
   genera el QR de transferencia.
6. **Comercialización:** no publica anuncios ni gestiona candidatos (Rentger sí, y está en Idealista).
7. **Notificaciones push reales y App Store:** preparadas, pero sin la cuenta de Apple Developer.
8. **Legal y empresa:** falta lo que exige ofrecerlo a terceros: política de privacidad, contrato de
   encargado del tratamiento (RGPD), condiciones de uso, facturación del servicio y soporte.
9. **Validación:** las reglas fiscales y legales son orientativas y no las ha revisado un profesional.
10. **Escala:** hecho y probado con datos de demostración de 8 pisos. No se ha medido con miles de inmuebles.

## En una frase

Como **proyecto de portfolio** está por encima de lo habitual: un producto completo, probado y documentado,
con decisiones de riesgo y regulación bien explicadas. Como **producto comercial**, todavía no compite con
Rentila ni con Rentger. Los pasos que más acercarían serían, por este orden:

1. Desplegarlo.
2. Una web para el propietario.
3. Cobros reales (SEPA y pasarela).
4. Firma con un prestador de confianza.
5. Cumplimiento RGPD.
6. Validar con propietarios reales.
