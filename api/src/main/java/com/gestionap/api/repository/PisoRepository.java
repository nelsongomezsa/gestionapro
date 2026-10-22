package com.gestionap.api.repository;

import com.gestionap.api.domain.Piso;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PisoRepository extends JpaRepository<Piso, Integer> {

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros"})
    List<Piso> findAllByOrderByDireccionAsc();

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros"})
    List<Piso> findByPropietarioIdOrderByDireccionAsc(Integer idPropietario);

    @EntityGraph(attributePaths = {"ciudad", "datosFinancieros", "propietario"})
    Optional<Piso> findWithDetallesById(Integer id);
}
