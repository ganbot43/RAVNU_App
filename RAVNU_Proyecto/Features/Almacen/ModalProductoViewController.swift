import CoreData
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

    private var puedeGestionarDirecto: Bool {
        RoleAccessControl.canManageDirectly
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        [txtPrecio, txtStockMinimo, txtCapacidad].forEach { $0?.keyboardType = .decimalPad }
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
        cargarProductoExistenteSiAplica()
    }

    private func parseDouble(_ text: String?) -> Double {
        Double((text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func validateInputs() -> String? {
        let trimmedName = (txtNombre?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Ingresa el nombre del producto."
        }
        if parseDouble(txtPrecio?.text) <= 0 {
            return "Ingresa un precio mayor a cero."
        }
        if (txtUnidad?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa la unidad de medida."
        }
        if parseDouble(txtStockMinimo?.text) <= 0 {
            return "Ingresa un stock mínimo mayor a cero."
        }
        if parseDouble(txtCapacidad?.text) <= 0 {
            return "Ingresa una capacidad total mayor a cero."
        }
        if parseDouble(txtStockMinimo?.text) > parseDouble(txtCapacidad?.text) {
            return "El stock mínimo no puede ser mayor que la capacidad total."
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
        txtNombre?.text = productoExistente.nombre
        txtPrecio?.text = productoExistente.precioPorLitro == 0 ? "" : String(format: "%.2f", productoExistente.precioPorLitro)
        txtUnidad?.text = productoExistente.unidadMedida
        txtStockMinimo?.text = productoExistente.stockMinimo == 0 ? "" : String(format: "%.0f", productoExistente.stockMinimo)
        txtCapacidad?.text = productoExistente.capacidadTotal == 0 ? "" : String(format: "%.0f", productoExistente.capacidadTotal)
        tipoControl?.selectedSegmentIndex = (productoExistente.tipo ?? "").uppercased() == "GLP" ? 1 : 0
    }

    private func payload(for productId: UUID) -> [String: Any] {
        var payload: [String: Any] = [
            "id": productId.uuidString,
            "nombre": txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "precioPorLitro": parseDouble(txtPrecio?.text),
            "unidadMedida": (txtUnidad?.text ?? "L").trimmingCharacters(in: .whitespacesAndNewlines),
            "stockMinimo": parseDouble(txtStockMinimo?.text),
            "capacidadTotal": parseDouble(txtCapacidad?.text),
            "stockLitros": productoExistente?.stockLitros ?? 0.0,
            "tipo": tipoControl?.selectedSegmentIndex == 1 ? "GLP" : "Combustible",
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
        producto.nombre = txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.precioPorLitro = parseDouble(txtPrecio?.text)
        producto.unidadMedida = (txtUnidad?.text ?? "L").trimmingCharacters(in: .whitespacesAndNewlines)
        producto.stockMinimo = parseDouble(txtStockMinimo?.text)
        producto.capacidadTotal = parseDouble(txtCapacidad?.text)
        if productoExistente == nil {
            producto.stockLitros = 0
        }
        producto.tipo = tipoControl?.selectedSegmentIndex == 1 ? "GLP" : "Combustible"
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
                        "stockMinimo": parseDouble(txtStockMinimo?.text),
                        "capacidadTotal": parseDouble(txtCapacidad?.text),
                        "unidadMedida": (txtUnidad?.text ?? "L").trimmingCharacters(in: .whitespacesAndNewlines)
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
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud detallada para registrar el producto. Describe la necesidad operativa y el impacto esperado.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Motivo principal"
        }
        alert.addTextField { textField in
            textField.placeholder = "Uso operativo o necesidad"
        }
        alert.addTextField { textField in
            textField.placeholder = "Observación adicional"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let motivo = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let necesidad = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let observacion = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard motivo.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            guard necesidad.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Describe la necesidad operativa del producto.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudProducto(
                        motivo: motivo,
                        necesidad: necesidad,
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
                "nombre": .string(txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
                "precioPorLitro": .number(parseDouble(txtPrecio?.text)),
                "unidadMedida": .string((txtUnidad?.text ?? "L").trimmingCharacters(in: .whitespacesAndNewlines)),
                "stockMinimo": .number(parseDouble(txtStockMinimo?.text)),
                "capacidadTotal": .number(parseDouble(txtCapacidad?.text)),
                "tipo": .string(tipoControl?.selectedSegmentIndex == 1 ? "GLP" : "Combustible"),
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
                    "requiereCreacionStockInicial": .bool(true)
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
}
