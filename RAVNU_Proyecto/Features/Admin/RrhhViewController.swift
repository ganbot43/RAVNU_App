import SwiftUI
import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class RrhhViewController: UIViewController {

    private var hostingController: UIHostingController<RrhhDashboardView>?
    private var datosVista = DatosPantallaRrhh.estadoInicial

    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var trabajadores: [TrabajadorRemoto] = []
    private var roles: [RolRemoto] = []
    private var eventosVenta: [EventoOperacionRemota] = []
    private var eventosCobro: [EventoOperacionRemota] = []
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarVistaHibrida()
        cargarDatos()
    }

    deinit {
        #if canImport(FirebaseFirestore)
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        #endif
    }

    private func configurarVistaHibrida() {
        let host = UIHostingController(rootView: crearVistaRaiz())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func actualizarVista() {
        hostingController?.rootView = crearVistaRaiz()
    }

    private func crearVistaRaiz() -> RrhhDashboardView {
        RrhhDashboardView(
            datos: datosVista,
            onBack: { [weak self] in
                guard let self else { return }
                if let navigationController = self.navigationController {
                    navigationController.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            },
            onAgregar: { [weak self] in
                self?.presentarModalAgregarTrabajador()
            },
            onSeleccionarTrabajador: { [weak self] trabajadorId in
                self?.presentarModalEditarTrabajador(id: trabajadorId)
            }
        )
    }

    private func cargarDatos() {
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else {
            datosVista = .estadoSinFirebase(
                permiteAgregar: puedeGestionarRrhh,
                mensaje: "Firebase no está configurado o la sincronización remota está desactivada."
            )
            actualizarVista()
            return
        }
        iniciarListenersSiHaceFalta()
    }

    private var puedeGestionarRrhh: Bool {
        AppSession.shared.rolLogueado == "Admin"
    }

    private func presentarModalAgregarTrabajador() {
        guard puedeGestionarRrhh else { return }
        guard FirebaseBootstrap.shared.isConfigured else {
            mostrarAlerta(titulo: "RRHH", mensaje: "Firebase no está configurado.")
            return
        }

        let controlador = UIHostingController(
            rootView: TrabajadorSheetView(modo: .crear) { [weak self] borrador in
                try await self?.registrarTrabajador(borrador: borrador)
            }
        )
        presentarSheet(controlador)
    }

    private func presentarModalEditarTrabajador(id trabajadorId: String) {
        guard puedeGestionarRrhh else { return }
        guard let trabajador = trabajadores.first(where: { $0.id == trabajadorId }) else { return }
        guard FirebaseBootstrap.shared.isConfigured else {
            mostrarAlerta(titulo: "RRHH", mensaje: "Firebase no está configurado.")
            return
        }

        let controlador = UIHostingController(
            rootView: TrabajadorSheetView(
                modo: .editar(trabajador),
                onGuardar: { [weak self] borrador in
                    try await self?.actualizarTrabajador(trabajador, con: borrador)
                }
            )
        )
        presentarSheet(controlador)
    }

    private func presentarSheet(_ controlador: UIHostingController<TrabajadorSheetView>) {
        controlador.modalPresentationStyle = .pageSheet
        if let sheet = controlador.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 26
        }
        present(controlador, animated: true)
    }

    private func mostrarAlerta(titulo: String, mensaje: String) {
        let alert = UIAlertController(title: titulo, message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    #if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
    private func registrarTrabajador(borrador: BorradorTrabajador) async throws {
        let authSecundaria = try crearAuthSecundaria()
        let resultadoAuth = try await crearUsuarioAuth(borrador: borrador, auth: authSecundaria)

        do {
            try await guardarPerfilTrabajador(
                borrador: borrador,
                authUid: resultadoAuth.user.uid
            )
            try? authSecundaria.signOut()
        } catch {
            await eliminarUsuarioSecundario(resultadoAuth.user)
            try? authSecundaria.signOut()
            throw error
        }
    }

    private func crearAuthSecundaria() throws -> Auth {
        guard let appPrincipal = FirebaseApp.app() else {
            throw ErrorRegistroTrabajador.mensaje("Firebase no está configurado.")
        }

        let nombreApp = "rrhh-secundaria"
        let appSecundaria: FirebaseApp
        if let existente = FirebaseApp.app(name: nombreApp) {
            appSecundaria = existente
        } else {
            FirebaseApp.configure(name: nombreApp, options: appPrincipal.options)
            guard let nueva = FirebaseApp.app(name: nombreApp) else {
                throw ErrorRegistroTrabajador.mensaje("No se pudo preparar la autenticación secundaria.")
            }
            appSecundaria = nueva
        }
        return Auth.auth(app: appSecundaria)
    }

    private func crearUsuarioAuth(borrador: BorradorTrabajador, auth: Auth) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.createUser(withEmail: borrador.correoNormalizado, password: borrador.contraseña) { resultado, error in
                if let error {
                    continuation.resume(throwing: ErrorRegistroTrabajador.mensaje(self.mensajeErrorAuth(error)))
                    return
                }

                guard let resultado else {
                    continuation.resume(throwing: ErrorRegistroTrabajador.mensaje("No se pudo crear el acceso en Firebase Authentication."))
                    return
                }
                continuation.resume(returning: resultado)
            }
        }
    }

    private func guardarPerfilTrabajador(borrador: BorradorTrabajador, authUid: String) async throws {
        let timestamp = Timestamp(date: Date())
        let usuarioRef = firestore.collection("users").document()
        let lookupRef = firestore.collection("users_lookup").document(authUid)
        let rolRef = firestore.collection("roles").document(borrador.rol.id)

        let batch = firestore.batch()
        batch.setData([
            "authUid": authUid,
            "email": borrador.correoNormalizado,
            "username": borrador.nombreNormalizado,
            "fullName": borrador.nombreNormalizado,
            "roleId": borrador.rol.id,
            "active": borrador.activo,
            "phone": borrador.telefonoNormalizado,
            "shift": borrador.turno.id,
            "salaryMonthly": borrador.salarioMensual,
            "createdAt": timestamp,
            "updatedAt": timestamp
        ], forDocument: usuarioRef, merge: true)
        batch.setData([
            "userId": usuarioRef.documentID,
            "roleId": borrador.rol.id,
            "active": borrador.activo,
            "updatedAt": timestamp
        ], forDocument: lookupRef, merge: true)
        batch.setData(rolBaseParaFirestore(id: borrador.rol.id), forDocument: rolRef, merge: true)
        let rolAdminRef = firestore.collection("roles").document("admin")
        batch.setData(rolBaseParaFirestore(id: "admin"), forDocument: rolAdminRef, merge: true)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: ErrorRegistroTrabajador.mensaje("No se pudo guardar el perfil del trabajador: \(error.localizedDescription)"))
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func actualizarTrabajador(_ trabajador: TrabajadorRemoto, con borrador: BorradorTrabajador) async throws {
        let timestamp = Timestamp(date: Date())
        let usuarioRef = firestore.collection("users").document(trabajador.id)
        let lookupDocumentId = trabajador.authUid.isEmpty ? trabajador.id : trabajador.authUid
        let lookupRef = firestore.collection("users_lookup").document(lookupDocumentId)
        let rolRef = firestore.collection("roles").document(borrador.rol.id)

        let batch = firestore.batch()
        batch.setData([
            "username": borrador.nombreNormalizado,
            "fullName": borrador.nombreNormalizado,
            "roleId": borrador.rol.id,
            "active": borrador.activo,
            "phone": borrador.telefonoNormalizado,
            "shift": borrador.turno.id,
            "salaryMonthly": borrador.salarioMensual,
            "updatedAt": timestamp
        ], forDocument: usuarioRef, merge: true)
        batch.setData([
            "userId": trabajador.id,
            "roleId": borrador.rol.id,
            "active": borrador.activo,
            "updatedAt": timestamp
        ], forDocument: lookupRef, merge: true)
        batch.setData(rolBaseParaFirestore(id: borrador.rol.id), forDocument: rolRef, merge: true)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: ErrorRegistroTrabajador.mensaje("No se pudo actualizar el trabajador: \(error.localizedDescription)"))
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func eliminarUsuarioSecundario(_ user: User) async {
        await withCheckedContinuation { continuation in
            user.delete { _ in
                continuation.resume()
            }
        }
    }

    private func rolBaseParaFirestore(id: String) -> [String: Any] {
        let permisos: [String: Bool]
        switch id {
        case "admin":
            permisos = [
                "inicio": true,
                "ventas": true,
                "clientes": true,
                "almacen": true,
                "tesoreria": true,
                "cobros": true,
                "compras": true,
                "mas": true,
                "rrhh": true
            ]
        case "supervisor":
            permisos = [
                "inicio": true,
                "ventas": true,
                "clientes": true,
                "almacen": true,
                "tesoreria": false,
                "cobros": true,
                "compras": true,
                "mas": true,
                "rrhh": false
            ]
        case "almacenero":
            permisos = [
                "inicio": true,
                "ventas": false,
                "clientes": false,
                "almacen": true,
                "tesoreria": false,
                "cobros": false,
                "compras": true,
                "mas": true,
                "rrhh": false
            ]
        default:
            permisos = [
                "inicio": true,
                "ventas": true,
                "clientes": true,
                "almacen": false,
                "tesoreria": false,
                "cobros": true,
                "compras": false,
                "mas": true,
                "rrhh": false
            ]
        }

        return [
            "name": nombreRolFirestore(id: id),
            "active": true,
            "modulePermissions": permisos,
            "updatedAt": Timestamp(date: Date())
        ]
    }

    private func nombreRolFirestore(id: String) -> String {
        switch id {
        case "admin": return "Administrador"
        case "supervisor": return "Supervisor"
        case "almacenero": return "Almacenero"
        default: return "Cajero"
        }
    }

    private func mensajeErrorAuth(_ error: Error) -> String {
        guard let authError = error as NSError?,
              let code = AuthErrorCode(rawValue: authError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .emailAlreadyInUse:
            return "Ya existe un trabajador con ese correo."
        case .invalidEmail:
            return "El correo electrónico no es válido."
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres."
        case .networkError:
            return "No se pudo conectar con Firebase."
        default:
            return error.localizedDescription
        }
    }

    private func iniciarListenersSiHaceFalta() {
        guard listeners.isEmpty else { return }

        listeners.append(
            firestore.collection("users").addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.trabajadores = self.consolidarTrabajadores((snapshot?.documents ?? []).map(self.mapearTrabajador))
                self.reconstruirVista()
            }
        )

        listeners.append(
            firestore.collection("roles").addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.roles = (snapshot?.documents ?? []).map(self.mapearRol)
                self.reconstruirVista()
            }
        )

        listeners.append(
            firestore.collection("sales").addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.eventosVenta = (snapshot?.documents ?? []).map(self.mapearEventoOperacion)
                self.reconstruirVista()
            }
        )

        listeners.append(
            firestore.collection("sale_installments").addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.eventosCobro = (snapshot?.documents ?? []).map(self.mapearEventoOperacion)
                self.reconstruirVista()
            }
        )
    }

    private func reconstruirVista() {
        datosVista = construirDatosVista()
        actualizarVista()
    }

    private func construirDatosVista() -> DatosPantallaRrhh {
        let trabajadoresActivos = trabajadores.filter(\.active)
        let trabajadoresOrdenados = trabajadores.sorted {
            if $0.active != $1.active {
                return $0.active && !$1.active
            }
            return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
        let tarjetasTrabajadores = trabajadoresOrdenados.map(crearTarjetaTrabajador)

        let resumenPorRol = Dictionary(grouping: trabajadoresActivos, by: \.roleId)
        let rolesMostrados = rolesDisponibles()

        let tarjetasRol = rolesMostrados.map { rol in
            let total = resumenPorRol[rol.id]?.count ?? 0
            return DatosPantallaRrhh.TarjetaRol(
                id: rol.id,
                nombre: rol.nombreVisual,
                subtitulo: rol.permisos.isEmpty ? "Sin configurar" : "\(rol.permisosActivos) módulos",
                colorHex: rol.colorHex,
                total: total
            )
        }

        let distribucionRoles = rolesMostrados.map { rol in
            DatosPantallaRrhh.SegmentoRol(
                id: rol.id,
                nombre: rol.nombreVisual,
                colorHex: rol.colorHex,
                total: resumenPorRol[rol.id]?.count ?? 0,
                icono: rol.icono
            )
        }

        let actividadSemanal = trabajadoresOrdenados.map { trabajador in
            DatosPantallaRrhh.BarraActividad(
                id: trabajador.id,
                iniciales: trabajador.iniciales,
                ventas: conteoVentas(para: trabajador),
                cobros: conteoCobros(para: trabajador)
            )
        }

        let turnosHoy = trabajadoresOrdenados.map { trabajador in
            DatosPantallaRrhh.FilaTurno(
                id: trabajador.id,
                nombre: trabajador.fullName,
                rol: trabajador.nombreRol,
                turno: trabajador.turnoTexto,
                telefono: trabajador.phone,
                colorHex: trabajador.colorHex
            )
        }

        let permisosRoles = rolesMostrados.map { rol in
            DatosPantallaRrhh.BloquePermisosRol(
                id: rol.id,
                nombre: rol.nombreVisual,
                subtitulo: rol.permisos.isEmpty ? "Sin configurar" : "\(rol.permisosActivos)/\(rol.permisos.count) módulos",
                colorHex: rol.colorHex,
                permisos: rol.permisosOrdenados.map {
                    DatosPantallaRrhh.FilaPermiso(
                        id: "\($0.key)-\(rol.id)",
                        nombre: nombreModulo($0.key),
                        activo: $0.value,
                        fijo: $0.key == "inicio"
                    )
                }
            )
        }

        return DatosPantallaRrhh(
            permiteAgregar: puedeGestionarRrhh,
            mensajeEstado: trabajadoresActivos.isEmpty && roles.isEmpty
                ? "No hay trabajadores ni roles configurados todavía."
                : nil,
            totalActivos: trabajadoresActivos.count,
            tarjetasRol: tarjetasRol,
            distribucionRoles: distribucionRoles,
            actividadSemanal: actividadSemanal,
            turnosHoy: turnosHoy,
            tarjetasTrabajadores: tarjetasTrabajadores,
            filtrosRol: [.todos] + rolesMostrados.map { .rol(id: $0.id, nombre: $0.nombreVisual, colorHex: $0.colorHex) },
            bloquesPermisos: permisosRoles
        )
    }

    private func rolesDisponibles() -> [RolRemoto] {
        let idsDesdeUsuarios = Set(trabajadores.map(\.roleId))
        let rolesRemotos = roles.reduce(into: [String: RolRemoto]()) { acumulado, rol in
            guard rol.id.isEmpty == false else { return }
            if let existente = acumulado[rol.id] {
                acumulado[rol.id] = combinarRol(existente, con: rol)
            } else {
                acumulado[rol.id] = rol
            }
        }
        .values
        .sorted { $0.nombreVisual < $1.nombreVisual }
        let idsRemotos = Set(rolesRemotos.map(\.id))

        let faltantes = idsDesdeUsuarios.subtracting(idsRemotos).map { RolRemoto(id: $0, name: $0, active: true, permisos: [:]) }
        return (rolesRemotos + faltantes).sorted { $0.nombreVisual < $1.nombreVisual }
    }

    private func combinarRol(_ actual: RolRemoto, con nuevo: RolRemoto) -> RolRemoto {
        let permisos = actual.permisos.count >= nuevo.permisos.count ? actual.permisos : nuevo.permisos
        let nombre = actual.name.count >= nuevo.name.count ? actual.name : nuevo.name
        return RolRemoto(
            id: actual.id,
            name: nombre,
            active: actual.active || nuevo.active,
            permisos: permisos
        )
    }

    private func crearTarjetaTrabajador(_ trabajador: TrabajadorRemoto) -> DatosPantallaRrhh.TarjetaTrabajador {
        DatosPantallaRrhh.TarjetaTrabajador(
            id: trabajador.id,
            iniciales: trabajador.iniciales,
            nombre: trabajador.fullName,
            rol: trabajador.nombreRol,
            turno: trabajador.turnoTexto,
            telefono: trabajador.phone,
            estado: trabajador.active ? "Activo" : "Inactivo",
            colorHex: trabajador.colorHex,
            colorSuaveHex: trabajador.colorSuaveHex,
            icono: trabajador.iconoRol,
            ventas: conteoVentas(para: trabajador),
            cobros: conteoCobros(para: trabajador)
        )
    }

    private func conteoVentas(para trabajador: TrabajadorRemoto) -> Int {
        eventosVenta.filter { $0.coincideCon(trabajador: trabajador) }.count
    }

    private func conteoCobros(para trabajador: TrabajadorRemoto) -> Int {
        eventosCobro.filter { $0.coincideCon(trabajador: trabajador) }.count
    }

    private func consolidarTrabajadores(_ lista: [TrabajadorRemoto]) -> [TrabajadorRemoto] {
        lista.reduce(into: [String: TrabajadorRemoto]()) { acumulado, trabajador in
            let clave = identidadTrabajador(trabajador)
            if let existente = acumulado[clave] {
                acumulado[clave] = combinarTrabajador(existente, con: trabajador)
            } else {
                acumulado[clave] = trabajador
            }
        }
        .values
        .sorted {
            if $0.active != $1.active {
                return $0.active && !$1.active
            }
            return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    private func identidadTrabajador(_ trabajador: TrabajadorRemoto) -> String {
        if trabajador.authUid.isEmpty == false {
            return "auth:\(trabajador.authUid.lowercased())"
        }
        if trabajador.email.isEmpty == false {
            return "email:\(trabajador.email.lowercased())"
        }
        return "doc:\(trabajador.id)"
    }

    private func combinarTrabajador(_ actual: TrabajadorRemoto, con nuevo: TrabajadorRemoto) -> TrabajadorRemoto {
        let preferido = puntajeTrabajador(nuevo) >= puntajeTrabajador(actual) ? nuevo : actual
        let respaldo = preferido.id == actual.id ? nuevo : actual

        return TrabajadorRemoto(
            id: preferido.id,
            authUid: preferido.authUid.isEmpty ? respaldo.authUid : preferido.authUid,
            fullName: preferido.fullName == "Sin nombre" ? respaldo.fullName : preferido.fullName,
            email: preferido.email.isEmpty ? respaldo.email : preferido.email,
            roleId: preferido.roleId == "sin_rol" ? respaldo.roleId : preferido.roleId,
            active: preferido.active || respaldo.active,
            phone: preferido.phone == "Sin teléfono" ? respaldo.phone : preferido.phone,
            shift: preferido.shift.isEmpty ? respaldo.shift : preferido.shift,
            salaryMonthly: preferido.salaryMonthly > 0 ? preferido.salaryMonthly : respaldo.salaryMonthly
        )
    }

    private func puntajeTrabajador(_ trabajador: TrabajadorRemoto) -> Int {
        var puntaje = 0
        if trabajador.active { puntaje += 10 }
        if trabajador.authUid.isEmpty == false { puntaje += 5 }
        if trabajador.email.isEmpty == false { puntaje += 3 }
        if trabajador.fullName != "Sin nombre" { puntaje += 2 }
        if trabajador.phone != "Sin teléfono" { puntaje += 1 }
        if trabajador.shift.isEmpty == false { puntaje += 1 }
        if trabajador.salaryMonthly > 0 { puntaje += 1 }
        return puntaje
    }

    private func mapearTrabajador(_ document: QueryDocumentSnapshot) -> TrabajadorRemoto {
        let data = document.data()
        return TrabajadorRemoto(
            id: document.documentID,
            authUid: valorTexto(data, keys: ["authUid"]) ?? "",
            fullName: valorTexto(data, keys: ["fullName", "username", "nombre"]) ?? "Sin nombre",
            email: valorTexto(data, keys: ["email"]) ?? "",
            roleId: normalizarRoleId(valorTexto(data, keys: ["roleId", "role"]) ?? "sin_rol"),
            active: valorBool(data, keys: ["active", "activo", "status"], default: true),
            phone: valorTexto(data, keys: ["phone", "telefono"]) ?? "Sin teléfono",
            shift: valorTexto(data, keys: ["shift", "turno"]) ?? "",
            salaryMonthly: valorDouble(data, keys: ["salaryMonthly", "salarioMensual"], default: 0)
        )
    }

    private func mapearRol(_ document: QueryDocumentSnapshot) -> RolRemoto {
        let data = document.data()
        let permisos = data["modulePermissions"] as? [String: Bool] ?? data["permissions"] as? [String: Bool] ?? [:]
        let nombre = valorTexto(data, keys: ["name", "nombre"]) ?? document.documentID
        return RolRemoto(
            id: roleIdCanonico(id: document.documentID, nombre: nombre),
            name: nombre,
            active: valorBool(data, keys: ["active", "activo"], default: true),
            permisos: permisos
        )
    }

    private func mapearEventoOperacion(_ document: QueryDocumentSnapshot) -> EventoOperacionRemota {
        let data = document.data()
        return EventoOperacionRemota(
            userId: valorTexto(data, keys: ["createdByUserId", "paidByUserId", "userId", "workerUserId"]),
            authUid: valorTexto(data, keys: ["createdByAuthUid", "authUid"]),
            email: valorTexto(data, keys: ["createdByEmail", "email"])
        )
    }

    private func valorTexto(_ data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return value
            }
        }
        return nil
    }

    private func valorBool(_ data: [String: Any], keys: [String], default valorPorDefecto: Bool) -> Bool {
        for key in keys {
            if let value = data[key] as? Bool {
                return value
            }
            if let value = data[key] as? NSNumber {
                return value.boolValue
            }
        }
        return valorPorDefecto
    }

    private func valorDouble(_ data: [String: Any], keys: [String], default valorPorDefecto: Double) -> Double {
        for key in keys {
            if let value = data[key] as? Double {
                return value
            }
            if let value = data[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = data[key] as? String, let numero = Double(value.replacingOccurrences(of: ",", with: ".")) {
                return numero
            }
        }
        return valorPorDefecto
    }

    private func nombreModulo(_ clave: String) -> String {
        switch clave {
        case "inicio": return "Inicio"
        case "ventas": return "Ventas"
        case "clientes": return "Clientes"
        case "almacen": return "Almacén"
        case "tesoreria": return "Tesorería"
        case "cobros": return "Cobros"
        case "compras": return "Compras"
        case "mas": return "Más"
        case "rrhh": return "RRHH"
        default: return clave.capitalized
        }
    }

    private func normalizarRoleId(_ valor: String) -> String {
        switch valor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin", "administrador":
            return "admin"
        case "supervisor", "super":
            return "supervisor"
        case "almacenero", "almacen":
            return "almacenero"
        case "cajero":
            return "cajero"
        default:
            return valor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private func roleIdCanonico(id: String, nombre: String) -> String {
        let normalizadoId = normalizarRoleId(id)
        if ["admin", "supervisor", "almacenero", "cajero"].contains(normalizadoId) {
            return normalizadoId
        }

        let normalizadoNombre = normalizarRoleId(nombre)
        if ["admin", "supervisor", "almacenero", "cajero"].contains(normalizadoNombre) {
            return normalizadoNombre
        }

        return normalizadoId
    }
    #endif
}

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
private struct ErrorRegistroTrabajador: LocalizedError {
    let mensaje: String

    static func mensaje(_ texto: String) -> ErrorRegistroTrabajador {
        ErrorRegistroTrabajador(mensaje: texto)
    }

    var errorDescription: String? { mensaje }
}

struct TrabajadorRemoto {
    let id: String
    let authUid: String
    let fullName: String
    let email: String
    let roleId: String
    let active: Bool
    let phone: String
    let shift: String
    let salaryMonthly: Double

    var nombreRol: String {
        switch roleId.lowercased() {
        case "admin", "administrador": return "Administrador"
        case "cajero": return "Cajero"
        case "almacenero", "almacen": return "Almacenero"
        case "super", "supervisor": return "Supervisor"
        default: return roleId.capitalized
        }
    }

    var turnoTexto: String {
        switch shift.lowercased() {
        case "manana", "mañana": return "Turno mañana"
        case "tarde": return "Turno tarde"
        case "dia_completo", "día completo", "completo": return "Día completo"
        default: return shift.isEmpty ? "Turno sin definir" : shift.capitalized
        }
    }

    var iniciales: String {
        let partes = fullName.split(separator: " ")
        let letras = partes.prefix(2).compactMap { $0.first }
        return letras.isEmpty ? "?" : String(letras)
    }

    var colorHex: String {
        switch roleId.lowercased() {
        case "cajero": return "4C7CF3"
        case "almacenero", "almacen": return "F3A533"
        case "super", "supervisor": return "8B5CF6"
        default: return "7C3AED"
        }
    }

    var colorSuaveHex: String {
        switch roleId.lowercased() {
        case "cajero": return "EEF4FF"
        case "almacenero", "almacen": return "FFF7E8"
        case "super", "supervisor": return "F4EEFF"
        default: return "F3F0FF"
        }
    }

    var iconoRol: String {
        switch roleId.lowercased() {
        case "cajero": return "dollarsign"
        case "almacenero", "almacen": return "shippingbox"
        case "super", "supervisor": return "star"
        default: return "person"
        }
    }

    var salarioMensualTexto: String {
        if salaryMonthly.rounded() == salaryMonthly {
            return String(Int(salaryMonthly))
        }
        return String(salaryMonthly)
    }
}

private struct RolRemoto {
    let id: String
    let name: String
    let active: Bool
    let permisos: [String: Bool]

    var nombreVisual: String {
        switch id.lowercased() {
        case "admin", "administrador": return "Administrador"
        case "cajero": return "Cajero"
        case "almacenero", "almacen": return "Almacenero"
        case "super", "supervisor": return "Supervisor"
        default: return name.capitalized
        }
    }

    var colorHex: String {
        switch id.lowercased() {
        case "admin", "administrador": return "4C7CF3"
        case "cajero": return "4C7CF3"
        case "almacenero", "almacen": return "F3A533"
        case "super", "supervisor": return "8B5CF6"
        default: return "9CA3AF"
        }
    }

    var icono: String {
        switch id.lowercased() {
        case "cajero": return "dollarsign"
        case "almacenero", "almacen": return "shippingbox"
        case "super", "supervisor": return "star"
        default: return "person"
        }
    }

    var permisosActivos: Int {
        permisos.values.filter { $0 }.count
    }

    var permisosOrdenados: [(key: String, value: Bool)] {
        permisos.sorted { $0.key < $1.key }
    }
}

private struct EventoOperacionRemota {
    let userId: String?
    let authUid: String?
    let email: String?

    func coincideCon(trabajador: TrabajadorRemoto) -> Bool {
        if let userId, userId == trabajador.id { return true }
        if let authUid, authUid == trabajador.authUid { return true }
        if let email, email.caseInsensitiveCompare(trabajador.email) == .orderedSame { return true }
        return false
    }
}
#endif
