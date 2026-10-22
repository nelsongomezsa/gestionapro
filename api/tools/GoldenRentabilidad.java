// Herramienta, no forma parte de la API ni de su build.
//
// Regenera los valores esperados de CalculadoraRentabilidadTest ejecutando el
// RentabilidadController REAL de la app de escritorio sin ventana.
//
// Uso (desde un clon del repo de escritorio, ya compilado con `mvn compile`):
//   mvn -q dependency:build-classpath -Dmdep.outputFile=cp.txt
//   CP="target/classes:$(cat cp.txt)"
//   javac -d /tmp/golden -cp "$CP" /ruta/a/api/tools/GoldenRentabilidad.java
//   java -cp "/tmp/golden:$CP" GoldenRentabilidad
//
import com.gestionap.controller.RentabilidadController;
import javafx.application.Platform;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.lang.reflect.Field;
import java.util.*;
import java.util.concurrent.CountDownLatch;

/**
 * Ejecuta el RentabilidadController REAL de la app de escritorio (sin ventana)
 * y vuelca sus resultados internos para usarlos como valores de referencia
 * en los tests de la API.
 */
public class GoldenRentabilidad {

    static final String[] CAMPOS = {"tfPrecioCompra", "tfGastos", "tfGastosHipoteca", "tfReforma", "tfComision",
            "tfMobiliario", "tfIbiMensual", "tfSegurosMensual", "tfComunidadMensual", "tfMantenimientoMensual",
            "tfVacioMensual", "tfAlquilerMensual", "tfRevalorizacion", "tfPctFinanciado", "tfPlazo", "tfTipoInteres"};

    static final String[] SALIDAS = {"_itpPct", "_itp", "_totalCompra", "_gastosMensual", "_gastosAnual",
            "_alquilerMensual", "_alquilerAnual", "_hipoteca", "_capitalAportado", "_cuotaMensual",
            "_interesesMensual", "_amortizacionMensual", "_rentBruta", "_rentNeta", "_cashFlowMensual",
            "_cashFlowAnual", "_aniosRecuperar", "_plusvalia5", "_plusvalia10"};

    // comunidad + 16 campos en el orden de CAMPOS
    static final Object[][] CASOS = {
            {"Madrid", 200000, 2500, 1500, 10000, 3000, 4000, 50, 30, 80, 40, 60, 1400, 3, 80, 25, 3.2},
            {"Cataluña", 180000, 2000, 0, 5000, 0, 3000, 45, 25, 70, 30, 50, 1100, 0, 0, 0, 0},
            {"País Vasco", 220000, 2200, 1200, 0, 2500, 2000, 55, 35, 90, 40, 70, 1300, 2, 70, 20, 0},
            {"Canarias", 120000, 1500, 900, 2000, 1500, 1500, 30, 20, 50, 25, 40, 700, 1.5, 90, 5, 4.1},
            {"Andalucía", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {"Cantabria", 95000, 1200, 800, 15000, 2000, 3500, 25, 15, 40, 30, 35, 0, 4.5, 60, 30, 2.75},
    };

    public static void main(String[] args) throws Exception {
        CountDownLatch inicio = new CountDownLatch(1);
        Platform.startup(inicio::countDown);
        inicio.await();

        CountDownLatch fin = new CountDownLatch(1);
        Platform.runLater(() -> {
            try {
                ejecutar();
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                fin.countDown();
            }
        });
        fin.await();
        Platform.exit();
    }

    static void ejecutar() throws Exception {
        RentabilidadController c = new RentabilidadController();
        for (Field f : RentabilidadController.class.getDeclaredFields()) {
            if (!f.isAnnotationPresent(FXML.class)) continue;
            f.setAccessible(true);
            f.set(c, f.getType().getDeclaredConstructor().newInstance());
        }
        c.initialize(null, null);

        Field mapa = RentabilidadController.class.getDeclaredField("ITP_MAP");
        mapa.setAccessible(true);
        System.out.println("ITP_MAP=" + mapa.get(null));

        @SuppressWarnings("unchecked")
        ComboBox<String> combo = (ComboBox<String>) campo(c, "cmbComunidad");
        for (Object[] caso : CASOS) {
            combo.setValue((String) caso[0]);
            for (int i = 0; i < CAMPOS.length; i++) {
                ((TextField) campo(c, CAMPOS[i])).setText(String.valueOf(caso[i + 1]));
            }
            StringBuilder sb = new StringBuilder("CASO " + Arrays.toString(caso) + "\n");
            for (String s : SALIDAS) {
                Field f = RentabilidadController.class.getDeclaredField(s);
                f.setAccessible(true);
                // Double.toString da la representación exacta más corta del double
                sb.append("  ").append(s).append(" = ").append(Double.toString(f.getDouble(c))).append('\n');
            }
            System.out.print(sb);
        }
    }

    static Object campo(Object o, String nombre) throws Exception {
        Field f = o.getClass().getDeclaredField(nombre);
        f.setAccessible(true);
        return f.get(o);
    }
}
