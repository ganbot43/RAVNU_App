import Combine
import CoreData
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalAlmacenViewControllerDelegate: AnyObject {
    func modalAlmacenViewControllerDidSave(_ controller: ModalAlmacenViewController)
}

final class ModalAlmacenViewController: UIViewController {

    @IBOutlet private weak var txtNombre: UITextField?
    @IBOutlet private weak var txtDireccion: UITextField?
    @IBOutlet private weak var txtResponsable: UITextField?
    @IBOutlet private weak var btnGuardar: UIButton?

    weak var delegate: ModalAlmacenViewControllerDelegate?
    var almacenExistente: AlmacenEntity?
    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let context = AppCoreData.viewContext
    private let formState = AlmacenFormState()
    private var responsablesDisponibles: [String] = []
    private var hostingController: UIHostingController<AlmacenModalContentView>?

    private var puedeGestionarDirecto: Bool {
        RoleAccessControl.canManageDirectly
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
        configurarVistaHibrida()
        configurarMensajesDeContexto()
        cargarResponsables()
        cargarAlmacenExistenteSiAplica()
        actualizarVistaHibrida()
    }

    private func configurarVistaHibrida() {
        [txtNombre, txtDireccion, txtResponsable, btnGuardar].forEach { $0?.isHidden = true }

        let host = UIHostingController(rootView: crearVistaAlmacen())
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

    private func crearVistaAlmacen() -> AlmacenModalContentView {
        AlmacenModalContentView(
            state: formState,
            isEditing: almacenExistente != nil,
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSave: { [weak self] in self?.handleSaveTapped() }
        )
    }

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaAlmacen()
    }

    private func configurarMensajesDeContexto() {
        txtNombre?.placeholder = "Nombre del almacén"
        txtDireccion?.placeholder = "Dirección"
        txtResponsable?.placeholder = "Responsable"
        formState.namePlaceholder = "Main Station, Planta Norte..."
        formState.addressPlaceholder = "Av. Principal 245, Lima"
        formState.capacityPlaceholder = "Capacidad máxima del almacén"
    }

    private func parseDouble(_ text: String?) -> Double {
        Double((text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func validateInputs() -> String? {
        let trimmedName = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Ingresa el nombre del almacén."
        }
        if formState.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa la dirección."
        }
        if formState.manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Selecciona un responsable."
        }
        if parseDouble(formState.capacity) <= 0 {
            return "Ingresa la cantidad máxima del almacén."
        }
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "nombre =[c] %@", trimmedName)
        let duplicados = ((try? context.fetch(request)) ?? []).filter { $0.objectID != almacenExistente?.objectID }
        if duplicados.isEmpty == false {
            return "Ya existe un almacén con ese nombre."
        }
        return nil
    }

    private func cargarAlmacenExistenteSiAplica() {
        guard let almacenExistente else { return }
        formState.name = almacenExistente.nombre ?? ""
        formState.address = almacenExistente.direccion ?? ""
        formState.manager = almacenExistente.responsable ?? ""
        formState.capacity = almacenExistente.stockEspacio > 0 ? String(format: "%.0f", almacenExistente.stockEspacio) : ""
    }

    private func payload(for almacenId: UUID) -> [String: Any] {
        var payload: [String: Any] = [
            "id": almacenId.uuidString,
            "nombre": formState.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "direccion": formState.address.trimmingCharacters(in: .whitespacesAndNewlines),
            "responsable": formState.manager.trimmingCharacters(in: .whitespacesAndNewlines),
            "stockEspacio": parseDouble(formState.capacity),
            "activo": true,
            "updatedAt": Timestamp(date: Date())
        ]
        if almacenExistente == nil {
            payload["createdAt"] = Timestamp(date: Date())
        }
        return payload
    }

    private func saveAlmacenToLocal(id: UUID) throws {
        let almacen = almacenExistente ?? AlmacenEntity(context: context)
        almacen.id = id
        almacen.nombre = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.direccion = formState.address.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.responsable = formState.manager.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.stockEspacio = parseDouble(formState.capacity)
        almacen.activo = true
        if almacenExistente == nil {
            createInitialStocks(for: almacen)
        }
        try context.save()
    }

    private func saveAlmacen() throws {
        let almacenId = almacenExistente?.id ?? UUID()

        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            let warehouseRef = firestore.collection("warehouses").document(almacenId.uuidString)
            let batch = firestore.batch()
            batch.setData(payload(for: almacenId), forDocument: warehouseRef, merge: true)

            if almacenExistente == nil {
                let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
                let productos = (try? context.fetch(request)) ?? []
                for producto in productos {
                    let stockId = UUID().uuidString
                    let stockRef = firestore.collection("warehouse_stock").document(stockId)
                    batch.setData([
                        "id": stockId,
                        "almacenId": almacenId.uuidString,
                        "productoId": producto.id?.uuidString ?? UUID().uuidString,
                        "stockActual": 0.0,
                        "stockMinimo": producto.stockMinimo,
                        "capacidadTotal": producto.capacidadTotal,
                        "unidadMedida": producto.unidadMedida ?? "L"
                    ], forDocument: stockRef, merge: true)
                }
            }
            batch.commit()
        }
        #endif

        try saveAlmacenToLocal(id: almacenId)
    }

    private func createInitialStocks(for almacen: AlmacenEntity) {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        let productos = (try? context.fetch(request)) ?? []

        productos.forEach { producto in
            let stock = StockAlmacenEntity(context: context)
            stock.id = UUID()
            stock.almacen = almacen
            stock.producto = producto
            stock.stockActual = 0
            stock.stockMinimo = producto.stockMinimo
            stock.capacidadTotal = producto.capacidadTotal
            stock.unidadMedida = producto.unidadMedida ?? "L"
        }
    }

    private func tipoSolicitudAlmacen() -> String {
        almacenExistente == nil ? "create_warehouse" : "update_warehouse"
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func solicitarMotivoYEnviar() {
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud detallada para registrar el almacén. Describe el motivo y el impacto operativo.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Motivo principal"
        }
        alert.addTextField { textField in
            textField.placeholder = "Uso o cobertura operativa"
        }
        alert.addTextField { textField in
            textField.placeholder = "Observación adicional"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let motivo = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cobertura = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let observacion = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard motivo.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            guard cobertura.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Describe la cobertura operativa del almacén.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudAlmacen(
                        motivo: motivo,
                        cobertura: cobertura,
                        observacion: observacion
                    )
                    await MainActor.run {
                        self.showAlertAndDismiss(
                            title: "Solicitud enviada",
                            message: "La solicitud fue enviada al panel administrativo."
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func enviarSolicitudAlmacen(
        motivo: String,
        cobertura: String,
        observacion: String
    ) async throws {
        let requester = try AdminRequestService.currentRequester()
        let payload = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: tipoSolicitudAlmacen(),
            module: "almacen",
            status: "pending",
            requestedBy: requester,
            target: almacenExistente.flatMap { almacen in
                guard let id = almacen.id?.uuidString else { return nil }
                return .init(entity: "warehouse", entityId: id)
            },
            payload: [
                "modoOperacion": .string(almacenExistente == nil ? "crear" : "editar"),
                "nombre": .string(formState.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                "direccion": .string(formState.address.trimmingCharacters(in: .whitespacesAndNewlines)),
                "responsable": .string(formState.manager.trimmingCharacters(in: .whitespacesAndNewlines)),
                "stockEspacio": .number(parseDouble(formState.capacity)),
                "estadoActual": .object([
                    "id": .string(almacenExistente?.id?.uuidString ?? ""),
                    "nombre": .string(almacenExistente?.nombre ?? ""),
                    "direccion": .string(almacenExistente?.direccion ?? ""),
                    "responsable": .string(almacenExistente?.responsable ?? ""),
                    "stockEspacio": .number(almacenExistente?.stockEspacio ?? 0)
                ]),
                "detalleSolicitud": .object([
                    "coberturaOperativa": .string(cobertura),
                    "observacion": observacion.isEmpty ? .string("sin_observacion") : .string(observacion),
                    "requiereMatrizStock": .bool(true)
                ])
            ],
            reason: motivo,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        try await AdminRequestService.submit(payload)
    }

    private func showAlertAndDismiss(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func cargarResponsables() {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        firestore.collection("users").getDocuments { [weak self] snapshot, _ in
            guard let self else { return }
            let trabajadores = (snapshot?.documents ?? []).compactMap { document -> String? in
                let data = document.data()
                let roleId = ((data["roleId"] as? String) ?? (data["role"] as? String) ?? "").lowercased()
                let activo = (data["active"] as? Bool) ?? (data["status"] as? Bool) ?? true
                guard activo, roleId == "almacenero" || roleId == "almacen" else { return nil }
                return (data["fullName"] as? String) ?? (data["username"] as? String)
            }
            .sorted()

            DispatchQueue.main.async {
                self.responsablesDisponibles = trabajadores
                self.formState.availableManagers = trabajadores
                if self.formState.manager.isEmpty, let primero = trabajadores.first {
                    self.formState.manager = primero
                }
                self.actualizarVistaHibrida()
            }
        }
        #endif
    }

    private func handleSaveTapped() {
        guard RoleAccessControl.canManageWarehouse else {
            showAlert(title: "Permiso denegado", message: RoleAccessControl.denialMessage(for: .manageWarehouse))
            return
        }

        if let message = validateInputs() {
            showAlert(title: "Validación", message: message)
            return
        }

        if puedeGestionarDirecto {
            do {
                try saveAlmacen()
                delegate?.modalAlmacenViewControllerDidSave(self)
                dismiss(animated: true)
            } catch {
                showAlert(title: "Error", message: "No se pudo guardar el almacén.")
            }
        } else if RoleAccessControl.canRequestWarehouseCreation {
            solicitarMotivoYEnviar()
        } else {
            showAlert(title: "Permiso denegado", message: "Tu rol no puede solicitar nuevos almacenes.")
        }
    }

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnGuardarTapped(_ sender: UIButton) {
        handleSaveTapped()
    }
}

private final class AlmacenFormState: ObservableObject {
    @Published var name = ""
    @Published var address = ""
    @Published var manager = ""
    @Published var capacity = ""
    @Published var availableManagers: [String] = []

    var namePlaceholder = ""
    var addressPlaceholder = ""
    var capacityPlaceholder = ""
}

private struct AlmacenModalContentView: View {
    @ObservedObject var state: AlmacenFormState
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var showManagerPicker = false

    private var capacityValue: Double {
        Double(state.capacity.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    sectionCard(title: "Identidad operativa", subtitle: "Define cómo se verá y ubicará este almacén dentro de la red.") {
                        field("Nombre del almacén", text: $state.name, placeholder: state.namePlaceholder, icon: "building.2")
                        field("Dirección", text: $state.address, placeholder: state.addressPlaceholder, icon: "mappin.and.ellipse")
                    }
                    sectionCard(title: "Capacidad y responsable", subtitle: "La capacidad máxima fija el techo operativo; el responsable facilita control y trazabilidad.") {
                        managerField
                        field("Cantidad máxima del almacén", text: $state.capacity, placeholder: state.capacityPlaceholder, icon: "gauge.with.dots.needle.67percent", keyboard: .decimalPad)
                    }
                    insightCard
                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            Image(systemName: isEditing ? "square.and.pencil" : "shippingbox.fill")
                            Text(isEditing ? "Guardar cambios" : "Registrar almacén")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F3F7FB").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Editar almacén" : "Nuevo almacén")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .confirmationDialog("Selecciona un responsable", isPresented: $showManagerPicker) {
                if state.availableManagers.isEmpty {
                    Button("No hay almaceneros disponibles", role: .cancel) { }
                } else {
                    ForEach(state.availableManagers, id: \.self) { manager in
                        Button(manager) {
                            state.manager = manager
                        }
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Refina la estación" : "Activa un nuevo almacén")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Text("Aquí defines la base operativa; luego el stock real se gestionará por producto y movimiento.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.84))
                }
                Spacer()
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 10) {
                metricChip(title: "RESP.", value: state.manager.isEmpty ? "Pendiente" : state.manager)
                metricChip(title: "CAP.", value: capacityValue > 0 ? "\(Int(capacityValue.rounded())) L" : "Definir")
                metricChip(title: "MODO", value: isEditing ? "Edición" : "Alta")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "2563EB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var managerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESPONSABLE")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color(hex: "64748B"))

            Button {
                showManagerPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "2563EB"))
                        .frame(width: 18)

                    Text(state.manager.isEmpty ? "Selecciona un almacenero" : state.manager)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(state.manager.isEmpty ? Color(hex: "94A3B8") : Color(hex: "0F172A"))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(hex: "F8FAFC"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cómo se usa este almacén", systemImage: "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "92400E"))

            Text("La cantidad máxima es la capacidad total de la estación. No representa litros libres; el espacio real disponible se verá después en el detalle por producto y transferencias.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "7C2D12"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "FFF7ED"))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "FED7AA"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(hex: "0F172A"))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "64748B"))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color(hex: "64748B"))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "2563EB"))
                    .frame(width: 18)

                TextField(placeholder, text: text)
                    .font(.system(size: 15, weight: .medium))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(hex: "F8FAFC"))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.68))
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
