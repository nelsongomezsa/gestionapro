package com.gestionap.api.repository;

import com.gestionap.api.domain.ElementoInventario;
import com.gestionap.api.domain.Inventario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface InventarioRepository extends JpaRepository<Inventario, Integer> {

    List<Inventario> findByHabitacionIdOrderByFechaDescIdDesc(Integer idHabitacion);

    @Query("select e from ElementoInventario e join fetch e.inventario where e.id = :id")
    Optional<ElementoInventario> elemento(Integer id);
}
