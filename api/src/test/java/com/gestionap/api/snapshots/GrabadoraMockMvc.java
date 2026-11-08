package com.gestionap.api.snapshots;

import org.springframework.boot.test.autoconfigure.web.servlet.MockMvcBuilderCustomizer;
import org.springframework.stereotype.Component;
import org.springframework.test.web.servlet.setup.ConfigurableMockMvcBuilder;

/** Añade la grabación de respuestas a todo MockMvc de los tests (solo con -Dsnapshots). */
@Component
public class GrabadoraMockMvc implements MockMvcBuilderCustomizer {

    @Override
    public void customize(ConfigurableMockMvcBuilder<?> builder) {
        if (Snapshots.activo()) builder.alwaysDo(Snapshots::registrar);
    }
}
