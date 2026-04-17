import CoreData
import UIKit

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

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        [txtPrecio, txtStockMinimo, txtCapacidad].forEach { $0?.keyboardType = .decimalPad }
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
    }

    private func parseDouble(_ text: String?) -> Double {
        Double((text ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func validateInputs() -> String? {
        if (txtNombre?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        return nil
    }

    private func saveProducto() throws {
        let producto = ProductoEntity(context: context)
        producto.id = UUID()
        producto.nombre = txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.precioPorLitro = parseDouble(txtPrecio?.text)
        producto.unidadMedida = (txtUnidad?.text ?? "L").trimmingCharacters(in: .whitespacesAndNewlines)
        producto.stockMinimo = parseDouble(txtStockMinimo?.text)
        producto.capacidadTotal = parseDouble(txtCapacidad?.text)
        producto.stockLitros = 0
        producto.tipo = tipoControl?.selectedSegmentIndex == 1 ? "GLP" : "Combustible"
        producto.activo = true
        createInitialStocks(for: producto)
        try context.save()
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
            try saveProducto()
            delegate?.modalProductoViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar el producto.")
        }
    }
}
