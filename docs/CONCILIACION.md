# Conciliación bancaria

El propietario o administrador carga un CSV de movimientos. La API propone el contrato más probable para cada ingreso, muestra la confianza y señala pagos ya registrados. Las propuestas de confianza baja no se preseleccionan. No se guarda el extracto ni se crea ningún pago hasta que el usuario confirme; los pagos confirmados pasan por el servicio habitual y reciben su número de recibo. Se rechazan duplicados.

Se admiten CSV con separador punto y coma, coma o tabulador; codificación UTF-8 (con o sin BOM) o ISO-8859-1; importes españoles como `1.234,56`; y fechas `dd/MM/yyyy`, `dd-MM-yyyy` o `yyyy-MM-dd`. Se busca una cabecera de fecha, concepto e importe (o cargo/abono o debe/haber), incluso después de líneas de título. Los formatos bancarios son aproximados: conviene probar con extractos reales de cada entidad.

Una integración futura podría usar un agregador con licencia de AIS, que ofrece acceso a cuentas bajo la Directiva (UE) 2015/2366. El consentimiento del titular es renovable cada 180 días según el Reglamento Delegado (UE) 2022/2360. El backend recibiría los movimientos por webhook o consulta y reutilizaría el mismo emparejamiento; esta funcionalidad no contrata ni integra proveedores PSD2.
