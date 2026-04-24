import CoreData
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
    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

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

    private func payload(for almacenId: UUID) -> [String: Any] {
        [
            "id": almacenId.uuidString,
            "nombre": txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "direccion": txtDireccion?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "responsable": txtResponsable?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "activo": true,
            "createdAt": Timestamp(date: Date())
        ]
    }

    private func saveAlmacenToLocal(id: UUID) throws {
        let almacen = AlmacenEntity(context: context)
        almacen.id = id
        almacen.nombre = txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.direccion = txtDireccion?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.responsable = txtResponsable?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.activo = true
        createInitialStocks(for: almacen)
        try context.save()
    }

    private func saveAlmacen() throws {
        let almacenId = UUID()

        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            let warehouseRef = firestore.collection("warehouses").document(almacenId.uuidString)
            let batch = firestore.batch()
            batch.setData(payload(for: almacenId), forDocument: warehouseRef, merge: true)

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
