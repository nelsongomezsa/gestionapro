package com.gestionap.api.repository;

import com.gestionap.api.domain.Incidencia;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IncidenciaRepository extends JpaRepository<Incidencia, Integer> {

    boolean existsByHabitacionId(Integer idHabitacion);

    boolean existsByInquilinoId(Integer idInquilino);
}
