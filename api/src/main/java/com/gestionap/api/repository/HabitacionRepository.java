package com.gestionap.api.repository;

import com.gestionap.api.domain.Habitacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;

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
}
