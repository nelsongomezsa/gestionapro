package com.gestionap.api.repository;

import com.gestionap.api.domain.Inquilino;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface InquilinoRepository extends JpaRepository<Inquilino, Integer> {

    Optional<Inquilino> findByUsuarioId(Integer idUsuario);

    /** Bloquea la fila para que dos registros simultáneos no enlacen dos cuentas. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from Inquilino i where i.id = :id")
    Optional<Inquilino> findByIdParaActualizar(Integer id);
}
