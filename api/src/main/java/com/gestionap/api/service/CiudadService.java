package com.gestionap.api.service;

import com.gestionap.api.domain.Ciudad;
import com.gestionap.api.repository.CiudadRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.dto.CiudadResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;

/**
 * Ciudades de los pisos. Es una tabla común (los nombres de ciudad no son datos privados); al dar de
 * alta una que ya existe, con otras mayúsculas o tildes, se devuelve la existente en vez de duplicarla.
 */
@Service
public class CiudadService {

    private final CiudadRepository ciudades;
    private final ActividadService actividad;

    public CiudadService(CiudadRepository ciudades, ActividadService actividad) {
        this.ciudades = ciudades;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public List<CiudadResponse> listar() {
        return ciudades.findAllByOrderByNombreAsc().stream().map(c -> new CiudadResponse(c.getId(), c.getNombre())).toList();
    }

    public record Alta(CiudadResponse ciudad, boolean nueva) {}

    @Transactional
    public Alta crear(String nombre, UsuarioAutenticado actor) {
        String limpio = nombre.strip().replaceAll("\\s+", " ");
        String clave = Textos.sinTildes(limpio).toLowerCase(Locale.ROOT);
        var existente = ciudades.findAll().stream()
                .filter(c -> Textos.sinTildes(c.getNombre()).toLowerCase(Locale.ROOT).equals(clave)).findFirst();
        if (existente.isPresent()) {
            return new Alta(new CiudadResponse(existente.get().getId(), existente.get().getNombre()), false);
        }
        Ciudad c = new Ciudad();
        c.setNombre(limpio.substring(0, 1).toUpperCase(Locale.of("es")) + limpio.substring(1));
        ciudades.save(c);
        actividad.registrar(actor.id(), "CREAR_CIUDAD", c.getNombre());
        return new Alta(new CiudadResponse(c.getId(), c.getNombre()), true);
    }
}
