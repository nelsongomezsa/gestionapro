package com.gestionap.api.repository;

import com.gestionap.api.domain.FotoIncidencia;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FotoIncidenciaRepository extends JpaRepository<FotoIncidencia, Integer> {

    List<FotoIncidencia> findByIncidenciaIdOrderByFechaAscIdAsc(Integer idIncidencia);

    long countByIncidenciaId(Integer idIncidencia);
}
