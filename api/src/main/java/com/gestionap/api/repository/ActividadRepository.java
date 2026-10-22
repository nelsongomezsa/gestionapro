package com.gestionap.api.repository;

import com.gestionap.api.domain.Actividad;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ActividadRepository extends JpaRepository<Actividad, Integer> {
}
