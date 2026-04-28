import CoreData
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalMovimientoViewControllerDelegate: AnyObject {
    func modalMovimientoViewControllerDidSave(_ controller: ModalMovimientoViewController)
}

final class ModalMovimientoViewController: UIViewController {

    @IBOutlet private weak var tipoControl: UISegmentedControl?
    @IBOutlet private weak var txtOrigen: UITextField?
    @IBOutlet private weak var txtDestino: UITextField?
    @IBOutlet private weak var txtProducto: UITextField?
    @IBOutlet private weak var txtCantidad: UITextField?
    @IBOutlet private weak var txtNota: UITextField?
    @IBOutlet private weak var btnGuardar: UIButton?

    weak var delegate: ModalMovimientoViewControllerDelegate?

    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private var almacenes: [AlmacenEntity] = []
    private var productos: [ProductoEntity] = []
    private var proveedores: [ProveedorEntity] = []
    private var hostingController: UIHostingController<VistaRaizModalMovimiento>?

    private let contexto = AppCoreData.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        cargarDatos()
        configurarVistaHibrida()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarDatos()
        actualizarVistaHibrida()
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

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaRaiz()
    }

    private func crearVistaRaiz() -> VistaRaizModalMovimiento {
        VistaRaizModalMovimiento(
            data: crearDatosVista(),
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            },
            onSave: { [weak self] draft in
                self?.manejarBorrador(draft)
            }
        )
    }

    private func cargarDatos() {
        let almacenRequest: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        almacenRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        almacenes = (try? contexto.fetch(almacenRequest)) ?? []

        let productoRequest: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        productoRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        productos = (try? contexto.fetch(productoRequest)) ?? []

        let proveedorRequest: NSFetchRequest<ProveedorEntity> = ProveedorEntity.fetchRequest()
        proveedorRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        proveedores = (try? contexto.fetch(proveedorRequest)) ?? []
    }

    private func crearDatosVista() -> DatosVistaModalMovimiento {
        let warehouseRows = almacenes.map { almacen in
            FilaAlmacenModalMovimiento(
                id: almacen.id?.uuidString ?? UUID().uuidString,
                name: almacen.nombre ?? "Almacén",
                managerName: almacen.responsable ?? "Sin responsable"
            )
        }

        let productRows = productos.map { producto in
            let warehouseStocks = Dictionary(
                uniqueKeysWithValues: almacenes.map { almacen in
                    (almacen.id?.uuidString ?? "", stockAmount(producto: producto, almacen: almacen))
                }
            )
            return FilaProductoModalMovimiento(
                id: producto.id?.uuidString ?? UUID().uuidString,
                name: producto.nombre ?? "Producto",
                unit: producto.unidadMedida?.isEmpty == false ? producto.unidadMedida! : "L",
                price: producto.precioPorLitro,
                totalStock: producto.stockLitros,
                stocksByWarehouse: warehouseStocks
            )
        }

        let supplierRows = proveedores.map { proveedor in
            FilaProveedorModalMovimiento(
                id: proveedor.id?.uuidString ?? UUID().uuidString,
                name: proveedor.nombre ?? "Proveedor"
            )
        }

        return DatosVistaModalMovimiento(
            warehouses: warehouseRows,
            products: productRows,
            suppliers: supplierRows
        )
    }

    private func stockAmount(producto: ProductoEntity, almacen: AlmacenEntity) -> Double {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)
        return (try? contexto.fetch(request).first?.stockActual) ?? 0
    }

    private func manejarBorrador(_ draft: BorradorModalMovimiento) {
        if let message = validarBorrador(draft) {
            mostrarAlerta(title: "Validación", message: message)
            return
        }

        do {
            try guardarMovimiento(using: draft)
            delegate?.modalMovimientoViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            mostrarAlerta(title: "Error", message: "No se pudo registrar el movimiento.")
        }
    }

    private func validarBorrador(_ draft: BorradorModalMovimiento) -> String? {
        if almacenes.isEmpty {
            return "Registra al menos un almacén."
        }
        if productos.isEmpty {
            return "Registra al menos un producto."
        }
        if draft.quantity <= 0 {
            return "Ingresa una cantidad válida."
        }
        if draft.kind == .transfer,
           draft.originWarehouseIndex == draft.destinationWarehouseIndex {
            return "El origen y destino deben ser diferentes."
        }
        if draft.kind == .ingreso, draft.supplierIndex == nil, proveedores.isEmpty == false {
            return "Selecciona un proveedor."
        }

        let producto = productos[draft.productIndex]
        let origen = almacenes[draft.originWarehouseIndex]
        let stockOrigen = stockAmount(producto: producto, almacen: origen)

        if draft.kind == .salida || draft.kind == .transfer {
            if stockOrigen < draft.quantity {
                return "No hay stock suficiente en el almacén de origen."
            }
        }

        if draft.kind == .ingreso || draft.kind == .transfer {
            let destino = draft.kind == .transfer
                ? almacenes[draft.destinationWarehouseIndex]
                : origen
            let stockDestino = stockAmount(producto: producto, almacen: destino)
            let capacidad = max(producto.capacidadTotal, stockRecord(producto: producto, almacen: destino).capacidadTotal)
            if capacidad > 0, stockDestino + draft.quantity > capacidad {
                return "La cantidad supera la capacidad disponible del almacén destino."
            }
        }
        return nil
    }

    private func guardarMovimiento(using draft: BorradorModalMovimiento) throws {
        let producto = productos[draft.productIndex]
        let origen = almacenes[draft.originWarehouseIndex]
        let noteText = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        switch draft.kind {
        case .ingreso:
            let supplierName = draft.supplierIndex.flatMap { proveedores.indices.contains($0) ? proveedores[$0].nombre : nil } ?? "Proveedor"
            adjustStock(producto: producto, almacen: origen, delta: draft.quantity)
            createMovement(
                type: draft.kind.rawValue,
                amount: draft.quantity,
                producto: producto,
                almacen: origen,
                origen: supplierName,
                destino: origen.nombre,
                note: noteText.isEmpty ? "Compra de proveedor" : noteText
            )
            saveRemoteStock(producto: producto, almacen: origen, delta: draft.quantity)
            saveRemoteMovement(
                type: draft.kind.rawValue,
                amount: draft.quantity,
                producto: producto,
                almacen: origen,
                origen: supplierName,
                destino: origen.nombre,
                note: noteText.isEmpty ? "Compra de proveedor" : noteText
            )

        case .salida:
            adjustStock(producto: producto, almacen: origen, delta: -draft.quantity)
            createMovement(
                type: draft.kind.rawValue,
                amount: -draft.quantity,
                producto: producto,
                almacen: origen,
                origen: origen.nombre,
                destino: "Operación",
                note: noteText.isEmpty ? "Salida de almacén" : noteText
            )
            saveRemoteStock(producto: producto, almacen: origen, delta: -draft.quantity)
            saveRemoteMovement(
                type: draft.kind.rawValue,
                amount: -draft.quantity,
                producto: producto,
                almacen: origen,
                origen: origen.nombre,
                destino: "Operación",
                note: noteText.isEmpty ? "Salida de almacén" : noteText
            )

        case .transfer:
            let destino = almacenes[draft.destinationWarehouseIndex]
            adjustStock(producto: producto, almacen: origen, delta: -draft.quantity)
            adjustStock(producto: producto, almacen: destino, delta: draft.quantity)
            createMovement(
                type: draft.kind.rawValue,
                amount: draft.quantity,
                producto: producto,
                almacen: origen,
                origen: origen.nombre,
                destino: destino.nombre,
                note: noteText.isEmpty ? "Transferencia entre almacenes" : noteText
            )
            saveRemoteStock(producto: producto, almacen: origen, delta: -draft.quantity)
            saveRemoteStock(producto: producto, almacen: destino, delta: draft.quantity)
            saveRemoteMovement(
                type: draft.kind.rawValue,
                amount: draft.quantity,
                producto: producto,
                almacen: origen,
                origen: origen.nombre,
                destino: destino.nombre,
                note: noteText.isEmpty ? "Transferencia entre almacenes" : noteText
            )
        }

        producto.stockLitros = totalStock(for: producto)
        try contexto.save()
    }

    private func adjustStock(producto: ProductoEntity, almacen: AlmacenEntity, delta: Double) {
        let stock = stockRecord(producto: producto, almacen: almacen)
        stock.stockActual = max(stock.stockActual + delta, 0)
        if stock.capacidadTotal <= 0 { stock.capacidadTotal = producto.capacidadTotal }
        if stock.stockMinimo <= 0 { stock.stockMinimo = producto.stockMinimo }
        stock.unidadMedida = producto.unidadMedida ?? "L"
    }

    private func stockRecord(producto: ProductoEntity, almacen: AlmacenEntity) -> StockAlmacenEntity {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)

        if let existing = try? contexto.fetch(request).first {
            return existing
        }

        let stock = StockAlmacenEntity(context: contexto)
        stock.id = UUID()
        stock.producto = producto
        stock.almacen = almacen
        stock.stockActual = 0
        stock.stockMinimo = producto.stockMinimo
        stock.capacidadTotal = producto.capacidadTotal
        stock.unidadMedida = producto.unidadMedida ?? "L"
        return stock
    }

    private func totalStock(for producto: ProductoEntity) -> Double {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@", producto)
        return ((try? contexto.fetch(request)) ?? []).reduce(0) { $0 + $1.stockActual }
    }

    private func createMovement(
        type: String,
        amount: Double,
        producto: ProductoEntity,
        almacen: AlmacenEntity,
        origen: String?,
        destino: String?,
        note: String
    ) {
        let movimiento = MovimientoInventarioEntity(context: contexto)
        movimiento.id = UUID()
        movimiento.fecha = Date()
        movimiento.tipo = type
        movimiento.cantidadLitros = amount
        movimiento.producto = producto
        movimiento.almacen = almacen
        movimiento.origen = origen
        movimiento.destino = destino
        movimiento.nota = note
    }

    private func mostrarAlerta(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnGuardarTapped(_ sender: UIButton) {
        actualizarVistaHibrida()
    }

    private func saveRemoteStock(producto: ProductoEntity, almacen: AlmacenEntity, delta: Double) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard let almacenId = almacen.id?.uuidString, let productoId = producto.id?.uuidString else { return }

        firestore.collection("warehouse_stock")
            .whereField("almacenId", isEqualTo: almacenId)
            .whereField("productoId", isEqualTo: productoId)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                let stockRef: DocumentReference
                var currentStock = 0.0
                let payloadId: String

                if let existing = snapshot?.documents.first {
                    stockRef = existing.reference
                    payloadId = existing.documentID
                    currentStock = (existing.data()["stockActual"] as? NSNumber)?.doubleValue ?? 0
                } else {
                    payloadId = UUID().uuidString
                    stockRef = self.firestore.collection("warehouse_stock").document(payloadId)
                }

                stockRef.setData([
                    "id": payloadId,
                    "almacenId": almacenId,
                    "productoId": productoId,
                    "stockActual": max(currentStock + delta, 0),
                    "stockMinimo": producto.stockMinimo,
                    "capacidadTotal": producto.capacidadTotal,
                    "unidadMedida": producto.unidadMedida ?? "L"
                ], merge: true)
            }
        #endif
    }

    private func saveRemoteMovement(
        type: String,
        amount: Double,
        producto: ProductoEntity,
        almacen: AlmacenEntity,
        origen: String?,
        destino: String?,
        note: String
    ) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        let movementId = UUID()
        firestore.collection("inventory_movements")
            .document(movementId.uuidString)
            .setData([
                "id": movementId.uuidString,
                "tipo": type,
                "cantidadLitros": amount,
                "productoId": producto.id?.uuidString ?? "",
                "almacenId": almacen.id?.uuidString ?? "",
                "origen": origen ?? "",
                "destino": destino ?? "",
                "nota": note,
                "fecha": Timestamp(date: Date())
            ], merge: true)
        #endif
    }
}

private enum TipoMovimientoModal: String, CaseIterable {
    case ingreso = "entrada"
    case salida = "salida"
    case transfer = "transfer"

    var title: String {
        switch self {
        case .ingreso: return "Ingreso"
        case .salida: return "Salida"
        case .transfer: return "Transferencia"
        }
    }

    var actionTitle: String {
        switch self {
        case .ingreso: return "Registrar Ingreso"
        case .salida: return "Registrar Salida"
        case .transfer: return "Registrar Transferencia"
        }
    }

    var accentColor: UIColor {
        switch self {
        case .ingreso: return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
        case .salida: return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        case .transfer: return UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1)
        }
    }

    var iconName: String {
        switch self {
        case .ingreso: return "arrow.down"
        case .salida: return "arrow.up"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    var routeTitle: String {
        switch self {
        case .ingreso: return "PROVEEDOR -> ALMACÉN"
        case .salida: return "ALMACÉN -> OPERACIÓN"
        case .transfer: return "ALMACÉN ORIGEN -> DESTINO"
        }
    }
}

private struct DatosVistaModalMovimiento {
    let warehouses: [FilaAlmacenModalMovimiento]
    let products: [FilaProductoModalMovimiento]
    let suppliers: [FilaProveedorModalMovimiento]
}

private struct FilaAlmacenModalMovimiento: Identifiable {
    let id: String
    let name: String
    let managerName: String
}

private struct FilaProductoModalMovimiento: Identifiable {
    let id: String
    let name: String
    let unit: String
    let price: Double
    let totalStock: Double
    let stocksByWarehouse: [String: Double]
}

private struct FilaProveedorModalMovimiento: Identifiable {
    let id: String
    let name: String
}

private struct BorradorModalMovimiento {
    let kind: TipoMovimientoModal
    let supplierIndex: Int?
    let originWarehouseIndex: Int
    let destinationWarehouseIndex: Int
    let productIndex: Int
    let quantity: Double
    let note: String
}

private struct VistaRaizModalMovimiento: View {
    let data: DatosVistaModalMovimiento
    let onCancel: () -> Void
    let onSave: (BorradorModalMovimiento) -> Void

    @State private var kind: TipoMovimientoModal
    @State private var supplierIndex: Int?
    @State private var originWarehouseIndex: Int
    @State private var destinationWarehouseIndex: Int
    @State private var productIndex: Int
    @State private var quantityText: String
    @State private var note: String
    @State private var activePicker: PickerTarget?

    init(
        data: DatosVistaModalMovimiento,
        onCancel: @escaping () -> Void,
        onSave: @escaping (BorradorModalMovimiento) -> Void
    ) {
        self.data = data
        self.onCancel = onCancel
        self.onSave = onSave
        _kind = State(initialValue: .ingreso)
        _supplierIndex = State(initialValue: data.suppliers.isEmpty ? nil : 0)
        _originWarehouseIndex = State(initialValue: 0)
        _destinationWarehouseIndex = State(initialValue: min(1, max(data.warehouses.count - 1, 0)))
        _productIndex = State(initialValue: 0)
        _quantityText = State(initialValue: "0")
        _note = State(initialValue: "")
        _activePicker = State(initialValue: nil)
    }

    private enum PickerTarget {
        case supplier
        case origin
        case destination
        case product
    }

    private var selectedProduct: FilaProductoModalMovimiento? {
        data.products.indices.contains(productIndex) ? data.products[productIndex] : nil
    }

    private var selectedOrigin: FilaAlmacenModalMovimiento? {
        data.warehouses.indices.contains(originWarehouseIndex) ? data.warehouses[originWarehouseIndex] : nil
    }

    private var selectedDestination: FilaAlmacenModalMovimiento? {
        data.warehouses.indices.contains(destinationWarehouseIndex) ? data.warehouses[destinationWarehouseIndex] : nil
    }

    private var selectedSupplier: FilaProveedorModalMovimiento? {
        guard let supplierIndex, data.suppliers.indices.contains(supplierIndex) else { return nil }
        return data.suppliers[supplierIndex]
    }

    private var quantityValue: Double {
        Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var currentWarehouseStock: Double {
        guard let selectedProduct, let selectedOrigin else { return 0 }
        return selectedProduct.stocksByWarehouse[selectedOrigin.id] ?? 0
    }

    private var projectedSourceStock: Double {
        switch kind {
        case .ingreso:
            return currentWarehouseStock + quantityValue
        case .salida, .transfer:
            return max(currentWarehouseStock - quantityValue, 0)
        }
    }

    private var actionTitle: String {
        kind.actionTitle
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 42, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                header
                Divider()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        kindSelector
                        routeSection
                        productSection
                        stockCard
                        inputRow
                        noteSection
                        saveButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .confirmationDialog("Seleccionar", isPresented: Binding(
            get: { activePicker != nil },
            set: { if !$0 { activePicker = nil } }
        )) {
            switch activePicker {
            case .supplier:
                ForEach(Array(data.suppliers.enumerated()), id: \.offset) { index, supplier in
                    Button(supplier.name) { supplierIndex = index }
                }
            case .origin:
                ForEach(Array(data.warehouses.enumerated()), id: \.offset) { index, warehouse in
                    Button(warehouse.name) { originWarehouseIndex = index }
                }
            case .destination:
                ForEach(Array(data.warehouses.enumerated()), id: \.offset) { index, warehouse in
                    Button(warehouse.name) { destinationWarehouseIndex = index }
                }
            case .product:
                ForEach(Array(data.products.enumerated()), id: \.offset) { index, product in
                    Button(product.name) { productIndex = index }
                }
            case .none:
                EmptyView()
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancelar", action: onCancel)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(Color.blue)

            Spacer()

            Text("Registrar Movimiento")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.label))

            Spacer()

            Color.clear.frame(width: 52, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var kindSelector: some View {
        HStack(spacing: 10) {
            ForEach(TipoMovimientoModal.allCases, id: \.rawValue) { option in
                Button {
                    kind = option
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.iconName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(option == kind ? Color(uiColor: option.accentColor) : Color(.systemGray6))
                    )
                    .foregroundStyle(option == kind ? .white : Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.routeTitle)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.secondaryLabel))

            switch kind {
            case .ingreso:
                HStack(spacing: 10) {
                    selectionCard(
                        title: "DEL PROVEEDOR",
                        value: selectedSupplier?.name ?? "Seleccionar proveedor...",
                        accent: kind.accentColor,
                        dashed: true
                    ) {
                        activePicker = .supplier
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(uiColor: kind.accentColor))

                    selectionCard(
                        title: "AL ALMACÉN",
                        value: selectedOrigin?.name ?? "Seleccionar almacén...",
                        accent: UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
                    ) {
                        activePicker = .origin
                    }
                }

            case .salida:
                HStack(spacing: 10) {
                    selectionCard(
                        title: "DESDE",
                        value: selectedOrigin?.name ?? "Seleccionar almacén...",
                        accent: UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
                    ) {
                        activePicker = .origin
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(uiColor: kind.accentColor))

                    fixedCard(title: "HACIA", value: "Operación")
                }

            case .transfer:
                HStack(spacing: 10) {
                    selectionCard(
                        title: "DESDE",
                        value: selectedOrigin?.name ?? "Seleccionar origen...",
                        accent: UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
                    ) {
                        activePicker = .origin
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(uiColor: kind.accentColor))

                    selectionCard(
                        title: "ALMACÉN DESTINO",
                        value: selectedDestination?.name ?? "Seleccionar destino...",
                        accent: kind.accentColor
                    ) {
                        activePicker = .destination
                    }
                }
            }
        }
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Producto")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.secondaryLabel))

            Button {
                activePicker = .product
            } label: {
                HStack {
                    Text(productTitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var stockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stockTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("\(intString(currentWarehouseStock)) -> \(intString(projectedSourceStock)) \(selectedProduct?.unit ?? "L")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(uiColor: kind.accentColor))
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let fill = min(projectedRatio, 1) * width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            Color(
                                uiColor: kind == .salida
                                    ? UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
                                    : UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
                            )
                        )
                        .frame(width: fill)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cantidad (\(selectedProduct?.unit ?? "L"))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.secondaryLabel))

                TextField("0", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trabajador")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.secondaryLabel))

                HStack {
                    Text(workerName)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(.label))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nota (opcional)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.secondaryLabel))

            TextField(notePlaceholder, text: $note)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
        }
    }

    private var saveButton: some View {
        Button {
            onSave(
                BorradorModalMovimiento(
                    kind: kind,
                    supplierIndex: supplierIndex,
                    originWarehouseIndex: originWarehouseIndex,
                    destinationWarehouseIndex: destinationWarehouseIndex,
                    productIndex: productIndex,
                    quantity: quantityValue,
                    note: note
                )
            )
        } label: {
            Text(actionTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: kind.accentColor))
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func selectionCard(
        title: String,
        value: String,
        accent: UIColor,
        dashed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.secondaryLabel))
                HStack {
                    Text(value)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: dashed ? 1.5 : 1, dash: dashed ? [5] : [])
                            )
                            .foregroundStyle(Color(uiColor: accent).opacity(0.35))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func fixedCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.secondaryLabel))
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.label))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private var productTitle: String {
        guard let selectedProduct else { return "Seleccionar producto" }
        return "\(selectedProduct.name) — \(intString(selectedProduct.totalStock)) \(selectedProduct.unit) disp."
    }

    private var stockTitle: String {
        switch kind {
        case .ingreso:
            return "\(selectedOrigin?.name ?? "Almacén") — Tras recibir"
        case .salida:
            return "\(selectedOrigin?.name ?? "Almacén") — Tras salida"
        case .transfer:
            return "\(selectedOrigin?.name ?? "Origen") — Tras transferir"
        }
    }

    private var workerName: String {
        switch kind {
        case .transfer:
            return selectedDestination?.managerName ?? selectedOrigin?.managerName ?? "Sin responsable"
        case .ingreso, .salida:
            return selectedOrigin?.managerName ?? "Sin responsable"
        }
    }

    private var notePlaceholder: String {
        switch kind {
        case .ingreso: return "Compra de proveedor..."
        case .salida: return "Salida de almacén..."
        case .transfer: return "Transferencia entre almacenes..."
        }
    }

    private var projectedRatio: CGFloat {
        guard let selectedProduct else { return 0 }
        let capacity = max(selectedProduct.totalStock > 0 ? selectedProduct.totalStock : 1, 1)
        return CGFloat(projectedSourceStock / capacity)
    }

    private func intString(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
