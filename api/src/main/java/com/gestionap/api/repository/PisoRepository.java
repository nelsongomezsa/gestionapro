package com.gestionap.api.repository;

import com.gestionap.api.domain.Piso;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PisoRepository extends JpaRepository<Piso, Integer> {

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros"})
    List<Piso> findAllByOrderByDireccionAsc();

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros"})
    List<Piso> findByPropietarioIdOrderByDireccionAsc(Integer idPropietario);

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros", "propietario"})
    Optional<Piso> findWithDetallesById(Integer id);

    /** Si el propietario (o todos, con null) tiene garajes o trasteros: los textos dicen "unidades". */
    @Query("select count(p) > 0 from Piso p where p.tipo <> com.gestionap.api.domain.TipoInmueble.vivienda "
            + "and (:prop is null or p.propietario.id = :prop)")
    boolean hayNoViviendas(@Param("prop") Integer idPropietario);
}
