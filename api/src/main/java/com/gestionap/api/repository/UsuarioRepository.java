package com.gestionap.api.repository;

import com.gestionap.api.domain.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface UsuarioRepository extends JpaRepository<Usuario, Integer> {

    Optional<Usuario> findByEmail(String email);

    boolean existsByEmail(String email);

    @org.springframework.data.jpa.repository.Query(
            "select count(u) from Usuario u where u.rol = com.gestionap.api.domain.Rol.ADMIN and u.activo = true and u.fechaBaja is null")
    long contarAdminsActivos();

    /** Bloquea la fila del usuario hasta el final de la transacción (generar avisos de uno en uno). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from Usuario u where u.id = :id")
    Usuario bloquear(Integer id);
}
