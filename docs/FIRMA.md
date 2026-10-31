# Firma de contratos

## Qué hace hoy la app

- Cada parte dibuja su firma en el iPhone. El propietario puede recoger las dos si firman en persona;
  el inquilino solo puede firmar como arrendatario, desde su cuenta.
- La API guarda la imagen de la firma, quién firmó, cuándo, desde qué IP y una **huella SHA-256 de los
  datos del contrato** (partes, DNI, habitación, piso, fechas y renta).
- Si el contrato cambia después (por ejemplo, una actualización de la renta), la huella deja de
  coincidir: la app lo avisa y permite volver a firmar.
- El PDF firmado añade una hoja de firmas con las imágenes, los datos y la huella.

Es una **firma electrónica simple** según el Reglamento (UE) 910/2014 (eIDAS): vale como prueba
(art. 25.1: no se le puede negar efecto jurídico solo por ser electrónica), pero en caso de
conflicto quien la aporta tiene que demostrar su autenticidad.

## Cómo se pasaría a una firma con más validez

Para una **firma avanzada** (vinculada de forma única al firmante y capaz de detectar cambios) o
**cualificada** (con certificado cualificado, equivalente a la manuscrita, art. 25.2 eIDAS) habría
que delegar en un prestador de servicios de confianza, idealmente uno de la lista de confianza
española (TSL del Ministerio para la Transformación Digital).

El punto de enganche ya existe:

1. `FirmaService` es el único sitio que crea firmas; el campo `proveedor` de `FirmasContrato`
   vale hoy `EN_PANTALLA` y guardaría el del prestador.
2. El flujo con un prestador sería: la API sube el PDF del contrato al prestador, recibe un enlace
   de firma por parte, el firmante se identifica allí (SMS, vídeo o certificado) y el prestador
   avisa por *webhook*; la API guarda el PDF firmado que devuelve y su evidencia.
3. La app no cambiaría: en vez del panel de firma abriría el enlace del prestador.

No se ha contratado ni integrado ningún prestador (cuestan dinero y requieren un contrato): hay que
decidirlo antes.
