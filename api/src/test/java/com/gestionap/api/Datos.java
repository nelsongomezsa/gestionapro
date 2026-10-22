package com.gestionap.api;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Crea datos de prueba en H2. Los tests son @Transactional: todo se deshace al acabar. */
@Component
public class Datos {

    public static final String PASSWORD = "secreta123";

    private final UsuarioRepository usuarios;
    private final CiudadRepository ciudades;
    private final PisoRepository pisos;
    private final HabitacionRepository habitaciones;
    private final InquilinoRepository inquilinos;
    private final ContratoRepository contratos;
    private final PasswordEncoder encoder;

    public Datos(UsuarioRepository usuarios, CiudadRepository ciudades, PisoRepository pisos,
                 HabitacionRepository habitaciones, InquilinoRepository inquilinos,
                 ContratoRepository contratos, PasswordEncoder encoder) {
        this.usuarios = usuarios;
        this.ciudades = ciudades;
        this.pisos = pisos;
        this.habitaciones = habitaciones;
        this.inquilinos = inquilinos;
        this.contratos = contratos;
        this.encoder = encoder;
    }

    public Usuario usuario(String email, Rol rol) {
        return usuarioConHash(email, rol, encoder.encode(PASSWORD));
    }

    public Usuario usuarioConHash(String email, Rol rol, String hash) {
        Usuario u = new Usuario();
        u.setNombre("Usuario " + email);
        u.setEmail(email);
        u.setPasswordHash(hash);
        u.setRol(rol);
        u.setActivo(true);
        return usuarios.save(u);
    }

    public Ciudad ciudad(String nombre) {
        Ciudad c = new Ciudad();
        c.setNombre(nombre);
        return ciudades.save(c);
    }

    public Piso piso(String direccion, Ciudad ciudad, Usuario propietario) {
        Piso p = new Piso();
        p.setDireccion(direccion);
        p.setNumeroHabitaciones(3);
        p.setCiudad(ciudad);
        p.setPropietario(propietario);
        return pisos.save(p);
    }

    public Habitacion habitacion(Piso piso, int numero, EstadoHabitacion estado) {
        Habitacion h = new Habitacion();
        h.setNumero(numero);
        h.setPrecio(new BigDecimal("400.00"));
        h.setEstado(estado);
        h.setPiso(piso);
        return habitaciones.save(h);
    }

    public Inquilino inquilino(String dni, String email) {
        Inquilino i = new Inquilino();
        i.setNombre("Ana");
        i.setApellidos("García " + dni);
        i.setDni(dni);
        i.setEmail(email);
        return inquilinos.save(i);
    }

    public Contrato contratoActivo(Habitacion h, Inquilino i, String renta) {
        Contrato c = new Contrato();
        c.setHabitacion(h);
        c.setInquilino(i);
        c.setFechaInicio(LocalDate.now().minusMonths(2));
        c.setFechaFin(LocalDate.now().plusMonths(10));
        c.setPrecioMensual(new BigDecimal(renta));
        return contratos.save(c);
    }
}
