package com.gestionap.api.repository;

import com.gestionap.api.domain.Notificacion;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface NotificacionRepository extends JpaRepository<Notificacion, Integer> {

    List<Notificacion> findByIdUsuarioOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    List<Notificacion> findByIdUsuarioAndLeidaFalseOrderByFechaDescIdDesc(Integer idUsuario, Limit limite);

    long countByIdUsuarioAndLeidaFalse(Integer idUsuario);

    /** Sin leer contando una vez cada referencia (el escritorio puede haber creado el mismo aviso varias veces). */
    @Query("""
            select count(distinct n.referencia) from Notificacion n
            where n.idUsuario = :idUsuario and n.leida = false and n.referencia is not null
            """)
    long contarReferenciasNoLeidas(Integer idUsuario);

    long countByIdUsuarioAndLeidaFalseAndReferenciaIsNull(Integer idUsuario);

    /** Marca leídas todas las copias de un aviso (y refresca las ya cargadas). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update Notificacion n set n.leida = true where n.idUsuario = :idUsuario and n.referencia = :referencia")
    int marcarLeidasPorReferencia(Integer idUsuario, String referencia);

    Optional<Notificacion> findByIdAndIdUsuario(Integer id, Integer idUsuario);

    /** Para los avisos que se dan una sola vez (aunque ya se hayan leído). */
    boolean existsByIdUsuarioAndReferencia(Integer idUsuario, String referencia);

    boolean existsByIdUsuarioAndReferenciaAndLeidaFalse(Integer idUsuario, String referencia);

    @Modifying
    @Query("update Notificacion n set n.leida = true where n.idUsuario = :idUsuario and n.leida = false")
    int marcarTodasLeidas(Integer idUsuario);
}
