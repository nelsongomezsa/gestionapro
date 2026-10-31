package com.gestionap.api.repository;

import com.gestionap.api.domain.FirmaContrato;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FirmaContratoRepository extends JpaRepository<FirmaContrato, Integer> {

    List<FirmaContrato> findByContratoIdOrderByFechaAsc(Integer idContrato);
}
