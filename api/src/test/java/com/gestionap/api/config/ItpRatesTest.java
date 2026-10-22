package com.gestionap.api.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.env.PropertySource;
import org.springframework.mock.env.MockEnvironment;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

public class ItpRatesTest {

    /** ITP_MAP de RentabilidadController (escritorio), volcado del controlador real el 2026-10-22. */
    static final Map<String, Double> ITP_ESCRITORIO = new LinkedHashMap<>();
    static {
        ITP_ESCRITORIO.put("Andalucía", 7.0);
        ITP_ESCRITORIO.put("Aragón", 8.0);
        ITP_ESCRITORIO.put("Asturias", 8.0);
        ITP_ESCRITORIO.put("Baleares", 8.0);
        ITP_ESCRITORIO.put("Canarias", 6.5);
        ITP_ESCRITORIO.put("Cantabria", 10.0);
        ITP_ESCRITORIO.put("Castilla-La Mancha", 9.0);
        ITP_ESCRITORIO.put("Castilla y León", 8.0);
        ITP_ESCRITORIO.put("Cataluña", 10.0);
        ITP_ESCRITORIO.put("Ceuta", 6.0);
        ITP_ESCRITORIO.put("Comunitat Valenciana", 10.0);
        ITP_ESCRITORIO.put("Extremadura", 8.0);
        ITP_ESCRITORIO.put("Galicia", 10.0);
        ITP_ESCRITORIO.put("La Rioja", 7.0);
        ITP_ESCRITORIO.put("Madrid", 6.0);
        ITP_ESCRITORIO.put("Melilla", 6.0);
        ITP_ESCRITORIO.put("Murcia", 8.0);
        ITP_ESCRITORIO.put("Navarra", 6.0);
        ITP_ESCRITORIO.put("País Vasco", 4.0);
    }

    /** Carga itp-rates.yml igual que lo hace Spring al arrancar. */
    public static ItpProperties cargar() throws Exception {
        var env = new MockEnvironment();
        for (PropertySource<?> ps : new YamlPropertySourceLoader().load("itp", new ClassPathResource("itp-rates.yml"))) {
            env.getPropertySources().addLast(ps);
        }
        return Binder.get(env).bind("gestionap.itp", ItpProperties.class).get();
    }

    @Test
    void itpRatesYml_tieneLas19ComunidadesConLosMismosTiposQueElEscritorio() throws Exception {
        ItpProperties itp = cargar();

        Map<String, Double> cargados = new LinkedHashMap<>();
        itp.comunidades().forEach(c -> cargados.put(c.nombre(), c.tipo()));

        assertThat(cargados).hasSize(19).containsExactlyEntriesOf(ITP_ESCRITORIO);
        assertThat(itp.anioReferencia()).isNotBlank();
    }
}
