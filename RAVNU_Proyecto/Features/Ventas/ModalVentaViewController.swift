import UIKit
import CoreData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalVentaViewControllerDelegate: AnyObject {
    func modalVentaViewControllerDidSaveVenta(_ controller: ModalVentaViewController)
}

final class ModalVentaViewController: UIViewController {

    private struct InventorySyncSnapshot {
        let almacen: AlmacenEntity?
        let stock: StockAlmacenEntity?
        let movimiento: MovimientoInventarioEntity
    }

    @IBOutlet private weak var txtCliente: UITextField!
    @IBOutlet private weak var txtProducto: UITextField!
    @IBOutlet private weak var txtCantidad: UITextField!
    @IBOutlet private weak var lblTotal: UILabel!
    @IBOutlet private weak var btnEfectivo: UIButton!
    @IBOutlet private weak var btnCredito: UIButton!
    @IBOutlet private weak var creditContainerView: UIView!
    @IBOutlet private weak var lblCuotas: UILabel!
    @IBOutlet private weak var lblPorCuota: UILabel!
    @IBOutlet private weak var lblFechaVencimiento: UILabel!
    @IBOutlet private weak var btnGuardarVenta: UIButton!

    weak var delegate: ModalVentaViewControllerDelegate?
    var clientesDisponibles: [ClienteEntity] = []
    var productosDisponibles: [ProductoEntity] = []

    private let clientePicker = UIPickerView()
    private let productoPicker = UIPickerView()
    private var cuotas = 3 {
        didSet {
            cuotas = min(max(cuotas, 1), 12)
            updateCreditSummary()
        }
    }
    private var metodoPago: MetodoPagoVenta = .efectivo {
        didSet {
            updatePaymentSelection()
        }
    }
    private var selectedClienteIndex: Int?
    private var selectedProductoIndex: Int?
    private var firstDueDateOverride: Date?
    private var embeddedController: NewSaleViewController?
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
        configureUI()
        configureEmbeddedForm()
    }

    private func configureUI() {
        view.backgroundColor = UIColor.systemBackground
        txtCliente.delegate = self
        txtProducto.delegate = self
        txtCantidad.delegate = self

        txtCliente.tintColor = .clear
        txtProducto.tintColor = .clear
        txtCantidad.keyboardType = .decimalPad
        txtCantidad.addTarget(self, action: #selector(quantityDidChange), for: .editingChanged)

        clientePicker.dataSource = self
        clientePicker.delegate = self
        productoPicker.dataSource = self
        productoPicker.delegate = self

        txtCliente.inputView = clientePicker
        txtProducto.inputView = productoPicker
        txtCliente.inputAccessoryView = pickerToolbar(selector: #selector(donePickingCliente))
        txtProducto.inputAccessoryView = pickerToolbar(selector: #selector(donePickingProducto))

        txtCliente.placeholder = "Seleccionar cliente"
        txtProducto.placeholder = "Seleccionar producto y precio"
        txtCantidad.placeholder = "Cantidad en litros (Ej: 50.5)"

        btnGuardarVenta.layer.cornerRadius = 16
        btnGuardarVenta.clipsToBounds = true
        creditContainerView.layer.cornerRadius = 18
        creditContainerView.clipsToBounds = true
    }

    private func configureEmbeddedForm() {
        hideLegacyForm()

        let clientOptions = clientesDisponibles.enumerated().map { index, client in
            OpcionCliente(
                id: client.id?.uuidString ?? "\(index)",
                name: client.nombre ?? "Cliente",
                status: statusForClient(client),
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

        let child = NewSaleViewController(
            clients: clientOptions,
            products: productOptions,
            initialClientIndex: suggestedClientIndex,
            initialProductIndex: suggestedProductIndex,
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSave: { [weak self] draft in self?.handleEmbeddedDraft(draft) }
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
        embeddedController = child
    }

    private func hideLegacyForm() {
        [txtCliente, txtProducto, txtCantidad, lblTotal, btnEfectivo, btnCredito, creditContainerView, lblCuotas, lblPorCuota, lblFechaVencimiento, btnGuardarVenta].forEach {
            $0?.isHidden = true
        }
    }

    private func handleEmbeddedDraft(_ draft: BorradorNuevaVenta) {
        selectedClienteIndex = draft.clientIndex
        selectedProductoIndex = draft.productIndex
        txtCantidad.text = "\(draft.quantity)"
        metodoPago = draft.paymentType == "cash" ? .efectivo : .credito
        cuotas = draft.installments
        firstDueDateOverride = draft.firstDueDate

        if let validationMessage = validateInputs() {
            showAlert(title: "Validación", message: validationMessage)
            return
        }

        do {
            try saveVenta()
            delegate?.modalVentaViewControllerDidSaveVenta(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar la venta.")
        }
    }

    private func statusForClient(_ client: ClienteEntity) -> String {
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

    private func updateSelectionFields() {
        txtCliente.text = selectedCliente?.nombre

        if let producto = selectedProducto {
            txtProducto.text = String(format: "%@ - S/ %.2f/L",
                                      producto.nombre ?? "Producto",
                                      producto.precioPorLitro)
        } else {
            txtProducto.text = nil
        }
    }

    @objc
    private func quantityDidChange() {
        updateTotal()
    }

    private func updateTotal() {
        let cantidad = parseCantidad()
        let precio = selectedProducto?.precioPorLitro ?? 0
        let total = cantidad * precio
        lblTotal.text = String(format: "Total: S/ %.2f", total)
        updateCreditSummary()
    }

    private func updateCreditSummary() {
        let total = parseCantidad() * (selectedProducto?.precioPorLitro ?? 0)
        let porCuota = cuotas > 0 ? total / Double(cuotas) : 0
        lblCuotas.text = "\(cuotas)"
        lblPorCuota.text = String(format: "S/ %.2f", porCuota)

        if total > 0 {
            let dueDate = firstDueDateOverride ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_PE")
            formatter.dateFormat = "dd MMM, yyyy"
            lblFechaVencimiento.text = formatter.string(from: dueDate)
        } else {
            lblFechaVencimiento.text = "-"
        }
    }

    private func updatePaymentSelection() {
        let selectedColor = UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
        let unselectedColor = UIColor(white: 0.94, alpha: 1)
        let selectedTitleColor = UIColor.white
        let unselectedTitleColor = UIColor(red: 0.45, green: 0.47, blue: 0.55, alpha: 1)

        stylePaymentButton(btnEfectivo,
                           backgroundColor: metodoPago == .efectivo ? selectedColor : unselectedColor,
                           titleColor: metodoPago == .efectivo ? selectedTitleColor : unselectedTitleColor)
        stylePaymentButton(btnCredito,
                           backgroundColor: metodoPago == .credito ? selectedColor : unselectedColor,
                           titleColor: metodoPago == .credito ? selectedTitleColor : unselectedTitleColor)
        creditContainerView.isHidden = metodoPago != .credito
    }

    private func stylePaymentButton(_ button: UIButton, backgroundColor: UIColor, titleColor: UIColor) {
        button.backgroundColor = backgroundColor
        button.setTitleColor(titleColor, for: .normal)
        button.layer.cornerRadius = 14
        button.clipsToBounds = true
    }

    private func pickerToolbar(selector: Selector) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Listo", style: .plain, target: self, action: selector)
        ]
        return toolbar
    }

    private func parseCantidad() -> Double {
        let rawValue = txtCantidad.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        return Double(rawValue) ?? 0
    }

    @objc
    private func donePickingCliente() {
        guard !clientesDisponibles.isEmpty else { return }
        selectedClienteIndex = clientePicker.selectedRow(inComponent: 0)
        updateSelectionFields()
        txtCliente.resignFirstResponder()
    }

    @objc
    private func donePickingProducto() {
        guard !productosDisponibles.isEmpty else { return }
        selectedProductoIndex = productoPicker.selectedRow(inComponent: 0)
        updateSelectionFields()
        updateTotal()
        txtProducto.resignFirstResponder()
    }

    private func validateInputs() -> String? {
        if selectedCliente == nil {
            return "Selecciona un cliente."
        }
        if selectedProducto == nil {
            return "Selecciona un producto."
        }
        if parseCantidad() <= 0 {
            return "Ingresa una cantidad válida en litros."
        }
        if let producto = selectedProducto, producto.stockLitros < parseCantidad() {
            return "No hay suficiente stock disponible para esta venta."
        }
        if metodoPago == .credito, let cliente = selectedCliente {
            let total = parseCantidad() * (selectedProducto?.precioPorLitro ?? 0)
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

        let cantidad = parseCantidad()
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
            stock = currentStock
            currentStock.stockActual = max(currentStock.stockActual - cantidad, 0)
            currentStock.stockMinimo = producto.stockMinimo
            currentStock.capacidadTotal = producto.capacidadTotal
            currentStock.unidadMedida = producto.unidadMedida ?? "L"
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
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)

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

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnEfectivoTapped(_ sender: UIButton) {
        metodoPago = .efectivo
    }

    @IBAction private func btnCreditoTapped(_ sender: UIButton) {
        metodoPago = .credito
    }

    @IBAction private func btnRestarCuotaTapped(_ sender: UIButton) {
        cuotas -= 1
    }

    @IBAction private func btnSumarCuotaTapped(_ sender: UIButton) {
        cuotas += 1
    }

    @IBAction private func btnGuardarTapped(_ sender: UIButton) {
        if let validationMessage = validateInputs() {
            showAlert(title: "Validación", message: validationMessage)
            return
        }

        do {
            try saveVenta()
            delegate?.modalVentaViewControllerDidSaveVenta(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar la venta.")
        }
    }
}

extension ModalVentaViewController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == txtCliente, clientesDisponibles.isEmpty {
            showAlert(title: "Sin datos", message: "No hay clientes registrados.")
            return false
        }

        if textField == txtProducto, productosDisponibles.isEmpty {
            showAlert(title: "Sin datos", message: "No hay productos registrados.")
            return false
        }

        if textField == txtCliente, let selectedClienteIndex {
            clientePicker.selectRow(selectedClienteIndex, inComponent: 0, animated: false)
        }

        if textField == txtProducto, let selectedProductoIndex {
            productoPicker.selectRow(selectedProductoIndex, inComponent: 0, animated: false)
        }

        return true
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard textField == txtCantidad else {
            return false
        }

        if string.isEmpty {
            return true
        }

        let allowedCharacters = CharacterSet(charactersIn: "0123456789.,")
        guard string.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return false
        }

        let currentText = textField.text ?? ""
        guard let textRange = Range(range, in: currentText) else {
            return false
        }

        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        let separatorCount = updatedText.filter { $0 == "." || $0 == "," }.count
        return separatorCount <= 1
    }
}

extension ModalVentaViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView == clientePicker ? clientesDisponibles.count : productosDisponibles.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == clientePicker {
            return clientesDisponibles[row].nombre
        }

        let producto = productosDisponibles[row]
        return String(format: "%@ - S/ %.2f/L", producto.nombre ?? "Producto", producto.precioPorLitro)
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == clientePicker {
            selectedClienteIndex = row
            updateSelectionFields()
            return
        }

        selectedProductoIndex = row
        updateSelectionFields()
        updateTotal()
    }
}

enum MetodoPagoVenta: String {
    case efectivo
    case credito
}
