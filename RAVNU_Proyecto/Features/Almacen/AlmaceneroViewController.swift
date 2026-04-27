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

    private enum Modo: Int {
        case almacenes = 0
        case productos = 1
        case movimientos = 2
    }

    private enum Fila {
        case almacen(AlmacenEntity)
        case stock(StockAlmacenEntity)
        case producto(ProductoEntity)
        case movimiento(MovimientoInventarioEntity)
    }

    private let identificadorCelda = "almacenCell"
    private var almacenes: [AlmacenEntity] = []
    private var productos: [ProductoEntity] = []
    private var stocks: [StockAlmacenEntity] = []
    private var movimientos: [MovimientoInventarioEntity] = []
    private var filas: [Fila] = []
    private var modo: Modo = .almacenes
    private var hostingController: UIHostingController<WarehouseDashboardView>?

    private let contexto = AppCoreData.viewContext

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
        observarSincronizacionRemota()
        cargarDatos()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            RemoteSyncCoordinator.shared.startInitialSyncIfPossible()
        }
        cargarDatos()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurarUI() {
        lblTitulo?.text = "Almacén"
        segmentedTabs?.setTitle("Almacenes", forSegmentAt: 0)
        segmentedTabs?.setTitle("Productos", forSegmentAt: 1)
        segmentedTabs?.setTitle("Movimientos", forSegmentAt: 2)
        segmentedTabs?.selectedSegmentIndex = Modo.almacenes.rawValue
        segmentedTabs?.addTarget(self, action: #selector(tabChanged), for: .valueChanged)

        tableView?.register(AlmacenTableViewCell.self, forCellReuseIdentifier: identificadorCelda)
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

    private func configurarAccesoPorRol() {
        btnRegistrar?.isHidden = RoleAccessControl.canManageWarehouse == false
        btnRegistrar?.isEnabled = RoleAccessControl.canManageWarehouse
    }

    private func configurarVistaHibrida() {
        ocultarVistaLegacy()
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

    private func ocultarVistaLegacy() {
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

    private func observarSincronizacionRemota() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(manejarCambioSincronizacionRemota),
            name: .remoteSyncStateDidChange,
            object: nil
        )
    }

    @objc
    private func manejarCambioSincronizacionRemota() {
        cargarDatos()
    }

    private func cargarDatos() {
        cargarAlmacenes()
        cargarProductos()
        cargarStocks()
        cargarMovimientos()
        actualizarTotalesProducto()
        actualizarMetricas()
        aplicarModo()
        actualizarVistaHibrida()
    }

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaRaiz()
    }

    private func crearVistaRaiz() -> WarehouseDashboardView {
        WarehouseDashboardView(
            data: crearDatosDashboard(),
            onRegister: { [weak self] in
                self?.presentRegisterSheet()
            },
            onSelectWarehouse: { [weak self] warehouseId in
                self?.mostrarDetalleAlmacen(warehouseId: warehouseId)
            }
        )
    }

    private func crearDatosDashboard() -> DatosDashboardAlmacen {
        let valorTotal = productos.reduce(0.0) { $0 + ($1.stockLitros * $1.precioPorLitro) }
        let bajoMinimo = stocks.filter { $0.stockActual > 0 && $0.stockActual < minimo(for: $0) }.count
        let entradas = movimientos.filter { $0.tipo == "entrada" }.reduce(0.0) { $0 + max($1.cantidadLitros, 0) }
        let salidas = movimientos.filter { $0.tipo == "salida" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }
        let transferencias = movimientos.filter { $0.tipo == "transfer" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }

        let summaryMetrics = [
            DatosDashboardAlmacen.MetricaResumen(title: "ENTRADA", value: formatearValorLitros(entradas), colorHex: "22C55E"),
            DatosDashboardAlmacen.MetricaResumen(title: "SALIDA", value: formatearValorLitros(salidas), colorHex: "EF4444"),
            DatosDashboardAlmacen.MetricaResumen(title: "TRANSF.", value: formatearValorLitros(transferencias), colorHex: "8B5CF6"),
            DatosDashboardAlmacen.MetricaResumen(title: "BAJO", value: "\(bajoMinimo)", colorHex: "F59E0B")
        ]

        let warehouseFilters = almacenes.enumerated().map { index, almacen in
            DatosDashboardAlmacen.FiltroAlmacen(
                id: almacen.id?.uuidString ?? "\(index)",
                title: nombreCortoAlmacen(almacen.nombre ?? "Almacén"),
                colorHex: warehouseColorHex(for: index)
            )
        }

        let warehouseCards = almacenes.enumerated().map { index, almacen in
            let warehouseStocks = stocks.filter { $0.almacen == almacen }
            let totalLiters = warehouseStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = warehouseStocks.reduce(0.0) { $0 + capacidad(for: $1) }
            let lowCount = warehouseStocks.filter { $0.stockActual > 0 && $0.stockActual < minimo(for: $0) }.count
            let warehouseValue = warehouseStocks.reduce(0.0) { partial, stock in
                partial + (stock.stockActual * (stock.producto?.precioPorLitro ?? 0))
            }

            return DatosDashboardAlmacen.TarjetaAlmacen(
                id: almacen.id?.uuidString ?? "\(index)",
                name: almacen.nombre ?? "Almacén",
                shortName: nombreCortoAlmacen(almacen.nombre ?? "Almacén"),
                address: almacen.direccion ?? "Sin dirección",
                colorHex: warehouseColorHex(for: index),
                totalStockText: formatearValorLitros(totalLiters),
                totalCapacityText: formatearValorLitros(totalCapacity),
                fillRatio: totalCapacity > 0 ? min(totalLiters / totalCapacity, 1) : 0,
                levelText: "Nivel — \(Int((totalCapacity > 0 ? totalLiters / totalCapacity : 0) * 100))%",
                productsText: "\(warehouseStocks.count) productos",
                lowStockText: lowCount > 0 ? "\(lowCount) bajo" : nil,
                valueText: formatearMoneda(warehouseValue)
            )
        }

        let productCards = productos.map { producto in
            let productStocks = stocks.filter { $0.producto == producto }
            let totalStock = productStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = productStocks.reduce(0.0) { $0 + capacidad(for: $1) }
            let totalValue = totalStock * producto.precioPorLitro
            let isLow = totalStock < producto.stockMinimo
            let meta = fuelMeta(for: producto)

            return DatosDashboardAlmacen.TarjetaProducto(
                id: producto.id?.uuidString ?? UUID().uuidString,
                name: producto.nombre ?? "Producto",
                priceText: "\(formatearMoneda(producto.precioPorLitro)) / \(producto.unidadMedida ?? "L")",
                minimumText: formatearValorLitros(producto.stockMinimo),
                totalStockText: formatearValorLitros(totalStock),
                totalValueText: formatearMoneda(totalValue),
                fillRatio: totalCapacity > 0 ? min(totalStock / totalCapacity, 1) : 0,
                colorHex: meta.colorHex,
                bgHex: meta.bgHex,
                symbolName: meta.symbolName,
                isLow: isLow,
                stocks: productStocks.enumerated().map { stockIndex, stock in
                    DatosDashboardAlmacen.StockProductoPorAlmacen(
                        warehouseName: nombreCortoAlmacen(stock.almacen?.nombre ?? "Almacén"),
                        colorHex: warehouseColorHex(for: stockIndex),
                        stockText: formatearValorLitros(stock.stockActual),
                        fillRatio: capacidad(for: stock) > 0 ? min(stock.stockActual / capacidad(for: stock), 1) : 0,
                        isLow: stock.stockActual > 0 && stock.stockActual < minimo(for: stock)
                    )
                }
            )
        }

        let movementCards = movimientos.map { movimiento in
            let type = tipoMovimientoDashboard(for: movimiento.tipo ?? "")
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

            return DatosDashboardAlmacen.TarjetaMovimiento(
                id: movimiento.id?.uuidString ?? UUID().uuidString,
                warehouseId: movimiento.almacen?.id?.uuidString ?? "",
                destinationWarehouseId: almacenes.first(where: { $0.nombre == movimiento.destino })?.id?.uuidString,
                productName: movimiento.producto?.nombre ?? "Movimiento",
                type: type,
                quantityText: "\(quantityPrefix)\(formatearValorLitros(amountValue))",
                note: descripcionMovimiento(movimiento),
                actorText: textoActorMovimiento(movimiento),
                dateText: formatearFecha(movimiento.fecha),
                sourceChipText: textoOrigenMovimiento(movimiento, type: type),
                sourceChipIcon: iconoOrigenMovimiento(type: type),
                destinationChipText: textoDestinoMovimiento(movimiento, type: type),
                destinationChipIcon: iconoDestinoMovimiento(type: type),
                colorHex: typeColorHex(type),
                bgHex: typeBackgroundHex(type),
                accentHex: typeColorHex(type),
                symbolName: meta.symbolName
            )
        }

        return DatosDashboardAlmacen(
            title: "Almacén",
            subtitle: "\(almacenes.count) ubicaciones · \(formatearMoneda(valorTotal)) valor · \(bajoMinimo) bajo",
            canRegister: RoleAccessControl.canManageWarehouse,
            inventoryValueText: formatearMoneda(valorTotal),
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

    private func mostrarDetalleAlmacen(warehouseId: String) {
        guard almacenes.contains(where: { $0.id?.uuidString == warehouseId }) else { return }
        performSegue(withIdentifier: "mostrarModalMovimientos", sender: nil)
    }

    private func cargarAlmacenes() {
        let request: NSFetchRequest<AlmacenEntity> = AlmacenEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        almacenes = (try? contexto.fetch(request)) ?? []
    }

    private func cargarProductos() {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        productos = (try? contexto.fetch(request)) ?? []
    }

    private func cargarStocks() {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "almacen.nombre", ascending: true),
            NSSortDescriptor(key: "producto.nombre", ascending: true)
        ]
        stocks = (try? contexto.fetch(request)) ?? []
    }

    private func cargarMovimientos() {
        let request: NSFetchRequest<MovimientoInventarioEntity> = MovimientoInventarioEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        movimientos = (try? contexto.fetch(request)) ?? []
    }

    private func actualizarTotalesProducto() {
        for product in productos {
            product.stockLitros = stocks
                .filter { $0.producto == product }
                .reduce(0) { $0 + $1.stockActual }
        }
    }

    private func actualizarMetricas() {
        let stockTotal = stocks.reduce(0.0) { $0 + $1.stockActual }
        let valorTotal = productos.reduce(0.0) { $0 + ($1.stockLitros * $1.precioPorLitro) }
        let bajoMinimo = stocks.filter { $0.stockActual > 0 && $0.stockActual < minimo(for: $0) }.count
        let entradas = movimientos.filter { $0.tipo == "entrada" }.reduce(0.0) { $0 + max($1.cantidadLitros, 0) }
        let salidas = movimientos.filter { $0.tipo == "salida" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }
        let transferencias = movimientos.filter { $0.tipo == "transfer" }.reduce(0.0) { $0 + abs($1.cantidadLitros) }

        lblResumen?.text = "\(almacenes.count) ubicaciones · \(formatearLitros(stockTotal)) valor · \(bajoMinimo) bajo"
        lblValorStock?.text = formatearMoneda(valorTotal)
        lblAlmacenes?.text = "\(almacenes.count) almacenes"
        lblProductos?.text = "\(productos.count)"
        lblValorRed?.text = formatearMoneda(valorTotal)
        lblEntradas?.text = formatearLitros(entradas)
        lblSalidas?.text = formatearLitros(salidas)
        lblTransferencias?.text = formatearLitros(transferencias)
        lblBajoMinimo?.text = "\(bajoMinimo)"
        lblAlerta?.text = bajoMinimo == 0
            ? "Stock estable en la red."
            : "\(bajoMinimo) producto(s) bajo el mínimo. Registra un movimiento para reponer stock."
    }

    private func aplicarModo() {
        switch modo {
        case .almacenes:
            filas = almacenes.map { .almacen($0) }
        case .productos:
            filas = productos.map { .producto($0) }
        case .movimientos:
            filas = movimientos.map { .movimiento($0) }
        }
        tableView?.reloadData()
    }

    @objc
    private func tabChanged() {
        modo = Modo(rawValue: segmentedTabs?.selectedSegmentIndex ?? 0) ?? .almacenes
        aplicarModo()
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

    private func minimo(for stock: StockAlmacenEntity) -> Double {
        stock.stockMinimo > 0 ? stock.stockMinimo : (stock.producto?.stockMinimo ?? 0)
    }

    private func capacidad(for stock: StockAlmacenEntity) -> Double {
        stock.capacidadTotal > 0 ? stock.capacidadTotal : max(stock.producto?.capacidadTotal ?? 1, 1)
    }

    private func formatearMoneda(_ amount: Double) -> String {
        formateadorMoneda.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func formatearLitros(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        return "\(rounded.formatted()) L"
    }

    private func formatearValorLitros(_ amount: Double) -> String {
        Int(amount.rounded()).formatted()
    }

    private func formatearFecha(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private func nombreCortoAlmacen(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.first.map(String.init) ?? name
    }

    private func warehouseColorHex(for index: Int) -> String {
        let palette = ["3B82F6", "22C55E", "F59E0B", "8B5CF6", "EF4444"]
        return palette[index % palette.count]
    }

    private func tipoMovimientoDashboard(for rawType: String) -> DatosDashboardAlmacen.TipoMovimiento {
        switch rawType.lowercased() {
        case "entrada":
            return .entrada
        case "salida":
            return .salida
        default:
            return .transfer
        }
    }

    private func typeColorHex(_ type: DatosDashboardAlmacen.TipoMovimiento) -> String {
        switch type {
        case .entrada:
            return "22C55E"
        case .salida:
            return "EF4444"
        case .transfer:
            return "8B5CF6"
        }
    }

    private func typeBackgroundHex(_ type: DatosDashboardAlmacen.TipoMovimiento) -> String {
        switch type {
        case .entrada:
            return "F0FDF4"
        case .salida:
            return "FEF2F2"
        case .transfer:
            return "F5F3FF"
        }
    }

    private func descripcionMovimiento(_ movimiento: MovimientoInventarioEntity) -> String {
        if let note = movimiento.nota, note.isEmpty == false {
            return note
        }
        let origen = movimiento.origen ?? "Origen"
        let destino = movimiento.destino ?? movimiento.almacen?.nombre ?? "Destino"
        return "\(origen) → \(destino)"
    }

    private func textoActorMovimiento(_ movimiento: MovimientoInventarioEntity) -> String {
        if let note = movimiento.nota?.lowercased() {
            if note.contains("compra") { return "Ingreso de stock" }
            if note.contains("venta") { return "Salida de stock" }
            if note.contains("transfer") { return "Transferencia" }
        }
        return "Movimiento"
    }

    private func textoOrigenMovimiento(_ movimiento: MovimientoInventarioEntity, type: DatosDashboardAlmacen.TipoMovimiento) -> String? {
        switch type {
        case .entrada:
            return movimiento.origen ?? "Proveedor"
        case .salida, .transfer:
            return nombreCortoAlmacen(movimiento.almacen?.nombre ?? movimiento.origen ?? "Origen")
        }
    }

    private func textoDestinoMovimiento(_ movimiento: MovimientoInventarioEntity, type: DatosDashboardAlmacen.TipoMovimiento) -> String? {
        switch type {
        case .entrada:
            return nombreCortoAlmacen(movimiento.almacen?.nombre ?? movimiento.destino ?? "Destino")
        case .salida:
            return movimiento.destino ?? "Sin cliente"
        case .transfer:
            return nombreCortoAlmacen(movimiento.destino ?? "Destino")
        }
    }

    private func iconoOrigenMovimiento(type: DatosDashboardAlmacen.TipoMovimiento) -> String {
        switch type {
        case .entrada:
            return "shippingbox"
        case .salida, .transfer:
            return "building.2"
        }
    }

    private func iconoDestinoMovimiento(type: DatosDashboardAlmacen.TipoMovimiento) -> String {
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
        filas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: identificadorCelda, for: indexPath)
        guard let almacenCell = cell as? AlmacenTableViewCell else { return cell }

        switch filas[indexPath.row] {
        case .almacen(let almacen):
            let warehouseStocks = stocks.filter { $0.almacen == almacen }
            let totalLiters = warehouseStocks.reduce(0.0) { $0 + $1.stockActual }
            let totalCapacity = warehouseStocks.reduce(0.0) { $0 + capacidad(for: $1) }
            let lowCount = warehouseStocks.filter { $0.stockActual > 0 && $0.stockActual < minimo(for: $0) }.count
            almacenCell.configure(
                accent: lowCount > 0
                    ? UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
                    : UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1),
                title: almacen.nombre ?? "Almacén",
                subtitle: almacen.responsable ?? "Sin responsable",
                detail: almacen.direccion ?? "Sin dirección",
                amount: formatearLitros(totalLiters),
                progress: CGFloat(min(totalLiters / max(totalCapacity, 1), 1)),
                status: lowCount > 0 ? "\(lowCount) bajo" : "Activo"
            )
        case .stock(let stock):
            let isLow = stock.stockActual < minimo(for: stock)
            let productName = stock.producto?.nombre ?? "Producto"
            let warehouseName = stock.almacen?.nombre ?? "Almacén"
            almacenCell.configure(
                accent: isLow ? UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1),
                title: productName,
                subtitle: warehouseName,
                detail: "Min \(formatearLitros(minimo(for: stock))) · Cap \(formatearLitros(capacidad(for: stock)))",
                amount: formatearLitros(stock.stockActual),
                progress: CGFloat(min(stock.stockActual / capacidad(for: stock), 1)),
                status: isLow ? "Stock Bajo" : "OK"
            )
        case .producto(let producto):
            let minimum = producto.stockMinimo
            let low = producto.stockLitros < minimum
            almacenCell.configure(
                accent: low ? UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1),
                title: producto.nombre ?? "Producto",
                subtitle: "\(formatearMoneda(producto.precioPorLitro)) / \(producto.unidadMedida ?? "L")",
                detail: "Stock total consolidado · Min \(formatearLitros(minimum))",
                amount: formatearLitros(producto.stockLitros),
                progress: CGFloat(min(producto.stockLitros / max(producto.capacidadTotal * Double(max(almacenes.count, 1)), 1), 1)),
                status: low ? "Bajo" : "OK"
            )
        case .movimiento(let movimiento):
            let tipo = movimiento.tipo ?? "evento"
            let color = colorForMovement(tipo)
            almacenCell.configure(
                accent: color,
                title: movimiento.producto?.nombre ?? "Movimiento",
                subtitle: "\(tipo.uppercased()) · \(formatearFecha(movimiento.fecha))",
                detail: movimiento.nota?.isEmpty == false ? movimiento.nota! : "\(movimiento.origen ?? "Origen") → \(movimiento.destino ?? movimiento.almacen?.nombre ?? "Destino")",
                amount: formatearLitros(movimiento.cantidadLitros),
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
        cargarDatos()
    }

    func modalProductoViewControllerDidSave(_ controller: ModalProductoViewController) {
        cargarDatos()
    }

    func modalMovimientoViewControllerDidSave(_ controller: ModalMovimientoViewController) {
        cargarDatos()
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
