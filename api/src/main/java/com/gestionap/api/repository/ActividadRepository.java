package com.gestionap.api.repository;

import com.gestionap.api.domain.Actividad;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface ActividadRepository extends JpaRepository<Actividad, Integer> {

    List<Actividad> findByIdUsuarioOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    List<Actividad> findAllByOrderByFechaDescIdDesc(Limit limite);

    /** Sin los inicios de sesión (LOGIN, LOGIN_API...): lo que ha cambiado en la cartera. */
    @Query("select a from Actividad a where a.accion is null or a.accion not like 'LOGIN%' order by a.fecha desc, a.id desc")
    List<Actividad> recientesSinAccesos(Limit limite);

    @Query("""
            select a from Actividad a where a.idUsuario = :idUsuario and (a.accion is null or a.accion not like 'LOGIN%')
            order by a.fecha desc, a.id desc""")
    List<Actividad> recientesSinAccesosDe(Integer idUsuario, Limit limite);
}
