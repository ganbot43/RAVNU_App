import CoreData
import UIKit

protocol ModalCuotaViewControllerDelegate: AnyObject {
    func modalCuotaViewControllerDidSavePago(_ controller: ModalCuotaViewController)
}

final class ModalCuotaViewController: UIViewController {

    @IBOutlet private weak var txtCliente: UITextField?
    @IBOutlet private weak var txtMonto: UITextField?
    @IBOutlet private weak var lblCuotaTitulo: UILabel?
    @IBOutlet private weak var lblCuotaMonto: UILabel?
    @IBOutlet private weak var lblCuotaVencimiento: UILabel?
    @IBOutlet private weak var lblCuotaEstado: UILabel?
    @IBOutlet private weak var lblSaldoRestante: UILabel?
    @IBOutlet private weak var lblDeudaActual: UILabel?
    @IBOutlet private weak var btnConfirmar: UIButton?
    @IBOutlet private weak var cuotaCardView: UIView?
    @IBOutlet private weak var resumenCardView: UIView?
    @IBOutlet private weak var infoCardView: UIView?

    weak var delegate: ModalCuotaViewControllerDelegate?

    private let cuotaPicker = UIPickerView()
    private var cuotasPendientes: [CuotaEntity] = []
    private var selectedCuotaIndex: Int? {
        didSet {
            updateSelectedCuotaUI()
        }
    }

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    private var selectedCuota: CuotaEntity? {
        guard let selectedCuotaIndex, cuotasPendientes.indices.contains(selectedCuotaIndex) else {
            return nil
        }
        return cuotasPendientes[selectedCuotaIndex]
    }

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.currencySymbol = "S/"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadCuotasPendientes()
        updateSelectedCuotaUI()
    }

    private func configureUI() {
        txtCliente?.delegate = self
        txtCliente?.tintColor = .clear
        txtCliente?.inputView = cuotaPicker
        txtCliente?.inputAccessoryView = pickerToolbar()
        txtCliente?.placeholder = "Seleccionar cuota pendiente a cobrar"

        txtMonto?.keyboardType = .decimalPad
        txtMonto?.addTarget(self, action: #selector(montoDidChange), for: .editingChanged)

        cuotaPicker.dataSource = self
        cuotaPicker.delegate = self

        [cuotaCardView, resumenCardView, infoCardView].forEach { view in
            view?.layer.cornerRadius = 16
            view?.clipsToBounds = true
        }

        btnConfirmar?.layer.cornerRadius = 16
        btnConfirmar?.clipsToBounds = true
    }

    private func loadCuotasPendientes() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "pagada == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]

        do {
            cuotasPendientes = try context.fetch(request)
            selectedCuotaIndex = cuotasPendientes.isEmpty ? nil : 0
            cuotaPicker.reloadAllComponents()
        } catch {
            cuotasPendientes = []
            selectedCuotaIndex = nil
            showAlert(title: "Error", message: "No se pudieron cargar las cuotas pendientes.")
        }
    }

    private func updateSelectedCuotaUI() {
        guard let cuota = selectedCuota else {
            txtCliente?.text = nil
            txtMonto?.text = nil
            lblCuotaTitulo?.text = "Sin cuotas pendientes"
            lblCuotaMonto?.text = formatCurrency(0)
            lblCuotaVencimiento?.text = "No hay cuotas por cobrar"
            lblCuotaEstado?.text = "Pendiente"
            lblSaldoRestante?.text = formatCurrency(0)
            lblDeudaActual?.text = formatCurrency(0)
            btnConfirmar?.isEnabled = false
            btnConfirmar?.alpha = 0.55
            return
        }

        let cliente = cuota.venta?.cliente
        let totalCuotas = cuota.venta?.cuotas?.count ?? 0
        txtCliente?.text = cliente?.nombre ?? "Cliente"
        txtMonto?.text = String(format: "%.2f", cuota.monto)
        lblCuotaTitulo?.text = "Cuota \(cuota.numero) de \(totalCuotas)"
        lblCuotaMonto?.text = formatCurrency(cuota.monto)
        lblCuotaVencimiento?.text = "Vence \(formatDate(cuota.fechaVencimiento))"
        lblCuotaEstado?.text = isVencida(cuota) ? "Vencido" : "Pendiente"
        lblSaldoRestante?.text = formatCurrency(max((cliente?.creditoUsado ?? 0) - cuota.monto, 0))
        lblDeudaActual?.text = formatCurrency(cliente?.creditoUsado ?? cuota.monto)
        btnConfirmar?.isEnabled = true
        btnConfirmar?.alpha = 1
    }

    @objc
    private func montoDidChange() {
        guard let cuota = selectedCuota else { return }
        let monto = parseMonto()
        let deuda = cuota.venta?.cliente?.creditoUsado ?? cuota.monto
        lblSaldoRestante?.text = formatCurrency(max(deuda - monto, 0))
    }

    private func pickerToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPicking)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Listo", style: .plain, target: self, action: #selector(donePicking))
        ]
        return toolbar
    }

    @objc
    private func cancelPicking() {
        txtCliente?.resignFirstResponder()
    }

    @objc
    private func donePicking() {
        guard !cuotasPendientes.isEmpty else {
            txtCliente?.resignFirstResponder()
            return
        }
        selectedCuotaIndex = cuotaPicker.selectedRow(inComponent: 0)
        txtCliente?.resignFirstResponder()
    }

    private func parseMonto() -> Double {
        let rawValue = txtMonto?.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        return Double(rawValue) ?? 0
    }

    private func validatePayment() -> String? {
        guard let cuota = selectedCuota else {
            return "No hay una cuota seleccionada."
        }

        let monto = parseMonto()
        if monto <= 0 {
            return "Ingresa un monto valido."
        }

        if monto + 0.01 < cuota.monto {
            return "El pago debe cubrir la cuota completa."
        }

        return nil
    }

    private func registerPayment() throws {
        guard let cuota = selectedCuota else { return }

        let cliente = cuota.venta?.cliente
        let monto = min(parseMonto(), cuota.monto)

        cuota.pagada = true
        cuota.fechaPago = Date()
        cliente?.creditoUsado = max((cliente?.creditoUsado ?? 0) - monto, 0)

        if let venta = cuota.venta, allCuotasPagadas(in: venta) {
            venta.estado = "pagada"
        }

        try context.save()
    }

    private func allCuotasPagadas(in venta: VentaEntity) -> Bool {
        guard let cuotas = venta.cuotas?.allObjects as? [CuotaEntity], !cuotas.isEmpty else {
            return false
        }
        return cuotas.allSatisfy { $0.pagada }
    }

    private func isVencida(_ cuota: CuotaEntity) -> Bool {
        guard let fecha = cuota.fechaVencimiento else { return false }
        return !cuota.pagada && Calendar.current.startOfDay(for: fecha) < Calendar.current.startOfDay(for: Date())
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0.00"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter.string(from: date)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnConfirmarTapped(_ sender: UIButton) {
        if let validationMessage = validatePayment() {
            showAlert(title: "Validacion", message: validationMessage)
            return
        }

        do {
            try registerPayment()
            delegate?.modalCuotaViewControllerDidSavePago(self)
            dismiss(animated: true)
        } catch {
            showAlert(title: "Error", message: "No se pudo registrar el pago.")
        }
    }
}

extension ModalCuotaViewController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == txtCliente, cuotasPendientes.isEmpty {
            showAlert(title: "Sin cuotas", message: "No hay cuotas pendientes para cobrar.")
            return false
        }

        if textField == txtCliente, let selectedCuotaIndex {
            cuotaPicker.selectRow(selectedCuotaIndex, inComponent: 0, animated: false)
        }

        return true
    }
}

extension ModalCuotaViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        cuotasPendientes.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard cuotasPendientes.indices.contains(row) else { return nil }
        let cuota = cuotasPendientes[row]
        let cliente = cuota.venta?.cliente?.nombre ?? "Cliente"
        return "\(cliente) - Cuota \(cuota.numero) - \(formatCurrency(cuota.monto))"
    }
}
