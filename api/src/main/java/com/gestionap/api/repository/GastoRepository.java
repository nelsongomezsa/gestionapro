package com.gestionap.api.repository;

import com.gestionap.api.domain.Gasto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface GastoRepository extends JpaRepository<Gasto, Integer> {

    @Query("""
            select g from Gasto g
            join fetch g.piso p
            join fetch p.ciudad
            join fetch p.propietario
            left join fetch g.habitacion
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idPiso is null or p.id = :idPiso)
              and (:desde is null or g.fecha >= :desde)
              and (:hasta is null or g.fecha <= :hasta)
            order by g.fecha desc, g.id desc
            """)
    List<Gasto> buscar(Integer idPropietario, Integer idPiso, LocalDate desde, LocalDate hasta);

    @Query("""
            select g.piso.id, g.categoria, sum(g.importe)
            from Gasto g
            where g.piso.id in :idsPiso and g.fecha >= :desde and g.fecha <= :hasta
            group by g.piso.id, g.categoria
            """)
    List<Object[]> sumarPorPisoYCategoria(Collection<Integer> idsPiso, LocalDate desde, LocalDate hasta);

    Optional<Gasto> findByIdIncidencia(Integer idIncidencia);
}
