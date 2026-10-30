package com.gestionap.api.repository;

import com.gestionap.api.domain.Pago;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;

public interface PagoRepository extends JpaRepository<Pago, Integer> {

    @Query("""
            select p from Pago p
            where p.contrato.id in :idsContrato
            order by p.fechaPago desc, p.id desc
            """)
    List<Pago> deContratos(Collection<Integer> idsContrato);
}
