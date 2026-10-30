package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Actividad;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDate;
import com.gestionap.api.service.Textos;

import java.time.OffsetDateTime;
import java.util.List;

/** Respuestas de Inicio, Estadísticas y Calendario. */
public final class PanelDtos {

    private PanelDtos() {}

    /** Importe de un mes; la etiqueta va siempre en español ("oct"), sea cual sea el idioma del servidor. */
    public record ImporteMes(@Schema(example = "2026-10") String mes, @Schema(example = "oct") String etiqueta, BigDecimal importe) {}

    public record ConteoMes(String mes, String etiqueta, long cantidad) {}

    public record Ocupacion(long habitaciones, long alquiladas, long disponibles, long mantenimiento,
                            @Schema(description = "Porcentaje, p. ej. 66.67") double porcentaje,
                            @Schema(description = "Mismos umbrales que el escritorio: ≥ 75 % saludable, ≥ 40 % media")
                            String salud) {}

    public record Alerta(@Schema(example = "CONTRATOS_POR_VENCER") String tipo, String titulo, String mensaje,
                         @Schema(example = "aviso") String tono) {}

    public record ActividadResponse(Integer id, String accion, String descripcion, OffsetDateTime fecha) {
        public static ActividadResponse de(Actividad a) {
            return new ActividadResponse(a.getId(), a.getAccion(), a.getDescripcion(), Textos.conZona(a.getFecha()));
        }
    }

    public record DashboardResponse(
            Ocupacion ocupacion,
            long inquilinos,
            long contratosActivos,
            long incidenciasPendientes,
            long incidenciasEnProceso,
            @Schema(description = "Cobrado en el mes actual") BigDecimal cobradoMes,
            @Schema(description = "Cobrado en todo el mes anterior") BigDecimal cobradoMesAnterior,
            @Schema(description = "Cobrado en el mes anterior hasta el mismo día que hoy") BigDecimal cobradoMesAnteriorMismoDia,
            @Schema(description = "Día del mes anterior hasta el que se compara (hoy, o el último si es más corto)") int diaComparado,
            @Schema(description = "Mes con el que se compara, abreviado", example = "sept") String mesComparado,
            @Schema(description = "Variación del cobrado frente al mes anterior hasta el mismo día, en %; ausente si fue 0")
            Double tendenciaPct,
            @Schema(description = "Rentas de los contratos vigentes este mes") BigDecimal esperadoMes,
            @Schema(description = "Suma del cash flow mensual de los pisos con datos financieros") BigDecimal cashFlowMensual,
            List<ImporteMes> ingresosUltimos6Meses,
            List<Alerta> alertas,
            @Schema(description = "Contratos que vencen en 30 días o menos") List<ContratoResponse> proximosVencimientos,
            List<ActividadResponse> actividadReciente) {}

    public record EstadisticasResponse(
            List<ImporteMes> ingresos12Meses,
            Ocupacion ocupacion,
            List<ConteoMes> incidencias6Meses,
            BigDecimal ingresosAnioActual,
            @Schema(description = "Cobrado en todo el año anterior") BigDecimal ingresosAnioAnterior,
            @Schema(description = "Cobrado el año anterior hasta la misma fecha que hoy") BigDecimal ingresosAnioAnteriorHastaHoy,
            @Schema(description = "Fecha del año anterior hasta la que se compara") java.time.LocalDate fechaComparada,
            @Schema(description = "Variación frente al año anterior hasta la misma fecha, en %; ausente si entonces fue 0")
            Double variacionAnualPct,
            int anioActual) {}

    /** Estado de un día como en el escritorio: PAGADO, ESPERADO (días 1-5 aún por llegar), VENCIDO o NORMAL. */
    public record DiaCalendario(LocalDate fecha, String estado, List<PagoResponse> pagos,
                                @Schema(description = "Contratos que terminan ese día") List<ContratoResponse> vencimientos) {}

    public record CalendarioResponse(String mes, String nombreMes, BigDecimal esperado, BigDecimal cobrado,
                                     BigDecimal pendiente, List<DiaCalendario> dias) {}
}
