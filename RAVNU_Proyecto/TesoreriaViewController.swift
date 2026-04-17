import CoreData
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

    private enum Tab {
        case resumen
        case transacciones
    }

    private enum TransactionKind {
        case ingreso
        case gasto

        var color: UIColor {
            switch self {
            case .ingreso:
                return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
            case .gasto:
                return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
            }
        }

        var sign: String {
            switch self {
            case .ingreso:
                return "+"
            case .gasto:
                return "-"
            }
        }
    }

    private struct TreasuryTransaction {
        let title: String
        let subtitle: String
        let amount: Double
        let date: Date
        let kind: TransactionKind
    }

    private let cellIdentifier = "tesoreriaTransactionCell"
    private var transactions: [TreasuryTransaction] = []
    private var currentTab: Tab = .resumen

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

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
        configureUI()
        loadTreasuryData()
        showResumen()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadTreasuryData()
    }

    private func configureUI() {
        tableView?.register(TesoreriaTransactionCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.rowHeight = 96
        tableView?.estimatedRowHeight = 96
        tableView?.separatorStyle = .none
        tableView?.backgroundColor = .clear
        tableView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView?.showsVerticalScrollIndicator = false

        resumenScrollView?.showsVerticalScrollIndicator = false

        [lblSaldo, lblMargen, lblIngresos, lblGastos, lblTendencia, lblIngresosGastos, lblDesglose].forEach {
            $0?.adjustsFontSizeToFitWidth = true
            $0?.minimumScaleFactor = 0.72
        }
    }

    private func loadTreasuryData() {
        do {
            let ventas = try fetchVentas()
            let cuotas = try fetchCuotasPagadas()
            let ordenes = try fetchOrdenesCompra()

            transactions = buildTransactions(ventas: ventas, cuotas: cuotas, ordenes: ordenes)
            updateSummary()
            tableView?.reloadData()
        } catch {
            transactions = []
            updateSummary()
            tableView?.reloadData()
        }
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
        let ventasTransactions = ventas.compactMap { venta -> TreasuryTransaction? in
            guard let date = venta.fechaVenta else { return nil }
            return TreasuryTransaction(
                title: venta.producto?.nombre ?? "Venta",
                subtitle: venta.cliente?.nombre ?? "Cliente",
                amount: venta.total,
                date: date,
                kind: .ingreso
            )
        }

        let cuotasTransactions = cuotas.compactMap { cuota -> TreasuryTransaction? in
            guard let date = cuota.fechaPago else { return nil }
            return TreasuryTransaction(
                title: "Cuota - \(cuota.venta?.cliente?.nombre ?? "Cliente")",
                subtitle: "Cobro de cuota \(cuota.numero)",
                amount: cuota.monto,
                date: date,
                kind: .ingreso
            )
        }

        let compraTransactions = ordenes.compactMap { orden -> TreasuryTransaction? in
            guard let date = orden.fecha, orden.total > 0 else { return nil }
            return TreasuryTransaction(
                title: orden.producto?.nombre ?? "Orden de compra",
                subtitle: orden.proveedor?.nombre ?? orden.almacen?.nombre ?? "Proveedor",
                amount: orden.total,
                date: date,
                kind: .gasto
            )
        }

        return (ventasTransactions + cuotasTransactions + compraTransactions)
            .sorted { $0.date > $1.date }
    }

    private func updateSummary() {
        let ingresos = transactions
            .filter { $0.kind == .ingreso }
            .reduce(0.0) { $0 + $1.amount }
        let gastos = transactions
            .filter { $0.kind == .gasto }
            .reduce(0.0) { $0 + $1.amount }
        let saldo = ingresos - gastos
        let margen = ingresos == 0 ? 0 : Int(((saldo / ingresos) * 100).rounded())

        lblSaldo?.text = formatCurrency(saldo)
        lblMargen?.text = ingresos == 0 ? "Sin movimientos registrados" : "\(margen)% margen neto"
        lblIngresos?.text = formatCurrency(ingresos)
        lblGastos?.text = formatCurrency(gastos)

        let monthly = groupedByMonth(transactions)
        lblTendencia?.text = monthly.isEmpty ? "Sin tendencia disponible" : "Saldo neto por mes actualizado"
        lblIngresosGastos?.text = transactions.isEmpty ? "Sin ingresos ni gastos" : "\(transactions.count) transacción(es) registradas"
        lblDesglose?.text = gastos == 0
            ? "Sin gastos registrados"
            : "Compras y gastos: \(formatCurrency(gastos))"
    }

    private func groupedByMonth(_ transactions: [TreasuryTransaction]) -> [String: Double] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "MMM"

        return transactions.reduce(into: [:]) { result, transaction in
            let key = formatter.string(from: transaction.date)
            let signedAmount = transaction.kind == .ingreso ? transaction.amount : -transaction.amount
            result[key, default: 0] += signedAmount
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Hoy"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Ayer"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private func updateTabStyle() {
        styleTab(btnResumen, active: currentTab == .resumen)
        styleTab(btnTransacciones, active: currentTab == .transacciones)
    }

    private func styleTab(_ button: UIButton?, active: Bool) {
        guard var config = button?.configuration else { return }
        config.baseForegroundColor = active
            ? UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
            : UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
        config.background.backgroundColor = active ? .white : .clear
        button?.configuration = config
    }

    private func showResumen() {
        currentTab = .resumen
        resumenScrollView?.isHidden = false
        transaccionesView?.isHidden = true
        updateTabStyle()
    }

    private func showTransacciones() {
        currentTab = .transacciones
        resumenScrollView?.isHidden = true
        transaccionesView?.isHidden = false
        updateTabStyle()
    }

    @IBAction private func btnVolverTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnAgregarTapped(_ sender: UIButton) {
        showTransacciones()
    }

    @IBAction private func btnResumenTapped(_ sender: UIButton) {
        showResumen()
    }

    @IBAction private func btnTransaccionesTapped(_ sender: UIButton) {
        showTransacciones()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        guard let transactionCell = cell as? TesoreriaTransactionCell else { return cell }
        let transaction = transactions[indexPath.row]
        transactionCell.configure(
            title: transaction.title,
            subtitle: transaction.subtitle,
            amount: "\(transaction.kind.sign)\(formatCurrency(transaction.amount))",
            date: formatDate(transaction.date),
            color: transaction.kind.color
        )
        return transactionCell
    }
}

private final class TesoreriaTransactionCell: UITableViewCell {

    private let cardView = UIView()
    private let accentLine = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()
    private let dateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }

    private func configureUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        [cardView, accentLine, titleLabel, subtitleLabel, amountLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.07
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.addSubview(cardView)

        accentLine.layer.cornerRadius = 1.5
        accentLine.clipsToBounds = true

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)

        amountLabel.font = .systemFont(ofSize: 15, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.72

        dateLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        dateLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
        dateLabel.textAlignment = .right

        [accentLine, titleLabel, subtitleLabel, amountLabel, dateLabel].forEach {
            cardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            accentLine.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            accentLine.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            accentLine.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            accentLine.heightAnchor.constraint(equalToConstant: 3),

            titleLabel.topAnchor.constraint(equalTo: accentLine.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -12),

            amountLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            amountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),

            dateLabel.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: amountLabel.trailingAnchor),
            dateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    }

    func configure(title: String, subtitle: String, amount: String, date: String, color: UIColor) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        amountLabel.text = amount
        amountLabel.textColor = color
        dateLabel.text = date
        accentLine.backgroundColor = color
    }
}
