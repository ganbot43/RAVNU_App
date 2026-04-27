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

    private let context = AppCoreData.viewContext
    private var responsablesDisponibles: [String] = []
    private let selectorResponsable = UIPickerView()

    private var puedeGestionarDirecto: Bool {
        RoleAccessControl.isAdmin
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        btnGuardar?.layer.cornerRadius = 16
        btnGuardar?.clipsToBounds = true
        configurarSelectorResponsable()
        cargarResponsables()
    }

    private func validateInputs() -> String? {
        let trimmedName = (txtNombre?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Ingresa el nombre del almacén."
        }
        if (txtDireccion?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa la dirección."
        }
        if (txtResponsable?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ingresa el responsable."
        }
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "nombre =[c] %@", trimmedName)
        if ((try? context.fetch(request)) ?? []).isEmpty == false {
            return "Ya existe un almacén con ese nombre."
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

    private func solicitarMotivoYEnviar() {
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud al panel administrativo para crear el almacén.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Motivo de la solicitud"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let motivo = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard motivo.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudAlmacen(motivo: motivo)
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

    private func enviarSolicitudAlmacen(motivo: String) async throws {
        let requester = try AdminRequestService.currentRequester()
        let payload = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: "create_warehouse",
            module: "almacen",
            status: "pending",
            requestedBy: requester,
            target: nil,
            payload: [
                "nombre": .string(txtNombre?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
                "direccion": .string(txtDireccion?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
                "responsable": .string(txtResponsable?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
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

    private func configurarSelectorResponsable() {
        selectorResponsable.dataSource = self
        selectorResponsable.delegate = self
        txtResponsable?.inputView = selectorResponsable

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Listo", style: .done, target: self, action: #selector(confirmarResponsable))
        ]
        txtResponsable?.inputAccessoryView = toolbar
    }

    private func cargarResponsables() {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        firestore.collection("users").getDocuments { [weak self] snapshot, _ in
            guard let self else { return }
            let trabajadores = (snapshot?.documents ?? []).compactMap { document -> String? in
                let data = document.data()
                let roleId = ((data["roleId"] as? String) ?? (data["role"] as? String) ?? "").lowercased()
                let activo = (data["active"] as? Bool) ?? (data["status"] as? Bool) ?? true
                guard activo, roleId == "almacenero" || roleId == "almacen" else { return nil }
                return (data["fullName"] as? String) ?? (data["username"] as? String)
            }
            .sorted()

            DispatchQueue.main.async {
                self.responsablesDisponibles = trabajadores
                self.selectorResponsable.reloadAllComponents()
                if self.txtResponsable?.text?.isEmpty != false, let primero = trabajadores.first {
                    self.txtResponsable?.text = primero
                }
            }
        }
        #endif
    }

    @objc
    private func confirmarResponsable() {
        let indice = selectorResponsable.selectedRow(inComponent: 0)
        if responsablesDisponibles.indices.contains(indice) {
            txtResponsable?.text = responsablesDisponibles[indice]
        }
        txtResponsable?.resignFirstResponder()
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
                try saveAlmacen()
                delegate?.modalAlmacenViewControllerDidSave(self)
                dismiss(animated: true)
            } catch {
                showAlert(title: "Error", message: "No se pudo guardar el almacén.")
            }
        } else if RoleAccessControl.canRequestWarehouseCreation {
            solicitarMotivoYEnviar()
        } else {
            showAlert(title: "Permiso denegado", message: "Tu rol no puede solicitar nuevos almacenes.")
        }
    }
}

extension ModalAlmacenViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        max(responsablesDisponibles.count, 1)
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if responsablesDisponibles.isEmpty {
            return "No hay almaceneros"
        }
        return responsablesDisponibles[row]
    }
}
