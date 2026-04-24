import CoreData
import UIKit

final class ComprasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet private weak var btnProveedores: UIButton?
    @IBOutlet private weak var btnOrdenes: UIButton?
    @IBOutlet private weak var btnAnalisis: UIButton?
    @IBOutlet private weak var proveedoresView: UIView?
    @IBOutlet private weak var ordenesView: UIView?
    @IBOutlet private weak var analisisScrollView: UIScrollView?
    @IBOutlet private weak var proveedoresTableView: UITableView?
    @IBOutlet private weak var ordenesTableView: UITableView?
    @IBOutlet private weak var proveedoresSearchBar: UISearchBar?
    @IBOutlet private weak var proveedoresEmptyLabel: UILabel?
    @IBOutlet private weak var lblPendientesBadge: UILabel?
    @IBOutlet private weak var lblGastoTotal: UILabel?
    @IBOutlet private weak var lblPendientes: UILabel?
    @IBOutlet private weak var lblRecibidas: UILabel?
    @IBOutlet private weak var lblAnalisisGasto: UILabel?
    @IBOutlet private weak var lblAnalisisVolumen: UILabel?
    @IBOutlet private weak var lblAnalisisProveedores: UILabel?
    @IBOutlet private weak var lblRanking: UILabel?
    @IBOutlet private weak var lblGastoProducto: UILabel?
    @IBOutlet private weak var lblPorProducto: UILabel?

    private enum Tab {
        case proveedores
        case ordenes
        case analisis
    }

    private let proveedorCellIdentifier = "proveedorCompraCell"
    private let ordenCellIdentifier = "ordenCompraCell"
    private let primaryColor = UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
    private let inactiveColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
    private var currentTab: Tab = .ordenes
    private var proveedores: [ProveedorEntity] = []
    private var proveedoresFiltrados: [ProveedorEntity] = []
    private var ordenes: [OrdenCompraEntity] = []

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
        configureRoleAccess()
        loadData()
        showOrdenes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func configureUI() {
        configureTable(proveedoresTableView, identifier: proveedorCellIdentifier)
        configureTable(ordenesTableView, identifier: ordenCellIdentifier)
        proveedoresSearchBar?.delegate = self
        proveedoresSearchBar?.searchTextField.backgroundColor = .white
        proveedoresSearchBar?.searchTextField.layer.cornerRadius = 12
        proveedoresSearchBar?.searchTextField.clipsToBounds = true
        proveedoresSearchBar?.placeholder = "Buscar proveedor"
        analisisScrollView?.showsVerticalScrollIndicator = false

        [
            lblPendientesBadge,
            lblGastoTotal,
            lblPendientes,
            lblRecibidas,
            lblAnalisisGasto,
            lblAnalisisVolumen,
            lblAnalisisProveedores,
            lblRanking,
            lblGastoProducto,
            lblPorProducto,
            proveedoresEmptyLabel
        ].forEach {
            $0?.adjustsFontSizeToFitWidth = true
            $0?.minimumScaleFactor = 0.72
        }
    }

    private func configureTable(_ tableView: UITableView?, identifier: String) {
        tableView?.register(CompraCardCell.self, forCellReuseIdentifier: identifier)
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.rowHeight = 142
        tableView?.estimatedRowHeight = 142
        tableView?.separatorStyle = .none
        tableView?.backgroundColor = .clear
        tableView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 96, right: 0)
        tableView?.showsVerticalScrollIndicator = false
    }

    private func configureRoleAccess() {
        let shouldHideCreateActions = RoleAccessControl.isAdmin == false
        RoleAccessControl.configureButtons(
            in: view,
            target: self,
            selectors: [#selector(btnNuevaOrdenTapped(_:))],
            hidden: shouldHideCreateActions
        )
    }

    private func loadData() {
        do {
            proveedores = try fetchProveedores()
            ordenes = try fetchOrdenes()
            applyProviderFilter()
            updateMetrics()
            proveedoresTableView?.reloadData()
            ordenesTableView?.reloadData()
        } catch {
            proveedores = []
            proveedoresFiltrados = []
            ordenes = []
            updateProviderEmptyState()
            updateMetrics()
        }
    }

    private func fetchProveedores() throws -> [ProveedorEntity] {
        let request: NSFetchRequest<ProveedorEntity> = ProveedorEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return try context.fetch(request)
    }

    private func fetchOrdenes() throws -> [OrdenCompraEntity] {
        let request: NSFetchRequest<OrdenCompraEntity> = OrdenCompraEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        return try context.fetch(request)
    }

    private func updateMetrics() {
        let total = ordenes.reduce(0.0) { $0 + $1.total }
        let pendientes = ordenes.filter { ($0.estado ?? "").lowercased().contains("pend") }
        let recibidas = ordenes.filter { ($0.estado ?? "").lowercased().contains("recib") || ($0.estado ?? "").lowercased().contains("complet") }
        let volumen = ordenes.reduce(0.0) { $0 + $1.cantidadLitros }

        lblPendientesBadge?.text = pendientes.isEmpty ? "Sin pendientes" : "\(pendientes.count) pendiente"
        lblGastoTotal?.text = formatCurrency(total)
        lblPendientes?.text = "\(pendientes.count)"
        lblRecibidas?.text = "\(recibidas.count)"
        lblAnalisisGasto?.text = formatCurrency(total)
        lblAnalisisVolumen?.text = "\(Int(volumen.rounded()).formatted())L"
        lblAnalisisProveedores?.text = "\(proveedores.count)"
        lblRanking?.text = rankingDescription()
        lblGastoProducto?.text = productExpenseDescription()
        lblPorProducto?.text = productVolumeDescription()
    }

    private func applyProviderFilter() {
        let text = proveedoresSearchBar?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            proveedoresFiltrados = proveedores
            updateProviderEmptyState()
            return
        }

        proveedoresFiltrados = proveedores.filter { proveedor in
            [proveedor.nombre, proveedor.documento, proveedor.telefono]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(text.lowercased()) }
        }
        updateProviderEmptyState()
    }

    private func updateProviderEmptyState() {
        if proveedores.isEmpty {
            proveedoresEmptyLabel?.text = "No hay proveedores registrados"
            proveedoresEmptyLabel?.isHidden = false
            proveedoresTableView?.isHidden = true
        } else if proveedoresFiltrados.isEmpty {
            proveedoresEmptyLabel?.text = "No se encontraron proveedores"
            proveedoresEmptyLabel?.isHidden = false
            proveedoresTableView?.isHidden = true
        } else {
            proveedoresEmptyLabel?.isHidden = true
            proveedoresTableView?.isHidden = false
        }
    }

    private func rankingDescription() -> String {
        let grouped = Dictionary(grouping: ordenes) { $0.proveedor?.nombre ?? "Sin proveedor" }
            .map { (name: $0.key, total: $0.value.reduce(0.0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }

        guard !grouped.isEmpty else { return "Sin proveedores activos" }
        return grouped.prefix(3).enumerated().map { index, item in
            "#\(index + 1) \(item.name) \(formatCurrency(item.total))"
        }.joined(separator: " · ")
    }

    private func productExpenseDescription() -> String {
        let grouped = Dictionary(grouping: ordenes) { $0.producto?.nombre ?? "Producto" }
            .map { (name: $0.key, total: $0.value.reduce(0.0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }

        guard !grouped.isEmpty else { return "Sin gasto por producto" }
        return grouped.prefix(3).map { "\($0.name): \(formatCurrency($0.total))" }.joined(separator: " · ")
    }

    private func productVolumeDescription() -> String {
        let grouped = Dictionary(grouping: ordenes) { $0.producto?.nombre ?? "Producto" }
            .map { (name: $0.key, volume: $0.value.reduce(0.0) { $0 + $1.cantidadLitros }) }
            .sorted { $0.volume > $1.volume }

        guard !grouped.isEmpty else { return "Sin volumen registrado" }
        return grouped.prefix(3).map { "\($0.name): \(Int($0.volume.rounded()).formatted())L" }.joined(separator: " · ")
    }

    private func showProveedores() {
        currentTab = .proveedores
        proveedoresView?.isHidden = false
        ordenesView?.isHidden = true
        analisisScrollView?.isHidden = true
        updateTabs()
    }

    private func showOrdenes() {
        currentTab = .ordenes
        proveedoresView?.isHidden = true
        ordenesView?.isHidden = false
        analisisScrollView?.isHidden = true
        updateTabs()
    }

    private func showAnalisis() {
        currentTab = .analisis
        proveedoresView?.isHidden = true
        ordenesView?.isHidden = true
        analisisScrollView?.isHidden = false
        updateTabs()
    }

    private func updateTabs() {
        styleTab(btnProveedores, active: currentTab == .proveedores)
        styleTab(btnOrdenes, active: currentTab == .ordenes)
        styleTab(btnAnalisis, active: currentTab == .analisis)
    }

    private func styleTab(_ button: UIButton?, active: Bool) {
        guard var config = button?.configuration else { return }
        config.baseForegroundColor = active ? UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1) : inactiveColor
        config.background.backgroundColor = active ? .white : .clear
        button?.configuration = config
    }

    private func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "S/0"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }

    @IBAction private func btnVolverTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnNuevaOrdenTapped(_ sender: UIButton) {
        guard RoleAccessControl.isAdmin else { return }
        showOrdenes()
    }

    @IBAction private func btnProveedoresTapped(_ sender: UIButton) {
        showProveedores()
    }

    @IBAction private func btnOrdenesTapped(_ sender: UIButton) {
        showOrdenes()
    }

    @IBAction private func btnAnalisisTapped(_ sender: UIButton) {
        showAnalisis()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView == proveedoresTableView ? proveedoresFiltrados.count : ordenes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = tableView == proveedoresTableView ? proveedorCellIdentifier : ordenCellIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        guard let compraCell = cell as? CompraCardCell else { return cell }

        if tableView == proveedoresTableView {
            let proveedor = proveedoresFiltrados[indexPath.row]
            let ordenesProveedor = ordenes.filter { $0.proveedor == proveedor }
            let total = ordenesProveedor.reduce(0.0) { $0 + $1.total }
            compraCell.configure(
                initials: initials(for: proveedor.nombre),
                title: proveedor.nombre ?? "Proveedor",
                subtitle: proveedor.documento ?? proveedor.telefono ?? "Sin datos",
                detail: "\(ordenesProveedor.count) orden(es)",
                amount: formatCurrency(total),
                badge: proveedor.activo ? "Activo" : "Inactivo",
                color: proveedor.activo ? UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1) : inactiveColor
            )
            return compraCell
        }

        let orden = ordenes[indexPath.row]
        let estado = orden.estado ?? "Pendiente"
        let estadoColor = colorForStatus(estado)
        compraCell.configure(
            initials: initials(for: orden.proveedor?.nombre),
            title: orden.proveedor?.nombre ?? "Proveedor",
            subtitle: orden.producto?.nombre ?? "Producto",
            detail: "\(Int(orden.cantidadLitros.rounded()).formatted())L · \(orden.almacen?.nombre ?? "Almacén") · \(formatDate(orden.fecha))",
            amount: formatCurrency(orden.total),
            badge: estado,
            color: estadoColor
        )
        return compraCell
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyProviderFilter()
        proveedoresTableView?.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func initials(for name: String?) -> String {
        let parts = (name ?? "PP").split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    private func colorForStatus(_ status: String) -> UIColor {
        let value = status.lowercased()
        if value.contains("recib") || value.contains("complet") {
            return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
        }
        if value.contains("cancel") {
            return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        }
        return UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
    }
}

private final class CompraCardCell: UITableViewCell {

    private let cardView = UIView()
    private let topLine = UIView()
    private let avatarLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let amountLabel = UILabel()
    private let badgeLabel = UILabel()

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

        [cardView, topLine, avatarLabel, titleLabel, subtitleLabel, detailLabel, amountLabel, badgeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.07
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.addSubview(cardView)

        topLine.layer.cornerRadius = 1.5
        topLine.clipsToBounds = true

        avatarLabel.font = .systemFont(ofSize: 13, weight: .bold)
        avatarLabel.textAlignment = .center
        avatarLabel.textColor = .white
        avatarLabel.layer.cornerRadius = 15
        avatarLabel.clipsToBounds = true

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)

        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
        detailLabel.numberOfLines = 2

        amountLabel.font = .systemFont(ofSize: 16, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.72

        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.textColor = .white
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true

        [topLine, avatarLabel, titleLabel, subtitleLabel, detailLabel, amountLabel, badgeLabel].forEach {
            cardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            topLine.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            topLine.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            topLine.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            topLine.heightAnchor.constraint(equalToConstant: 3),

            avatarLabel.topAnchor.constraint(equalTo: topLine.bottomAnchor, constant: 18),
            avatarLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            avatarLabel.widthAnchor.constraint(equalToConstant: 30),
            avatarLabel.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.topAnchor.constraint(equalTo: avatarLabel.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: avatarLabel.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            amountLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            amountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            detailLabel.topAnchor.constraint(equalTo: avatarLabel.bottomAnchor, constant: 18),
            detailLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -12),

            badgeLabel.centerYAnchor.constraint(equalTo: detailLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    func configure(initials: String, title: String, subtitle: String, detail: String, amount: String, badge: String, color: UIColor) {
        avatarLabel.text = initials.isEmpty ? "PP" : initials
        avatarLabel.backgroundColor = color
        topLine.backgroundColor = color
        titleLabel.text = title
        subtitleLabel.text = subtitle
        detailLabel.text = detail
        amountLabel.text = amount
        badgeLabel.text = badge
        badgeLabel.backgroundColor = color
    }
}
