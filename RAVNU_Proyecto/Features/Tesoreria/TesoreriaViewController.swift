import CoreData
import SwiftUI
import UIKit

final class TesoreriaViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var btnResumen: UIButton?
    @IBOutlet private weak var btnTransacciones: UIButton?
    @IBOutlet private weak var resumenScrollView: UIScrollView?
    @IBOutlet private weak var transaccionesView: UIView?
    @IBOutlet private weak var tableView: UITableView?
    @IBOutlet private weak var lblSaldo: UILabel?
    @IBOutlet private weak var lblMargen: UILabel?
    @IBOutlet private weak var lblIngresos: UILabel?
    @IBOutlet private weak var lblGastos: UILabel?
    @IBOutlet private weak var lblTendencia: UILabel?
    @IBOutlet private weak var lblIngresosGastos: UILabel?
    @IBOutlet private weak var lblDesglose: UILabel?

    private enum TransactionKind {
        case ingreso
        case gasto

        var accentHex: String {
            switch self {
            case .ingreso: return "4CCB63"
            case .gasto: return "FF5C5C"
            }
        }

        var sign: String {
            switch self {
            case .ingreso: return "+"
            case .gasto: return "-"
            }
        }
    }

    private struct TreasuryTransaction {
        let id: String
        let title: String
        let subtitle: String
        let amount: Double
        let date: Date
        let kind: TransactionKind
    }

    private struct TreasuryMonthSummary {
        let monthLabel: String
        let income: Double
        let expense: Double

        var net: Double { income - expense }
    }

    private var hostingController: UIHostingController<TreasuryDashboardView>?
    private var transactions: [TreasuryTransaction] = []
    private var monthlySummaries: [TreasuryMonthSummary] = []
    private var totalIncome: Double = 0
    private var totalExpense: Double = 0

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
        loadTreasuryData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadTreasuryData()
    }

    private func configureRoleAccess() {
        let shouldHideCreateActions = RoleAccessControl.canAddTreasuryAdjustments == false
        RoleAccessControl.configureButtons(
            in: view,
            target: self,
            selectors: [#selector(btnAgregarTapped(_:))],
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
            btnResumen,
            btnTransacciones,
            resumenScrollView,
            transaccionesView,
            tableView,
            lblSaldo,
            lblMargen,
            lblIngresos,
            lblGastos,
            lblTendencia,
            lblIngresosGastos,
            lblDesglose
        ].forEach { $0?.isHidden = true }
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    private func refreshHybridView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> TreasuryDashboardView {
        TreasuryDashboardView(
            data: makeDashboardData(),
            onBack: { [weak self] in self?.dismiss(animated: true) },
            onAdd: { [weak self] in self?.presentTreasuryInfoAlert() }
        )
    }

    private func loadTreasuryData() {
        do {
            let ventas = try fetchVentas()
            let cuotas = try fetchCuotasPagadas()
            let ordenes = try fetchOrdenesCompra()

            transactions = buildTransactions(ventas: ventas, cuotas: cuotas, ordenes: ordenes)
            totalIncome = transactions.filter { $0.kind == .ingreso }.reduce(0) { $0 + $1.amount }
            totalExpense = transactions.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amount }
            monthlySummaries = buildMonthlySummaries(from: transactions)
            refreshHybridView()
        } catch {
            transactions = []
            totalIncome = 0
            totalExpense = 0
            monthlySummaries = []
            refreshHybridView()
        }
    }

    private func makeDashboardData() -> TreasuryDashboardData {
        let balance = totalIncome - totalExpense
        let margin = totalIncome == 0 ? 0 : Int(((balance / totalIncome) * 100).rounded())

        let trendValues = monthlySummaries.map(\.net)
        let bars = monthlySummaries.map {
            TreasuryDashboardData.MonthBar(
                monthLabel: $0.monthLabel,
                incomeValue: $0.income,
                expenseValue: $0.expense
            )
        }

        let expenseRows = expenseBreakdownRows()
        let transactionRows = transactions.map {
            TreasuryDashboardData.TransactionRow(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                amountText: "\($0.kind.sign)\(formatCurrency($0.amount))",
                dateText: relativeDateText(from: $0.date),
                date: $0.date,
                accentHex: $0.kind.accentHex,
                isIncome: $0.kind == .ingreso
            )
        }

        return TreasuryDashboardData(
            balanceText: formatCurrency(balance),
            marginText: totalIncome == 0 ? "Sin movimientos este mes" : "\(margin)% margen neto este mes",
            incomeText: formatCurrency(totalIncome),
            expenseText: formatCurrency(totalExpense),
            trendValues: trendValues,
            monthBars: bars,
            expenseBreakdown: expenseRows,
            transactions: transactionRows,
            canAdd: RoleAccessControl.canAddTreasuryAdjustments
        )
    }

    private func fetchVentas() throws -> [VentaEntity] {
        let request: NSFetchRequest<VentaEntity> = VentaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVenta", ascending: false)]
        return try context.fetch(request)
    }

    private func fetchCuotasPagadas() throws -> [CuotaEntity] {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "pagada == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "fechaPago", ascending: false)]
        return try context.fetch(request)
    }

    private func fetchOrdenesCompra() throws -> [OrdenCompraEntity] {
        let request: NSFetchRequest<OrdenCompraEntity> = OrdenCompraEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        return try context.fetch(request)
    }

    private func buildTransactions(
        ventas: [VentaEntity],
        cuotas: [CuotaEntity],
        ordenes: [OrdenCompraEntity]
    ) -> [TreasuryTransaction] {
        let sales = ventas.compactMap { venta -> TreasuryTransaction? in
            guard let date = venta.fechaVenta else { return nil }
            return TreasuryTransaction(
                id: venta.id?.uuidString ?? UUID().uuidString,
                title: "\(venta.producto?.nombre ?? "Venta") sale",
                subtitle: venta.cliente?.nombre ?? "Cliente",
                amount: venta.total,
                date: date,
                kind: .ingreso
            )
        }

        let installments = cuotas.compactMap { cuota -> TreasuryTransaction? in
            guard let date = cuota.fechaPago else { return nil }
            let clientName = cuota.venta?.cliente?.nombre ?? "Cliente"
            return TreasuryTransaction(
                id: cuota.id?.uuidString ?? UUID().uuidString,
                title: "Installment - \(clientName)",
                subtitle: cuota.venta?.producto?.nombre ?? "Cobro de cuota",
                amount: cuota.monto,
                date: date,
                kind: .ingreso
            )
        }

        let purchases = ordenes.compactMap { orden -> TreasuryTransaction? in
            guard let date = orden.fecha, orden.total > 0 else { return nil }
            return TreasuryTransaction(
                id: orden.id?.uuidString ?? UUID().uuidString,
                title: "\(orden.producto?.nombre ?? "Purchase") purchase",
                subtitle: orden.proveedor?.nombre ?? orden.almacen?.nombre ?? "Proveedor",
                amount: orden.total,
                date: date,
                kind: .gasto
            )
        }

        return (sales + installments + purchases).sorted { $0.date > $1.date }
    }

    private func buildMonthlySummaries(from transactions: [TreasuryTransaction]) -> [TreasuryMonthSummary] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"

        let anchors = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .month, value: -(6 - offset), to: Date())
        }

        return anchors.map { anchor in
            let monthTransactions = transactions.filter { transaction in
                calendar.isDate(transaction.date, equalTo: anchor, toGranularity: .month)
                    && calendar.isDate(transaction.date, equalTo: anchor, toGranularity: .year)
            }

            let income = monthTransactions.filter { $0.kind == .ingreso }.reduce(0) { $0 + $1.amount }
            let expense = monthTransactions.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amount }

            return TreasuryMonthSummary(
                monthLabel: formatter.string(from: anchor),
                income: income,
                expense: expense
            )
        }
    }

    private func expenseBreakdownRows() -> [TreasuryDashboardData.ExpenseRow] {
        let purchaseRequest: NSFetchRequest<OrdenCompraEntity> = OrdenCompraEntity.fetchRequest()
        let purchases = (try? context.fetch(purchaseRequest)) ?? []
        let grouped = Dictionary(grouping: purchases) { order in
            order.producto?.nombre ?? "Operating"
        }

        let total = purchases.reduce(0.0) { $0 + $1.total }
        let sorted = grouped.map { key, orders in
            (name: key, total: orders.reduce(0.0) { $0 + $1.total })
        }.sorted { $0.total > $1.total }

        return sorted.prefix(4).enumerated().map { index, item in
            TreasuryDashboardData.ExpenseRow(
                name: item.name,
                percentText: total > 0 ? "\(Int(((item.total / total) * 100).rounded()))%" : "0%",
                accentHex: expenseColor(at: index),
                share: total > 0 ? item.total / total : 0
            )
        }
    }

    private func expenseColor(at index: Int) -> String {
        let palette = ["F5B13A", "8B5CF6", "4F86F7", "52C783"]
        return palette[index % palette.count]
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func relativeDateText(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func presentTreasuryInfoAlert() {
        let alert = UIAlertController(
            title: "Tesorería",
            message: "Los movimientos de tesorería se generan desde Ventas, Cobros y Compras. No hay alta manual directa en este módulo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func btnVolverTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnAgregarTapped(_ sender: UIButton) {
        guard RoleAccessControl.canAddTreasuryAdjustments else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .addTreasuryAdjustments))
            return
        }
        presentTreasuryInfoAlert()
    }

    @IBAction private func btnResumenTapped(_ sender: UIButton) {
        refreshHybridView()
    }

    @IBAction private func btnTransaccionesTapped(_ sender: UIButton) {
        refreshHybridView()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: "TreasuryLegacyCell")
    }
}

private struct TreasuryDashboardData {
    struct MonthBar: Identifiable {
        let id = UUID()
        let monthLabel: String
        let incomeValue: Double
        let expenseValue: Double
    }

    struct ExpenseRow: Identifiable {
        let id = UUID()
        let name: String
        let percentText: String
        let accentHex: String
        let share: Double
    }

    struct TransactionRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let amountText: String
        let dateText: String
        let date: Date
        let accentHex: String
        let isIncome: Bool
    }

    let balanceText: String
    let marginText: String
    let incomeText: String
    let expenseText: String
    let trendValues: [Double]
    let monthBars: [MonthBar]
    let expenseBreakdown: [ExpenseRow]
    let transactions: [TransactionRow]
    let canAdd: Bool
}

private struct TreasuryDashboardView: View {
    enum Tab {
        case resumen
        case transacciones
    }

    enum PeriodFilter: String, CaseIterable {
        case hoy = "Hoy"
        case semana = "Semana"
        case mes = "Mes"
    }

    let data: TreasuryDashboardData
    let onBack: () -> Void
    let onAdd: () -> Void

    @State private var selectedTab: Tab = .resumen
    @State private var selectedFilter: PeriodFilter = .semana

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    segmentedTabs

                    if selectedTab == .resumen {
                        summaryTab
                    } else {
                        transactionsTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(symbol: "chevron.left", action: onBack)
            Spacer()
            Text("Tesorería")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1E293B"))
            Spacer()
            if data.canAdd {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Agregar")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color(hex: "4CCB63"))
                    .clipShape(Capsule())
                }
            } else {
                Color.clear.frame(width: 76, height: 34)
            }
        }
    }

    private var segmentedTabs: some View {
        HStack(spacing: 8) {
            TreasuryTabButton(title: "Resumen", icon: "chart.bar", isActive: selectedTab == .resumen) {
                selectedTab = .resumen
            }
            TreasuryTabButton(title: "Transacciones", icon: nil, isActive: selectedTab == .transacciones) {
                selectedTab = .transacciones
            }
        }
        .padding(6)
        .background(Color(hex: "E5E7EB"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryTab: some View {
        VStack(spacing: 16) {
            balanceCard
            TreasuryCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("Tendencia de Saldo")
                    TreasuryLineChart(values: data.trendValues)
                        .frame(height: 120)
                }
            }
            TreasuryCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("Ingresos vs Gastos")
                    TreasuryBarsChart(items: data.monthBars)
                        .frame(height: 180)
                }
            }
            TreasuryCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("Desglose de Gastos")
                    HStack(spacing: 20) {
                        TreasuryDonutChart(items: data.expenseBreakdown)
                            .frame(width: 118, height: 118)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(data.expenseBreakdown) { row in
                                ExpenseBreakdownRow(row: row)
                            }
                        }
                    }
                }
            }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SALDO ACTUAL")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(data.balanceText)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(data.marginText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 12) {
                miniMetric(title: "Ingresos", value: data.incomeText)
                miniMetric(title: "Gastos", value: data.expenseText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "46B862"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
    }

    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var transactionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(PeriodFilter.allCases, id: \.rawValue) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedFilter == filter ? .white : Color(hex: "64748B"))
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(selectedFilter == filter ? Color(hex: "4F83F6") : .white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(filteredTransactions) { row in
                TreasuryTransactionCard(row: row)
            }
        }
    }

    private var filteredTransactions: [TreasuryDashboardData.TransactionRow] {
        let calendar = Calendar.current
        return data.transactions.filter { row in
            switch selectedFilter {
            case .hoy:
                return calendar.isDateInToday(row.date)
            case .semana:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return true }
                return row.date >= weekAgo
            case .mes:
                return calendar.isDate(row.date, equalTo: Date(), toGranularity: .month)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "1F2937"))
    }
}

private struct TreasuryCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

private struct TreasuryTabButton: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isActive ? Color(hex: "1F2937") : Color(hex: "6B7280"))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(isActive ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct CircleIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "475569"))
                .frame(width: 40, height: 40)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct TreasuryLineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(hex: "4CCB63").opacity(0.18), Color(hex: "4CCB63").opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(AreaPathShape(points: points))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(Color(hex: "4CCB63"), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                HStack {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, _ in
                        Text(monthLabel(for: index))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "94A3B8"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, proxy.size.height - 18)
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.isEmpty == false else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * size.width
            let y = size.height - 28 - ((CGFloat(value - minValue) / CGFloat(range)) * (size.height - 48))
            return CGPoint(x: x, y: y)
        }
    }

    private func monthLabel(for index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        guard let date = Calendar.current.date(byAdding: .month, value: -(6 - index), to: Date()) else {
            return ""
        }
        return formatter.string(from: date)
    }
}

private struct AreaPathShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: rect.height))
        path.addLine(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.addLine(to: CGPoint(x: last.x, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct TreasuryBarsChart: View {
    let items: [TreasuryDashboardData.MonthBar]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(items.flatMap { [$0.incomeValue, $0.expenseValue] }.max() ?? 1, 1)
            VStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(items) { item in
                        VStack(spacing: 10) {
                            Spacer()
                            HStack(alignment: .bottom, spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "78D884"))
                                    .frame(width: 14, height: max(10, (item.incomeValue / maxValue) * (proxy.size.height - 70)))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "F57B7B"))
                                    .frame(width: 14, height: max(10, (item.expenseValue / maxValue) * (proxy.size.height - 70)))
                            }
                            Text(item.monthLabel)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "94A3B8"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                legend
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(color: Color(hex: "78D884"), title: "Ingresos")
            legendItem(color: Color(hex: "F57B7B"), title: "Gastos")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "94A3B8"))
        }
    }
}

private struct TreasuryDonutChart: View {
    let items: [TreasuryDashboardData.ExpenseRow]

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                DonutSegment(
                    startFraction: startFraction(for: index),
                    endFraction: endFraction(for: index),
                    color: Color(hex: item.accentHex)
                )
            }
        }
    }

    private func startFraction(for index: Int) -> Double {
        items.prefix(index).reduce(0.0) { $0 + $1.share }
    }

    private func endFraction(for index: Int) -> Double {
        items.prefix(index + 1).reduce(0.0) { $0 + $1.share }
    }
}

private struct DonutSegment: View {
    let startFraction: Double
    let endFraction: Double
    let color: Color

    var body: some View {
        Circle()
            .trim(from: startFraction, to: endFraction)
            .stroke(color, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

private struct ExpenseBreakdownRow: View {
    let row: TreasuryDashboardData.ExpenseRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: row.accentHex))
                        .frame(width: 10, height: 10)
                    Text(row.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "475569"))
                }
                Spacer()
                Text(row.percentText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "334155"))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E5E7EB"))
                    Capsule()
                        .fill(Color(hex: row.accentHex))
                        .frame(width: proxy.size.width * row.share)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct TreasuryTransactionCard: View {
    let row: TreasuryDashboardData.TransactionRow

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: row.accentHex))
                .frame(height: 3)

            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: row.isIncome ? "ECFDF3" : "FEF2F2"))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: row.isIncome ? "arrow.down" : "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: row.accentHex))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "1F2937"))
                    Text(row.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(row.amountText)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: row.accentHex))
                    Text(row.dateText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
            }
            .padding(18)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.07), radius: 10, y: 4)
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
