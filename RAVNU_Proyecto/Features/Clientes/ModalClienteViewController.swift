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

    private let contexto = AppCoreData.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        ocultarFormularioLegacy()
        configurarFormularioEmbebido()
    }

    private func ocultarFormularioLegacy() {
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

    private func configurarFormularioEmbebido() {
        let rootView = ClienteModalFormView(
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            },
            onSave: { [weak self] form in
                self?.guardarDesdeFormulario(form)
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

    private func guardarDesdeFormulario(_ form: ClienteModalFormData) {
        if let validationError = validar(form: form) {
            mostrarAlerta(title: "Validación", message: validationError)
            return
        }

        do {
            try guardarCliente(form: form)
            delegate?.modalClienteViewControllerDidSave(self)
            dismiss(animated: true)
        } catch {
            mostrarAlerta(title: "Error", message: "No se pudo guardar el cliente.")
        }
    }

    private func validar(form: ClienteModalFormData) -> String? {
        let nombre = form.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let documento = form.documento.trimmingCharacters(in: .whitespacesAndNewlines)
        let telefono = form.telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        if nombre.isEmpty {
            return "Ingresa el nombre del cliente."
        }
        if documento.count != form.tipoDocumento.maxLength {
            return "El número de documento no tiene la longitud correcta."
        }
        if telefono.count != 9 {
            return "El teléfono debe tener 9 dígitos."
        }
        if convertirCredito(form.limiteCredito) < 0 {
            return "El límite de crédito no puede ser negativo."
        }
        let requestDocumento: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        requestDocumento.fetchLimit = 1
        requestDocumento.predicate = NSPredicate(format: "documento =[c] %@", valorDocumento(desde: form))
        if ((try? contexto.fetch(requestDocumento)) ?? []).isEmpty == false {
            return "Ya existe un cliente con ese documento."
        }
        let requestTelefono: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        requestTelefono.fetchLimit = 1
        requestTelefono.predicate = NSPredicate(format: "telefono == %@", telefono)
        if ((try? contexto.fetch(requestTelefono)) ?? []).isEmpty == false {
            return "Ya existe un cliente con ese teléfono."
        }
        return nil
    }

    private func convertirCredito(_ rawValue: String) -> Double {
        Double(rawValue.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func valorDocumento(desde form: ClienteModalFormData) -> String {
        "\(form.tipoDocumento.rawValue) \(form.documento.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func payloadCliente(id: UUID, form: ClienteModalFormData) -> [String: Any] {
        [
            "id": id.uuidString,
            "nombre": form.nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            "documento": valorDocumento(desde: form),
            "telefono": form.telefono.trimmingCharacters(in: .whitespacesAndNewlines),
            "direccion": form.direccion.trimmingCharacters(in: .whitespacesAndNewlines),
            "limiteCredito": convertirCredito(form.limiteCredito),
            "creditoUsado": 0.0,
            "activo": true,
            "createdAt": Timestamp(date: Date())
        ]
    }

    private func guardarClienteLocal(id: UUID, form: ClienteModalFormData) throws {
        let cliente = ClienteEntity(context: contexto)
        cliente.id = id
        cliente.nombre = form.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.documento = valorDocumento(desde: form)
        cliente.telefono = form.telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.direccion = form.direccion.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.limiteCredito = convertirCredito(form.limiteCredito)
        cliente.creditoUsado = 0
        cliente.activo = true
        try contexto.save()
    }

    private func guardarCliente(form: ClienteModalFormData) throws {
        let clienteId = UUID()

        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            let payload = payloadCliente(id: clienteId, form: form)
            firestore.collection("customers").document(clienteId.uuidString).setData(payload, merge: true)
        }
        #endif

        try guardarClienteLocal(id: clienteId, form: form)
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
        // El flujo principal ya vive en SwiftUI. Mantengo la acción para no romper storyboard.
    }
}
