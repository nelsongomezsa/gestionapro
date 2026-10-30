package com.gestionap.api.repository;

import com.gestionap.api.domain.ActualizacionRenta;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface ActualizacionRentaRepository extends JpaRepository<ActualizacionRenta, Integer> {

    List<ActualizacionRenta> findByContratoIdOrderByFechaEfectoDesc(Integer idContrato);

    boolean existsByContratoIdAndFechaEfecto(Integer idContrato, LocalDate fechaEfecto);
}
