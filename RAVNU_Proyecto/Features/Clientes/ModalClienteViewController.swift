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

    private var puedeGestionarDirecto: Bool {
        RoleAccessControl.canManageDirectly
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarFormularioEmbebido()
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
        guard RoleAccessControl.canCreateCustomers else {
            mostrarAlerta(title: "Permiso denegado", message: "Tu rol no tiene permiso para agregar clientes.")
            return
        }

        if let validationError = validar(form: form) {
            mostrarAlerta(title: "Validación", message: validationError)
            return
        }

        if puedeGestionarDirecto {
            do {
                try guardarCliente(form: form)
                delegate?.modalClienteViewControllerDidSave(self)
                dismiss(animated: true)
            } catch {
                mostrarAlerta(title: "Error", message: "No se pudo guardar el cliente.")
            }
        } else if RoleAccessControl.canRequestCustomerCreation {
            solicitarMotivoYEnviar(form: form)
        } else {
            mostrarAlerta(title: "Permiso denegado", message: "Tu rol no puede crear ni solicitar nuevos clientes.")
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

    private func solicitarMotivoYEnviar(form: ClienteModalFormData) {
        let config = AdminRequestComposerConfig(
            title: "Solicitud de alta de cliente",
            subtitle: "La solicitud se registrará en el web admin para revisión, con los datos del cliente y el endpoint ya configurado.",
            moduleLabel: "Clientes",
            typeLabel: "create_customer",
            targetLabel: form.nombre.trimmingCharacters(in: .whitespacesAndNewlines).fallback("Cliente nuevo"),
            accent: .green,
            primaryField: .init(
                title: "Motivo principal",
                placeholder: "Ej. alta por nuevo convenio, nuevo cliente crédito o regularización",
                helper: "Explica por qué este cliente debe ser creado desde solicitudes.",
                isRequired: true
            ),
            secondaryField: .init(
                title: "Contexto comercial",
                placeholder: "Indica canal, vendedor, frecuencia esperada o relación con ventas/cobros",
                helper: "Sirve para que administración entienda el impacto y priorice la revisión.",
                isRequired: true
            ),
            tertiaryField: .init(
                title: "Observación adicional",
                placeholder: "Notas opcionales sobre documento, crédito o contacto",
                helper: "Puedes dejarlo vacío si no hace falta agregar más contexto.",
                isRequired: false
            ),
            summaryItems: [
                .init(title: "Cliente", value: form.nombre.trimmingCharacters(in: .whitespacesAndNewlines).fallback("Sin nombre")),
                .init(title: "Documento", value: valorDocumento(desde: form)),
                .init(title: "Teléfono", value: form.telefono.trimmingCharacters(in: .whitespacesAndNewlines).fallback("Sin teléfono")),
                .init(title: "Dirección", value: form.direccion.trimmingCharacters(in: .whitespacesAndNewlines).fallback("Sin dirección")),
                .init(title: "Límite crédito", value: currencyText(convertirCredito(form.limiteCredito)))
            ],
            endpointLabel: AdminRequestService.requestEndpointDescription()
        )
        presentAdminRequestComposer(config: config) { [weak self] result, presenter in
            guard let self else { return }
            presenter.dismiss(animated: true)
            Task {
                do {
                    try await self.enviarSolicitudCliente(
                        form: form,
                        motivo: result.primaryText,
                        contextoComercial: result.secondaryText,
                        observacion: result.tertiaryText
                    )
                    await MainActor.run {
                        self.mostrarAlertaYSalir(
                            title: "Solicitud enviada",
                            message: "La solicitud fue enviada al panel administrativo."
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.mostrarAlerta(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func enviarSolicitudCliente(
        form: ClienteModalFormData,
        motivo: String,
        contextoComercial: String,
        observacion: String
    ) async throws {
        let requester = try AdminRequestService.currentRequester()
        let payload = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: "create_customer",
            module: "clientes",
            status: "pending",
            requestedBy: requester,
            target: nil,
            payload: [
                "nombre": .string(form.nombre.trimmingCharacters(in: .whitespacesAndNewlines)),
                "documento": .string(valorDocumento(desde: form)),
                "telefono": .string(form.telefono.trimmingCharacters(in: .whitespacesAndNewlines)),
                "direccion": .string(form.direccion.trimmingCharacters(in: .whitespacesAndNewlines)),
                "limiteCredito": .number(convertirCredito(form.limiteCredito)),
                "detalleSolicitud": .object([
                    "contextoComercial": .string(contextoComercial),
                    "observacion": observacion.isEmpty ? .string("sin_observacion") : .string(observacion),
                    "requiereValidacionCredito": .bool(convertirCredito(form.limiteCredito) > 0)
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

    private func mostrarAlertaYSalir(title: String, message: String) {
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
        // El flujo principal ya vive en SwiftUI. Mantengo la acción para no romper storyboard.
    }
}

private extension ModalClienteViewController {
    func currencyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: NSNumber(value: value)) ?? "S/\(value)"
    }
}

private extension String {
    func fallback(_ value: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? value : self
    }
}
