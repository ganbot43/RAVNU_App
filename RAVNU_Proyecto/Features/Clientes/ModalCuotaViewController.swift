import CoreData
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ModalCuotaViewControllerDelegate: AnyObject {
    func modalCuotaViewControllerDidSavePago(_ controller: ModalCuotaViewController)
}

final class ModalCuotaViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

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
    var preferredCuotaID: UUID?

    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let cuotaPicker = UIPickerView()
    private var cuotasPendientes: [CuotaEntity] = []
    private var indiceCuotaSeleccionada: Int? {
        didSet { actualizarVistaHibrida() }
    }
    private var hostingController: UIHostingController<PaymentInstallmentSheetView>?

    private let contexto = AppCoreData.viewContext

    private var cuotaSeleccionada: CuotaEntity? {
        guard let indiceCuotaSeleccionada, cuotasPendientes.indices.contains(indiceCuotaSeleccionada) else { return nil }
        return cuotasPendientes[indiceCuotaSeleccionada]
    }

    private let formateadorMoneda: NumberFormatter = {
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
        ocultarVistaLegacy()
        cargarCuotasPendientes()
        configurarVistaHibrida()
    }

    private func ocultarVistaLegacy() {
        [
            txtCliente,
            txtMonto,
            lblCuotaTitulo,
            lblCuotaMonto,
            lblCuotaVencimiento,
            lblCuotaEstado,
            lblSaldoRestante,
            lblDeudaActual,
            btnConfirmar,
            cuotaCardView,
            resumenCardView,
            infoCardView
        ].forEach { $0?.isHidden = true }
    }

    private func configurarVistaHibrida() {
        let host = UIHostingController(rootView: crearVistaRaiz())
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

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaRaiz()
    }

    private func crearVistaRaiz() -> PaymentInstallmentSheetView {
        PaymentInstallmentSheetView(
            data: crearDatosVista(),
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSelectCuota: { [weak self] id in self?.seleccionarCuota(id: id) },
            onConfirm: { [weak self] amount in self?.manejarConfirmacion(monto: amount) }
        )
    }

    private func cargarCuotasPendientes() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "pagada == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]

        do {
            cuotasPendientes = try contexto.fetch(request)
            if let preferredCuotaID,
               let index = cuotasPendientes.firstIndex(where: { $0.id == preferredCuotaID }) {
                indiceCuotaSeleccionada = index
            } else {
                indiceCuotaSeleccionada = cuotasPendientes.isEmpty ? nil : 0
            }
        } catch {
            cuotasPendientes = []
            indiceCuotaSeleccionada = nil
        }
    }

    private func seleccionarCuota(id: UUID?) {
        guard let id, let index = cuotasPendientes.firstIndex(where: { $0.id == id }) else { return }
        indiceCuotaSeleccionada = index
    }

    private func crearDatosVista() -> PaymentInstallmentSheetData {
        let options = cuotasPendientes.map { cuota in
            PaymentInstallmentSheetData.Option(
                id: cuota.id ?? UUID(),
                title: cuota.venta?.cliente?.nombre ?? "Cliente",
                subtitle: "Cuota \(cuota.numero) - \(formatearMoneda(cuota.monto))"
            )
        }

        guard let cuota = cuotaSeleccionada else {
            return PaymentInstallmentSheetData(
                options: options,
                selectedID: nil,
                titleText: "Sin cuotas pendientes",
                amountText: formatearMoneda(0),
                dueText: "No hay cuotas por cobrar",
                statusText: "Pendiente",
                statusAccentHex: "94A3B8",
                amountValueText: "0.00",
                remainingText: formatearMoneda(0),
                debtAfterText: formatearMoneda(0),
                isConfirmEnabled: false
            )
        }

        let cliente = cuota.venta?.cliente
        let totalCuotas = cuota.venta?.cuotas?.count ?? Int(cuota.numero)
        let debt = cliente?.creditoUsado ?? cuota.monto
        let remaining = max(debt - cuota.monto, 0)

        return PaymentInstallmentSheetData(
            options: options,
            selectedID: cuota.id,
            titleText: "Cuota \(cuota.numero) de \(max(totalCuotas, Int(cuota.numero)))",
            amountText: formatearMoneda(cuota.monto),
            dueText: "Vence \(formatearFecha(cuota.fechaVencimiento))",
            statusText: estaVencida(cuota) ? "Vencido" : "Pendiente",
            statusAccentHex: estaVencida(cuota) ? "EF4444" : "F59E0B",
            amountValueText: String(format: "%.2f", cuota.monto),
            remainingText: formatearMoneda(0),
            debtAfterText: formatearMoneda(remaining),
            isConfirmEnabled: true
        )
    }

    private func manejarConfirmacion(monto: Double) {
        if let validationMessage = validarPago(monto: monto) {
            mostrarAlerta(title: "Validación", message: validationMessage)
            return
        }

        do {
            try registrarPago(monto: monto)
            delegate?.modalCuotaViewControllerDidSavePago(self)
            dismiss(animated: true)
        } catch {
            mostrarAlerta(title: "Error", message: "No se pudo registrar el pago.")
        }
    }

    private func validarPago(monto: Double) -> String? {
        guard let cuota = cuotaSeleccionada else {
            return "No hay una cuota seleccionada."
        }
        if monto <= 0 {
            return "Ingresa un monto válido."
        }
        if monto + 0.01 < cuota.monto {
            return "El pago debe cubrir la cuota completa."
        }
        return nil
    }

    private func registrarPago(monto: Double) throws {
        guard let cuota = cuotaSeleccionada else { return }

        let cliente = cuota.venta?.cliente
        let montoAplicado = min(monto, cuota.monto)

        cuota.pagada = true
        cuota.fechaPago = Date()
        cliente?.creditoUsado = max((cliente?.creditoUsado ?? 0) - montoAplicado, 0)

        if let venta = cuota.venta, todasLasCuotasPagadas(en: venta) {
            venta.estado = "pagada"
        }

        try contexto.save()
        sincronizarPagoRemoto(cuota: cuota, cliente: cliente, montoAplicado: montoAplicado)
    }

    private func todasLasCuotasPagadas(en venta: VentaEntity) -> Bool {
        guard let cuotas = venta.cuotas?.allObjects as? [CuotaEntity], !cuotas.isEmpty else { return false }
        return cuotas.allSatisfy(\.pagada)
    }

    private func estaVencida(_ cuota: CuotaEntity) -> Bool {
        guard let fecha = cuota.fechaVencimiento else { return false }
        return !cuota.pagada && Calendar.current.startOfDay(for: fecha) < Calendar.current.startOfDay(for: Date())
    }

    private func formatearMoneda(_ amount: Double) -> String {
        formateadorMoneda.string(from: NSNumber(value: amount)) ?? "S/0.00"
    }

    private func formatearFecha(_ date: Date?) -> String {
        guard let date else { return "sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "d MMM, yyyy"
        return formatter.string(from: date)
    }

    private func mostrarAlerta(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func sincronizarPagoRemoto(cuota: CuotaEntity, cliente: ClienteEntity?, montoAplicado: Double) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard let cuotaId = cuota.id?.uuidString else { return }

        var cuotaPayload: [String: Any] = [
            "id": cuotaId,
            "numero": cuota.numero,
            "monto": cuota.monto,
            "pagada": cuota.pagada,
            "fechaVencimiento": Timestamp(date: cuota.fechaVencimiento ?? Date())
        ]

        if let fechaPago = cuota.fechaPago {
            cuotaPayload["fechaPago"] = Timestamp(date: fechaPago)
            cuotaPayload["paidAt"] = Timestamp(date: fechaPago)
        }

        if let ventaId = cuota.venta?.id?.uuidString {
            cuotaPayload["ventaId"] = ventaId
            cuotaPayload["saleId"] = ventaId
            firestore.collection("sales").document(ventaId).setData([
                "id": ventaId,
                "estado": cuota.venta?.estado ?? "pendiente",
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }

        firestore.collection("sale_installments").document(cuotaId).setData(cuotaPayload, merge: true)

        if let cliente, let clienteId = cliente.id?.uuidString {
            firestore.collection("customers").document(clienteId).setData([
                "id": clienteId,
                "creditoUsado": cliente.creditoUsado,
                "ultimoPago": montoAplicado,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }

        TreasuryRemoteSync.syncInstallmentPayment(cuota: cuota, cliente: cliente, amount: montoAplicado)
        AppSession.shared.lastRemoteSyncAt = Date()
        #endif
    }

    @IBAction private func btnCancelarTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnConfirmarTapped(_ sender: UIButton) {}

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { cuotasPendientes.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { nil }
}

private struct PaymentInstallmentSheetData {
    struct Option: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
    }

    let options: [Option]
    let selectedID: UUID?
    let titleText: String
    let amountText: String
    let dueText: String
    let statusText: String
    let statusAccentHex: String
    let amountValueText: String
    let remainingText: String
    let debtAfterText: String
    let isConfirmEnabled: Bool
}

private struct PaymentInstallmentSheetView: View {
    let data: PaymentInstallmentSheetData
    let onCancel: () -> Void
    let onSelectCuota: (UUID?) -> Void
    let onConfirm: (Double) -> Void

    @State private var amount: String = ""

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    clienteField
                    cuotaCard
                    amountField
                    summaryCard
                    infoCard
                    confirmButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .onAppear { amount = data.amountValueText }
        .onChange(of: data.selectedID) { _, _ in amount = data.amountValueText }
    }

    private var header: some View {
        HStack {
            Button("Cancelar", action: onCancel)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "3B82F6"))
            Spacer()
            Text("Registrar Pago")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1F2937"))
            Spacer()
            Color.clear.frame(width: 48)
        }
    }

    private var clienteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seleccionar cliente")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "64748B"))
            Menu {
                ForEach(data.options) { option in
                    Button(action: { onSelectCuota(option.id) }) {
                        VStack(alignment: .leading) {
                            Text(option.title)
                            Text(option.subtitle)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(data.options.first(where: { $0.id == data.selectedID })?.title ?? "Sin cuotas pendientes")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "334155"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(hex: "EEF2F7"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var cuotaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(data.titleText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1F2937"))
                Spacer()
                Text(data.statusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color(hex: data.statusAccentHex))
                    .clipShape(Capsule())
            }
            Text(data.amountText)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "111827"))
            Text(data.dueText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: data.statusAccentHex))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "EEF5FF"))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "93C5FD"), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monto a pagar (S/)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "64748B"))
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "334155"))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(hex: "EEF2F7"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            summaryRow(title: "Saldo restante", value: data.remainingText, accentHex: "22C55E")
            summaryRow(title: "Deuda después del pago", value: data.debtAfterText, accentHex: "111827")
        }
        .padding(16)
        .background(Color(hex: "F8FAFC"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("⚡")
            Text("El pago se registrará automáticamente en Tesorería")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "64748B"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "EEF5FF"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var confirmButton: some View {
        Button(action: {
            let normalized = amount.replacingOccurrences(of: ",", with: ".")
            onConfirm(Double(normalized) ?? 0)
        }) {
            Text("Confirmar Pago")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(data.isConfirmEnabled ? Color(hex: "4F83F6") : Color(hex: "A5B4FC"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!data.isConfirmEnabled)
    }

    private func summaryRow(title: String, value: String, accentHex: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "94A3B8"))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: accentHex))
        }
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
