import CoreData
import SwiftUI
import UIKit

final class VentasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var scrollViewResumen: UIScrollView?
    @IBOutlet private weak var tblListaVentas: UITableView?
    @IBOutlet private weak var btnResumen: UIButton?
    @IBOutlet private weak var btnListaVentas: UIButton?
    @IBOutlet private weak var emptyStateView: UIView?
    @IBOutlet private weak var lblIngresosTotal: UILabel?
    @IBOutlet private weak var lblEfectivoTotal: UILabel?
    @IBOutlet private weak var lblCreditoTotal: UILabel?
    @IBOutlet private weak var lblVentaRecienteCliente1: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto1: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle1: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto1: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo1: UILabel?
    @IBOutlet private weak var ventaRecienteCard1: UIView?
    @IBOutlet private weak var lblVentaRecienteCliente2: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto2: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle2: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto2: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo2: UILabel?
    @IBOutlet private weak var ventaRecienteCard2: UIView?
    @IBOutlet private weak var lblVentaRecienteCliente3: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto3: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle3: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto3: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo3: UILabel?
    @IBOutlet private weak var ventaRecienteCard3: UIView?

    private let contexto = AppCoreData.viewContext
    private var ventas: [VentaEntity] = []
    private var clientes: [ClienteEntity] = []
    private var productos: [ProductoEntity] = []
    private var hostingController: UIHostingController<SalesDashboardView>?
    private lazy var isoFormatter = ISO8601DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarAccesoPorRol()
        configurarVistaHibrida()
        cargarDatosCatalogo()
        cargarVentas()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarDatosCatalogo()
        cargarVentas()
    }

    @IBAction private func btnResumenTapped(_ sender: UIButton) {
        actualizarVistaSwiftUI()
    }

    @IBAction private func btnListaVentasTapped(_ sender: UIButton) {
        actualizarVistaSwiftUI()
    }

    @IBAction private func btnNuevaVentaTapped(_ sender: UIButton) {
        presentNewSaleFlow()
    }

    private func configurarAccesoPorRol() {
        let shouldHideCreateActions = RoleAccessControl.canCreateSales == false
        RoleAccessControl.configureButtons(
            in: view,
            target: self,
            selectors: [#selector(btnNuevaVentaTapped(_:))],
            hidden: shouldHideCreateActions
        )
    }

    private func configurarVistaHibrida() {
        let host = UIHostingController(rootView: crearVistaRaiz())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = UIColor.clear
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

    private func cargarDatosCatalogo() {
        do {
            let clienteRequest = ClienteEntity.fetchRequest()
            clienteRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            clientes = try contexto.fetch(clienteRequest)

            let productoRequest = ProductoEntity.fetchRequest()
            productoRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            productos = try contexto.fetch(productoRequest)
        } catch {
            showErrorAlert(message: "No se pudieron cargar clientes y productos.")
        }
    }

    private func cargarVentas() {
        do {
            let request = VentaEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "fechaVenta", ascending: false)]
            ventas = try contexto.fetch(request)
            actualizarVistaSwiftUI()
        } catch {
            ventas = []
            actualizarVistaSwiftUI()
            showErrorAlert(message: "No se pudieron cargar las ventas.")
        }
    }

    private func actualizarVistaSwiftUI() {
        hostingController?.rootView = crearVistaRaiz()
    }

    private func crearVistaRaiz() -> SalesDashboardView {
        SalesDashboardView(
            data: crearDatosDashboard(),
            onNewSale: { [weak self] in
                self?.presentNewSaleFlow()
            },
            onRequestEditSale: { [weak self] sale in
                self?.solicitarEdicionVenta(sale)
            },
            onRequestCancelSale: { [weak self] sale in
                self?.solicitarAnulacionVenta(sale)
            }
        )
    }

    private func crearDatosDashboard() -> DatosDashboardVentas {
        let totalIngresos = ventas.reduce(0) { $0 + $1.total }
        let efectivoVentas = ventas.filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.efectivo.rawValue }
        let creditoVentas = ventas.filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.credito.rawValue }
        let efectivoTotal = efectivoVentas.reduce(0) { $0 + $1.total }
        let creditoTotal = creditoVentas.reduce(0) { $0 + $1.total }

        let metrics = [
            DatosDashboardVentas.Metrica(icon: "dollarsign.circle.fill", label: "INGRESOS", value: formatearMoneda(totalIngresos), sub: ventas.isEmpty ? "Sin ventas" : "Este período", colorHex: "3B82F6"),
            DatosDashboardVentas.Metrica(icon: "banknote.fill", label: "EFECTIVO", value: formatearMoneda(efectivoTotal), sub: textoParticipacionVentas(amount: efectivoTotal, total: totalIngresos), colorHex: "22C55E"),
            DatosDashboardVentas.Metrica(icon: "creditcard.fill", label: "CRÉDITO", value: formatearMoneda(creditoTotal), sub: textoParticipacionVentas(amount: creditoTotal, total: totalIngresos), colorHex: "8B5CF6")
        ]

        let weekBars = crearBarrasSemanales()
        let trendBars = crearBarrasTendencia()
        let productRows = crearFilasProducto()
        let distributionRows = [
            DatosDashboardVentas.FilaDistribucion(colorHex: "22C55E", label: "Efectivo", value: formatearMoneda(efectivoTotal)),
            DatosDashboardVentas.FilaDistribucion(colorHex: "3B82F6", label: "Crédito", value: formatearMoneda(creditoTotal))
        ]
        let salesRows = ventas.prefix(20).map { sale in
            let entityId = sale.id?.uuidString ?? UUID().uuidString
            return DatosDashboardVentas.FilaVenta(
                id: entityId,
                entityId: entityId,
                clientName: sale.cliente?.nombre ?? "Cliente sin nombre",
                productInfo: "\(sale.producto?.nombre ?? "Producto") · \(formatLiters(sale.cantidadLitros))",
                total: formatearMoneda(sale.total),
                paymentType: (sale.metodoPago ?? "-").capitalized,
                colorHex: ((sale.metodoPago ?? "").lowercased() == MetodoPagoVenta.efectivo.rawValue) ? "22C55E" : "3B82F6",
                date: relativeDateText(from: sale.fechaVenta)
            )
        }

        return DatosDashboardVentas(
            title: "Ventas",
            subtitle: "\(ventas.count) transacciones este período",
            canCreateSale: RoleAccessControl.canCreateSales,
            canRequestSaleChanges: RoleAccessControl.canRequestSaleChanges,
            metricas: metrics,
            barrasSemanales: weekBars,
            barrasTendencia: trendBars,
            filasProducto: productRows,
            filasDistribucion: distributionRows,
            totalSalesCountText: "\(ventas.count) ventas en total",
            cashPercent: totalIngresos > 0 ? max(0, min(1, efectivoTotal / totalIngresos)) : 0,
            filasVenta: salesRows
        )
    }

    private func textoParticipacionVentas(amount: Double, total: Double) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int(((amount / total) * 100).rounded()))%"
    }

    private func crearBarrasSemanales() -> [DatosDashboardVentas.BarraSemanal] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "EEE"

        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
        let grouped = Dictionary(grouping: ventas) { sale in
            calendar.startOfDay(for: sale.fechaVenta ?? today)
        }

        let values = days.map { day -> DatosDashboardVentas.BarraSemanal in
            let amount = (grouped[day] ?? []).reduce(0) { $0 + $1.total }
            let label = formatter.string(from: day).prefix(1).uppercased() + formatter.string(from: day).dropFirst().prefix(2)
            return DatosDashboardVentas.BarraSemanal(label: String(label), value: amount)
        }

        let maxValue = values.map(\.value).max() ?? 0
        return values.map { DatosDashboardVentas.BarraSemanal(label: $0.label, value: $0.value, isHighlighted: $0.value == maxValue && maxValue > 0) }
    }

    private func crearBarrasTendencia() -> [DatosDashboardVentas.BarraTendencia] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "MMM"
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let months = (0..<7).compactMap { calendar.date(byAdding: .month, value: -6 + $0, to: startOfCurrentMonth) }

        return months.map { monthDate in
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) ?? monthDate
            let monthSales = ventas.filter { sale in
                guard let fecha = sale.fechaVenta else { return false }
                return fecha >= monthDate && fecha < nextMonth
            }
            let cash = monthSales.filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.efectivo.rawValue }.reduce(0) { $0 + $1.total }
            let credit = monthSales.filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.credito.rawValue }.reduce(0) { $0 + $1.total }
            let monthLabel = formatter.string(from: monthDate).capitalized
            let compactLabel = String(monthLabel.prefix(1).uppercased())
            return DatosDashboardVentas.BarraTendencia(label: compactLabel, cash: cash, credit: credit)
        }
    }

    private func crearFilasProducto() -> [DatosDashboardVentas.FilaProducto] {
        let groupedSales = Dictionary(grouping: ventas) { $0.producto?.nombre ?? "Producto" }
        let grouped: [DatosDashboardVentas.FilaProducto] = groupedSales.map { key, values in
            let revenue = values.reduce(0) { $0 + $1.total }
            return DatosDashboardVentas.FilaProducto(name: key, revenue: revenue, colorHex: colorHexForProductName(key))
        }
        .sorted { $0.revenue > $1.revenue }

        let totalRevenue = grouped.reduce(0) { $0 + $1.revenue }
        return grouped.prefix(4).map { row in
            let percent = totalRevenue > 0 ? Int(((row.revenue / totalRevenue) * 100).rounded()) : 0
            return DatosDashboardVentas.FilaProducto(name: row.name, revenue: row.revenue, percent: percent, colorHex: row.colorHex)
        }
    }

    private func colorHexForProductName(_ name: String) -> String {
        let palette = ["3B82F6", "8B5CF6", "F59E0B", "22C55E", "EF4444"]
        let index = abs(name.hashValue) % palette.count
        return palette[index]
    }

    private func formatearMoneda(_ amount: Double) -> String {
        String(format: "S/%.0f", amount)
    }

    private func formatLiters(_ amount: Double) -> String {
        if amount == amount.rounded() {
            return "\(Int(amount))L"
        }
        return String(format: "%.1fL", amount)
    }

    private func relativeDateText(from date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0: return "Hoy"
        case 1: return "Ayer"
        default: return "Hace \(days) días"
        }
    }

    private func presentNewSaleFlow() {
        guard RoleAccessControl.canCreateSales else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .createSales))
            return
        }
        performSegue(withIdentifier: "mostrarModalVenta", sender: nil)
    }

    private func solicitarEdicionVenta(_ sale: DatosDashboardVentas.FilaVenta) {
        guard RoleAccessControl.canRequestSaleChanges else { return }
        let alert = UIAlertController(
            title: "Solicitar edición",
            message: "Detalla con precisión qué debe corregirse, por qué y qué impacto operativo tendrá el cambio.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Cambios solicitados"
        }
        alert.addTextField { textField in
            textField.placeholder = "Motivo principal"
        }
        alert.addTextField { textField in
            textField.placeholder = "Impacto operativo o comercial"
        }
        alert.addTextField { textField in
            textField.placeholder = "Referencia adicional (opcional)"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let changes = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reason = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let impact = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reference = alert.textFields?[3].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard changes.isEmpty == false else {
                self.showErrorAlert(message: "Describe los cambios que deseas realizar.")
                return
            }
            guard reason.isEmpty == false else {
                self.showErrorAlert(message: "Ingresa el motivo de la solicitud.")
                return
            }
            guard impact.isEmpty == false else {
                self.showErrorAlert(message: "Describe el impacto operativo o comercial del cambio.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudVenta(
                        type: "edit_sale",
                        sale: sale,
                        reason: reason,
                        extraPayload: [
                            "requestedChanges": .string(changes),
                            "impactoOperativo": .string(impact),
                            "referenciaAdicional": reference.isEmpty ? .null : .string(reference),
                            "detalleSolicitud": .object([
                                "accionSolicitada": .string("editar_venta"),
                                "requiereRevisionStock": .bool(true),
                                "requiereRevisionTesoreria": .bool(true)
                            ])
                        ]
                    )
                    await MainActor.run {
                        self.showSuccessAndDismissAlert(title: "Solicitud enviada", message: "La solicitud de edición fue enviada al panel administrativo.")
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorAlert(message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func solicitarAnulacionVenta(_ sale: DatosDashboardVentas.FilaVenta) {
        guard RoleAccessControl.canRequestSaleChanges else { return }
        let alert = UIAlertController(
            title: "Solicitar anulación",
            message: "La venta no se anulará desde la app. Describe la causa, el contexto y el ajuste esperado.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Motivo principal"
        }
        alert.addTextField { textField in
            textField.placeholder = "Detalle del incidente"
        }
        alert.addTextField { textField in
            textField.placeholder = "Ajuste esperado en stock/caja"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let reason = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let incident = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let expectedAdjustment = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard reason.isEmpty == false else {
                self.showErrorAlert(message: "Ingresa el motivo de la anulación.")
                return
            }
            guard incident.isEmpty == false else {
                self.showErrorAlert(message: "Describe el incidente o la razón operativa.")
                return
            }
            guard expectedAdjustment.isEmpty == false else {
                self.showErrorAlert(message: "Indica qué ajuste esperas en stock o caja.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudVenta(
                        type: "cancel_sale",
                        sale: sale,
                        reason: reason,
                        extraPayload: [
                            "detalleIncidente": .string(incident),
                            "ajusteEsperado": .string(expectedAdjustment),
                            "detalleSolicitud": .object([
                                "accionSolicitada": .string("anular_venta"),
                                "requiereReversionStock": .bool(true),
                                "requiereReversionTesoreria": .bool(true)
                            ])
                        ]
                    )
                    await MainActor.run {
                        self.showSuccessAndDismissAlert(title: "Solicitud enviada", message: "La solicitud de anulación fue enviada al panel administrativo.")
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorAlert(message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func enviarSolicitudVenta(
        type: String,
        sale: DatosDashboardVentas.FilaVenta,
        reason: String,
        extraPayload: [String: JSONValue]
    ) async throws {
        let requester = try AdminRequestService.currentRequester()
        let currentSale = ventaEntity(for: sale.entityId)
        var payload: [String: JSONValue] = [
            "clientName": .string(sale.clientName),
            "productInfo": .string(sale.productInfo),
            "total": .string(sale.total),
            "paymentType": .string(sale.paymentType),
            "dateLabel": .string(sale.date),
            "resumenVenta": .object([
                "cliente": .string(sale.clientName),
                "producto": .string(sale.productInfo),
                "totalTexto": .string(sale.total),
                "tipoPago": .string(sale.paymentType),
                "fechaVisible": .string(sale.date)
            ])
        ]
        if let currentSale {
            payload["estadoActual"] = .string(currentSale.estado ?? "pendiente")
            payload["cantidadLitros"] = .number(currentSale.cantidadLitros)
            payload["precioUnitario"] = .number(currentSale.precioUnitario)
            payload["totalActual"] = .number(currentSale.total)
            payload["metodoPagoActual"] = .string(currentSale.metodoPago ?? "")
            payload["fechaVenta"] = .string(isoFormatter.string(from: currentSale.fechaVenta ?? Date()))
            payload["ventaActual"] = .object([
                "id": .string(currentSale.id?.uuidString ?? sale.entityId),
                "estado": .string(currentSale.estado ?? "pendiente"),
                "cliente": .string(currentSale.cliente?.nombre ?? sale.clientName),
                "producto": .string(currentSale.producto?.nombre ?? sale.productInfo),
                "cantidadLitros": .number(currentSale.cantidadLitros),
                "precioUnitario": .number(currentSale.precioUnitario),
                "total": .number(currentSale.total),
                "metodoPago": .string(currentSale.metodoPago ?? ""),
                "fechaISO": .string(isoFormatter.string(from: currentSale.fechaVenta ?? Date()))
            ])
        }
        payload["solicitadoPorRolOperativo"] = .string(AppSession.shared.rolLogueado ?? "desconocido")
        payload["requiereAprobacionAdmin"] = .bool(true)
        extraPayload.forEach { payload[$0.key] = $0.value }

        let request = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: type,
            module: "ventas",
            status: "pending",
            requestedBy: requester,
            target: .init(entity: "sale", entityId: sale.entityId),
            payload: payload,
            reason: reason,
            createdAt: isoFormatter.string(from: Date()),
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        try await AdminRequestService.submit(request)
    }

    private func ventaEntity(for entityId: String) -> VentaEntity? {
        ventas.first { $0.id?.uuidString == entityId }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "mostrarModalVenta",
              let destination = segue.destination as? ModalNuevaVentaViewController else {
            return
        }

        destination.clientesDisponibles = clientes
        destination.productosDisponibles = productos
        destination.delegate = self
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessAndDismissAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: "legacyEmptyCell")
    }
}

extension VentasViewController: ModalNuevaVentaViewControllerDelegate {
    func modalNuevaVentaViewControllerDidSaveVenta(_ controller: ModalNuevaVentaViewController) {
        cargarDatosCatalogo()
        cargarVentas()
    }
}
