package com.gestionap.api.repository;

import com.gestionap.api.domain.AnalisisInversion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AnalisisInversionRepository extends JpaRepository<AnalisisInversion, Integer> {
    List<AnalisisInversion> findByIdUsuarioOrderByFechaActualizacionDesc(Integer idUsuario);

    Optional<AnalisisInversion> findByIdAndIdUsuario(Integer id, Integer idUsuario);

    long countByIdUsuario(Integer idUsuario);
}
