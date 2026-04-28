import UIKit
import CoreData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalNuevaVentaViewControllerDelegate: AnyObject {
    func modalNuevaVentaViewControllerDidSaveVenta(_ controller: ModalNuevaVentaViewController)
}

final class ModalNuevaVentaViewController: UIViewController {

    private struct InventorySyncSnapshot {
        let almacen: AlmacenEntity?
        let stock: StockAlmacenEntity?
        let movimiento: MovimientoInventarioEntity
    }

    weak var delegate: ModalNuevaVentaViewControllerDelegate?
    var clientesDisponibles: [ClienteEntity] = []
    var productosDisponibles: [ProductoEntity] = []

    private var cuotas = 3
    private var metodoPago: MetodoPagoVenta = .efectivo
    private var cantidadSeleccionada: Double = 0
    private var selectedClienteIndex: Int?
    private var selectedProductoIndex: Int?
    private var firstDueDateOverride: Date?
    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let context = AppCoreData.viewContext

    private var selectedCliente: ClienteEntity? {
        guard let selectedClienteIndex, clientesDisponibles.indices.contains(selectedClienteIndex) else {
            return nil
        }
        return clientesDisponibles[selectedClienteIndex]
    }

    private var selectedProducto: ProductoEntity? {
        guard let selectedProductoIndex, productosDisponibles.indices.contains(selectedProductoIndex) else {
            return nil
        }
        return productosDisponibles[selectedProductoIndex]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarFormularioEmbebido()
    }

    private func configurarFormularioEmbebido() {
        let clientOptions = clientesDisponibles.enumerated().map { index, client in
            OpcionCliente(
                id: client.id?.uuidString ?? "\(index)",
                name: client.nombre ?? "Cliente",
                status: estadoParaCliente(client),
                debt: client.creditoUsado,
                limit: max(client.limiteCredito, 1)
            )
        }
        let productOptions = productosDisponibles.enumerated().map { index, product in
            let inventoryInfo = inventoryInfo(for: product)
            return OpcionProductoVenta(
                id: product.id?.uuidString ?? "\(index)",
                name: product.nombre ?? "Producto",
                pricePerUnit: product.precioPorLitro,
                unit: product.unidadMedida ?? "liter",
                availableStock: inventoryInfo.availableStock,
                warehouseName: inventoryInfo.warehouseName
            )
        }

        guard clientOptions.isEmpty == false, productOptions.isEmpty == false else { return }

        let suggestedClientIndex = 0
        let suggestedProductIndex = 0
        selectedClienteIndex = suggestedClientIndex
        selectedProductoIndex = suggestedProductIndex
        metodoPago = .credito
        cuotas = 3
        firstDueDateOverride = siguienteFechaMensual()

        let child = NuevaVentaViewController(
            clients: clientOptions,
            products: productOptions,
            initialClientIndex: suggestedClientIndex,
            initialProductIndex: suggestedProductIndex,
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSave: { [weak self] draft in self?.manejarBorradorEmbebido(draft) }
        )

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
    }

    private func manejarBorradorEmbebido(_ draft: BorradorNuevaVenta) {
        selectedClienteIndex = draft.clientIndex
        selectedProductoIndex = draft.productIndex
        cantidadSeleccionada = Double(draft.quantity)
        metodoPago = draft.paymentType == "cash" ? .efectivo : .credito
        cuotas = min(max(draft.installments, 1), 12)
        firstDueDateOverride = draft.firstDueDate

        if let validationMessage = validateInputs() {
            showAlert(title: "Validación", message: validationMessage)
            return
        }

        do {
            try saveVenta()
            delegate?.modalNuevaVentaViewControllerDidSaveVenta(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar la venta.")
        }
    }

    private func estadoParaCliente(_ client: ClienteEntity) -> String {
        guard client.limiteCredito > 0 else { return client.creditoUsado > 0 ? "vencido" : "activo" }
        let usage = client.creditoUsado / client.limiteCredito
        if usage >= 0.75 { return "vencido" }
        if usage >= 0.3 { return "enRiesgo" }
        return "activo"
    }

    private func inventoryInfo(for product: ProductoEntity) -> (availableStock: Double, warehouseName: String) {
        let stockRequest: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        stockRequest.predicate = NSPredicate(format: "producto == %@", product)
        stockRequest.sortDescriptors = [NSSortDescriptor(key: "stockActual", ascending: false)]

        let stockRows = (try? context.fetch(stockRequest)) ?? []
        if let primaryStock = stockRows.first {
            let warehouseName = primaryStock.almacen?.nombre ?? "Almacén"
            let totalAvailable = stockRows.reduce(0) { $0 + max($1.stockActual, 0) }
            return (availableStock: max(totalAvailable, product.stockLitros), warehouseName: warehouseName)
        }

        return (
            availableStock: max(product.stockLitros, 0),
            warehouseName: "Sin almacén"
        )
    }

    private func validateInputs() -> String? {
        if selectedCliente == nil {
            return "Selecciona un cliente."
        }
        if selectedProducto == nil {
            return "Selecciona un producto."
        }
        if cantidadSeleccionada <= 0 {
            return "Ingresa una cantidad válida en litros."
        }
        if let producto = selectedProducto, producto.stockLitros < cantidadSeleccionada {
            return "No hay suficiente stock disponible para esta venta."
        }
        if metodoPago == .credito, let cliente = selectedCliente {
            let total = cantidadSeleccionada * (selectedProducto?.precioPorLitro ?? 0)
            if cliente.creditoUsado + total > cliente.limiteCredito {
                return "El cliente supera su límite de crédito."
            }
        }
        if defaultWarehouse() == nil {
            return "Registra al menos un almacén antes de vender."
        }
        return nil
    }

    private func saveVenta() throws {
        guard let cliente = selectedCliente, let producto = selectedProducto else { return }
        ensurePersistentIdentifiers(cliente: cliente, producto: producto)

        let cantidad = cantidadSeleccionada
        let total = cantidad * producto.precioPorLitro

        let venta = VentaEntity(context: context)
        venta.id = UUID()
        venta.cliente = cliente
        venta.producto = producto
        venta.cantidadLitros = cantidad
        venta.precioUnitario = producto.precioPorLitro
        venta.total = total
        venta.fechaVenta = Date()
        venta.metodoPago = metodoPago.rawValue
        venta.estado = metodoPago == .efectivo ? "pagada" : "pendiente"

        let inventorySnapshot = registerInventorySalida(for: producto, cantidad: cantidad, cliente: cliente)
        var cuotasGeneradas: [CuotaEntity] = []

        if metodoPago == .credito {
            cliente.creditoUsado += total
            cuotasGeneradas = createCuotas(for: venta, total: total)
        }

        try context.save()
        syncVentaToRemote(
            venta: venta,
            cliente: cliente,
            producto: producto,
            cuotas: cuotasGeneradas,
            inventorySnapshot: inventorySnapshot
        )
    }

    private func createCuotas(for venta: VentaEntity, total: Double) -> [CuotaEntity] {
        let montoPorCuota = total / Double(cuotas)
        var cuotasGeneradas: [CuotaEntity] = []
        let fechaBase = firstDueDateOverride ?? siguienteFechaMensual(desde: venta.fechaVenta ?? Date())
        for numero in 1...cuotas {
            let cuota = CuotaEntity(context: context)
            cuota.id = UUID()
            cuota.numero = Int32(numero)
            cuota.monto = montoPorCuota
            cuota.pagada = false
            cuota.venta = venta
            cuota.fechaVencimiento = Calendar.current.date(byAdding: .month, value: numero - 1, to: fechaBase)
            cuotasGeneradas.append(cuota)
        }
        return cuotasGeneradas
    }

    private func siguienteFechaMensual(desde fecha: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: fecha) ?? fecha
    }

    private func registerInventorySalida(for producto: ProductoEntity, cantidad: Double, cliente: ClienteEntity) -> InventorySyncSnapshot {
        let almacen = defaultWarehouse()
        var stock: StockAlmacenEntity?
        if let almacen {
            if almacen.id == nil {
                almacen.id = UUID()
            }
            let currentStock = stockRecord(producto: producto, almacen: almacen)
            let stockDisponible = stockActualConsolidado(producto: producto, almacen: almacen)
            stock = currentStock
            currentStock.stockActual = max(stockDisponible - cantidad, 0)
            currentStock.stockMinimo = producto.stockMinimo
            if currentStock.capacidadTotal <= 0 {
                currentStock.capacidadTotal = producto.capacidadTotal
            }
            currentStock.unidadMedida = producto.unidadMedida ?? "L"
            consolidarStocksDuplicados(producto: producto, almacen: almacen, principal: currentStock)
        }

        producto.stockLitros = totalStock(for: producto)

        let movimiento = MovimientoInventarioEntity(context: context)
        movimiento.id = UUID()
        movimiento.fecha = Date()
        movimiento.tipo = "salida"
        movimiento.cantidadLitros = -cantidad
        movimiento.producto = producto
        movimiento.almacen = almacen
        movimiento.origen = movimiento.almacen?.nombre ?? "Almacén"
        movimiento.destino = cliente.nombre ?? "Cliente"
        movimiento.nota = "Venta a \(cliente.nombre ?? "cliente")"
        return InventorySyncSnapshot(almacen: almacen, stock: stock, movimiento: movimiento)
    }

    private func stockRecord(producto: ProductoEntity, almacen: AlmacenEntity) -> StockAlmacenEntity {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)
        request.sortDescriptors = [NSSortDescriptor(key: "stockActual", ascending: false)]

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let stock = StockAlmacenEntity(context: context)
        stock.id = UUID()
        stock.producto = producto
        stock.almacen = almacen
        stock.stockActual = producto.stockLitros
        stock.stockMinimo = producto.stockMinimo
        stock.capacidadTotal = producto.capacidadTotal
        stock.unidadMedida = producto.unidadMedida ?? "L"
        return stock
    }

    private func stockActualConsolidado(producto: ProductoEntity, almacen: AlmacenEntity) -> Double {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)
        return ((try? context.fetch(request)) ?? []).reduce(0) { $0 + $1.stockActual }
    }

    private func consolidarStocksDuplicados(producto: ProductoEntity, almacen: AlmacenEntity, principal: StockAlmacenEntity) {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)
        let stocks = (try? context.fetch(request)) ?? []
        stocks
            .filter { $0.objectID != principal.objectID }
            .forEach { context.delete($0) }
    }

    private func totalStock(for producto: ProductoEntity) -> Double {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@", producto)
        return ((try? context.fetch(request)) ?? []).reduce(0) { $0 + $1.stockActual }
    }

    private func defaultWarehouse() -> AlmacenEntity? {
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return try? context.fetch(request).first
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func ensurePersistentIdentifiers(cliente: ClienteEntity, producto: ProductoEntity) {
        if cliente.id == nil {
            cliente.id = UUID()
        }
        if producto.id == nil {
            producto.id = UUID()
        }
    }

    private func syncVentaToRemote(
        venta: VentaEntity,
        cliente: ClienteEntity,
        producto: ProductoEntity,
        cuotas: [CuotaEntity],
        inventorySnapshot: InventorySyncSnapshot
    ) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard
            let ventaId = venta.id?.uuidString,
            let clienteId = cliente.id?.uuidString,
            let productoId = producto.id?.uuidString
        else {
            return
        }

        let fechaVenta = venta.fechaVenta ?? Date()
        var salePayload: [String: Any] = [
            "id": ventaId,
            "clienteId": clienteId,
            "productoId": productoId,
            "cantidadLitros": venta.cantidadLitros,
            "precioUnitario": venta.precioUnitario,
            "total": venta.total,
            "metodoPago": venta.metodoPago ?? metodoPago.rawValue,
            "estado": venta.estado ?? "pendiente",
            "fechaVenta": Timestamp(date: fechaVenta)
        ]

        if let userId = AppSession.shared.userDocumentId {
            salePayload["createdByUserId"] = userId
        }
        if let authUid = AppSession.shared.authUid {
            salePayload["createdByAuthUid"] = authUid
        }
        if let email = AppSession.shared.userEmail {
            salePayload["createdByEmail"] = email
        }

        if let almacenId = inventorySnapshot.almacen?.id?.uuidString {
            salePayload["almacenId"] = almacenId
        }

        let batch = firestore.batch()
        let saleRef = firestore.collection("sales").document(ventaId)
        batch.setData(salePayload, forDocument: saleRef, merge: true)

        let customerRef = firestore.collection("customers").document(clienteId)
        batch.setData([
            "id": clienteId,
            "creditoUsado": cliente.creditoUsado
        ], forDocument: customerRef, merge: true)

        let productRef = firestore.collection("products").document(productoId)
        batch.setData([
            "id": productoId,
            "stockLitros": producto.stockLitros,
            "precioPorLitro": producto.precioPorLitro
        ], forDocument: productRef, merge: true)

        if let almacen = inventorySnapshot.almacen,
           let almacenId = almacen.id?.uuidString {
            let warehouseRef = firestore.collection("warehouses").document(almacenId)
            batch.setData([
                "id": almacenId,
                "nombre": almacen.nombre ?? "Almacén",
                "direccion": almacen.direccion ?? "",
                "responsable": almacen.responsable ?? "",
                "activo": almacen.activo
            ], forDocument: warehouseRef, merge: true)
        }

        if let stock = inventorySnapshot.stock,
           let stockId = stock.id?.uuidString,
           let almacenId = stock.almacen?.id?.uuidString,
           let productoStockId = stock.producto?.id?.uuidString {
            let stockRef = firestore.collection("warehouse_stock").document(stockId)
            batch.setData([
                "id": stockId,
                "almacenId": almacenId,
                "productoId": productoStockId,
                "stockActual": stock.stockActual,
                "stockMinimo": stock.stockMinimo,
                "capacidadTotal": stock.capacidadTotal,
                "unidadMedida": stock.unidadMedida ?? "L"
            ], forDocument: stockRef, merge: true)
        }

        if let movimientoId = inventorySnapshot.movimiento.id?.uuidString,
           let almacenId = inventorySnapshot.movimiento.almacen?.id?.uuidString,
           let movimientoProductoId = inventorySnapshot.movimiento.producto?.id?.uuidString {
            let movementRef = firestore.collection("inventory_movements").document(movimientoId)
            batch.setData([
                "id": movimientoId,
                "tipo": inventorySnapshot.movimiento.tipo ?? "salida",
                "cantidadLitros": inventorySnapshot.movimiento.cantidadLitros,
                "productoId": movimientoProductoId,
                "almacenId": almacenId,
                "origen": inventorySnapshot.movimiento.origen ?? "",
                "destino": inventorySnapshot.movimiento.destino ?? "",
                "nota": inventorySnapshot.movimiento.nota ?? "",
                "fecha": Timestamp(date: inventorySnapshot.movimiento.fecha ?? fechaVenta)
            ], forDocument: movementRef, merge: true)
        }

        for cuota in cuotas {
            guard let cuotaId = cuota.id?.uuidString else { continue }
            let installmentRef = firestore.collection("sale_installments").document(cuotaId)
            batch.setData([
                "id": cuotaId,
                "ventaId": ventaId,
                "saleId": ventaId,
                "numero": cuota.numero,
                "monto": cuota.monto,
                "pagada": cuota.pagada,
                "fechaVencimiento": Timestamp(date: cuota.fechaVencimiento ?? fechaVenta)
            ], forDocument: installmentRef, merge: true)
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.showAlert(title: "Firebase", message: "La venta se guardó localmente, pero no se pudo sincronizar: \(error.localizedDescription)")
                    return
                }
                TreasuryRemoteSync.syncSaleIfNeeded(
                    venta: venta,
                    cliente: cliente,
                    productName: producto.nombre ?? "Producto",
                    paymentMethod: venta.metodoPago ?? self?.metodoPago.rawValue ?? "efectivo"
                )
                AppSession.shared.lastRemoteSyncAt = Date()
            }
        }
        #endif
    }

}

enum MetodoPagoVenta: String {
    case efectivo
    case credito
}
