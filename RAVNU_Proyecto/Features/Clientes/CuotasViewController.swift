import CoreData
import SwiftUI
import UIKit

final class CuotasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var analyticsScrollView: UIScrollView?
    @IBOutlet private weak var tblCuotas: UITableView?
    @IBOutlet private weak var btnAnalitica: UIButton?
    @IBOutlet private weak var btnCuotas: UIButton?
    @IBOutlet private weak var btnTodos: UIButton?
    @IBOutlet private weak var btnPendiente: UIButton?
    @IBOutlet private weak var btnVencido: UIButton?
    @IBOutlet private weak var btnPagado: UIButton?
    @IBOutlet private weak var lblVencidoTotal: UILabel?
    @IBOutlet private weak var lblVencidoDetalle: UILabel?
    @IBOutlet private weak var lblPendienteTotal: UILabel?
    @IBOutlet private weak var lblPendienteDetalle: UILabel?
    @IBOutlet private weak var lblHoyTotal: UILabel?
    @IBOutlet private weak var lblHoyDetalle: UILabel?
    @IBOutlet private weak var lblProgreso: UILabel?
    @IBOutlet private weak var lblClientesDeuda: UILabel?
    @IBOutlet private weak var emptyStateView: UIView?

    enum Filter: String, CaseIterable {
        case todos = "Todos"
        case pendiente = "Pendiente"
        case vencido = "Vencido"
        case pagado = "Pagado"
    }

    private var cuotas: [CuotaEntity] = []
    private var filteredCuotas: [CuotaEntity] = []
    private var selectedFilter: Filter = .todos
    private var selectedCuotaID: UUID?
    private var hostingController: UIHostingController<CollectionsDashboardView>?

    private let context = AppCoreData.viewContext

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.currencySymbol = "S/"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureRoleAccess()
        configureHybridView()
        loadCuotas()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCuotas()
    }

    private func configureRoleAccess() {
        let shouldHideCreateActions = RoleAccessControl.canManageCollections == false
        RoleAccessControl.configureButtons(
            in: view,
            target: self,
            selectors: [#selector(btnPagarTapped(_:))],
            hidden: shouldHideCreateActions
        )
    }

    private func configureHybridView() {
        hideLegacyUI()
        let host = UIHostingController(rootView: makeRootView())
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

    private func hideLegacyUI() {
        [
            analyticsScrollView,
            tblCuotas,
            btnAnalitica,
            btnCuotas,
            btnTodos,
            btnPendiente,
            btnVencido,
            btnPagado,
            lblVencidoTotal,
            lblVencidoDetalle,
            lblPendienteTotal,
            lblPendienteDetalle,
            lblHoyTotal,
            lblHoyDetalle,
            lblProgreso,
            lblClientesDeuda,
            emptyStateView
        ].forEach { $0?.isHidden = true }
        tblCuotas?.dataSource = self
        tblCuotas?.delegate = self
    }

    private func loadCuotas() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]

        do {
            cuotas = try context.fetch(request)
            applyFilter()
            refreshHybridView()
        } catch {
            cuotas = []
            filteredCuotas = []
            refreshHybridView()
        }
    }

    private func applyFilter() {
        let today = Calendar.current.startOfDay(for: Date())
        switch selectedFilter {
        case .todos:
            filteredCuotas = cuotas
        case .pendiente:
            filteredCuotas = cuotas.filter { !$0.pagada && !isVencida($0) }
        case .vencido:
            filteredCuotas = cuotas.filter { cuota in
                guard !cuota.pagada, let fecha = cuota.fechaVencimiento else { return false }
                return Calendar.current.startOfDay(for: fecha) < today
            }
        case .pagado:
            filteredCuotas = cuotas.filter(\.pagada)
        }
    }

    private func refreshHybridView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> CollectionsDashboardView {
        CollectionsDashboardView(
            data: makeDashboardData(),
            onBack: { [weak self] in self?.dismiss(animated: true) },
            onOpenPayment: { [weak self] cuotaID in
                self?.selectedCuotaID = cuotaID
                self?.performSegue(withIdentifier: "mostrarModalCuota", sender: nil)
            },
            onOpenGenericPayment: { [weak self] in
                self?.selectedCuotaID = nil
                self?.performSegue(withIdentifier: "mostrarModalCuota", sender: nil)
            },
            onSelectFilter: { [weak self] filter in
                self?.selectedFilter = filter
                self?.applyFilter()
                self?.refreshHybridView()
            }
        )
    }

    private func makeDashboardData() -> CollectionsDashboardData {
        let today = Calendar.current.startOfDay(for: Date())
        let pendientes = cuotas.filter { !$0.pagada }
        let vencidas = pendientes.filter {
            guard let fecha = $0.fechaVencimiento else { return false }
            return Calendar.current.startOfDay(for: fecha) < today
        }
        let pendientesNoVencidas = pendientes.filter {
            guard let fecha = $0.fechaVencimiento else { return false }
            return Calendar.current.startOfDay(for: fecha) >= today
        }
        let pagadasHoy = cuotas.filter {
            guard $0.pagada, let fecha = $0.fechaPago else { return false }
            return Calendar.current.isDateInToday(fecha)
        }

        let overdueAmount = vencidas.reduce(0.0) { $0 + $1.monto }
        let pendingAmount = pendientesNoVencidas.reduce(0.0) { $0 + $1.monto }
        let paidTodayAmount = pagadasHoy.reduce(0.0) { $0 + $1.monto }

        let currentMonthCuotas = cuotas.filter {
            guard let dueDate = $0.fechaVencimiento else { return false }
            return Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .month)
        }
        let currentMonthTotal = currentMonthCuotas.reduce(0.0) { $0 + $1.monto }
        let currentMonthPaid = currentMonthCuotas.filter(\.pagada).reduce(0.0) { $0 + $1.monto }
        let collectionProgress = currentMonthTotal > 0 ? currentMonthPaid / currentMonthTotal : 0

        let debtRows = buildDebtRows()
        let cuotaRows = filteredCuotas.map { cuota in
            let totalCuotas = max(cuota.venta?.cuotas?.count ?? Int(cuota.numero), Int(cuota.numero))
            let status = cuota.pagada ? CollectionsDashboardData.CuotaRow.Status.pagado : (isVencida(cuota) ? .vencido : .pendiente)
            return CollectionsDashboardData.CuotaRow(
                id: cuota.id?.uuidString ?? UUID().uuidString,
                clientName: cuota.venta?.cliente?.nombre ?? "Cliente",
                installmentText: "Cuota \(cuota.numero) de \(totalCuotas)",
                amountText: formatCurrency(cuota.monto),
                dueText: "Vence \(formatDate(cuota.fechaVencimiento))",
                progressText: "\(min(Int(cuota.numero), totalCuotas))/\(totalCuotas)",
                progressValue: totalCuotas > 0 ? Double(cuota.numero) / Double(totalCuotas) : 0,
                status: status
            )
        }

        return CollectionsDashboardData(
            overdueMetric: .init(title: "VENCIDO", value: formatCurrency(overdueAmount), detail: "\(vencidas.count) cuota\(vencidas.count == 1 ? "" : "s")", accentHex: "EF4444"),
            pendingMetric: .init(title: "PENDIENTE", value: formatCurrency(pendingAmount), detail: "\(pendientesNoVencidas.count) cuota\(pendientesNoVencidas.count == 1 ? "" : "s")", accentHex: "F59E0B"),
            todayMetric: .init(title: "HOY", value: formatCurrency(paidTodayAmount), detail: "cobrado", accentHex: "22C55E"),
            progressText: "\(Int((collectionProgress * 100).rounded()))%",
            progressSlices: [
                .init(label: "Vencido", valueText: formatCurrency(overdueAmount), accentHex: "EF4444", share: currentMonthTotal > 0 ? overdueAmount / currentMonthTotal : 0),
                .init(label: "Pendiente", valueText: formatCurrency(pendingAmount), accentHex: "F59E0B", share: currentMonthTotal > 0 ? pendingAmount / currentMonthTotal : 0),
                .init(label: "Cobrado", valueText: formatCurrency(currentMonthPaid), accentHex: "4CCB63", share: currentMonthTotal > 0 ? currentMonthPaid / currentMonthTotal : 0)
            ],
            alertText: vencidas.isEmpty ? nil : "\(vencidas.count) cuota vencida\(vencidas.count == 1 ? "" : "s") — contacta a los clientes de inmediato para evitar más retrasos.",
            debtRows: debtRows,
            cuotaRows: cuotaRows,
            selectedFilter: selectedFilter,
            canPay: RoleAccessControl.canManageCollections
        )
    }

    private func buildDebtRows() -> [CollectionsDashboardData.DebtRow] {
        let grouped = Dictionary(grouping: cuotas.filter { !$0.pagada }) { $0.venta?.cliente }
        return grouped.compactMap { cliente, cuotas in
            guard let cliente else { return nil }
            let debt = cuotas.reduce(0.0) { $0 + $1.monto }
            let limit = max(cliente.limiteCredito, 1)
            let usage = min(max(debt / limit, 0), 1)
            let status: CollectionsDashboardData.DebtRow.Status = debt >= limit * 0.6 ? .vencido : .enRiesgo
            return CollectionsDashboardData.DebtRow(
                id: cliente.id?.uuidString ?? UUID().uuidString,
                name: cliente.nombre ?? "Cliente",
                amountText: formatCurrency(debt),
                detailText: "\(Int((usage * 100).rounded()))% del límite \(formatCurrency(limit))",
                status: status,
                progressValue: usage
            )
        }
        .sorted { currencyValue($0.amountText) > currencyValue($1.amountText) }
    }

    private func currencyValue(_ text: String) -> Double {
        let sanitized = text.replacingOccurrences(of: "S/", with: "").replacingOccurrences(of: ",", with: "")
        return Double(sanitized.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func isVencida(_ cuota: CuotaEntity) -> Bool {
        guard !cuota.pagada, let fecha = cuota.fechaVencimiento else { return false }
        return Calendar.current.startOfDay(for: fecha) < Calendar.current.startOfDay(for: Date())
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    @IBAction private func btnVolverTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnPagarTapped(_ sender: UIButton) {
        guard RoleAccessControl.canManageCollections else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .manageCollections))
            return
        }
        selectedCuotaID = nil
        performSegue(withIdentifier: "mostrarModalCuota", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let modalCuota = segue.destination as? ModalCuotaViewController {
            modalCuota.delegate = self
            modalCuota.preferredCuotaID = selectedCuotaID
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredCuotas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: "CuotaLegacyCell")
    }
}

extension CuotasViewController: ModalCuotaViewControllerDelegate {
    func modalCuotaViewControllerDidSavePago(_ controller: ModalCuotaViewController) {
        loadCuotas()
    }
}
