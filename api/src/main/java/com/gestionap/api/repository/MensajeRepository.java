package com.gestionap.api.repository;

import com.gestionap.api.domain.Mensaje;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;

public interface MensajeRepository extends JpaRepository<Mensaje, Integer> {

    /** Hilo de un contrato: el general (sin incidencia) o el de una incidencia. */
    @Query("""
            select m from Mensaje m left join fetch m.autor
            where m.contrato.id = :idContrato
              and ((:idIncidencia is null and m.idIncidencia is null) or m.idIncidencia = :idIncidencia)
            order by m.fecha asc, m.id asc
            """)
    List<Mensaje> hilo(Integer idContrato, Integer idIncidencia);

    /** Todos los mensajes de esos contratos, del más reciente al más antiguo (para la bandeja). */
    @Query("""
            select m from Mensaje m left join fetch m.autor
            where m.contrato.id in :idsContrato
            order by m.fecha desc, m.id desc
            """)
    List<Mensaje> deContratos(Collection<Integer> idsContrato);

    /** Marca leídos los mensajes del hilo que escribió otro. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update Mensaje m set m.leido = true
            where m.contrato.id = :idContrato and m.leido = false
              and ((:idIncidencia is null and m.idIncidencia is null) or m.idIncidencia = :idIncidencia)
              and (m.autor is null or m.autor.id <> :idLector)
            """)
    int marcarLeidos(Integer idContrato, Integer idIncidencia, Integer idLector);
}
