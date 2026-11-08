package com.gestionap.api.service;

import com.gestionap.api.domain.TipoInmueble;
import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Gasto;
import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.domain.Pago;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.GastoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.AnalisisDtos.*;
import com.gestionap.api.web.dto.PisoBreve;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/**
 * Estadísticas de un periodo (cartera, piso o habitación): ingresos frente a gastos, ranking de
 * pisos, ocupación histórica, días medios vacía, morosidad, rotación y comparación con el año anterior.
 *
 * La ocupación se calcula con los contratos (días cubiertos por un contrato) sobre las habitaciones
 * actuales: el sistema no guarda cuándo se dio de alta una habitación ni el historial de mantenimiento.
 * Los días posteriores a hoy no cuentan.
 */
@Service
public class AnalisisService {

    /** Periodo máximo: 5 años. */
    static final long DIAS_MAX = 5L * 366;

    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final GastoRepository gastos;
    private final ControlAcceso acceso;

    public AnalisisService(HabitacionRepository habitaciones, ContratoRepository contratos, PagoRepository pagos,
                           GastoRepository gastos, ControlAcceso acceso) {
        this.habitaciones = habitaciones;
        this.contratos = contratos;
        this.pagos = pagos;
        this.gastos = gastos;
        this.acceso = acceso;
    }

    /** Lo que entra en el análisis: habitaciones, contratos y si un gasto cuenta. */
    private record Ambito(String nombre, List<Habitacion> habitaciones, List<Contrato> contratos, Predicate<Gasto> gasto) {}

    @Transactional(readOnly = true)
    public AnalisisResponse analizar(LocalDate desde, LocalDate hasta, Integer idPiso, Integer idHabitacion,
                                     UsuarioAutenticado actor) {
        return analizar(desde, hasta, idPiso, idHabitacion, null, actor);
    }

    /** {@code tipo} filtra la cartera por tipo de inmueble; con un piso o habitación concretos no se usa. */
    @Transactional(readOnly = true)
    public AnalisisResponse analizar(LocalDate desde, LocalDate hasta, Integer idPiso, Integer idHabitacion,
                                     TipoInmueble tipo, UsuarioAutenticado actor) {
        if (desde == null || hasta == null) throw ApiException.badRequest("PERIODO_INVALIDO", "Indica desde y hasta");
        if (hasta.isBefore(desde)) throw ApiException.badRequest("PERIODO_INVALIDO", "hasta no puede ser anterior a desde");
        if (ChronoUnit.DAYS.between(desde, hasta) > DIAS_MAX) {
            throw ApiException.badRequest("PERIODO_INVALIDO", "El periodo no puede superar 5 años");
        }
        if (desde.getYear() < 2000) throw ApiException.badRequest("PERIODO_INVALIDO", "desde debe ser posterior a 2000");
        Ambito ambito = ambito(idPiso, idHabitacion, tipo, actor);
        LocalDate hoy = LocalDate.now();
        Integer prop = acceso.filtroPropietario(actor);

        Calculo actual = calcular(ambito, desde, hasta, hoy, prop);
        Calculo anterior = calcular(ambito, desde.minusYears(1), hasta.minusYears(1), hoy, prop);

        // Ranking por piso (solo tiene sentido en la cartera; en un piso o habitación sale una fila).
        Map<Integer, List<Habitacion>> habsPorPiso = ambito.habitaciones().stream()
                .collect(Collectors.groupingBy(h -> h.getPiso().getId(), LinkedHashMap::new, Collectors.toList()));
        List<PisoAnalisis> porPiso = new ArrayList<>();
        habsPorPiso.forEach((id, habs) -> {
            Set<Integer> ids = habs.stream().map(Habitacion::getId).collect(Collectors.toSet());
            BigDecimal ing = suma(actual.pagos.stream().filter(p -> ids.contains(p.getContrato().getHabitacion().getId()))
                    .map(Pago::getCantidad));
            BigDecimal gas = suma(actual.gastos.stream().filter(g -> g.getPiso().getId().equals(id)).map(Gasto::getImporte));
            Ocupacion o = ocupacion(habs, ambito.contratos(), desde, hasta, hoy);
            porPiso.add(new PisoAnalisis(PisoBreve.de(habs.getFirst().getPiso()), ing, gas, ing.subtract(gas),
                    o.pct(), o.diasMediosVacia(), habs.size()));
        });
        porPiso.sort(Comparator.comparing(PisoAnalisis::neto).reversed()
                .thenComparing(p -> p.piso().direccion()));

        List<MesAnalisis> meses = new ArrayList<>();
        for (YearMonth m = YearMonth.from(desde); !m.isAfter(YearMonth.from(hasta)); m = m.plusMonths(1)) {
            LocalDate ini = max(m.atDay(1), desde), fin = min(m.atEndOfMonth(), hasta);
            YearMonth mes = m;
            BigDecimal ing = suma(actual.pagos.stream().filter(p -> YearMonth.from(p.getFechaPago()).equals(mes)).map(Pago::getCantidad));
            BigDecimal gas = suma(actual.gastos.stream().filter(g -> YearMonth.from(g.getFecha()).equals(mes)).map(Gasto::getImporte));
            Double ocup = m.atDay(1).isAfter(hoy) ? null : ocupacion(ambito.habitaciones(), ambito.contratos(), ini, fin, hoy).pct();
            meses.add(new MesAnalisis(m.toString(), Textos.mesCorto(m), ing, gas, ocup));
        }

        return new AnalisisResponse(desde, hasta, ambito.nombre(), actual.totales, anterior.totales, porPiso, meses,
                morosidad(ambito.contratos(), actual.pagos, desde, hasta, hoy));
    }

    private Ambito ambito(Integer idPiso, Integer idHabitacion, TipoInmueble tipo, UsuarioAutenticado actor) {
        Integer prop = acceso.filtroPropietario(actor);
        if (idHabitacion != null) {
            Habitacion h = habitaciones.findConPisoById(idHabitacion)
                    .filter(x -> acceso.puedeVerPiso(x.getPiso(), actor))
                    .orElseThrow(() -> ApiException.noEncontrado("Habitación"));
            if (idPiso != null && !idPiso.equals(h.getPiso().getId())) {
                throw ApiException.badRequest("AMBITO_INVALIDO", "La habitación no es de ese piso");
            }
            List<Contrato> cs = contratos.buscar(prop, null, h.getPiso().getId()).stream()
                    .filter(c -> c.getHabitacion().getId().equals(h.getId())).toList();
            return new Ambito("HABITACION", List.of(h), cs,
                    g -> g.getHabitacion() != null && g.getHabitacion().getId().equals(h.getId()));
        }
        if (idPiso != null) {
            acceso.pisoVisible(idPiso, actor);
            return new Ambito("PISO", habitaciones.buscar(prop, idPiso, null), contratos.buscar(prop, null, idPiso),
                    g -> g.getPiso().getId().equals(idPiso));
        }
        if (tipo != null) {
            return new Ambito("CARTERA",
                    habitaciones.buscar(prop, null, null).stream().filter(h -> h.getPiso().getTipo() == tipo).toList(),
                    contratos.buscar(prop, null, null).stream().filter(c -> c.getHabitacion().getPiso().getTipo() == tipo).toList(),
                    g -> g.getPiso().getTipo() == tipo);
        }
        return new Ambito("CARTERA", habitaciones.buscar(prop, null, null), contratos.buscar(prop, null, null), g -> true);
    }

    private record Calculo(Totales totales, List<Pago> pagos, List<Gasto> gastos) {}

    private Calculo calcular(Ambito a, LocalDate desde, LocalDate hasta, LocalDate hoy, Integer prop) {
        Set<Integer> ids = a.habitaciones().stream().map(Habitacion::getId).collect(Collectors.toSet());
        List<Pago> ps = pagos.buscar(prop, null, desde, hasta).stream()
                .filter(p -> ids.contains(p.getContrato().getHabitacion().getId())).toList();
        List<Gasto> gs = gastos.buscar(prop, null, desde, hasta).stream()
                .filter(a.gasto()).toList();
        BigDecimal ing = suma(ps.stream().map(Pago::getCantidad));
        BigDecimal gas = suma(gs.stream().map(Gasto::getImporte));
        Ocupacion o = ocupacion(a.habitaciones(), a.contratos(), desde, hasta, hoy);
        LocalDate finReal = min(hasta, hoy);
        List<Contrato> iniciados = a.contratos().stream()
                .filter(c -> !c.getFechaInicio().isBefore(desde) && !c.getFechaInicio().isAfter(hasta)).toList();
        List<Contrato> finalizados = a.contratos().stream()
                .filter(c -> !c.getFechaFin().isBefore(desde) && !c.getFechaFin().isAfter(finReal)).toList();
        Double duracion = finalizados.isEmpty() ? null : redondear(finalizados.stream()
                .mapToDouble(c -> ChronoUnit.DAYS.between(c.getFechaInicio(), c.getFechaFin()) / 30.4375).average().orElse(0));
        int nHab = a.habitaciones().size();
        BigDecimal impagado = suma(morosidad(a.contratos(), ps, desde, hasta, hoy).stream().map(Morosidad::importeImpagado));
        return new Calculo(new Totales(ing, gas, ing.subtract(gas), o.pct(), o.diasMediosVacia(), nHab,
                iniciados.size(), finalizados.size(), duracion,
                nHab == 0 ? 0 : redondear(finalizados.size() * 100.0 / nHab), impagado), ps, gs);
    }

    private record Ocupacion(double pct, double diasMediosVacia) {}

    /** Días cubiertos por algún contrato en [desde, min(hasta, hoy)], por habitación. */
    static Ocupacion ocupacion(List<Habitacion> habs, List<Contrato> cs, LocalDate desde, LocalDate hasta, LocalDate hoy) {
        LocalDate fin = min(hasta, hoy);
        if (habs.isEmpty() || fin.isBefore(desde)) return new Ocupacion(0, 0);
        long dias = ChronoUnit.DAYS.between(desde, fin) + 1;
        Map<Integer, List<Contrato>> porHab = cs.stream().collect(Collectors.groupingBy(c -> c.getHabitacion().getId()));
        long ocupados = 0;
        for (Habitacion h : habs) {
            ocupados += diasCubiertos(porHab.getOrDefault(h.getId(), List.of()), desde, fin);
        }
        long totales = dias * habs.size();
        return new Ocupacion(redondear(ocupados * 100.0 / totales), redondear((totales - ocupados) / (double) habs.size()));
    }

    /** Unión de los intervalos de los contratos recortados al periodo (sin contar dos veces los solapes). */
    private static long diasCubiertos(List<Contrato> cs, LocalDate desde, LocalDate fin) {
        List<LocalDate[]> tramos = cs.stream()
                .map(c -> new LocalDate[]{max(c.getFechaInicio(), desde), min(c.getFechaFin(), fin)})
                .filter(t -> !t[1].isBefore(t[0]))
                .sorted(Comparator.comparing(t -> t[0])).toList();
        long total = 0;
        LocalDate ini = null, hastaT = null;
        for (LocalDate[] t : tramos) {
            if (ini == null) { ini = t[0]; hastaT = t[1]; continue; }
            if (!t[0].isAfter(hastaT.plusDays(1))) { hastaT = max(hastaT, t[1]); continue; }
            total += ChronoUnit.DAYS.between(ini, hastaT) + 1;
            ini = t[0]; hastaT = t[1];
        }
        if (ini != null) total += ChronoUnit.DAYS.between(ini, hastaT) + 1;
        return total;
    }

    /**
     * Meses del periodo ya vencidos (anteriores al mes actual) en que cada contrato estaba vigente:
     * impagado si no hubo ningún pago ese mes, fuera de plazo si el primero llegó después del día 5.
     */
    private static List<Morosidad> morosidad(List<Contrato> cs, List<Pago> ps, LocalDate desde, LocalDate hasta, LocalDate hoy) {
        Map<String, LocalDate> primerPago = new HashMap<>();
        for (Pago p : ps) {
            primerPago.merge(p.getContrato().getId() + "|" + YearMonth.from(p.getFechaPago()), p.getFechaPago(),
                    (a, b) -> a.isBefore(b) ? a : b);
        }
        YearMonth ultimo = min(YearMonth.from(hasta), YearMonth.from(hoy).minusMonths(1));
        Map<Integer, int[]> cuentas = new LinkedHashMap<>();
        Map<Integer, BigDecimal> importes = new HashMap<>();
        Map<Integer, String> nombres = new HashMap<>();
        for (Contrato c : cs) {
            for (YearMonth m = YearMonth.from(desde); !m.isAfter(ultimo); m = m.plusMonths(1)) {
                boolean vigente = !c.getFechaInicio().isAfter(m.atEndOfMonth()) && !c.getFechaFin().isBefore(m.atDay(1));
                if (!vigente) continue;
                Integer idInq = c.getInquilino().getId();
                nombres.putIfAbsent(idInq, c.getInquilino().getNombreCompleto());
                int[] k = cuentas.computeIfAbsent(idInq, x -> new int[3]); // debidos, impagados, tarde
                k[0]++;
                LocalDate pago = primerPago.get(c.getId() + "|" + m);
                if (pago == null) {
                    k[1]++;
                    importes.merge(idInq, c.getPrecioMensual(), BigDecimal::add);
                } else if (pago.getDayOfMonth() > PagoService.DIA_LIMITE_PAGO) {
                    k[2]++;
                }
            }
        }
        return cuentas.entrySet().stream().map(e -> {
            int[] k = e.getValue();
            return new Morosidad(e.getKey(), nombres.get(e.getKey()), k[0], k[1], k[2],
                    importes.getOrDefault(e.getKey(), BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP),
                    redondear((k[0] - k[1] - k[2]) * 100.0 / k[0]));
        }).sorted(Comparator.comparing(Morosidad::importeImpagado).reversed()
                .thenComparing(Morosidad::puntualidadPct).thenComparing(Morosidad::nombre)).toList();
    }

    private static BigDecimal suma(java.util.stream.Stream<BigDecimal> s) {
        return s.reduce(BigDecimal.ZERO, BigDecimal::add).setScale(2, RoundingMode.HALF_UP);
    }

    private static double redondear(double v) { return Math.round(v * 100) / 100.0; }
    private static LocalDate max(LocalDate a, LocalDate b) { return a.isAfter(b) ? a : b; }
    private static LocalDate min(LocalDate a, LocalDate b) { return a.isBefore(b) ? a : b; }
    private static YearMonth min(YearMonth a, YearMonth b) { return a.isBefore(b) ? a : b; }
}
