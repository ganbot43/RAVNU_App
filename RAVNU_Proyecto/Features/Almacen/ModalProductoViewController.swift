import Combine
import CoreData
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalProductoViewControllerDelegate: AnyObject {
    func modalProductoViewControllerDidSave(_ controller: ModalProductoViewController)
}

final class ModalProductoViewController: UIViewController {

    @IBOutlet private weak var txtNombre: UITextField?
    @IBOutlet private weak var txtPrecio: UITextField?
    @IBOutlet private weak var txtUnidad: UITextField?
    @IBOutlet private weak var txtStockMinimo: UITextField?
    @IBOutlet private weak var txtCapacidad: UITextField?
    @IBOutlet private weak var tipoControl: UISegmentedControl?
    @IBOutlet private weak var btnGuardar: UIButton?

    weak var delegate: ModalProductoViewControllerDelegate?
    var productoExistente: ProductoEntity?
    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let context = AppCoreData.viewContext
    private let formState = ProductoFormState()
    private var hostingController: UIHostingController<ProductoModalContentView>?

    private var puedeGestionarDirecto: Bool {
        RoleAccessControl.canManageDirectly
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        [txtPrecio, txtStockMinimo, txtCapacidad].forEach { $0?.keyboardType = .decimalPad }
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
        configurarVistaHibrida()
        configurarMensajesDeContexto()
        cargarProductoExistenteSiAplica()
        actualizarVistaHibrida()
    }

    private func configurarVistaHibrida() {
        [txtNombre, txtPrecio, txtUnidad, txtStockMinimo, txtCapacidad, tipoControl, btnGuardar]
            .forEach { $0?.isHidden = true }

        let host = UIHostingController(rootView: crearVistaProducto())
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

    private func crearVistaProducto() -> ProductoModalContentView {
        ProductoModalContentView(
            state: formState,
            isEditing: productoExistente != nil,
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSave: { [weak self] in self?.handleSaveTapped() }
        )
    }

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaProducto()
    }

    private func configurarMensajesDeContexto() {
        txtNombre?.placeholder = "Nombre del producto"
        txtPrecio?.placeholder = "Precio por litro"
        txtUnidad?.placeholder = "Unidad de medida"
        txtStockMinimo?.placeholder = "Mínimo base por almacén"
        txtCapacidad?.placeholder = "Capacidad base por almacén"
        formState.namePlaceholder = "Gasoline 90, GLP, Diesel B5..."
        formState.pricePlaceholder = "0.00"
        formState.unitPlaceholder = "L, bal, m3..."
        formState.minimumPlaceholder = "Mínimo base por almacén"
        formState.capacityPlaceholder = "Capacidad base por almacén"
    }

    private func parseDouble(_ text: String?) -> Double {
        Double((text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func validateInputs() -> String? {
        let trimmedName = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Ingresa el nombre del producto."
        }
        if parseDouble(formState.price) <= 0 {
            return "Ingresa un precio mayor a cero."
        }
        if formState.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa la unidad de medida."
        }
        if parseDouble(formState.minimumStock) <= 0 {
            return "Ingresa un mínimo base por almacén mayor a cero."
        }
        if parseDouble(formState.capacity) <= 0 {
            return "Ingresa una capacidad base por almacén mayor a cero."
        }
        if parseDouble(formState.minimumStock) > parseDouble(formState.capacity) {
            return "El mínimo base por almacén no puede ser mayor que la capacidad base por almacén."
        }
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "nombre =[c] %@", trimmedName)
        let duplicados = ((try? context.fetch(request)) ?? []).filter { $0.objectID != productoExistente?.objectID }
        if duplicados.isEmpty == false {
            return "Ya existe un producto con ese nombre."
        }
        return nil
    }

    private func cargarProductoExistenteSiAplica() {
        guard let productoExistente else { return }
        formState.name = productoExistente.nombre ?? ""
        formState.price = productoExistente.precioPorLitro == 0 ? "" : String(format: "%.2f", productoExistente.precioPorLitro)
        formState.unit = productoExistente.unidadMedida ?? ""
        formState.minimumStock = productoExistente.stockMinimo == 0 ? "" : String(format: "%.0f", productoExistente.stockMinimo)
        formState.capacity = productoExistente.capacidadTotal == 0 ? "" : String(format: "%.0f", productoExistente.capacidadTotal)
        formState.productType = (productoExistente.tipo ?? "").uppercased() == "GLP" ? .glp : .fuel
    }

    private func payload(for productId: UUID) -> [String: Any] {
        var payload: [String: Any] = [
            "id": productId.uuidString,
            "nombre": formState.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "precioPorLitro": parseDouble(formState.price),
            "unidadMedida": formState.normalizedUnit,
            "stockMinimo": parseDouble(formState.minimumStock),
            "capacidadTotal": parseDouble(formState.capacity),
            "stockLitros": productoExistente?.stockLitros ?? 0.0,
            "tipo": formState.productType.firestoreValue,
            "activo": true,
            "updatedAt": Timestamp(date: Date())
        ]
        if productoExistente == nil {
            payload["createdAt"] = Timestamp(date: Date())
        }
        return payload
    }

    private func saveProductoToLocal(id: UUID) throws {
        let producto = productoExistente ?? ProductoEntity(context: context)
        producto.id = id
        producto.nombre = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.precioPorLitro = parseDouble(formState.price)
        producto.unidadMedida = formState.normalizedUnit
        producto.stockMinimo = parseDouble(formState.minimumStock)
        producto.capacidadTotal = parseDouble(formState.capacity)
        if productoExistente == nil {
            producto.stockLitros = 0
        }
        producto.tipo = formState.productType.firestoreValue
        producto.activo = true
        if productoExistente == nil {
            createInitialStocks(for: producto)
        } else {
            actualizarStocksExistentes(for: producto)
        }
        try context.save()
    }

    private func saveProducto() throws {
        let productoId = productoExistente?.id ?? UUID()

        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            let productRef = firestore.collection("products").document(productoId.uuidString)
            let batch = firestore.batch()
            batch.setData(payload(for: productoId), forDocument: productRef, merge: true)

            if productoExistente == nil {
                let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
                let almacenes = (try? context.fetch(request)) ?? []
                for almacen in almacenes {
                    let stockId = UUID().uuidString
                    let stockRef = firestore.collection("warehouse_stock").document(stockId)
                    batch.setData([
                        "id": stockId,
                        "almacenId": almacen.id?.uuidString ?? UUID().uuidString,
                        "productoId": productoId.uuidString,
                        "stockActual": 0.0,
                        "stockMinimo": parseDouble(formState.minimumStock),
                        "capacidadTotal": parseDouble(formState.capacity),
                        "unidadMedida": formState.normalizedUnit
                    ], forDocument: stockRef, merge: true)
                }
            }
            batch.commit()
        }
        #endif

        try saveProductoToLocal(id: productoId)
    }

    private func createInitialStocks(for producto: ProductoEntity) {
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        let almacenes = (try? context.fetch(request)) ?? []

        almacenes.forEach { almacen in
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

    private func actualizarStocksExistentes(for producto: ProductoEntity) {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@", producto)
        let stocks = (try? context.fetch(request)) ?? []
        stocks.forEach { stock in
            stock.stockMinimo = producto.stockMinimo
            if stock.capacidadTotal <= 0 {
                stock.capacidadTotal = producto.capacidadTotal
            }
            stock.unidadMedida = producto.unidadMedida ?? "L"
        }
    }

    private func tipoSolicitudProducto() -> String {
        productoExistente == nil ? "create_product" : "update_product"
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func solicitarMotivoYEnviar() {
        let config = AdminRequestComposerConfig(
            title: productoExistente == nil ? "Solicitud de alta de producto" : "Solicitud de actualización de producto",
            subtitle: "Esta información llegará al web admin en la pestaña Solicitudes junto con el resumen del producto y la ruta configurada.",
            moduleLabel: "Almacén",
            typeLabel: tipoSolicitudProducto(),
            targetLabel: productoExistente?.nombre ?? "Producto nuevo",
            accent: .blue,
            primaryField: .init(
                title: "Motivo principal",
                placeholder: "Ej. ampliar portafolio o formalizar un producto ya usado en operación",
                helper: "Resume en una frase por qué debe crearse o ajustarse este producto.",
                isRequired: true
            ),
            secondaryField: .init(
                title: "Necesidad operativa",
                placeholder: "Explica dónde se venderá, almacenará o qué flujo depende de este producto",
                helper: "Este campo ayuda al aprobador a entender el impacto real en ventas, compras y stock.",
                isRequired: true
            ),
            tertiaryField: .init(
                title: "Observación adicional",
                placeholder: "Notas opcionales para precios, stock inicial o coordinación",
                helper: "Úsalo para agregar contexto adicional si hace falta.",
                isRequired: false
            ),
            summaryItems: [
                .init(title: "Nombre", value: formState.name.trimmingCharacters(in: .whitespacesAndNewlines).fallback("Sin nombre")),
                .init(title: "Precio/L", value: currencyText(parseDouble(formState.price))),
                .init(title: "Unidad", value: formState.normalizedUnit),
                .init(title: "Mínimo base", value: quantityText(parseDouble(formState.minimumStock), unit: formState.normalizedUnit)),
                .init(title: "Capacidad base", value: quantityText(parseDouble(formState.capacity), unit: formState.normalizedUnit))
            ],
            endpointLabel: AdminRequestService.requestEndpointDescription()
        )
        presentAdminRequestComposer(config: config) { [weak self] result, presenter in
            guard let self else { return }
            presenter.dismiss(animated: true)
            Task {
                do {
                    try await self.enviarSolicitudProducto(
                        motivo: result.primaryText,
                        necesidad: result.secondaryText,
                        observacion: result.tertiaryText
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
        }
    }

    private func enviarSolicitudProducto(
        motivo: String,
        necesidad: String,
        observacion: String
    ) async throws {
        let requester = try AdminRequestService.currentRequester()
        let payload = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: tipoSolicitudProducto(),
            module: "almacen",
            status: "pending",
            requestedBy: requester,
            target: productoExistente.flatMap { producto in
                guard let id = producto.id?.uuidString else { return nil }
                return .init(entity: "product", entityId: id)
            },
            payload: [
                "modoOperacion": .string(productoExistente == nil ? "crear" : "editar"),
                "nombre": .string(formState.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                "precioPorLitro": .number(parseDouble(formState.price)),
                "unidadMedida": .string(formState.normalizedUnit),
                "stockMinimo": .number(parseDouble(formState.minimumStock)),
                "capacidadTotal": .number(parseDouble(formState.capacity)),
                "tipo": .string(formState.productType.firestoreValue),
                "estadoActual": .object([
                    "id": .string(productoExistente?.id?.uuidString ?? ""),
                    "nombre": .string(productoExistente?.nombre ?? ""),
                    "precioPorLitro": .number(productoExistente?.precioPorLitro ?? 0),
                    "unidadMedida": .string(productoExistente?.unidadMedida ?? ""),
                    "stockMinimo": .number(productoExistente?.stockMinimo ?? 0),
                    "capacidadTotal": .number(productoExistente?.capacidadTotal ?? 0),
                    "tipo": .string(productoExistente?.tipo ?? "")
                ]),
                "detalleSolicitud": .object([
                    "necesidadOperativa": .string(necesidad),
                    "observacion": observacion.isEmpty ? .string("sin_observacion") : .string(observacion),
                    "requiereCreacionStockInicial": .bool(true),
                    "stockConfiguracion": .string("Los valores de stock mínimo y capacidad funcionan como referencia base por almacén. El stock real se controla en StockAlmacen.")
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

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnGuardarTapped(_ sender: UIButton) {
        handleSaveTapped()
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
                try saveProducto()
                delegate?.modalProductoViewControllerDidSave(self)
                dismiss(animated: true)
            } catch {
                showAlert(title: "Error", message: "No se pudo guardar el producto.")
            }
        } else if RoleAccessControl.canRequestProductCreation {
            solicitarMotivoYEnviar()
        } else {
            showAlert(title: "Permiso denegado", message: "Tu rol no puede solicitar nuevos productos.")
        }
    }

    private func currencyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: NSNumber(value: value)) ?? "S/\(value)"
    }

    private func quantityText(_ value: Double, unit: String) -> String {
        let number = value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
        return "\(number) \(unit)"
    }
}

private extension String {
    func fallback(_ value: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? value : self
    }
}

private final class ProductoFormState: ObservableObject {
    enum ProductType: String, CaseIterable, Identifiable {
        case fuel
        case glp

        var id: String { rawValue }
        var title: String { self == .fuel ? "Combustible" : "GLP" }
        var firestoreValue: String { self == .fuel ? "Combustible" : "GLP" }
        var iconName: String { self == .fuel ? "drop.fill" : "flame.fill" }
        var accentColor: Color { self == .fuel ? Color(hex: "3B82F6") : Color(hex: "22C55E") }
    }

    @Published var name = ""
    @Published var price = ""
    @Published var unit = ""
    @Published var minimumStock = ""
    @Published var capacity = ""
    @Published var productType: ProductType = .fuel

    var namePlaceholder = ""
    var pricePlaceholder = ""
    var unitPlaceholder = ""
    var minimumPlaceholder = ""
    var capacityPlaceholder = ""

    var normalizedUnit: String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "L" : trimmed
    }
}

private struct ProductoModalContentView: View {
    @ObservedObject var state: ProductoFormState
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    typePicker
                    sectionCard(title: "Datos base", subtitle: "Define identidad comercial y precio del producto.") {
                        field("Nombre", text: $state.name, placeholder: state.namePlaceholder, icon: "shippingbox")
                        field("Precio por litro", text: $state.price, placeholder: state.pricePlaceholder, icon: "banknote", keyboard: .decimalPad)
                        field("Unidad de medida", text: $state.unit, placeholder: state.unitPlaceholder, icon: "ruler")
                    }
                    sectionCard(title: "Parámetros por almacén", subtitle: "Estos valores sirven como referencia inicial para cada almacén.") {
                        field("Mínimo base por almacén", text: $state.minimumStock, placeholder: state.minimumPlaceholder, icon: "arrow.down.to.line", keyboard: .decimalPad)
                        field("Capacidad base por almacén", text: $state.capacity, placeholder: state.capacityPlaceholder, icon: "gauge.with.dots.needle.50percent", keyboard: .decimalPad)
                    }
                    helperCard
                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            Image(systemName: isEditing ? "square.and.pencil" : "plus.circle.fill")
                            Text(isEditing ? "Guardar cambios" : "Registrar producto")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "3B82F6"), Color(hex: "3B82F6")],
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
                    Text(isEditing ? "Editar producto" : "Nuevo producto")
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Ajusta el producto" : "Configura un nuevo producto")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Text("El stock real se moverá desde almacenes; aquí defines el catálogo y sus referencias.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.84))
                }
                Spacer()
                Image(systemName: state.productType.iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 10) {
                metricChip(title: "TIPO", value: state.productType.title)
                metricChip(title: "UNIDAD", value: state.normalizedUnit)
                metricChip(title: "MODO", value: isEditing ? "Edición" : "Alta")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "3B82F6"), Color(hex: "3B82F6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tipo de producto")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 10) {
                ForEach(ProductoFormState.ProductType.allCases) { type in
                    Button {
                        state.productType = type
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                            Text(type.title)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(state.productType == type ? .white : type.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(state.productType == type ? type.accentColor : type.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var helperCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cómo se aplican estos valores", systemImage: "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "92400E"))

            Text("El mínimo y la capacidad base se copian como referencia inicial a cada almacén. Luego cada almacén puede terminar con niveles reales distintos según compras, ventas y transferencias.")
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
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
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
                .foregroundStyle(Color.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "3B82F6"))
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
