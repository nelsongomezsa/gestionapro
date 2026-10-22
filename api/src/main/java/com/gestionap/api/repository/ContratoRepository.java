package com.gestionap.api.repository;

import com.gestionap.api.domain.Contrato;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ContratoRepository extends JpaRepository<Contrato, Integer> {

    /**
     * Filas [idPiso, suma de precio_mensual] de los contratos activos en {@code hoy}.
     * Es el "ingresos_mes" de AnalisisPisoDAO en el escritorio, que alimenta
     * la calculadora financiera de cada piso.
     */
    @Query("""
            select c.habitacion.piso.id, sum(c.precioMensual)
            from Contrato c
            where c.habitacion.piso.id in :idsPiso
              and c.fechaInicio <= :hoy and c.fechaFin >= :hoy
            group by c.habitacion.piso.id
            """)
    List<Object[]> ingresosMensualesActivos(Collection<Integer> idsPiso, LocalDate hoy);

    /** ¿Tiene este inquilino algún contrato en un piso de este propietario? */
    @Query("""
            select count(c) > 0 from Contrato c
            where c.inquilino.id = :idInquilino
              and c.habitacion.piso.propietario.id = :idPropietario
            """)
    boolean inquilinoTieneContratoConPropietario(Integer idInquilino, Integer idPropietario);

    @EntityGraph(attributePaths = {"inquilino", "inquilino.usuario", "habitacion", "habitacion.piso",
            "habitacion.piso.ciudad", "habitacion.piso.propietario"})
    Optional<Contrato> findConDetallesById(Integer id);
}
