package com.gestionap.api.repository;

import com.gestionap.api.domain.Dispositivo;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DispositivoRepository extends JpaRepository<Dispositivo, Integer> {

    List<Dispositivo> findByIdUsuario(Integer idUsuario);

    Optional<Dispositivo> findByToken(String token);
}
