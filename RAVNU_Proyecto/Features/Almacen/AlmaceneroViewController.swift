import CoreData
import SwiftUI
import UIKit

final class AlmaceneroViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var lblTitulo: UILabel?
    @IBOutlet private weak var lblResumen: UILabel?
    @IBOutlet private weak var segmentedTabs: UISegmentedControl?
    @IBOutlet private weak var lblValorStock: UILabel?
    @IBOutlet private weak var lblAlmacenes: UILabel?
    @IBOutlet private weak var lblProductos: UILabel?
    @IBOutlet private weak var lblValorRed: UILabel?
    @IBOutlet private weak var lblEntradas: UILabel?
    @IBOutlet private weak var lblSalidas: UILabel?
    @IBOutlet private weak var lblTransferencias: UILabel?
    @IBOutlet private weak var lblBajoMinimo: UILabel?
    @IBOutlet private weak var lblAlerta: UILabel?
    @IBOutlet private weak var tableView: UITableView?
    @IBOutlet private weak var summaryCardView: UIView?
    @IBOutlet private weak var alertCardView: UIView?
    @IBOutlet private weak var btnRegistrar: UIButton?

    var nombreBienvenido: String?

    private enum Mode: Int {
        case almacenes = 0
        case productos = 1
        case movimientos = 2
    }

    private enum RowItem {
        case almacen(AlmacenEntity)
        case stock(StockAlmacenEntity)
        case producto(ProductoEntity)
        case movimiento(MovimientoInventarioEntity)
    }

    private let cellIdentifier = "almacenCell"
    private var almacenes: [AlmacenEntity] = []
    private var productos: [ProductoEntity] = []
    private var stocks: [StockAlmacenEntity] = []
    private var movimientos: [MovimientoInventarioEntity] = []
    private var rows: [RowItem] = []
    private var mode: Mode = .almacenes
    private var hostingController: UIHostingController<WarehouseDashboardView>?

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
        configureUI()
        configureRoleAccess()
        configureHybridView()
        seedInitialWarehouseDataIfNeeded()
        observeRemoteSync()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            RemoteSyncCoordinator.shared.startInitialSyncIfPossible()
        }
        loadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        lblTitulo?.text = "Almacén"
        segmentedTabs?.setTitle("Almacenes", forSegmentAt: 0)
        segmentedTabs?.setTitle("Productos", forSegmentAt: 1)
        segmentedTabs?.setTitle("Movimientos", forSegmentAt: 2)
        segmentedTabs?.selectedSegmentIndex = Mode.almacenes.rawValue
        segmentedTabs?.addTarget(self, action: #selector(tabChanged), for: .valueChanged)

        tableView?.register(AlmacenTableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.rowHeight = 136
        tableView?.estimatedRowHeight = 136
        tableView?.separatorStyle = .none
        tableView?.tableFooterView = UIView()
        tableView?.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 24, right: 0)
        tableView?.showsVerticalScrollIndicator = false

        [summaryCardView, alertCardView].forEach { view in
            view?.layer.cornerRadius = 18
            view?.clipsToBounds = true
        }

        btnRegistrar?.layer.cornerRadius = 14
        btnRegistrar?.clipsToBounds = true

        [lblResumen, lblValorStock, lblAlmacenes, lblProductos, lblValorRed, lblEntradas, lblSalidas, lblTransferencias, lblBajoMinimo, lblAlerta].forEach { label in
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.72
        }
        lblAlerta?.numberOfLines = 2
    }

    private func configureRoleAccess() {
        btnRegistrar?.isHidden = RoleAccessControl.canManageWarehouse == false
        btnRegistrar?.isEnabled = RoleAccessControl.canManageWarehouse
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
            lblTitulo,
            lblResumen,
            segmentedTabs,
            lblValorStock,
            lblAlmacenes,
            lblProductos,
            lblValorRed,
            lblEntradas,
            lblSalidas,
            lblTransferencias,
            lblBajoMinimo,
            lblAlerta,
            tableView,
            summaryCardView,
            alertCardView,
            btnRegistrar
        ].forEach { $0?.isHidden = true }
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    private func resetWarehouseModuleCache() {
        context.performAndWait {
            do {
                try deleteAll(entityName: "MovimientoInventarioEntity")
                try deleteAll(entityName: "StockAlmacenEntity")
                try deleteAll(entityName: "ProductoEntity")
                try deleteAll(entityName: "AlmacenEntity")
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
            }
        }
    }

    private func deleteAll(entityName: String) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        }
    }

    private func observeRemoteSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteSyncStateChanged),
            name: .remoteSyncStateDidChange,
            object: nil
        )
    }

    @objc
    private func handleRemoteSyncStateChanged() {
        loadData()
    }

    private func seedInitialWarehouseDataIfNeeded() {
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            return
        }

        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.fetchLimit = 1

        do {
            let hasWarehouses = try context.count(for: request) > 0
            if !hasWarehouses {
                createWarehouse(name: "Main Station", address: "Av. La Marina 245, Lima", responsible: "Luis Torres")
                createWarehouse(name: "North Depot", address: "Av. Túpac Amaru 890, Lima", responsible: "Ana Flores")
                createWarehouse(name: "South Point", address: "Carretera Central Km 12, Lima", responsible: "Jorge Salinas")
            }

            let productRequest: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
            productRequest.fetchLimit = 1
            if try context.count(for: productRequest) == 0 {
                createProduct(name: "Gasoline 90", price: 5.64, minimum: 500, capacity: 12000)
                createProduct(name: "Gasoline 95", price: 7.10, minimum: 400, capacity: 9000)
                createProduct(name: "Diesel B5", price: 5.10, minimum: 600, capacity: 14000)
            }

            try context.save()
            loadAlmacenes()
            loadProductos()
            createInitialStocksIfNeeded()
            try context.save()
        } catch {
            print("No se pudo preparar almacén: \(error.localizedDescription)")
        }
    }

    private func createWarehouse(name: String, address: String, responsible: String) {
        let almacen = AlmacenEntity(context: context)
        almacen.id = UUID()
        almacen.nombre = name
        almacen.direccion = address
        almacen.responsable = responsible
        almacen.activo = true
    }

    private func createProduct(name: String, price: Double, minimum: Double, capacity: Double) {
        let product = ProductoEntity(context: context)
        product.id = UUID()
        product.nombre = name
        product.tipo = "Combustible"
        product.unidadMedida = "L"
        product.precioPorLitro = price
        product.stockMinimo = minimum
        product.capacidadTotal = capacity
        product.stockLitros = 0
        product.activo = true
    }

    private func createInitialStocksIfNeeded() {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        guard ((try? context.count(for: request)) ?? 0) == 0 else { return }

        for almacen in almacenes {
            for (index, product) in productos.enumerated() {
                let stock = StockAlmacenEntity(context: context)
                stock.id = UUID()
                stock.almacen = almacen
                stock.producto = product
                stock.unidadMedida = product.unidadMedida ?? "L"
                stock.capacidadTotal = product.capacidadTotal
                stock.stockMinimo = product.stockMinimo
                let initialAmount = initialStock(for: almacen.nombre ?? "", productIndex: index, capacity: product.capacidadTotal)
                stock.stockActual = initialAmount
                if initialAmount > 0 {
                    createInitialStockMovement(product: product, almacen: almacen, amount: initialAmount)
                }
            }
        }
        updateProductTotals()
    }

    private func createInitialStockMovement(product: ProductoEntity, almacen: AlmacenEntity, amount: Double) {
        let movimiento = MovimientoInventarioEntity(context: context)
        movimiento.id = UUID()
        movimiento.fecha = Date()
        movimiento.tipo = "entrada"
        movimiento.cantidadLitros = amount
        movimiento.producto = product
        movimiento.almacen = almacen
        movimiento.origen = "Stock inicial"
        movimiento.destino = almacen.nombre
        movimiento.nota = "Carga inicial de inventario"
    }

    private func initialStock(for warehouse: String, productIndex: Int, capacity: Double) -> Double {
        let base: [Double]
        if warehouse.contains("Main") {
            base = [0.58, 0.42, 0.32]
        } else if warehouse.contains("North") {
            base = [0.43, 0.31, 0.45]
        } else {
            base = [0.25, 0.19, 0.22]
        }
        return capacity * base[min(productIndex, base.count - 1)]
    }

    private func loadData() {
        loadAlmacenes()
        loadProductos()
        loadStocks()
        loadMovimientos()
        updateProductTotals()
        updateMetrics()
        applyMode()
        refreshHybridView()
    }

    private func refreshHybridView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> WarehouseDashboardView {
        WarehouseDashboardView(
            data: makeDashboardData(),
            onRegister: { [weak self] in
                self?.presentRegisterSheet()
            },
            onSelectWarehouse: { [weak self] warehouseId in
                self?.showWarehouseDetail(warehouseId: warehouseId)
            }
        )
    }

    private func makeDashboardData() -> WarehouseDashboardData {
        let valorTotal = productos.reduce(0.0) { $0 + ($1.stockLitros * $1.precioPorLitro) }
        let bajoMinimo = stocks.filter { $0.stockActual > 0 && $0.stockActual < minimum(for: $0) }.count
        let entradas = movimientos.filter { $0.tipo == "entrada" }.reduce(0.0) { $0 + max($1.cantidadLitros, 0) }
        let salidas = movimientos.filter { $0.tipo == "salida" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }
        let transferencias = movimientos.filter { $0.tipo == "transfer" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }

        let summaryMetrics = [
            WarehouseDashboardData.SummaryMetric(title: "ENTRADA", value: formatLitersValue(entradas), colorHex: "22C55E"),
            WarehouseDashboardData.SummaryMetric(title: "SALIDA", value: formatLitersValue(salidas), colorHex: "EF4444"),
            WarehouseDashboardData.SummaryMetric(title: "TRANSFER", value: formatLitersValue(transferencias), colorHex: "8B5CF6"),
            WarehouseDashboardData.SummaryMetric(title: "BAJO", value: "\(bajoMinimo)", colorHex: "F59E0B")
        ]

        let warehouseFilters = almacenes.enumerated().map { index, almacen in
            WarehouseDashboardData.WarehouseFilter(
                id: almacen.id?.uuidString ?? "\(index)",
                title: shortWarehouseName(almacen.nombre ?? "Almacén"),
                colorHex: warehouseColorHex(for: index)
            )
        }

        let warehouseCards = almacenes.enumerated().map { index, almacen in
            let warehouseStocks = stocks.filter { $0.almacen == almacen }
            let totalLiters = warehouseStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = warehouseStocks.reduce(0.0) { $0 + capacity(for: $1) }
            let lowCount = warehouseStocks.filter { $0.stockActual > 0 && $0.stockActual < minimum(for: $0) }.count
            let warehouseValue = warehouseStocks.reduce(0.0) { partial, stock in
                partial + (stock.stockActual * (stock.producto?.precioPorLitro ?? 0))
            }

            return WarehouseDashboardData.WarehouseCard(
                id: almacen.id?.uuidString ?? "\(index)",
                name: almacen.nombre ?? "Almacén",
                shortName: shortWarehouseName(almacen.nombre ?? "Almacén"),
                address: almacen.direccion ?? "Sin dirección",
                colorHex: warehouseColorHex(for: index),
                totalStockText: formatLitersValue(totalLiters),
                totalCapacityText: formatLitersValue(totalCapacity),
                fillRatio: totalCapacity > 0 ? min(totalLiters / totalCapacity, 1) : 0,
                levelText: "Nivel — \(Int((totalCapacity > 0 ? totalLiters / totalCapacity : 0) * 100))%",
                productsText: "\(warehouseStocks.count) productos",
                lowStockText: lowCount > 0 ? "\(lowCount) bajo" : nil,
                valueText: formatCurrency(warehouseValue)
            )
        }

        let productCards = productos.map { producto in
            let productStocks = stocks.filter { $0.producto == producto }
            let totalStock = productStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = productStocks.reduce(0.0) { $0 + capacity(for: $1) }
            let totalValue = totalStock * producto.precioPorLitro
            let isLow = totalStock < producto.stockMinimo
            let meta = fuelMeta(for: producto)

            return WarehouseDashboardData.ProductCard(
                id: producto.id?.uuidString ?? UUID().uuidString,
                name: producto.nombre ?? "Producto",
                priceText: "\(formatCurrency(producto.precioPorLitro)) / \(producto.unidadMedida ?? "L")",
                minimumText: formatLitersValue(producto.stockMinimo),
                totalStockText: formatLitersValue(totalStock),
                totalValueText: formatCurrency(totalValue),
                fillRatio: totalCapacity > 0 ? min(totalStock / totalCapacity, 1) : 0,
                colorHex: meta.colorHex,
                bgHex: meta.bgHex,
                symbolName: meta.symbolName,
                isLow: isLow,
                stocks: productStocks.enumerated().map { stockIndex, stock in
                    WarehouseDashboardData.WarehouseProductStock(
                        warehouseName: shortWarehouseName(stock.almacen?.nombre ?? "Almacén"),
                        colorHex: warehouseColorHex(for: stockIndex),
                        stockText: formatLitersValue(stock.stockActual),
                        fillRatio: capacity(for: stock) > 0 ? min(stock.stockActual / capacity(for: stock), 1) : 0,
                        isLow: stock.stockActual > 0 && stock.stockActual < minimum(for: stock)
                    )
                }
            )
        }

        let movementCards = movimientos.map { movimiento in
            let type = dashboardMovementType(for: movimiento.tipo ?? "")
            let meta = fuelMeta(for: movimiento.producto)
            let amountValue = abs(movimiento.cantidadLitros)
            let quantityPrefix: String
            switch type {
            case .entrada:
                quantityPrefix = "+"
            case .salida:
                quantityPrefix = "−"
            case .transfer:
                quantityPrefix = "⇄"
            }

            return WarehouseDashboardData.MovementCard(
                id: movimiento.id?.uuidString ?? UUID().uuidString,
                warehouseId: movimiento.almacen?.id?.uuidString ?? "",
                destinationWarehouseId: almacenes.first(where: { $0.nombre == movimiento.destino })?.id?.uuidString,
                productName: movimiento.producto?.nombre ?? "Movimiento",
                type: type,
                quantityText: "\(quantityPrefix)\(formatLitersValue(amountValue))",
                note: movementDescription(movimiento),
                actorText: movementActorText(movimiento),
                dateText: formatDate(movimiento.fecha),
                sourceChipText: movementSourceText(movimiento, type: type),
                sourceChipIcon: movementSourceIcon(type: type),
                destinationChipText: movementDestinationText(movimiento, type: type),
                destinationChipIcon: movementDestinationIcon(type: type),
                colorHex: typeColorHex(type),
                bgHex: typeBackgroundHex(type),
                accentHex: typeColorHex(type),
                symbolName: meta.symbolName
            )
        }

        return WarehouseDashboardData(
            title: "Almacén",
            subtitle: "\(almacenes.count) ubicaciones · \(formatCurrency(valorTotal)) valor · \(bajoMinimo) bajo",
            canRegister: RoleAccessControl.canManageWarehouse,
            inventoryValueText: formatCurrency(valorTotal),
            totalWarehousesText: "\(almacenes.count) almacenes",
            summaryMetrics: summaryMetrics,
            lowStockBannerText: bajoMinimo > 0 ? "\(bajoMinimo) productos bajo el mínimo en la red" : nil,
            warehouseFilters: warehouseFilters,
            warehouseCards: warehouseCards,
            productCards: productCards,
            movementCards: movementCards
        )
    }

    private func presentRegisterSheet() {
        guard RoleAccessControl.canManageWarehouse else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .manageWarehouse))
            return
        }
        let sheet = UIAlertController(title: "Registrar", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Almacén", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "mostrarModalAlmacen", sender: nil)
        })
        sheet.addAction(UIAlertAction(title: "Producto", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "mostrarModalProducto", sender: nil)
        })
        sheet.addAction(UIAlertAction(title: "Movimiento", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "mostrarModalMovimientos", sender: nil)
        })
        sheet.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(sheet, animated: true)
    }

    private func showWarehouseDetail(warehouseId: String) {
        guard almacenes.contains(where: { $0.id?.uuidString == warehouseId }) else { return }
        performSegue(withIdentifier: "mostrarModalMovimientos", sender: nil)
    }

    private func loadAlmacenes() {
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        almacenes = (try? context.fetch(request)) ?? []
    }

    private func loadProductos() {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        productos = (try? context.fetch(request)) ?? []
    }

    private func loadStocks() {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "almacen.nombre", ascending: true),
            NSSortDescriptor(key: "producto.nombre", ascending: true)
        ]
        stocks = (try? context.fetch(request)) ?? []
    }

    private func loadMovimientos() {
        let request: NSFetchRequest<MovimientoInventarioEntity> = MovimientoInventarioEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        movimientos = (try? context.fetch(request)) ?? []
    }

    private func updateProductTotals() {
        for product in productos {
            product.stockLitros = stocks
                .filter { $0.producto == product }
                .reduce(0) { $0 + $1.stockActual }
        }
    }

    private func updateMetrics() {
        let stockTotal = stocks.reduce(0.0) { $0 + $1.stockActual }
        let valorTotal = productos.reduce(0.0) { $0 + ($1.stockLitros * $1.precioPorLitro) }
        let bajoMinimo = stocks.filter { $0.stockActual > 0 && $0.stockActual < minimum(for: $0) }.count
        let entradas = movimientos.filter { $0.tipo == "entrada" }.reduce(0.0) { $0 + max($1.cantidadLitros, 0) }
        let salidas = movimientos.filter { $0.tipo == "salida" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }
        let transferencias = movimientos.filter { $0.tipo == "transfer" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }

        lblResumen?.text = "\(almacenes.count) ubicaciones · \(formatLiters(stockTotal)) valor · \(bajoMinimo) bajo"
        lblValorStock?.text = formatCurrency(valorTotal)
        lblAlmacenes?.text = "\(almacenes.count) almacenes"
        lblProductos?.text = "\(productos.count)"
        lblValorRed?.text = formatCurrency(valorTotal)
        lblEntradas?.text = formatLiters(entradas)
        lblSalidas?.text = formatLiters(salidas)
        lblTransferencias?.text = formatLiters(transferencias)
        lblBajoMinimo?.text = "\(bajoMinimo)"
        lblAlerta?.text = bajoMinimo == 0
            ? "Stock estable en la red."
            : "\(bajoMinimo) producto(s) bajo el mínimo. Registra un movimiento para reponer stock."
    }

    private func applyMode() {
        switch mode {
        case .almacenes:
            rows = almacenes.map { .almacen($0) }
        case .productos:
            rows = productos.map { .producto($0) }
        case .movimientos:
            rows = movimientos.map { .movimiento($0) }
        }
        tableView?.reloadData()
    }

    @objc
    private func tabChanged() {
        mode = Mode(rawValue: segmentedTabs?.selectedSegmentIndex ?? 0) ?? .almacenes
        applyMode()
    }

    @IBAction private func btnRegistrarTapped(_ sender: UIButton) {
        presentRegisterSheet()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let modal = segue.destination as? ModalAlmacenViewController {
            modal.delegate = self
        } else if let modal = segue.destination as? ModalProductoViewController {
            modal.delegate = self
        } else if let modal = segue.destination as? ModalMovimientoViewController {
            modal.delegate = self
        }
    }

    private func minimum(for stock: StockAlmacenEntity) -> Double {
        stock.stockMinimo > 0 ? stock.stockMinimo : (stock.producto?.stockMinimo ?? 0)
    }

    private func capacity(for stock: StockAlmacenEntity) -> Double {
        stock.capacidadTotal > 0 ? stock.capacidadTotal : max(stock.producto?.capacidadTotal ?? 1, 1)
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func formatLiters(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        return "\(rounded.formatted()) L"
    }

    private func formatLitersValue(_ amount: Double) -> String {
        Int(amount.rounded()).formatted()
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private func shortWarehouseName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.first.map(String.init) ?? name
    }

    private func warehouseColorHex(for index: Int) -> String {
        let palette = ["3B82F6", "22C55E", "F59E0B", "8B5CF6", "EF4444"]
        return palette[index % palette.count]
    }

    private func dashboardMovementType(for rawType: String) -> WarehouseDashboardData.MovementType {
        switch rawType.lowercased() {
        case "entrada":
            return .entrada
        case "salida":
            return .salida
        default:
            return .transfer
        }
    }

    private func typeColorHex(_ type: WarehouseDashboardData.MovementType) -> String {
        switch type {
        case .entrada:
            return "22C55E"
        case .salida:
            return "EF4444"
        case .transfer:
            return "8B5CF6"
        }
    }

    private func typeBackgroundHex(_ type: WarehouseDashboardData.MovementType) -> String {
        switch type {
        case .entrada:
            return "F0FDF4"
        case .salida:
            return "FEF2F2"
        case .transfer:
            return "F5F3FF"
        }
    }

    private func movementDescription(_ movimiento: MovimientoInventarioEntity) -> String {
        if let note = movimiento.nota, note.isEmpty == false {
            return note
        }
        let origen = movimiento.origen ?? "Origen"
        let destino = movimiento.destino ?? movimiento.almacen?.nombre ?? "Destino"
        return "\(origen) → \(destino)"
    }

    private func movementActorText(_ movimiento: MovimientoInventarioEntity) -> String {
        if let note = movimiento.nota?.lowercased() {
            if note.contains("compra") { return "Ingreso de stock" }
            if note.contains("venta") { return "Salida de stock" }
            if note.contains("transfer") { return "Transferencia" }
        }
        return "Movimiento"
    }

    private func movementSourceText(_ movimiento: MovimientoInventarioEntity, type: WarehouseDashboardData.MovementType) -> String? {
        switch type {
        case .entrada:
            return movimiento.origen ?? "Proveedor"
        case .salida, .transfer:
            return shortWarehouseName(movimiento.almacen?.nombre ?? movimiento.origen ?? "Origen")
        }
    }

    private func movementDestinationText(_ movimiento: MovimientoInventarioEntity, type: WarehouseDashboardData.MovementType) -> String? {
        switch type {
        case .entrada:
            return shortWarehouseName(movimiento.almacen?.nombre ?? movimiento.destino ?? "Destino")
        case .salida:
            return movimiento.destino ?? "Sin cliente"
        case .transfer:
            return shortWarehouseName(movimiento.destino ?? "Destino")
        }
    }

    private func movementSourceIcon(type: WarehouseDashboardData.MovementType) -> String {
        switch type {
        case .entrada:
            return "shippingbox"
        case .salida, .transfer:
            return "building.2"
        }
    }

    private func movementDestinationIcon(type: WarehouseDashboardData.MovementType) -> String {
        switch type {
        case .entrada, .transfer:
            return "building.2"
        case .salida:
            return "person"
        }
    }

    private func fuelMeta(for producto: ProductoEntity?) -> (colorHex: String, bgHex: String, symbolName: String) {
        let name = producto?.nombre?.lowercased() ?? ""
        if name.contains("90") {
            return ("3B82F6", "EFF6FF", "drop.fill")
        }
        if name.contains("95") {
            return ("8B5CF6", "F5F3FF", "drop.fill")
        }
        if name.contains("diesel") {
            return ("F59E0B", "FFFBEB", "drop.fill")
        }
        if name.contains("glp") {
            return ("10B981", "ECFDF5", "flame.fill")
        }
        return ("6B7280", "F3F4F6", "drop.fill")
    }

    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        guard let almacenCell = cell as? AlmacenTableViewCell else { return cell }

        switch rows[indexPath.row] {
        case .almacen(let almacen):
            let warehouseStocks = stocks.filter { $0.almacen == almacen }
            let totalLiters = warehouseStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = warehouseStocks.reduce(0.0) { $0 + capacity(for: $1) }
            let lowCount = warehouseStocks.filter { $0.stockActual > 0 && $0.stockActual < minimum(for: $0) }.count
            almacenCell.configure(
                accent: lowCount > 0
                    ? UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
                    : UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1),
                title: almacen.nombre ?? "Almacén",
                subtitle: almacen.responsable ?? "Sin responsable",
                detail: almacen.direccion ?? "Sin dirección",
                amount: formatLiters(totalLiters),
                progress: CGFloat(min(totalLiters / max(totalCapacity, 1), 1)),
                status: lowCount > 0 ? "\(lowCount) bajo" : "Activo"
            )
        case .stock(let stock):
            let isLow = stock.stockActual < minimum(for: stock)
            let productName = stock.producto?.nombre ?? "Producto"
            let warehouseName = stock.almacen?.nombre ?? "Almacén"
            almacenCell.configure(
                accent: isLow ? UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1),
                title: productName,
                subtitle: warehouseName,
                detail: "Min \(formatLiters(minimum(for: stock))) · Cap \(formatLiters(capacity(for: stock)))",
                amount: formatLiters(stock.stockActual),
                progress: CGFloat(min(stock.stockActual / capacity(for: stock), 1)),
                status: isLow ? "Stock Bajo" : "OK"
            )
        case .producto(let producto):
            let minimum = producto.stockMinimo
            let low = producto.stockLitros < minimum
            almacenCell.configure(
                accent: low ? UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1),
                title: producto.nombre ?? "Producto",
                subtitle: "\(formatCurrency(producto.precioPorLitro)) / \(producto.unidadMedida ?? "L")",
                detail: "Stock total consolidado · Min \(formatLiters(minimum))",
                amount: formatLiters(producto.stockLitros),
                progress: CGFloat(min(producto.stockLitros / max(producto.capacidadTotal * Double(max(almacenes.count, 1)), 1), 1)),
                status: low ? "Bajo" : "OK"
            )
        case .movimiento(let movimiento):
            let tipo = movimiento.tipo ?? "evento"
            let color = colorForMovement(tipo)
            almacenCell.configure(
                accent: color,
                title: movimiento.producto?.nombre ?? "Movimiento",
                subtitle: "\(tipo.uppercased()) · \(formatDate(movimiento.fecha))",
                detail: movimiento.nota?.isEmpty == false ? movimiento.nota! : "\(movimiento.origen ?? "Origen") → \(movimiento.destino ?? movimiento.almacen?.nombre ?? "Destino")",
                amount: formatLiters(movimiento.cantidadLitros),
                progress: 1,
                status: tipo.capitalized
            )
        }

        return almacenCell
    }

    private func colorForMovement(_ type: String) -> UIColor {
        switch type {
        case "entrada":
            return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
        case "salida":
            return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        case "transfer":
            return UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1)
        default:
            return UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
        }
    }
}

extension AlmaceneroViewController: ModalAlmacenViewControllerDelegate, ModalProductoViewControllerDelegate, ModalMovimientoViewControllerDelegate {

    func modalAlmacenViewControllerDidSave(_ controller: ModalAlmacenViewController) {
        loadData()
    }

    func modalProductoViewControllerDidSave(_ controller: ModalProductoViewController) {
        loadData()
    }

    func modalMovimientoViewControllerDidSave(_ controller: ModalMovimientoViewController) {
        loadData()
    }
}

private final class AlmacenTableViewCell: UITableViewCell {

    private let cardView = UIView()
    private let topLine = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressBackground = UIView()
    private let progressBar = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?

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

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.addSubview(cardView)

        [topLine, titleLabel, subtitleLabel, detailLabel, amountLabel, statusLabel, progressBackground, progressBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75

        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.75

        amountLabel.font = .systemFont(ofSize: 16, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.72

        statusLabel.font = .systemFont(ofSize: 11, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true

        progressBackground.backgroundColor = UIColor(red: 0.935, green: 0.941, blue: 0.961, alpha: 1)
        progressBackground.layer.cornerRadius = 3
        progressBackground.clipsToBounds = true
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true

        [topLine, titleLabel, subtitleLabel, statusLabel, amountLabel, detailLabel, progressBackground].forEach { cardView.addSubview($0) }
        progressBackground.addSubview(progressBar)

        progressWidthConstraint = progressBar.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: 0.1)
        progressWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            topLine.topAnchor.constraint(equalTo: cardView.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 3),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),
            statusLabel.heightAnchor.constraint(equalToConstant: 22),

            amountLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            amountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),

            progressBackground.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressBackground.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            progressBackground.heightAnchor.constraint(equalToConstant: 6),

            progressBar.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),

            detailLabel.topAnchor.constraint(equalTo: progressBackground.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18)
        ])
    }

    func configure(accent: UIColor, title: String, subtitle: String, detail: String, amount: String, progress: CGFloat, status: String) {
        topLine.backgroundColor = accent
        progressBar.backgroundColor = accent
        statusLabel.text = status
        statusLabel.textColor = accent
        statusLabel.backgroundColor = accent.withAlphaComponent(0.12)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        detailLabel.text = detail
        amountLabel.text = amount

        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: min(max(progress, 0.06), 1))
        progressWidthConstraint?.isActive = true
    }
}
