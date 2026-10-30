package com.gestionap.api.repository;

import com.gestionap.api.domain.Pago;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PagoRepository extends JpaRepository<Pago, Integer> {

    @Query("""
            select p from Pago p
            where p.contrato.id in :idsContrato
            order by p.fechaPago desc, p.id desc
            """)
    List<Pago> deContratos(Collection<Integer> idsContrato);

    /** Pagos visibles entre dos fechas (ambas opcionales), con contrato, inquilino y piso. */
    @Query("""
            select pg from Pago pg
            join fetch pg.contrato c
            join fetch c.inquilino i
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idInquilino is null or i.id = :idInquilino)
              and (cast(:desde as LocalDate) is null or pg.fechaPago >= :desde)
              and (cast(:hasta as LocalDate) is null or pg.fechaPago <= :hasta)
            order by pg.fechaPago desc, pg.id desc
            """)
    List<Pago> buscar(Integer idPropietario, Integer idInquilino, LocalDate desde, LocalDate hasta);

    @Query("""
            select pg from Pago pg
            join fetch pg.contrato c
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.propietario
            where pg.id = :id
            """)
    Optional<Pago> findConPisoById(Integer id);

    /** Un pago con todo lo que necesita su recibo. */
    @Query("""
            select pg from Pago pg
            join fetch pg.contrato c
            join fetch c.inquilino
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.propietario
            join fetch p.ciudad
            where pg.id = :id
            """)
    Optional<Pago> findConDetallesById(Integer id);
}
