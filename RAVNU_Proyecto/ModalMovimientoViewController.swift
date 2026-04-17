import CoreData
import UIKit

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

    private let origenPicker = UIPickerView()
    private let destinoPicker = UIPickerView()
    private let productoPicker = UIPickerView()
    private var almacenes: [AlmacenEntity] = []
    private var productos: [ProductoEntity] = []
    private var selectedOrigenIndex = 0
    private var selectedDestinoIndex = 0
    private var selectedProductoIndex = 0

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadData()
        updateFields()
    }

    private func configureUI() {
        txtCantidad?.keyboardType = .decimalPad
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
        tipoControl?.addTarget(self, action: #selector(typeChanged), for: .valueChanged)

        [origenPicker, destinoPicker, productoPicker].forEach {
            $0.dataSource = self
            $0.delegate = self
        }

        txtOrigen?.delegate = self
        txtDestino?.delegate = self
        txtProducto?.delegate = self
        txtOrigen?.inputView = origenPicker
        txtDestino?.inputView = destinoPicker
        txtProducto?.inputView = productoPicker
        txtOrigen?.inputAccessoryView = pickerToolbar(selector: #selector(donePickingOrigen))
        txtDestino?.inputAccessoryView = pickerToolbar(selector: #selector(donePickingDestino))
        txtProducto?.inputAccessoryView = pickerToolbar(selector: #selector(donePickingProducto))
        [txtOrigen, txtDestino, txtProducto].forEach { $0?.tintColor = .clear }
    }

    private func loadData() {
        let almacenRequest: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        almacenRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        almacenes = (try? context.fetch(almacenRequest)) ?? []

        let productoRequest: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        productoRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        productos = (try? context.fetch(productoRequest)) ?? []
    }

    private func updateFields() {
        txtOrigen?.text = almacenes.indices.contains(selectedOrigenIndex) ? almacenes[selectedOrigenIndex].nombre : nil
        txtDestino?.text = almacenes.indices.contains(selectedDestinoIndex) ? almacenes[selectedDestinoIndex].nombre : nil
        txtProducto?.text = productos.indices.contains(selectedProductoIndex) ? productos[selectedProductoIndex].nombre : nil
        txtDestino?.isEnabled = tipoControl?.selectedSegmentIndex == 2
        txtDestino?.alpha = txtDestino?.isEnabled == true ? 1 : 0.45
    }

    @objc
    private func typeChanged() {
        updateFields()
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

    @objc private func donePickingOrigen() {
        selectedOrigenIndex = origenPicker.selectedRow(inComponent: 0)
        updateFields()
        txtOrigen?.resignFirstResponder()
    }

    @objc private func donePickingDestino() {
        selectedDestinoIndex = destinoPicker.selectedRow(inComponent: 0)
        updateFields()
        txtDestino?.resignFirstResponder()
    }

    @objc private func donePickingProducto() {
        selectedProductoIndex = productoPicker.selectedRow(inComponent: 0)
        updateFields()
        txtProducto?.resignFirstResponder()
    }

    private func parseCantidad() -> Double {
        Double((txtCantidad?.text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func validateInputs() -> String? {
        if almacenes.isEmpty { return "Registra al menos un almacén." }
        if productos.isEmpty { return "Registra al menos un producto." }
        if parseCantidad() <= 0 { return "Ingresa una cantidad válida." }
        if tipoControl?.selectedSegmentIndex == 2 && selectedOrigenIndex == selectedDestinoIndex {
            return "El origen y destino deben ser diferentes."
        }
        return nil
    }

    private func saveMovement() throws {
        let typeIndex = tipoControl?.selectedSegmentIndex ?? 0
        let type = ["entrada", "salida", "transfer"][typeIndex]
        let amount = parseCantidad()
        let producto = productos[selectedProductoIndex]
        let origen = almacenes[selectedOrigenIndex]
        let destino = almacenes[selectedDestinoIndex]

        switch type {
        case "entrada":
            adjustStock(producto: producto, almacen: origen, delta: amount)
            createMovement(type: type, amount: amount, producto: producto, almacen: origen, origen: "Proveedor", destino: origen.nombre)
        case "salida":
            adjustStock(producto: producto, almacen: origen, delta: -amount)
            createMovement(type: type, amount: -amount, producto: producto, almacen: origen, origen: origen.nombre, destino: "Operación")
        default:
            adjustStock(producto: producto, almacen: origen, delta: -amount)
            adjustStock(producto: producto, almacen: destino, delta: amount)
            createMovement(type: type, amount: amount, producto: producto, almacen: origen, origen: origen.nombre, destino: destino.nombre)
        }

        producto.stockLitros = totalStock(for: producto)
        try context.save()
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

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let stock = StockAlmacenEntity(context: context)
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
        return ((try? context.fetch(request)) ?? []).reduce(0) { $0 + $1.stockActual }
    }

    private func createMovement(type: String, amount: Double, producto: ProductoEntity, almacen: AlmacenEntity, origen: String?, destino: String?) {
        let movimiento = MovimientoInventarioEntity(context: context)
        movimiento.id = UUID()
        movimiento.fecha = Date()
        movimiento.tipo = type
        movimiento.cantidadLitros = amount
        movimiento.producto = producto
        movimiento.almacen = almacen
        movimiento.origen = origen
        movimiento.destino = destino
        movimiento.nota = txtNota?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnGuardarTapped(_ sender: UIButton) {
        if let message = validateInputs() {
            showAlert(title: "Validación", message: message)
            return
        }

        do {
            try saveMovement()
            delegate?.modalMovimientoViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo registrar el movimiento.")
        }
    }
}

extension ModalMovimientoViewController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == txtOrigen || textField == txtDestino, almacenes.isEmpty {
            showAlert(title: "Sin almacenes", message: "Registra un almacén primero.")
            return false
        }
        if textField == txtProducto, productos.isEmpty {
            showAlert(title: "Sin productos", message: "Registra un producto primero.")
            return false
        }
        return true
    }
}

extension ModalMovimientoViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView == productoPicker ? productos.count : almacenes.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == productoPicker {
            return productos.indices.contains(row) ? productos[row].nombre : nil
        }
        return almacenes.indices.contains(row) ? almacenes[row].nombre : nil
    }
}
