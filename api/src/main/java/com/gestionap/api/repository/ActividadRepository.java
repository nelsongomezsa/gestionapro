package com.gestionap.api.repository;

import com.gestionap.api.domain.Actividad;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ActividadRepository extends JpaRepository<Actividad, Integer> {

    List<Actividad> findByIdUsuarioOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    List<Actividad> findAllByOrderByFechaDescIdDesc(Limit limite);
}
