package com.gestionap.api.repository;

import com.gestionap.api.domain.Notificacion;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface NotificacionRepository extends JpaRepository<Notificacion, Integer> {

    List<Notificacion> findByIdUsuarioOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    List<Notificacion> findByIdUsuarioAndLeidaFalseOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    long countByIdUsuarioAndLeidaFalse(Integer idUsuario);

    Optional<Notificacion> findByIdAndIdUsuario(Integer id, Integer idUsuario);

    /**
     * ¿Hay ya un aviso con esta referencia sin leer, o creado hoy? El escritorio solo miraba
     * "creado hoy" y repetía cada día los avisos sin leer; aquí no se duplican.
     */
    @Query("""
            select count(n) > 0 from Notificacion n
            where n.idUsuario = :idUsuario and n.referencia = :referencia
              and (n.leida = false or n.fecha >= :inicioDeHoy)
            """)
    boolean existeVigente(Integer idUsuario, String referencia, LocalDateTime inicioDeHoy);

    /** Para los avisos que se dan una sola vez (aunque ya se hayan leído). */
    boolean existsByIdUsuarioAndReferencia(Integer idUsuario, String referencia);

    @Modifying
    @Query("update Notificacion n set n.leida = true where n.idUsuario = :idUsuario and n.leida = false")
    int marcarTodasLeidas(Integer idUsuario);
}
