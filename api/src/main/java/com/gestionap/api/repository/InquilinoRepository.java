package com.gestionap.api.repository;

import com.gestionap.api.domain.Inquilino;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;

public interface InquilinoRepository extends JpaRepository<Inquilino, Integer> {

    Optional<Inquilino> findByUsuarioId(Integer idUsuario);

    /** Bloquea la fila para que dos registros simultáneos no enlacen dos cuentas. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from Inquilino i where i.id = :id")
    Optional<Inquilino> findByIdParaActualizar(Integer id);

    boolean existsByDni(String dni);

    boolean existsByDniAndIdNot(String dni, Integer id);

    /**
     * Inquilinos visibles: todos para el admin (idPropietario null); para un propietario,
     * los que dio de alta él más los que tienen o tuvieron contrato en sus pisos.
     */
    @Query("""
            select i from Inquilino i
            left join fetch i.usuario
            where :idPropietario is null
               or i.propietario.id = :idPropietario
               or exists (select 1 from Contrato c
                          where c.inquilino = i and c.habitacion.piso.propietario.id = :idPropietario)
            order by i.apellidos, i.nombre
            """)
    List<Inquilino> visiblesPara(Integer idPropietario);

    @Query("""
            select count(i) > 0 from Inquilino i
            where i.id = :id
              and (i.propietario.id = :idPropietario
                   or exists (select 1 from Contrato c
                              where c.inquilino = i and c.habitacion.piso.propietario.id = :idPropietario))
            """)
    boolean esVisiblePara(Integer id, Integer idPropietario);
}
