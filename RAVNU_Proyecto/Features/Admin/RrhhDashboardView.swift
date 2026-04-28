import SwiftUI

struct DatosPantallaRrhh {
    enum Pestana: String, CaseIterable {
        case analitica = "Analítica"
        case equipo = "Equipo"
        case permisos = "Permisos"
    }

    enum FiltroRol: Identifiable, Equatable {
        case todos
        case rol(id: String, nombre: String, colorHex: String)

        var id: String {
            switch self {
            case .todos:
                return "todos"
            case .rol(let id, _, _):
                return id
            }
        }

        var nombre: String {
            switch self {
            case .todos:
                return "Todos"
            case .rol(_, let nombre, _):
                return nombre
            }
        }

        var colorHex: String {
            switch self {
            case .todos:
                return "4C7CF3"
            case .rol(_, _, let colorHex):
                return colorHex
            }
        }
    }

    struct TarjetaRol: Identifiable {
        let id: String
        let nombre: String
        let subtitulo: String
        let colorHex: String
        let total: Int
    }

    struct SegmentoRol: Identifiable {
        let id: String
        let nombre: String
        let colorHex: String
        let total: Int
        let icono: String
    }

    struct BarraActividad: Identifiable {
        let id: String
        let iniciales: String
        let ventas: Int
        let cobros: Int
    }

    struct FilaTurno: Identifiable {
        let id: String
        let nombre: String
        let rol: String
        let turno: String
        let telefono: String
        let colorHex: String
    }

    struct TarjetaTrabajador: Identifiable {
        let id: String
        let iniciales: String
        let nombre: String
        let rol: String
        let turno: String
        let telefono: String
        let estado: String
        let colorHex: String
        let colorSuaveHex: String
        let icono: String
        let ventas: Int
        let cobros: Int
    }

    struct FilaPermiso: Identifiable {
        let id: String
        let nombre: String
        let activo: Bool
        let fijo: Bool
    }

    struct BloquePermisosRol: Identifiable {
        let id: String
        let nombre: String
        let subtitulo: String
        let colorHex: String
        let permisos: [FilaPermiso]
    }

    let permiteAgregar: Bool
    let mensajeEstado: String?
    let totalActivos: Int
    let tarjetasRol: [TarjetaRol]
    let distribucionRoles: [SegmentoRol]
    let actividadSemanal: [BarraActividad]
    let turnosHoy: [FilaTurno]
    let tarjetasTrabajadores: [TarjetaTrabajador]
    let filtrosRol: [FiltroRol]
    let bloquesPermisos: [BloquePermisosRol]

    static let estadoInicial = DatosPantallaRrhh(
        permiteAgregar: false,
        mensajeEstado: "Cargando trabajadores...",
        totalActivos: 0,
        tarjetasRol: [],
        distribucionRoles: [],
        actividadSemanal: [],
        turnosHoy: [],
        tarjetasTrabajadores: [],
        filtrosRol: [.todos],
        bloquesPermisos: []
    )

    static func estadoSinFirebase(permiteAgregar: Bool, mensaje: String) -> DatosPantallaRrhh {
        DatosPantallaRrhh(
            permiteAgregar: permiteAgregar,
            mensajeEstado: mensaje,
            totalActivos: 0,
            tarjetasRol: [],
            distribucionRoles: [],
            actividadSemanal: [],
            turnosHoy: [],
            tarjetasTrabajadores: [],
            filtrosRol: [.todos],
            bloquesPermisos: []
        )
    }
}

struct RrhhDashboardView: View {
    let datos: DatosPantallaRrhh
    let onBack: () -> Void
    let onAgregar: () -> Void
    let onSeleccionarTrabajador: (String) -> Void

    @State private var pestanaSeleccionada: DatosPantallaRrhh.Pestana = .analitica
    @State private var filtroRolSeleccionado: DatosPantallaRrhh.FiltroRol = .todos
    @State private var rolPermisosSeleccionadoId: String?

    private var trabajadoresFiltrados: [DatosPantallaRrhh.TarjetaTrabajador] {
        switch filtroRolSeleccionado {
        case .todos:
            return datos.tarjetasTrabajadores
        case .rol(_, let nombre, _):
            return datos.tarjetasTrabajadores.filter { $0.rol == nombre }
        }
    }

    private var bloquePermisosActivo: DatosPantallaRrhh.BloquePermisosRol? {
        let id = rolPermisosSeleccionadoId ?? datos.bloquesPermisos.first?.id
        return datos.bloquesPermisos.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            VStack(spacing: 0) {
                encabezado
                barraPestanas

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if let mensajeEstado = datos.mensajeEstado, datos.tarjetasTrabajadores.isEmpty, datos.bloquesPermisos.isEmpty {
                            tarjetaEstado(mensajeEstado)
                        } else {
                            switch pestanaSeleccionada {
                            case .analitica:
                                contenidoAnalitica
                            case .equipo:
                                contenidoEquipo
                            case .permisos:
                                contenidoPermisos
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if rolPermisosSeleccionadoId == nil {
                rolPermisosSeleccionadoId = datos.bloquesPermisos.first?.id
            }
            if datos.filtrosRol.contains(filtroRolSeleccionado) == false {
                filtroRolSeleccionado = .todos
            }
        }
    }

    private var encabezado: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Text("RRHH · Personal")
                .font(.system(size: 29, weight: .black))
                .foregroundStyle(Color(hex: "1F2937"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Button(action: onAgregar) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Agregar")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(datos.permiteAgregar ? Color(hex: "A855F7") : Color(hex: "D1D5DB"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(datos.permiteAgregar == false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var barraPestanas: some View {
        HStack(spacing: 6) {
            botonPestana(.analitica, icono: "chart.bar")
            botonPestana(.equipo, icono: "person.2")
            botonPestana(.permisos, icono: "shield")
        }
        .padding(4)
        .background(Color(hex: "E9EDF3"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func botonPestana(_ pestana: DatosPantallaRrhh.Pestana, icono: String) -> some View {
        Button {
            pestanaSeleccionada = pestana
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icono)
                    .font(.system(size: 11, weight: .semibold))
                Text(pestana.rawValue)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(pestanaSeleccionada == pestana ? Color(hex: "1F2937") : Color(hex: "6B7280"))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(pestanaSeleccionada == pestana ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var contenidoAnalitica: some View {
        VStack(spacing: 14) {
            tarjetaResumen
            tarjetaDistribucion
            tarjetaActividad
            tarjetaTurnos
        }
    }

    private var tarjetaResumen: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESUMEN DEL EQUIPO")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.8))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(datos.totalActivos)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                    Text("Trabajadores activos")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                }

                Spacer()

                HStack(spacing: -8) {
                    ForEach(datos.tarjetasTrabajadores.prefix(3)) { trabajador in
                        Text(trabajador.iniciales)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: trabajador.colorHex))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(datos.tarjetasRol) { rol in
                    VStack(spacing: 4) {
                        Text("\(rol.total)")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                        Text(rol.nombre)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "7C3AED"), Color(hex: "A855F7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var tarjetaDistribucion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribución por Rol")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "1F2937"))

            HStack(spacing: 14) {
                GraficoDonaRrhh(segmentos: datos.distribucionRoles)
                    .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(datos.distribucionRoles) { segmento in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: segmento.colorHex))
                                .frame(width: 8, height: 8)
                            Image(systemName: segmento.icono)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(hex: "9CA3AF"))
                            Text(segmento.nombre)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "4B5563"))
                            Spacer()
                            Text("\(segmento.total)")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color(hex: "1F2937"))
                        }
                    }
                }
            }
        }
        .padding(16)
        .tarjetaBase()
    }

    private var tarjetaActividad: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actividad Esta Semana")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "1F2937"))
            Text("Ventas y cobros por trabajador")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(hex: "9CA3AF"))

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(datos.actividadSemanal) { barra in
                    VStack(spacing: 6) {
                        HStack(alignment: .bottom, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: "5B88F7"))
                                .frame(width: 16, height: alturaBarra(barra.ventas))
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: "61C87A"))
                                .frame(width: 16, height: alturaBarra(barra.cobros))
                        }
                        .frame(height: 80, alignment: .bottom)

                        Text(barra.iniciales)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "6B7280"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 14) {
                leyendaActividad(colorHex: "5B88F7", texto: "Ventas")
                leyendaActividad(colorHex: "61C87A", texto: "Cobros")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .tarjetaBase()
    }

    private var tarjetaTurnos: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Horarios de Turno Hoy")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "1F2937"))

            ForEach(datos.turnosHoy) { turno in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: turno.colorHex))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(turno.nombre)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Text("\(turno.rol) · \(turno.turno)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "6B7280"))
                    }
                    Spacer()
                    Text(turno.telefono)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
            }
        }
        .padding(16)
        .tarjetaBase()
    }

    private var contenidoEquipo: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(datos.filtrosRol) { filtro in
                        Button {
                            filtroRolSeleccionado = filtro
                        } label: {
                            HStack(spacing: 6) {
                                Text(filtro.nombre)
                                    .font(.system(size: 14, weight: .bold))
                                if filtroRolSeleccionado == filtro {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundStyle(filtroRolSeleccionado == filtro ? .white : Color(hex: "6B7280"))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(filtroRolSeleccionado == filtro ? Color(hex: filtro.colorHex) : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(filtroRolSeleccionado == filtro ? Color.clear : Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if trabajadoresFiltrados.isEmpty {
                tarjetaEstado("No hay trabajadores para este filtro.")
            } else {
                ForEach(trabajadoresFiltrados) { trabajador in
                    Button {
                        onSeleccionarTrabajador(trabajador.id)
                    } label: {
                        tarjetaTrabajador(trabajador)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tarjetaTrabajador(_ trabajador: DatosPantallaRrhh.TarjetaTrabajador) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .fill(Color(hex: trabajador.colorHex))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack(alignment: .top, spacing: 14) {
                Text(trabajador.iniciales)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color(hex: trabajador.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(trabajador.nombre)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color(hex: "1F2937"))

                    Text(trabajador.rol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: trabajador.colorHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: trabajador.colorSuaveHex))
                        .clipShape(Capsule())

                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 12, weight: .semibold))
                        Text(trabajador.turno)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "9CA3AF"))

                    HStack(spacing: 6) {
                        Image(systemName: "phone")
                            .font(.system(size: 12, weight: .semibold))
                        Text(trabajador.telefono)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "9CA3AF"))
                }

                Spacer()

                Image(systemName: trabajador.icono)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: trabajador.colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: trabajador.colorSuaveHex))
                    .clipShape(Circle())
            }

            HStack(spacing: 8) {
                chipMetrica(colorHex: "4C7CF3", fondoHex: "EEF4FF", texto: "\(trabajador.ventas) ventas", icono: "chart.line.uptrend.xyaxis")
                chipMetrica(colorHex: "61C87A", fondoHex: "ECFDF3", texto: "\(trabajador.cobros) cobros", icono: "checkmark.circle")
                chipMetrica(colorHex: "61C87A", fondoHex: "F0FDF4", texto: trabajador.estado, icono: "circle.fill")
            }
        }
        .padding(16)
        .tarjetaBase()
    }

    private var contenidoPermisos: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CONTROL DE ACCESO")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                Text("Roles & Permisos")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                Text("Como Administrador puedes modificar los permisos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "7C3AED"), Color(hex: "A855F7")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("SELECCIONAR ROL")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "6B7280"))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(datos.bloquesPermisos) { bloque in
                        Button {
                            rolPermisosSeleccionadoId = bloque.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(bloque.nombre)
                                    .font(.system(size: 16, weight: .black))
                                Text(bloque.subtitulo)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: rolPermisosSeleccionadoId == bloque.id ? bloque.colorHex : "4B5563"))
                            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        Color(hex: rolPermisosSeleccionadoId == bloque.id ? bloque.colorHex : "E5E7EB"),
                                        lineWidth: rolPermisosSeleccionadoId == bloque.id ? 2 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .tarjetaBase()

            if let bloquePermisosActivo {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Permisos: \(bloquePermisosActivo.nombre)")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Spacer()
                        Text("\(bloquePermisosActivo.permisos.filter(\.activo).count) activos")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "4C7CF3"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "EEF4FF"))
                            .clipShape(Capsule())
                    }

                    ForEach(bloquePermisosActivo.permisos) { permiso in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: permiso.activo ? "ECFDF3" : "F3F4F6"))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: iconoPermiso(permiso.nombre))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(hex: permiso.activo ? "61C87A" : "9CA3AF"))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(permiso.nombre)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "1F2937"))
                                Text(permiso.fijo ? "Siempre activo" : "Permiso configurable")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "9CA3AF"))
                            }

                            Spacer()

                            Toggle("", isOn: .constant(permiso.activo))
                                .labelsHidden()
                                .disabled(true)
                        }
                    }
                }
                .padding(18)
                .tarjetaBase()
            } else {
                tarjetaEstado("No hay roles configurados para permisos.")
            }
        }
    }

    private func chipMetrica(colorHex: String, fondoHex: String, texto: String, icono: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
                .font(.system(size: 11, weight: .semibold))
            Text(texto)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Color(hex: colorHex))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color(hex: fondoHex))
        .clipShape(Capsule())
    }

    private func leyendaActividad(colorHex: String, texto: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 10, height: 10)
            Text(texto)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))
        }
    }

    private func tarjetaEstado(_ mensaje: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RRHH")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: "1F2937"))
            Text(mensaje)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tarjetaBase()
    }

    private func alturaBarra(_ valor: Int) -> CGFloat {
        if valor <= 0 { return 6 }
        return min(CGFloat(valor) * 10, 74)
    }

    private func iconoPermiso(_ nombre: String) -> String {
        switch nombre {
        case "Inicio": return "house"
        case "Ventas": return "cart"
        case "Clientes": return "person.2"
        case "Almacén": return "shippingbox"
        case "Tesorería": return "banknote"
        case "Cobros": return "creditcard"
        case "Compras": return "bag"
        case "Más": return "ellipsis"
        case "RRHH": return "person.text.rectangle"
        default: return "checkmark.circle"
        }
    }
}

private struct GraficoDonaRrhh: View {
    let segmentos: [DatosPantallaRrhh.SegmentoRol]

    private var total: Double {
        Double(max(segmentos.reduce(0) { $0 + $1.total }, 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * 0.22
            ZStack {
                Circle()
                    .stroke(Color(hex: "EEF2F7"), lineWidth: lineWidth)

                ForEach(Array(segmentos.enumerated()), id: \.element.id) { index, segmento in
                    Circle()
                        .trim(from: inicioSegmento(index), to: finSegmento(index))
                        .stroke(
                            Color(hex: segmento.colorHex),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func inicioSegmento(_ index: Int) -> CGFloat {
        let acumulado = segmentos.prefix(index).reduce(0) { $0 + $1.total }
        return CGFloat(Double(acumulado) / total)
    }

    private func finSegmento(_ index: Int) -> CGFloat {
        let acumulado = segmentos.prefix(index + 1).reduce(0) { $0 + $1.total }
        return CGFloat(Double(acumulado) / total)
    }
}

struct BorradorTrabajador {
    enum Rol: String, CaseIterable, Identifiable {
        case cajero
        case almacenero
        case supervisor

        var id: String { rawValue }

        var nombre: String {
            switch self {
            case .cajero: return "Cajero"
            case .almacenero: return "Almacenero"
            case .supervisor: return "Supervisor"
            }
        }

        var icono: String {
            switch self {
            case .cajero: return "dollarsign"
            case .almacenero: return "shippingbox"
            case .supervisor: return "star"
            }
        }

        var colorHex: String {
            switch self {
            case .cajero: return "4C7CF3"
            case .almacenero: return "F3A533"
            case .supervisor: return "8B5CF6"
            }
        }

        init?(id: String) {
            switch id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "cajero":
                self = .cajero
            case "almacenero", "almacen":
                self = .almacenero
            case "supervisor", "super":
                self = .supervisor
            default:
                return nil
            }
        }
    }

    enum Turno: String, CaseIterable, Identifiable {
        case manana
        case tarde
        case diaCompleto

        var id: String {
            switch self {
            case .manana: return "manana"
            case .tarde: return "tarde"
            case .diaCompleto: return "dia_completo"
            }
        }

        var nombre: String {
            switch self {
            case .manana: return "Turno mañana"
            case .tarde: return "Turno tarde"
            case .diaCompleto: return "Día completo"
            }
        }

        var icono: String {
            switch self {
            case .manana: return "sun.max.fill"
            case .tarde: return "sunset.fill"
            case .diaCompleto: return "clock.fill"
            }
        }

        init?(id: String) {
            switch id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "manana", "mañana":
                self = .manana
            case "tarde":
                self = .tarde
            case "dia_completo", "día completo", "completo":
                self = .diaCompleto
            default:
                return nil
            }
        }
    }

    var nombreCompleto = ""
    var telefono = ""
    var correoElectronico = ""
    var contraseña = ""
    var rol: Rol = .cajero
    var turno: Turno = .manana
    var salarioMensual = ""
    var activo = true

    var nombreNormalizado: String {
        nombreCompleto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var telefonoNormalizado: String {
        telefono.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var correoNormalizado: String {
        correoElectronico.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var salarioDecimal: Double? {
        Double(salarioMensual.replacingOccurrences(of: ",", with: "."))
    }

    func validar(requiereContraseña: Bool = true) -> String? {
        if nombreNormalizado.isEmpty {
            return "Ingresa el nombre completo."
        }
        if telefonoNormalizado.isEmpty {
            return "Ingresa el teléfono."
        }
        if correoNormalizado.isEmpty || correoNormalizado.contains("@") == false {
            return "Ingresa un correo válido."
        }
        if requiereContraseña && contraseña.count < 6 {
            return "La contraseña debe tener al menos 6 caracteres."
        }
        guard let salarioDecimal, salarioDecimal >= 0 else {
            return "Ingresa un salario mensual válido."
        }
        return nil
    }

    init() {}

    init(trabajador: TrabajadorRemoto) {
        nombreCompleto = trabajador.fullName
        telefono = trabajador.phone == "Sin teléfono" ? "" : trabajador.phone
        correoElectronico = trabajador.email
        contraseña = ""
        rol = Rol(id: trabajador.roleId) ?? .cajero
        turno = Turno(id: trabajador.shift) ?? .manana
        salarioMensual = trabajador.salarioMensualTexto
        activo = trabajador.active
    }
}

enum ModoTrabajadorSheet {
    case crear
    case editar(TrabajadorRemoto)
    case solicitarAlta
    case solicitarEdicion(TrabajadorRemoto)

    var titulo: String {
        switch self {
        case .crear:
            return "Agregar Trabajador"
        case .editar:
            return "Editar Trabajador"
        case .solicitarAlta:
            return "Solicitar Alta"
        case .solicitarEdicion:
            return "Solicitar Cambio"
        }
    }

    var textoBoton: String {
        switch self {
        case .crear:
            return "Agregar Trabajador"
        case .editar:
            return "Guardar Cambios"
        case .solicitarAlta, .solicitarEdicion:
            return "Enviar Solicitud"
        }
    }

    var requiereContraseña: Bool {
        switch self {
        case .crear:
            return true
        case .editar, .solicitarAlta, .solicitarEdicion:
            return false
        }
    }

    var requiereMotivo: Bool {
        switch self {
        case .solicitarAlta, .solicitarEdicion:
            return true
        case .crear, .editar:
            return false
        }
    }

    var descripcionMotivo: String {
        switch self {
        case .solicitarAlta:
            return "Explica por qué solicitas crear este trabajador."
        case .solicitarEdicion:
            return "Explica por qué solicitas modificar los datos del trabajador."
        case .crear, .editar:
            return ""
        }
    }
}

struct TrabajadorSheetSubmission {
    let modo: ModoTrabajadorSheet
    let borrador: BorradorTrabajador
    let motivo: String
}

struct TrabajadorSheetView: View {
    let modo: ModoTrabajadorSheet
    let onGuardar: (TrabajadorSheetSubmission) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var borrador: BorradorTrabajador
    @State private var guardando = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var motivoSolicitud = ""

    init(modo: ModoTrabajadorSheet, onGuardar: @escaping (TrabajadorSheetSubmission) async throws -> Void) {
        self.modo = modo
        self.onGuardar = onGuardar
        switch modo {
        case .crear, .solicitarAlta:
            _borrador = State(initialValue: BorradorTrabajador())
        case .editar(let trabajador), .solicitarEdicion(let trabajador):
            _borrador = State(initialValue: BorradorTrabajador(trabajador: trabajador))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    campoTexto(
                        titulo: "Nombre completo",
                        placeholder: "Ingresa el nombre completo",
                        text: $borrador.nombreCompleto
                    )

                    campoTexto(
                        titulo: "Teléfono",
                        placeholder: "9XX-XXX-XXX",
                        text: $borrador.telefono,
                        keyboardType: .phonePad
                    )

                    campoTexto(
                        titulo: "Correo electrónico",
                        placeholder: "correo@ejemplo.com",
                        text: $borrador.correoElectronico,
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )

                    if modo.requiereContraseña {
                        campoTexto(
                            titulo: "Contraseña temporal",
                            placeholder: "Mínimo 6 caracteres",
                            text: $borrador.contraseña,
                            secure: true,
                            autocapitalization: .never
                        )
                    }

                    selectorRol
                    selectorTurno
                    selectorEstado

                    if modo.requiereMotivo {
                        campoTexto(
                            titulo: "Motivo de la solicitud",
                            placeholder: modo.descripcionMotivo,
                            text: $motivoSolicitud,
                            axis: .vertical
                        )
                    }

                    campoTexto(
                        titulo: "Salario mensual (S/)",
                        placeholder: "Ej: 1500",
                        text: $borrador.salarioMensual,
                        keyboardType: .decimalPad
                    )

                    Button(action: guardar) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "A855F7"), Color(hex: "9333EA")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 58)

                            if guardando {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(modo.textoBoton)
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(guardando)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(modo.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "6B7280"))
                    .disabled(guardando)
                }
            }
        }
        .alert("RRHH", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) { }
        } message: {
            Text(mensajeError)
        }
    }

    private var selectorRol: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rol")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))

            HStack(spacing: 0) {
                ForEach(BorradorTrabajador.Rol.allCases) { rol in
                    Button {
                        borrador.rol = rol
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: rol.icono)
                                .font(.system(size: 14, weight: .bold))
                            Text(rol.nombre)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(
                            borrador.rol == rol ? Color(hex: rol.colorHex) : Color(hex: "9CA3AF")
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(borrador.rol == rol ? Color.white : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(borrador.rol == rol ? Color(hex: rol.colorHex) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(hex: "F3F6FB"))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var selectorTurno: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Turno")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))

            Menu {
                ForEach(BorradorTrabajador.Turno.allCases) { turno in
                    Button {
                        borrador.turno = turno
                    } label: {
                        Label(turno.nombre, systemImage: turno.icono)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: borrador.turno.icono)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "F3B341"))
                    Text(borrador.turno.nombre)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "374151"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(hex: "F6F8FC"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var selectorEstado: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estado")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "6B7280"))
                Text("Permite o bloquea el ingreso del trabajador.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }
            Spacer()
            Toggle("", isOn: $borrador.activo)
                .labelsHidden()
                .tint(Color(hex: "61C87A"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "F6F8FC"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func campoTexto(
        titulo: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        secure: Bool = false,
        autocapitalization: TextInputAutocapitalization? = .sentences,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))

            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text, axis: axis)
                }
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color(hex: "1F2937"))
            .textInputAutocapitalization(autocapitalization)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, axis == .vertical ? 14 : 0)
            .frame(minHeight: 54)
            .background(Color(hex: "F6F8FC"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func guardar() {
        if let error = borrador.validar(requiereContraseña: modo.requiereContraseña) {
            mensajeError = error
            mostrarError = true
            return
        }
        if modo.requiereMotivo && motivoSolicitud.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Ingresa el motivo de la solicitud."
            mostrarError = true
            return
        }

        guardando = true
        Task {
            do {
                try await onGuardar(
                    TrabajadorSheetSubmission(
                        modo: modo,
                        borrador: borrador,
                        motivo: motivoSolicitud
                    )
                )
                await MainActor.run {
                    guardando = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    guardando = false
                    mensajeError = error.localizedDescription
                    mostrarError = true
                }
            }
        }
    }
}

private extension View {
    func tarjetaBase() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
