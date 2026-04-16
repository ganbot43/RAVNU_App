import UIKit
import CoreData

final class ModalClienteViewController: UIViewController {

    @IBOutlet private weak var txtNombre: UITextField!
    @IBOutlet private weak var txtDocumento: UITextField!
    @IBOutlet private weak var txtTelefono: UITextField!
    @IBOutlet private weak var txtDireccion: UITextField!
    @IBOutlet private weak var txtLimiteCredito: UITextField!
    @IBOutlet private weak var clienteTipoControl: UISegmentedControl!
    @IBOutlet private weak var btnGuardar: UIButton!

    weak var delegate: ModalClienteViewControllerDelegate?

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        txtLimiteCredito.keyboardType = .decimalPad
        txtTelefono.keyboardType = .phonePad
        txtDocumento.keyboardType = .numberPad
        btnGuardar.layer.cornerRadius = 16
        btnGuardar.clipsToBounds = true
    }

    private func parseCredito() -> Double {
        let rawValue = txtLimiteCredito.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        return Double(rawValue) ?? 0
    }

    private func validateInputs() -> String? {
        if (txtNombre.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa el nombre del cliente."
        }
        if (txtDocumento.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa el documento."
        }
        if parseCredito() < 0 {
            return "El límite de crédito no puede ser negativo."
        }
        return nil
    }

    private func saveCliente() throws {
        let cliente = ClienteEntity(context: context)
        cliente.id = UUID()
        cliente.nombre = txtNombre.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.documento = txtDocumento.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.telefono = txtTelefono.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.direccion = txtDireccion.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.limiteCredito = parseCredito()
        cliente.creditoUsado = 0
        cliente.activo = true

        if clienteTipoControl.selectedSegmentIndex == 1 {
            cliente.documento = "RUC \(cliente.documento ?? "")"
        } else {
            cliente.documento = "DNI \(cliente.documento ?? "")"
        }

        try context.save()
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
        if let validationError = validateInputs() {
            showAlert(title: "Validación", message: validationError)
            return
        }

        do {
            try saveCliente()
            delegate?.modalClienteViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar el cliente.")
        }
    }
}
