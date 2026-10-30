package com.gestionap.api.repository;

import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.Habitacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface HabitacionRepository extends JpaRepository<Habitacion, Integer> {

    /** Filas [idPiso, estado, total] para calcular la ocupación de varios pisos en una consulta. */
    @Query("""
            select h.piso.id, h.estado, count(h)
            from Habitacion h
            where h.piso.id in :idsPiso
            group by h.piso.id, h.estado
            """)
    List<Object[]> contarPorPisoYEstado(Collection<Integer> idsPiso);

    boolean existsByPisoId(Integer idPiso);

    /**
     * Habitaciones visibles: las de los pisos del propietario (o todas si idPropietario
     * es null, para el admin), filtradas opcionalmente por piso y estado.
     */
    @Query("""
            select h from Habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idPiso is null or p.id = :idPiso)
              and (:estado is null or h.estado = :estado)
            order by p.direccion, h.numero
            """)
    List<Habitacion> buscar(Integer idPropietario, Integer idPiso, EstadoHabitacion estado);

    @Query("""
            select h from Habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            join fetch p.propietario
            where h.id = :id
            """)
    Optional<Habitacion> findConPisoById(Integer id);

    /**
     * Cambia el estado solo si sigue siendo el esperado (como HabitacionDAO.reservar/liberar del
     * escritorio): si otro usuario la alquiló a la vez, devuelve 0 y no se pisa.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update Habitacion h set h.estado = :nuevo where h.id = :id and h.estado = :actual")
    int cambiarEstadoSi(Integer id, EstadoHabitacion actual, EstadoHabitacion nuevo);

    @Query("""
            select count(h) > 0 from Habitacion h
            where h.piso.id = :idPiso and h.numero = :numero and (:excluirId is null or h.id <> :excluirId)
            """)
    boolean existeNumeroEnPiso(Integer idPiso, int numero, Integer excluirId);
}
