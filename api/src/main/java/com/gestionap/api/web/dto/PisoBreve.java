package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Piso;

public record PisoBreve(Integer id, String direccion, String ciudad) {

    public static PisoBreve de(Piso p) {
        return new PisoBreve(p.getId(), p.getDireccion(), p.getCiudad().getNombre());
    }
}
