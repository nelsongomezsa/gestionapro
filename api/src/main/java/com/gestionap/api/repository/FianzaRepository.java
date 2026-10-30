package com.gestionap.api.repository;

import com.gestionap.api.domain.Fianza;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface FianzaRepository extends JpaRepository<Fianza, Integer> {

    Optional<Fianza> findByContratoId(Integer idContrato);

    /** Para modificarla: dos peticiones a la vez no pueden validar contra el mismo estado. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select f from Fianza f where f.contrato.id = :idContrato")
    Optional<Fianza> bloquearDeContrato(Integer idContrato);

    /** Fianzas visibles (filtros opcionales), con contrato, inquilino y piso. */
    @Query("""
            select f from Fianza f
            join fetch f.contrato c
            join fetch c.inquilino i
            join fetch c.habitacion h
            join fetch h.piso p
            join fetch p.ciudad
            where (:idPropietario is null or p.propietario.id = :idPropietario)
              and (:idInquilino is null or i.id = :idInquilino)
            order by c.fechaInicio desc, f.id desc
            """)
    List<Fianza> buscar(Integer idPropietario, Integer idInquilino);
}
