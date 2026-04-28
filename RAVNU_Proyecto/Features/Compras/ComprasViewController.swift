import CoreData
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class ComprasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    private enum EstadoOrdenCompra: String {
        case registrada
        case aprobada
        case pagada
        case recibida
        case cancelada

        init(value: String?) {
            let normalized = value?.lowercased() ?? ""
            switch normalized {
            case "aprobada":
                self = .aprobada
            case "pagada":
                self = .pagada
            case "recibida", "completada", "completado":
                self = .recibida
            case "cancelada":
                self = .cancelada
            default:
                self = .registrada
            }
        }

        var title: String { rawValue.capitalized }

        var accentHex: String {
            switch self {
            case .registrada, .aprobada, .pagada:
                return "F5A623"
            case .recibida:
                return "22C55E"
            case .cancelada:
                return "EF4444"
            }
        }
    }

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
    private var productos: [ProductoEntity] = []
    private var almacenes: [AlmacenEntity] = []
    private var hostingController: UIHostingController<PurchasesDashboardView>?
    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let contexto = AppCoreData.viewContext
    private lazy var isoFormatter = ISO8601DateFormatter()

    private let formateadorMoneda: NumberFormatter = {
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
        configurarUI()
        configurarAccesoPorRol()
        configurarVistaHibrida()
        cargarDatos()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarDatos()
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

    private func crearVistaRaiz() -> PurchasesDashboardView {
        PurchasesDashboardView(
            data: crearDatosDashboard(),
            onBack: { [weak self] in self?.dismiss(animated: true) },
            onAddProvider: { [weak self] in self?.presentAddProviderFlow() },
            onNewOrder: { [weak self] in self?.presentCreateOrderFlow() },
            onSelectOrder: { [weak self] id in self?.presentOrderDetails(orderID: id) }
        )
    }

    private func crearDatosDashboard() -> DatosDashboardCompras {
        let pendingOrders = ordenes.filter {
            let status = estadoOrdenCompra(for: $0)
            return status == .registrada || status == .aprobada || status == .pagada
        }
        let receivedOrders = ordenes.filter { estadoOrdenCompra(for: $0) == .recibida }
        let cancelledOrders = ordenes.filter { estadoOrdenCompra(for: $0) == .cancelada }
        let totalAmount = ordenes.reduce(0.0) { $0 + $1.total }
        let totalVolume = ordenes.reduce(0.0) { $0 + $1.cantidadLitros }

        let tarjetasProveedor = proveedoresFiltrados.map { proveedor -> DatosDashboardCompras.TarjetaProveedor in
            let providerOrders = ordenes.filter { $0.proveedor == proveedor }
            let total = providerOrders.reduce(0.0) { $0 + $1.total }
            let rating = providerRating(for: proveedor)
            let accent = providerAccentHex(for: proveedor)
            return DatosDashboardCompras.TarjetaProveedor(
                id: proveedor.id?.uuidString ?? UUID().uuidString,
                initials: initials(for: proveedor.nombre),
                name: proveedor.nombre ?? "Proveedor",
                tags: providerTags(for: proveedor),
                subtitle: subtituloProveedor(for: proveedor),
                orderCountText: "\(providerOrders.count) orden\(providerOrders.count == 1 ? "" : "es")",
                totalAmountText: formatearMoneda(total),
                ratingText: String(format: "%.1f", rating),
                accentHex: accent,
                progress: providerProgressValue(total: total, overall: totalAmount)
            )
        }

        let tarjetasOrden = ordenes.map { orden in
            let accent = orderAccentHex(for: orden)
            return DatosDashboardCompras.TarjetaOrden(
                id: orden.id?.uuidString ?? UUID().uuidString,
                initials: initials(for: orden.proveedor?.nombre),
                providerName: orden.proveedor?.nombre ?? "Proveedor",
                productName: orden.producto?.nombre ?? "Producto",
                amountText: formatearMoneda(orden.total),
                dateText: formatearFecha(orden.fecha),
                volumeText: "\(Int(orden.cantidadLitros.rounded()).formatted()) L",
                warehouseText: orden.almacen?.nombre ?? "Almacén",
                workerText: orden.almacen?.responsable ?? "Sin responsable",
                noteText: notaOrdenCompra(for: orden),
                statusText: estadoOrdenCompra(for: orden).title,
                statusAccentHex: estadoOrdenCompra(for: orden).accentHex,
                accentHex: accent
            )
        }

        let ranking = tarjetasProveedor
            .sorted { currencyValue($0.totalAmountText) > currencyValue($1.totalAmountText) }
            .prefix(3)
            .enumerated()
            .map { index, card in
                DatosDashboardCompras.FilaRanking(
                    rank: index + 1,
                    initials: card.initials,
                    name: card.name,
                    amountText: card.totalAmountText,
                    percentText: providerPercentText(amountText: card.totalAmountText, total: totalAmount),
                    accentHex: card.accentHex,
                    progress: card.progress
                )
            }

        let productTotals = Dictionary(grouping: ordenes) { $0.producto?.nombre ?? "Producto" }
            .map { key, value in
                (
                    name: key,
                    total: value.reduce(0.0) { $0 + $1.total },
                    volume: value.reduce(0.0) { $0 + $1.cantidadLitros }
                )
            }
            .sorted { $0.total > $1.total }

        let segmentosProducto = productTotals.map {
            DatosDashboardCompras.SegmentoProducto(
                name: $0.name,
                valueText: "\(Int((totalAmount > 0 ? ($0.total / totalAmount) * 100 : 0).rounded()))%",
                accentHex: colorHexForProductName($0.name),
                share: totalAmount > 0 ? $0.total / totalAmount : 0
            )
        }

        let barrasProducto = productTotals.map {
            DatosDashboardCompras.BarraProducto(
                shortName: shortProductName($0.name),
                accentHex: colorHexForProductName($0.name),
                amountRatio: totalAmount > 0 ? $0.total / totalAmount : 0,
                volumeRatio: totalVolume > 0 ? $0.volume / totalVolume : 0
            )
        }

        return DatosDashboardCompras(
            title: "Compras",
            pendingBadgeText: "\(pendingOrders.count) pendiente\(pendingOrders.count == 1 ? "" : "s")",
            canCreateOrder: RoleAccessControl.canManagePurchases,
            providerCountText: "\(proveedores.count) PROVEEDORES",
            tarjetasProveedor: tarjetasProveedor,
            totalSpendText: formatearMoneda(totalAmount),
            pendingCountText: "\(pendingOrders.count)",
            receivedCountText: "\(receivedOrders.count)",
            cancelledCountText: "\(cancelledOrders.count)",
            tarjetasOrden: tarjetasOrden,
            filasRanking: Array(ranking),
            segmentosProducto: segmentosProducto,
            barrasProducto: barrasProducto,
            totalVolumeText: "\(Int(totalVolume.rounded()).formatted())L",
            totalProvidersText: "\(proveedores.count)"
        )
    }

    private func presentOrderDetails(orderID: String) {
        guard let orden = ordenes.first(where: { $0.id?.uuidString == orderID }) else { return }
        presentOrderActions(for: orden)
    }

    private func providerRating(for proveedor: ProveedorEntity) -> Double {
        if proveedor.calificacion > 0 {
            return proveedor.calificacion
        }
        let total = ordenes.filter { $0.proveedor == proveedor }.reduce(0.0) { $0 + $1.total }
        if total >= 15000 { return 4.8 }
        if total >= 8000 { return 4.5 }
        if total >= 3000 { return 4.2 }
        return 3.9
    }

    private func providerTags(for proveedor: ProveedorEntity) -> [String] {
        var tags: [String] = []
        if proveedor.preferido || providerRating(for: proveedor) >= 4.5 {
            tags.append("Preferido")
        }
        if proveedor.verificado || proveedor.activo {
            tags.append("Verificado")
        }
        return tags
    }

    private func subtituloProveedor(for proveedor: ProveedorEntity) -> String {
        if let categoria = proveedor.categoria, categoria.isEmpty == false {
            return categoria
        }
        return "Proveedor activo"
    }

    private func providerAccentHex(for proveedor: ProveedorEntity) -> String {
        let name = (proveedor.nombre ?? "").lowercased()
        if name.contains("repsol") { return "4F7CF7" }
        if name.contains("primax") { return "EF5350" }
        if name.contains("pecsa") { return "8B5CF6" }
        return "F5A623"
    }

    private func providerProgressValue(total: Double, overall: Double) -> Double {
        guard overall > 0 else { return 0 }
        return min(max(total / overall, 0), 1)
    }

    private func notaOrdenCompra(for orden: OrdenCompraEntity) -> String {
        if let nota = orden.nota, nota.isEmpty == false {
            return "\"\(nota)\""
        }
        return "\"Sin observaciones\""
    }

    private func colorHexForProductName(_ name: String) -> String {
        let value = name.lowercased()
        if value.contains("90") { return "4F7CF7" }
        if value.contains("95") { return "8B5CF6" }
        if value.contains("diesel") { return "F5A623" }
        return "94A3B8"
    }

    private func shortProductName(_ name: String) -> String {
        if name.lowercased().contains("90") { return "90" }
        if name.lowercased().contains("95") { return "95" }
        if name.lowercased().contains("diesel") { return "B5" }
        return String(name.prefix(2)).uppercased()
    }

    private func providerPercentText(amountText: String, total: Double) -> String {
        let amount = currencyValue(amountText)
        guard total > 0 else { return "0%" }
        return "\(Int(((amount / total) * 100).rounded()))%"
    }

    private func currencyValue(_ text: String) -> Double {
        let digits = text.replacingOccurrences(of: "S/", with: "").replacingOccurrences(of: ",", with: "")
        return Double(digits.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private func configurarUI() {
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

    private func configurarAccesoPorRol() {
        let shouldHideCreateActions = RoleAccessControl.canManagePurchases == false
        RoleAccessControl.configureButtons(
            in: view,
            target: self,
            selectors: [#selector(btnNuevaOrdenTapped(_:))],
            hidden: shouldHideCreateActions
        )
    }

    private func cargarDatos() {
        do {
            proveedores = try fetchProveedores()
            ordenes = try fetchOrdenes()
            productos = try fetchProductos()
            almacenes = try fetchAlmacenes()
            applyProviderFilter()
            updateMetrics()
            proveedoresTableView?.reloadData()
            ordenesTableView?.reloadData()
        } catch {
            proveedores = []
            proveedoresFiltrados = []
            ordenes = []
            productos = []
            almacenes = []
            updateProviderEmptyState()
            updateMetrics()
        }
        actualizarVistaHibrida()
    }

    private func fetchProveedores() throws -> [ProveedorEntity] {
        let request: NSFetchRequest<ProveedorEntity> = ProveedorEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return try contexto.fetch(request)
    }

    private func fetchOrdenes() throws -> [OrdenCompraEntity] {
        let request: NSFetchRequest<OrdenCompraEntity> = OrdenCompraEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        return try contexto.fetch(request)
    }

    private func fetchProductos() throws -> [ProductoEntity] {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return try contexto.fetch(request)
    }

    private func fetchAlmacenes() throws -> [AlmacenEntity] {
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return try contexto.fetch(request)
    }

    private func updateMetrics() {
        let total = ordenes.reduce(0.0) { $0 + $1.total }
        let pendientes = ordenes.filter { ($0.estado ?? "").lowercased().contains("pend") }
        let recibidas = ordenes.filter { ($0.estado ?? "").lowercased().contains("recib") || ($0.estado ?? "").lowercased().contains("complet") }
        let volumen = ordenes.reduce(0.0) { $0 + $1.cantidadLitros }

        lblPendientesBadge?.text = pendientes.isEmpty ? "Sin pendientes" : "\(pendientes.count) pendiente"
        lblGastoTotal?.text = formatearMoneda(total)
        lblPendientes?.text = "\(pendientes.count)"
        lblRecibidas?.text = "\(recibidas.count)"
        lblAnalisisGasto?.text = formatearMoneda(total)
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
            "#\(index + 1) \(item.name) \(formatearMoneda(item.total))"
        }.joined(separator: " · ")
    }

    private func productExpenseDescription() -> String {
        let grouped = Dictionary(grouping: ordenes) { $0.producto?.nombre ?? "Producto" }
            .map { (name: $0.key, total: $0.value.reduce(0.0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }

        guard !grouped.isEmpty else { return "Sin gasto por producto" }
        return grouped.prefix(3).map { "\($0.name): \(formatearMoneda($0.total))" }.joined(separator: " · ")
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

    private func formatearMoneda(_ value: Double) -> String {
        formateadorMoneda.string(from: NSNumber(value: value)) ?? "S/0"
    }

    private func formatearFecha(_ date: Date?) -> String {
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
        guard RoleAccessControl.canManagePurchases else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .managePurchases))
            return
        }
        showOrdenes()
        presentCreateOrderFlow()
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
                amount: formatearMoneda(total),
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
            detail: "\(Int(orden.cantidadLitros.rounded()).formatted())L · \(orden.almacen?.nombre ?? "Almacén") · \(formatearFecha(orden.fecha))",
            amount: formatearMoneda(orden.total),
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard tableView == ordenesTableView, ordenes.indices.contains(indexPath.row) else { return }
        presentOrderActions(for: ordenes[indexPath.row])
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

    private func estadoOrdenCompra(for orden: OrdenCompraEntity) -> EstadoOrdenCompra {
        EstadoOrdenCompra(value: orden.estado)
    }

    private func orderAccentHex(for orden: OrdenCompraEntity) -> String {
        colorHexForProductName(orden.producto?.nombre ?? "")
    }

    private func presentCreateOrderFlow() {
        guard !proveedores.isEmpty else {
            showAlert(title: "Compras", message: "No hay proveedores registrados.")
            return
        }
        guard !productos.isEmpty else {
            showAlert(title: "Compras", message: "No hay productos registrados.")
            return
        }
        guard !almacenes.isEmpty else {
            showAlert(title: "Compras", message: "No hay almacenes registrados.")
            return
        }
        let providerOptions = proveedores.map {
            PurchaseOrderSheetView.OpcionProveedor(
                id: $0.id?.uuidString ?? UUID().uuidString,
                name: $0.nombre ?? "Proveedor"
            )
        }
        let productOptions = productos.map {
            PurchaseOrderSheetView.OpcionProducto(
                id: $0.id?.uuidString ?? UUID().uuidString,
                name: $0.nombre ?? "Producto",
                availableStock: $0.stockLitros,
                pricePerLiter: $0.precioPorLitro
            )
        }
        let warehouseOptions = almacenes.map {
            PurchaseOrderSheetView.OpcionAlmacen(
                id: $0.id?.uuidString ?? UUID().uuidString,
                name: $0.nombre ?? "Almacén",
                managerName: $0.responsable ?? "Sin responsable"
            )
        }

        let controller = UIHostingController(
            rootView: PurchaseOrderSheetView(
                providers: providerOptions,
                products: productOptions,
                warehouses: warehouseOptions,
                onCancel: { [weak self] in self?.dismiss(animated: true) },
                onSave: { [weak self] draft in self?.handleBorradorOrdenCompra(draft) }
            )
        )
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 24
        }
        present(controller, animated: true)
    }

    private func presentAddProviderFlow() {
        guard RoleAccessControl.canManagePurchases else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .managePurchases))
            return
        }
        let controller = UIHostingController(
            rootView: AddSupplierSheetView(
                onCancel: { [weak self] in self?.dismiss(animated: true) },
                onSave: { [weak self] draft in self?.handleSupplierDraft(draft) }
            )
        )
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 24
        }
        present(controller, animated: true)
    }

    private func handleSupplierDraft(_ draft: AddSupplierDraft) {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            showAlert(title: "Proveedor", message: "Ingresa el nombre del proveedor.")
            return
        }
        let existingRequest: NSFetchRequest<ProveedorEntity> = ProveedorEntity.fetchRequest()
        existingRequest.fetchLimit = 1
        existingRequest.predicate = NSPredicate(format: "nombre =[c] %@", trimmedName)
        if ((try? contexto.fetch(existingRequest)) ?? []).isEmpty == false {
            showAlert(title: "Proveedor", message: "Ya existe un proveedor con ese nombre.")
            return
        }

        if RoleAccessControl.isAdmin == false {
            guard RoleAccessControl.canRequestSupplierCreation else {
                showAlert(title: "Permiso denegado", message: "Tu rol no puede solicitar nuevos proveedores.")
                return
            }
            solicitarMotivoProveedor(draft)
            return
        }

        let proveedor = ProveedorEntity(context: contexto)
        proveedor.id = UUID()
        proveedor.nombre = trimmedName
        proveedor.categoria = draft.category
        proveedor.telefono = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        proveedor.email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        proveedor.direccion = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        proveedor.calificacion = Double(draft.rating)
        proveedor.preferido = draft.isPreferred
        proveedor.verificado = draft.isVerified
        proveedor.documento = nil
        proveedor.activo = true

        do {
            try contexto.save()
            syncSupplierToRemote(proveedor, draft: draft)
            dismiss(animated: true) { [weak self] in
                self?.cargarDatos()
                self?.showAlert(title: "Compras", message: "Proveedor agregado.")
            }
        } catch {
            contexto.rollback()
            showAlert(title: "Error", message: "No se pudo guardar el proveedor.")
        }
    }

    private func handleBorradorOrdenCompra(_ draft: BorradorOrdenCompra) {
        guard
            proveedores.indices.contains(draft.indiceProveedor),
            productos.indices.contains(draft.indiceProducto),
            almacenes.indices.contains(draft.indiceAlmacen)
        else {
            showAlert(title: "Compras", message: "Completa los datos de la orden.")
            return
        }

        guard draft.cantidad > 0 else {
            showAlert(title: "Compras", message: "Ingresa una cantidad válida.")
            return
        }

        guard draft.precioUnitario > 0 else {
            showAlert(title: "Compras", message: "Ingresa un precio válido.")
            return
        }

        if RoleAccessControl.isAdmin == false {
            guard RoleAccessControl.canRequestPurchaseOrders else {
                showAlert(title: "Permiso denegado", message: "Tu rol no puede solicitar órdenes de compra.")
                return
            }
            solicitarMotivoOrdenCompra(draft)
            return
        }

        let proveedor = proveedores[draft.indiceProveedor]
        let producto = productos[draft.indiceProducto]
        let almacen = almacenes[draft.indiceAlmacen]
        ensureIdentifiers(proveedor: proveedor, producto: producto, almacen: almacen)

        let orden = OrdenCompraEntity(context: contexto)
        orden.id = UUID()
        orden.proveedor = proveedor
        orden.producto = producto
        orden.almacen = almacen
        orden.cantidadLitros = draft.cantidad
        orden.precioUnitarioCompra = draft.precioUnitario
        orden.total = draft.cantidad * draft.precioUnitario
        orden.fecha = Date()
        orden.estado = EstadoOrdenCompra.registrada.rawValue
        orden.nota = draft.notas.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try contexto.save()
            syncPurchaseOrderToRemote(orden, event: .registrada, note: draft.notas, unitPrice: draft.precioUnitario)
            dismiss(animated: true) { [weak self] in
                self?.cargarDatos()
                self?.showAlert(title: "Compras", message: "Compra registrada.")
            }
        } catch {
            contexto.rollback()
            showAlert(title: "Error", message: "No se pudo registrar la compra.")
        }
    }

    private func presentProveedorSelection() {
        let alert = UIAlertController(title: "Proveedor", message: "Selecciona el proveedor de la compra", preferredStyle: .actionSheet)
        proveedores.forEach { proveedor in
            alert.addAction(UIAlertAction(title: proveedor.nombre ?? "Proveedor", style: .default) { [weak self] _ in
                self?.presentProductoSelection(for: proveedor)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }

    private func presentProductoSelection(for proveedor: ProveedorEntity) {
        let alert = UIAlertController(title: "Producto", message: "Selecciona el producto", preferredStyle: .actionSheet)
        productos.forEach { producto in
            let title = "\(producto.nombre ?? "Producto") · \(formatearMoneda(producto.precioPorLitro)) / L"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.presentWarehouseSelection(for: proveedor, producto: producto)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }

    private func presentWarehouseSelection(for proveedor: ProveedorEntity, producto: ProductoEntity) {
        let alert = UIAlertController(title: "Almacén", message: "Selecciona el almacén destino", preferredStyle: .actionSheet)
        almacenes.forEach { almacen in
            alert.addAction(UIAlertAction(title: almacen.nombre ?? "Almacén", style: .default) { [weak self] _ in
                self?.presentQuantityPrompt(for: proveedor, producto: producto, almacen: almacen)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }

    private func presentQuantityPrompt(for proveedor: ProveedorEntity, producto: ProductoEntity, almacen: AlmacenEntity) {
        let alert = UIAlertController(
            title: "Nueva compra",
            message: "Ingresa la cantidad en litros para \(producto.nombre ?? "el producto")",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Cantidad en litros"
            field.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Crear", style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text else { return }
            let cantidad = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            guard cantidad > 0 else {
                self.showAlert(title: "Compras", message: "Ingresa una cantidad válida.")
                return
            }
            self.createPurchaseOrder(proveedor: proveedor, producto: producto, almacen: almacen, cantidadLitros: cantidad)
        })
        present(alert, animated: true)
    }

    private func createPurchaseOrder(proveedor: ProveedorEntity, producto: ProductoEntity, almacen: AlmacenEntity, cantidadLitros: Double) {
        ensureIdentifiers(proveedor: proveedor, producto: producto, almacen: almacen)

        let orden = OrdenCompraEntity(context: contexto)
        orden.id = UUID()
        orden.proveedor = proveedor
        orden.producto = producto
        orden.almacen = almacen
        orden.cantidadLitros = cantidadLitros
        orden.total = cantidadLitros * producto.precioPorLitro
        orden.fecha = Date()
        orden.estado = EstadoOrdenCompra.registrada.rawValue

        do {
            try contexto.save()
            syncPurchaseOrderToRemote(orden, event: .registrada)
            cargarDatos()
            showAlert(title: "Compras", message: "Compra registrada.")
        } catch {
            contexto.rollback()
            showAlert(title: "Error", message: "No se pudo registrar la compra.")
        }
    }

    private func presentOrderActions(for orden: OrdenCompraEntity) {
        let status = EstadoOrdenCompra(value: orden.estado)
        let alert = UIAlertController(
            title: orden.proveedor?.nombre ?? "Orden de compra",
            message: "Estado actual: \(status.title)",
            preferredStyle: .actionSheet
        )

        if RoleAccessControl.isAdmin {
            switch status {
            case .registrada:
                alert.addAction(UIAlertAction(title: "Aprobar", style: .default) { [weak self] _ in
                    self?.updateOrderStatus(orden, to: .aprobada)
                })
            case .aprobada:
                alert.addAction(UIAlertAction(title: "Marcar pagada", style: .default) { [weak self] _ in
                    self?.updateOrderStatus(orden, to: .pagada)
                })
            case .pagada:
                alert.addAction(UIAlertAction(title: "Ingresar a almacén", style: .default) { [weak self] _ in
                    self?.receivePurchaseOrder(orden)
                })
            case .recibida, .cancelada:
                break
            }

            if status != .recibida && status != .cancelada {
                alert.addAction(UIAlertAction(title: "Cancelar", style: .destructive) { [weak self] _ in
                    self?.updateOrderStatus(orden, to: .cancelada)
                })
            }
        } else if RoleAccessControl.canRequestPurchaseOrders {
            switch status {
            case .registrada:
                alert.addAction(UIAlertAction(title: "Solicitar aprobación", style: .default) { [weak self] _ in
                    self?.solicitarCambioEstadoOrden(orden, requestedStatus: .aprobada)
                })
            case .aprobada:
                alert.addAction(UIAlertAction(title: "Solicitar marcar pagada", style: .default) { [weak self] _ in
                    self?.solicitarCambioEstadoOrden(orden, requestedStatus: .pagada)
                })
            case .pagada:
                alert.addAction(UIAlertAction(title: "Solicitar ingreso a almacén", style: .default) { [weak self] _ in
                    self?.solicitarCambioEstadoOrden(orden, requestedStatus: .recibida)
                })
            case .recibida, .cancelada:
                break
            }

            if status != .recibida && status != .cancelada {
                alert.addAction(UIAlertAction(title: "Solicitar cancelación", style: .destructive) { [weak self] _ in
                    self?.solicitarCambioEstadoOrden(orden, requestedStatus: .cancelada)
                })
            }
        }

        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel))
        present(alert, animated: true)
    }

    private func solicitarMotivoProveedor(_ draft: AddSupplierDraft) {
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud al panel administrativo para crear el proveedor.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Motivo de la solicitud" }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let reason = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard reason.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudProveedor(draft: draft, reason: reason)
                    await MainActor.run {
                        self.showAlert(title: "Solicitud enviada", message: "La solicitud fue enviada al panel administrativo.")
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

    private func solicitarMotivoOrdenCompra(_ draft: BorradorOrdenCompra) {
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud al panel administrativo para registrar la orden de compra.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Motivo de la solicitud" }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let reason = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard reason.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudOrdenCompra(draft: draft, reason: reason)
                    await MainActor.run {
                        self.showAlert(title: "Solicitud enviada", message: "La solicitud fue enviada al panel administrativo.")
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

    private func solicitarCambioEstadoOrden(_ orden: OrdenCompraEntity, requestedStatus: EstadoOrdenCompra) {
        let alert = UIAlertController(
            title: "Enviar solicitud",
            message: "Se enviará una solicitud al panel administrativo para cambiar el estado de la orden a \(requestedStatus.title.lowercased()).",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Motivo de la solicitud" }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enviar", style: .default) { [weak self] _ in
            guard let self else { return }
            let reason = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard reason.isEmpty == false else {
                self.showAlert(title: "Validación", message: "Ingresa el motivo de la solicitud.")
                return
            }
            Task {
                do {
                    try await self.enviarSolicitudCambioEstadoOrden(orden: orden, requestedStatus: requestedStatus, reason: reason)
                    await MainActor.run {
                        self.showAlert(title: "Solicitud enviada", message: "La solicitud fue enviada al panel administrativo.")
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

    private func enviarSolicitudProveedor(draft: AddSupplierDraft, reason: String) async throws {
        let requester = try AdminRequestService.currentRequester()
        let request = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: "create_supplier",
            module: "compras",
            status: "pending",
            requestedBy: requester,
            target: nil,
            payload: [
                "name": .string(draft.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                "category": .string(draft.category),
                "phone": .string(draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)),
                "email": .string(draft.email.trimmingCharacters(in: .whitespacesAndNewlines)),
                "address": .string(draft.address.trimmingCharacters(in: .whitespacesAndNewlines)),
                "rating": .number(Double(draft.rating)),
                "isPreferred": .bool(draft.isPreferred),
                "isVerified": .bool(draft.isVerified)
            ],
            reason: reason,
            createdAt: isoFormatter.string(from: Date()),
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        try await AdminRequestService.submit(request)
    }

    private func enviarSolicitudOrdenCompra(draft: BorradorOrdenCompra, reason: String) async throws {
        let requester = try AdminRequestService.currentRequester()
        let proveedor = proveedores[draft.indiceProveedor]
        let producto = productos[draft.indiceProducto]
        let almacen = almacenes[draft.indiceAlmacen]
        let request = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: "create_purchase_order",
            module: "compras",
            status: "pending",
            requestedBy: requester,
            target: nil,
            payload: [
                "supplierId": .string(proveedor.id?.uuidString ?? ""),
                "supplierName": .string(proveedor.nombre ?? "Proveedor"),
                "productId": .string(producto.id?.uuidString ?? ""),
                "productName": .string(producto.nombre ?? "Producto"),
                "warehouseId": .string(almacen.id?.uuidString ?? ""),
                "warehouseName": .string(almacen.nombre ?? "Almacén"),
                "cantidadLitros": .number(draft.cantidad),
                "precioUnitario": .number(draft.precioUnitario),
                "total": .number(draft.cantidad * draft.precioUnitario),
                "notes": .string(draft.notas.trimmingCharacters(in: .whitespacesAndNewlines))
            ],
            reason: reason,
            createdAt: isoFormatter.string(from: Date()),
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        try await AdminRequestService.submit(request)
    }

    private func enviarSolicitudCambioEstadoOrden(
        orden: OrdenCompraEntity,
        requestedStatus: EstadoOrdenCompra,
        reason: String
    ) async throws {
        let requester = try AdminRequestService.currentRequester()
        let request = AdminRequestPayload(
            requestId: UUID().uuidString,
            type: "update_purchase_order_status",
            module: "compras",
            status: "pending",
            requestedBy: requester,
            target: .init(entity: "purchase_order", entityId: orden.id?.uuidString ?? ""),
            payload: [
                "currentStatus": .string(orden.estado ?? EstadoOrdenCompra.registrada.rawValue),
                "requestedStatus": .string(requestedStatus.rawValue),
                "supplierName": .string(orden.proveedor?.nombre ?? "Proveedor"),
                "productName": .string(orden.producto?.nombre ?? "Producto"),
                "warehouseName": .string(orden.almacen?.nombre ?? "Almacén"),
                "cantidadLitros": .number(orden.cantidadLitros),
                "total": .number(orden.total)
            ],
            reason: reason,
            createdAt: isoFormatter.string(from: Date()),
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        try await AdminRequestService.submit(request)
    }

    private func updateOrderStatus(_ orden: OrdenCompraEntity, to newStatus: EstadoOrdenCompra) {
        orden.estado = newStatus.rawValue
        do {
            try contexto.save()
            syncPurchaseOrderToRemote(orden, event: newStatus)
            cargarDatos()
        } catch {
            contexto.rollback()
            showAlert(title: "Error", message: "No se pudo actualizar la orden.")
        }
    }

    private func receivePurchaseOrder(_ orden: OrdenCompraEntity) {
        guard let producto = orden.producto, let almacen = orden.almacen else {
            showAlert(title: "Compras", message: "La orden no tiene producto o almacén asignado.")
            return
        }

        ensureIdentifiers(producto: producto, almacen: almacen)
        let stock = stockRecord(producto: producto, almacen: almacen)
        let capacidad = max(producto.capacidadTotal, stock.capacidadTotal)
        if capacidad > 0, stock.stockActual + orden.cantidadLitros > capacidad {
            showAlert(title: "Compras", message: "La recepción supera la capacidad del almacén para ese producto.")
            return
        }
        stock.stockActual += orden.cantidadLitros
        stock.stockMinimo = producto.stockMinimo
        stock.capacidadTotal = producto.capacidadTotal
        stock.unidadMedida = producto.unidadMedida ?? "L"

        let movimiento = MovimientoInventarioEntity(context: contexto)
        movimiento.id = UUID()
        movimiento.fecha = Date()
        movimiento.tipo = "entrada"
        movimiento.cantidadLitros = orden.cantidadLitros
        movimiento.producto = producto
        movimiento.almacen = almacen
        movimiento.origen = orden.proveedor?.nombre ?? "Proveedor"
        movimiento.destino = almacen.nombre ?? "Almacén"
        movimiento.nota = "Ingreso por orden \(orden.id?.uuidString ?? "")"

        producto.stockLitros = totalStock(for: producto)
        orden.estado = EstadoOrdenCompra.recibida.rawValue

        do {
            try contexto.save()
            syncPurchaseOrderToRemote(orden, event: .recibida)
            syncInboundMovementToRemote(orden: orden, movimiento: movimiento, stock: stock)
            cargarDatos()
            showAlert(title: "Compras", message: "Stock ingresado al almacén.")
        } catch {
            contexto.rollback()
            showAlert(title: "Error", message: "No se pudo ingresar la compra al almacén.")
        }
    }

    private func ensureIdentifiers(proveedor: ProveedorEntity? = nil, producto: ProductoEntity? = nil, almacen: AlmacenEntity? = nil) {
        if proveedor?.id == nil {
            proveedor?.id = UUID()
        }
        if producto?.id == nil {
            producto?.id = UUID()
        }
        if almacen?.id == nil {
            almacen?.id = UUID()
        }
    }

    private func stockRecord(producto: ProductoEntity, almacen: AlmacenEntity) -> StockAlmacenEntity {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "producto == %@ AND almacen == %@", producto, almacen)

        if let existing = try? contexto.fetch(request).first {
            if existing.id == nil {
                existing.id = UUID()
            }
            return existing
        }

        let stock = StockAlmacenEntity(context: contexto)
        stock.id = UUID()
        stock.producto = producto
        stock.almacen = almacen
        stock.stockActual = 0
        stock.stockMinimo = producto.stockMinimo
        stock.capacidadTotal = producto.capacidadTotal
        stock.unidadMedida = producto.unidadMedida ?? "L"
        return stock
    }

    private func totalStock(for producto: ProductoEntity) -> Double {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "producto == %@", producto)
        return ((try? contexto.fetch(request)) ?? []).reduce(0) { $0 + $1.stockActual }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func syncPurchaseOrderToRemote(
        _ orden: OrdenCompraEntity,
        event: EstadoOrdenCompra,
        note: String? = nil,
        unitPrice: Double? = nil
    ) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard
            let orderId = orden.id?.uuidString,
            let proveedorId = orden.proveedor?.id?.uuidString,
            let productoId = orden.producto?.id?.uuidString,
            let almacenId = orden.almacen?.id?.uuidString
        else {
            return
        }

        var payload: [String: Any] = [
            "id": orderId,
            "proveedorId": proveedorId,
            "supplierId": proveedorId,
            "productoId": productoId,
            "productId": productoId,
            "almacenId": almacenId,
            "warehouseId": almacenId,
            "cantidadLitros": orden.cantidadLitros,
            "total": orden.total,
            "estado": orden.estado ?? EstadoOrdenCompra.registrada.rawValue,
            "fecha": Timestamp(date: orden.fecha ?? Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        if let note, note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            payload["nota"] = note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let unitPrice {
            payload["precioUnitarioCompra"] = unitPrice
        }

        switch event {
        case .aprobada:
            payload["aprobada"] = true
            payload["fechaAprobacion"] = Timestamp(date: Date())
        case .pagada:
            payload["aprobada"] = true
            payload["pagada"] = true
            payload["fechaPago"] = Timestamp(date: Date())
        case .recibida:
            payload["aprobada"] = true
            payload["pagada"] = true
            payload["recibida"] = true
            payload["fechaRecepcion"] = Timestamp(date: Date())
        case .cancelada:
            payload["cancelada"] = true
        case .registrada:
            break
        }

        let batch = firestore.batch()
        batch.setData(payload, forDocument: firestore.collection("purchase_orders").document(orderId), merge: true)
        batch.setData([
            "id": proveedorId,
            "nombre": orden.proveedor?.nombre ?? "Proveedor",
            "documento": orden.proveedor?.documento ?? "",
            "telefono": orden.proveedor?.telefono ?? "",
            "activo": orden.proveedor?.activo ?? true
        ], forDocument: firestore.collection("suppliers").document(proveedorId), merge: true)

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.showAlert(title: "Firebase", message: "La orden quedó local, pero no se sincronizó: \(error.localizedDescription)")
                    return
                }
                TreasuryRemoteSync.syncPurchaseExpenseIfNeeded(orden: orden, status: event.rawValue)
                AppSession.shared.lastRemoteSyncAt = Date()
            }
        }
        #endif
    }

    private func syncSupplierToRemote(_ proveedor: ProveedorEntity, draft: AddSupplierDraft) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard let supplierId = proveedor.id?.uuidString else { return }

        firestore.collection("suppliers").document(supplierId).setData([
            "id": supplierId,
            "nombre": proveedor.nombre ?? "",
            "documento": proveedor.documento ?? "",
            "telefono": proveedor.telefono ?? "",
            "activo": proveedor.activo,
            "categoria": draft.category,
            "email": draft.email.trimmingCharacters(in: .whitespacesAndNewlines),
            "direccion": draft.address.trimmingCharacters(in: .whitespacesAndNewlines),
            "calificacion": draft.rating,
            "preferido": draft.isPreferred,
            "verificado": draft.isVerified,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], merge: true) { error in
            DispatchQueue.main.async {
                if error == nil {
                    AppSession.shared.lastRemoteSyncAt = Date()
                }
            }
        }
        #endif
    }

    private func syncInboundMovementToRemote(orden: OrdenCompraEntity, movimiento: MovimientoInventarioEntity, stock: StockAlmacenEntity) {
        #if canImport(FirebaseFirestore)
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard
            let movementId = movimiento.id?.uuidString,
            let stockId = stock.id?.uuidString,
            let almacenId = stock.almacen?.id?.uuidString,
            let productoId = stock.producto?.id?.uuidString
        else {
            return
        }

        let batch = firestore.batch()
        batch.setData([
            "id": movementId,
            "tipo": "entrada",
            "cantidadLitros": movimiento.cantidadLitros,
            "productoId": productoId,
            "almacenId": almacenId,
            "origen": movimiento.origen ?? "",
            "destino": movimiento.destino ?? "",
            "nota": movimiento.nota ?? "",
            "fecha": Timestamp(date: movimiento.fecha ?? Date())
        ], forDocument: firestore.collection("inventory_movements").document(movementId), merge: true)

        batch.setData([
            "id": stockId,
            "almacenId": almacenId,
            "productoId": productoId,
            "stockActual": stock.stockActual,
            "stockMinimo": stock.stockMinimo,
            "capacidadTotal": stock.capacidadTotal,
            "unidadMedida": stock.unidadMedida ?? "L"
        ], forDocument: firestore.collection("warehouse_stock").document(stockId), merge: true)

        batch.setData([
            "id": productoId,
            "stockLitros": orden.producto?.stockLitros ?? stock.stockActual
        ], forDocument: firestore.collection("products").document(productoId), merge: true)

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.showAlert(title: "Firebase", message: "Se recibió localmente, pero no se actualizó el stock remoto: \(error.localizedDescription)")
                    return
                }
                AppSession.shared.lastRemoteSyncAt = Date()
            }
        }
        #endif
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
        configurarUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurarUI()
    }

    private func configurarUI() {
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
