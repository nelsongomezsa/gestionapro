package com.gestionap.api.repository;

import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.domain.Incidencia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;

public interface IncidenciaRepository extends JpaRepository<Incidencia, Integer> {

    boolean existsByHabitacionId(Integer idHabitacion);

    boolean existsByInquilinoId(Integer idInquilino);

    /** Incidencias visibles (propietario/inquilino opcionales; null = sin filtro), con habitación, piso e inquilino. */
    @Query("""
            select i from Incidencia i
            join fetch i.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            join fetch i.inquilino q
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idInquilino is null or q.id = :idInquilino)
              and (:idPiso is null or p.id = :idPiso)
              and i.estado in :estados
            order by i.fecha desc, i.id desc
            """)
    List<Incidencia> buscar(Integer idPropietario, Integer idInquilino, Integer idPiso, Collection<EstadoIncidencia> estados);

    /** Incidencias resueltas con coste positivo de los pisos indicados. */
    @Query("""
            select i from Incidencia i
            join fetch i.habitacion h
            join fetch h.piso p
            where p.id in :idsPiso and i.estado = :estado and i.costeReparacion > 0
            """)
    List<Incidencia> resueltasConCoste(Collection<Integer> idsPiso, EstadoIncidencia estado);
}
