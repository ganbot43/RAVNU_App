import UIKit
import CoreData
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class ModalClienteViewController: UIViewController {

    @IBOutlet private weak var txtNombre: UITextField?
    @IBOutlet private weak var txtDocumento: UITextField?
    @IBOutlet private weak var txtTelefono: UITextField?
    @IBOutlet private weak var txtDireccion: UITextField?
    @IBOutlet private weak var txtLimiteCredito: UITextField?
    @IBOutlet private weak var clienteTipoControl: UISegmentedControl?
    @IBOutlet private weak var btnGuardar: UIButton?

    weak var delegate: ModalClienteViewControllerDelegate?

    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private var hostingController: UIHostingController<ClienteModalFormView>?

    private let context = AppCoreData.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        hideLegacyForm()
        configureHostedForm()
    }

    private func hideLegacyForm() {
        [
            txtNombre,
            txtDocumento,
            txtTelefono,
            txtDireccion,
            txtLimiteCredito,
            clienteTipoControl,
            btnGuardar
        ].forEach { $0?.isHidden = true }
        view.backgroundColor = UIColor(red: 244.0 / 255.0, green: 246.0 / 255.0, blue: 250.0 / 255.0, alpha: 1.0)
    }

    private func configureHostedForm() {
        let rootView = ClienteModalFormView(
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            },
            onSave: { [weak self] form in
                self?.saveFromForm(form)
            }
        )

        let host = UIHostingController(rootView: rootView)
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

    private func saveFromForm(_ form: ClienteModalFormData) {
        if let validationError = validate(form: form) {
            showAlert(title: "Validación", message: validationError)
            return
        }

        do {
            try saveCliente(form: form)
            delegate?.modalClienteViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo guardar el cliente.")
        }
    }

    private func validate(form: ClienteModalFormData) -> String? {
        let trimmedName = form.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDocument = form.documento.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = form.telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return "Ingresa el nombre del cliente."
        }
        if trimmedDocument.count != form.tipoDocumento.maxLength {
            return "El número de documento no tiene la longitud correcta."
        }
        if trimmedPhone.count != 9 {
            return "El teléfono debe tener 9 dígitos."
        }
        if parseCredito(form.limiteCredito) < 0 {
            return "El límite de crédito no puede ser negativo."
        }
        let documentRequest: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        documentRequest.fetchLimit = 1
        documentRequest.predicate = NSPredicate(format: "documento =[c] %@", documentValue(from: form))
        if ((try? context.fetch(documentRequest)) ?? []).isEmpty == false {
            return "Ya existe un cliente con ese documento."
        }
        let phoneRequest: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        phoneRequest.fetchLimit = 1
        phoneRequest.predicate = NSPredicate(format: "telefono == %@", trimmedPhone)
        if ((try? context.fetch(phoneRequest)) ?? []).isEmpty == false {
            return "Ya existe un cliente con ese teléfono."
        }
        return nil
    }

    private func parseCredito(_ rawValue: String) -> Double {
        Double(rawValue.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func documentValue(from form: ClienteModalFormData) -> String {
        "\(form.tipoDocumento.rawValue) \(form.documento.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func clientePayload(id: UUID, form: ClienteModalFormData) -> [String: Any] {
        [
            "id": id.uuidString,
            "nombre": form.nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            "documento": documentValue(from: form),
            "telefono": form.telefono.trimmingCharacters(in: .whitespacesAndNewlines),
            "direccion": form.direccion.trimmingCharacters(in: .whitespacesAndNewlines),
            "limiteCredito": parseCredito(form.limiteCredito),
            "creditoUsado": 0.0,
            "activo": true,
            "createdAt": Timestamp(date: Date())
        ]
    }

    private func saveClienteToLocal(id: UUID, form: ClienteModalFormData) throws {
        let cliente = ClienteEntity(context: context)
        cliente.id = id
        cliente.nombre = form.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.documento = documentValue(from: form)
        cliente.telefono = form.telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.direccion = form.direccion.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.limiteCredito = parseCredito(form.limiteCredito)
        cliente.creditoUsado = 0
        cliente.activo = true
        try context.save()
    }

    private func saveCliente(form: ClienteModalFormData) throws {
        let clienteId = UUID()

        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            let payload = clientePayload(id: clienteId, form: form)
            firestore.collection("customers").document(clienteId.uuidString).setData(payload, merge: true)
        }
        #endif

        try saveClienteToLocal(id: clienteId, form: form)
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
        // El flujo principal ya vive en SwiftUI. Mantengo la acción para no romper storyboard.
    }
}
