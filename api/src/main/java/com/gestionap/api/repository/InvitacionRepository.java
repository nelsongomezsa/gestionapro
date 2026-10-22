package com.gestionap.api.repository;

import com.gestionap.api.domain.Invitacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import jakarta.persistence.LockModeType;
import java.time.LocalDateTime;
import java.util.Optional;

public interface InvitacionRepository extends JpaRepository<Invitacion, Integer> {

    /** Bloquea la invitación: un código de un solo uso no puede canjearse dos veces a la vez. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<Invitacion> findByCodigoHash(String codigoHash);

    /** Al generar una invitación nueva, las pendientes del mismo inquilino dejan de valer. */
    // clearAutomatically: el UPDATE masivo no pasa por el contexto de persistencia; sin limpiarlo,
    // una invitación ya cargada en la misma transacción seguiría pareciendo vigente.
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update Invitacion i set i.fechaExpiracion = :ahora
            where i.inquilino.id = :idInquilino and i.fechaUso is null and i.fechaExpiracion > :ahora
            """)
    int caducarPendientes(Integer idInquilino, LocalDateTime ahora);
}
