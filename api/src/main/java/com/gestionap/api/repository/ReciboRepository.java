package com.gestionap.api.repository;

import com.gestionap.api.domain.Recibo;
import com.gestionap.api.domain.Usuario;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ReciboRepository extends JpaRepository<Recibo, Integer> {

    Optional<Recibo> findByPagoId(Integer idPago);

    List<Recibo> findByPagoIdIn(Collection<Integer> idsPago);

    /**
     * Bloquea la fila del propietario hasta el final de la transacción: los recibos de un
     * mismo propietario se numeran de uno en uno aunque haya dos pagos a la vez.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from Usuario u where u.id = :idPropietario")
    Usuario bloquearSerie(Integer idPropietario);

    /**
     * Último número de la serie, con lectura bloqueante: tras esperar al bloqueo de la serie,
     * una lectura normal en REPEATABLE READ podría ver una foto anterior y repetir número.
     */
    @Query(value = """
            SELECT numero FROM Recibos WHERE id_propietario = :idPropietario AND anio = :anio
            ORDER BY numero DESC LIMIT 1 FOR UPDATE
            """, nativeQuery = true)
    Integer ultimoNumero(Integer idPropietario, int anio);
}
