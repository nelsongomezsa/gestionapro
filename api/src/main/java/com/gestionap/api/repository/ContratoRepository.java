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

    /** Contratos activos hoy de un conjunto de habitaciones, con su inquilino. */
    @Query("""
            select c from Contrato c
            join fetch c.inquilino
            where c.habitacion.id in :idsHabitacion
              and c.fechaInicio <= :hoy and c.fechaFin >= :hoy
            """)
    List<Contrato> activosDeHabitaciones(Collection<Integer> idsHabitacion, LocalDate hoy);

    /** Contratos activos hoy de un conjunto de inquilinos, con habitación y piso. */
    @Query("""
            select c from Contrato c
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            where c.inquilino.id in :idsInquilino
              and c.fechaInicio <= :hoy and c.fechaFin >= :hoy
            """)
    List<Contrato> activosDeInquilinos(Collection<Integer> idsInquilino, LocalDate hoy);

    /** Contratos de un inquilino visibles para un propietario (todos si idPropietario es null). */
    @Query("""
            select c from Contrato c
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            join fetch p.propietario
            where c.inquilino.id = :idInquilino
              and (:idPropietario is null or p.propietario.id = :idPropietario)
            order by c.fechaInicio desc
            """)
    List<Contrato> deInquilino(Integer idInquilino, Integer idPropietario);

    /**
     * Contratos visibles con todo lo necesario para listarlos. Filtros opcionales: propietario
     * (null = admin), inquilino (para el rol INQUILINO o la ficha) y piso.
     */
    @Query("""
            select c from Contrato c
            join fetch c.inquilino i
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idInquilino is null or i.id = :idInquilino)
              and (:idPiso is null or p.id = :idPiso)
            order by c.fechaFin desc, c.id desc
            """)
    List<Contrato> buscar(Integer idPropietario, Integer idInquilino, Integer idPiso);

    boolean existsByHabitacionId(Integer idHabitacion);

    boolean existsByInquilinoId(Integer idInquilino);

    @Query("""
            select count(c) > 0 from Contrato c
            where c.habitacion.id = :idHabitacion and c.fechaInicio <= :hoy and c.fechaFin >= :hoy
            """)
    boolean habitacionTieneContratoActivo(Integer idHabitacion, LocalDate hoy);
}
