import CoreData
import UIKit

protocol ModalAlmacenViewControllerDelegate: AnyObject {
    func modalAlmacenViewControllerDidSave(_ controller: ModalAlmacenViewController)
}

final class ModalAlmacenViewController: UIViewController {

    @IBOutlet private weak var txtNombre: UITextField?
    @IBOutlet private weak var txtDireccion: UITextField?
    @IBOutlet private weak var txtResponsable: UITextField?
    @IBOutlet private weak var btnGuardar: UIButton?

    weak var delegate: ModalAlmacenViewControllerDelegate?

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
    }

    private func validateInputs() -> String? {
        if (txtNombre?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa el nombre del almacén."
        }
        if (txtDireccion?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa la dirección."
        }
        if (txtResponsable?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa el responsable."
        }
        return nil
    }

    private func saveAlmacen() throws {
        let almacen = AlmacenEntity(context: context)
        almacen.id = UUID()
        almacen.nombre = txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.direccion = txtDireccion?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.responsable = txtResponsable?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.activo = true
        createInitialStocks(for: almacen)
        try context.save()
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
            try saveAlmacen()
            delegate?.modalAlmacenViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar el almacén.")
        }
    }
}
