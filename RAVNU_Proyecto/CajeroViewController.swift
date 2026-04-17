import CoreData
import UIKit

final class CajeroViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var lblNombreBienvenido: UILabel?
    @IBOutlet private weak var lblSaldoActual: UILabel?
    @IBOutlet private weak var lblResumenSecundario: UILabel?
    @IBOutlet private weak var lblVentasHoy: UILabel?
    @IBOutlet private weak var lblVentasHoyDetalle: UILabel?
    @IBOutlet private weak var lblCobradoHoy: UILabel?
    @IBOutlet private weak var lblCobradoHoyDetalle: UILabel?
    @IBOutlet private weak var lblPendientes: UILabel?
    @IBOutlet private weak var lblPendientesDetalle: UILabel?
    @IBOutlet private weak var lblStockBajo: UILabel?
    @IBOutlet private weak var lblStockBajoDetalle: UILabel?
    @IBOutlet private weak var lblVentasSemana: UILabel?
    @IBOutlet private weak var lblVentasSemanaDetalle: UILabel?
    @IBOutlet private weak var lblAlertaStockTitulo: UILabel?
    @IBOutlet private weak var lblAlertaStockDetalle: UILabel?
    @IBOutlet private weak var emptyStateView: UIView?
    @IBOutlet private weak var tblCajero: UITableView?

    var nombreBienvenido: String?

    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.currencySymbol = "S/"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private var ventas: [VentaEntity] = []
    private var cuotas: [CuotaEntity] = []
    private var productos: [ProductoEntity] = []
    private var stocks: [StockAlmacenEntity] = []
    private var stockAlerts: [StockAlertItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureInitialState()
        loadDashboardData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDashboardData()
    }

    private func configureTableView() {
        tblCajero?.dataSource = self
        tblCajero?.delegate = self
        tblCajero?.rowHeight = 78
        tblCajero?.tableFooterView = UIView()
        tblCajero?.separatorStyle = .none
        tblCajero?.backgroundColor = .clear
        tblCajero?.showsVerticalScrollIndicator = false
    }

    private func configureInitialState() {
        lblNombreBienvenido?.text = "Hola, \(nombreBienvenido ?? "cajero")"
        resetDashboardLabels()
    }

    private func resetDashboardLabels() {
        lblSaldoActual?.text = "S/ --"
        lblResumenSecundario?.text = "Sin ventas ni cobros registrados"
        lblVentasHoy?.text = "--"
        lblVentasHoyDetalle?.text = "Sin ventas hoy"
        lblCobradoHoy?.text = "--"
        lblCobradoHoyDetalle?.text = "Sin cobros hoy"
        lblPendientes?.text = "--"
        lblPendientesDetalle?.text = "Sin cuotas pendientes"
        lblStockBajo?.text = "--"
        lblStockBajoDetalle?.text = "Sin alertas de stock"
        lblVentasSemana?.text = "S/ --"
        lblVentasSemanaDetalle?.text = "Sin ventas esta semana"
        lblAlertaStockTitulo?.text = "Stock estable"
        lblAlertaStockDetalle?.text = "Sin productos por debajo del minimo"
        stockAlerts = []
        tblCajero?.reloadData()
        emptyStateView?.isHidden = false
    }

    private func loadDashboardData() {
        do {
            ventas = try fetchVentas()
            cuotas = try fetchCuotas()
            productos = try fetchProductos()
            stocks = try fetchStocks()
            updateDashboard()
        } catch {
            resetDashboardLabels()
        }
    }

    private func fetchVentas() throws -> [VentaEntity] {
        let request: NSFetchRequest<VentaEntity> = VentaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVenta", ascending: false)]
        return try context.fetch(request)
    }

    private func fetchCuotas() throws -> [CuotaEntity] {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]
        return try context.fetch(request)
    }

    private func fetchProductos() throws -> [ProductoEntity] {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "stockLitros", ascending: true)]
        return try context.fetch(request)
    }

    private func fetchStocks() throws -> [StockAlmacenEntity] {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "stockActual", ascending: true),
            NSSortDescriptor(key: "producto.nombre", ascending: true)
        ]
        return try context.fetch(request)
    }

    private func updateDashboard() {
        let salesToday = ventas.filter { venta in
            guard let fecha = venta.fechaVenta else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let salesThisWeek = ventas.filter { venta in
            guard let fecha = venta.fechaVenta,
                  let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
                return false
            }
            return weekInterval.contains(fecha)
        }
        let paidCuotasToday = cuotas.filter { cuota in
            guard cuota.pagada, let fecha = cuota.fechaPago else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let pendingCuotas = cuotas.filter { !$0.pagada }
        let lowStockItems = buildLowStockItems()

        let totalVentas = ventas.reduce(0) { $0 + $1.total }
        let totalVentasHoy = salesToday.reduce(0) { $0 + $1.total }
        let totalVentasSemana = salesThisWeek.reduce(0) { $0 + $1.total }
        let totalCobradoHoy = paidCuotasToday.reduce(0) { $0 + $1.monto }
        let totalPendiente = pendingCuotas.reduce(0) { $0 + $1.monto }

        lblSaldoActual?.text = ventas.isEmpty && paidCuotasToday.isEmpty ? "S/ --" : formatCurrency(totalVentas + totalCobradoHoy)
        if ventas.isEmpty && paidCuotasToday.isEmpty {
            lblResumenSecundario?.text = "Sin ventas ni cobros registrados"
        } else {
            lblResumenSecundario?.text = "\(ventas.count) ventas registradas · \(paidCuotasToday.count) cobros hoy"
        }

        lblVentasHoy?.text = salesToday.isEmpty ? "--" : formatCurrency(totalVentasHoy)
        lblVentasHoyDetalle?.text = salesToday.isEmpty ? "Sin ventas hoy" : "\(salesToday.count) venta(s) hoy"
        lblVentasSemana?.text = salesThisWeek.isEmpty ? "S/ --" : formatCurrency(totalVentasSemana)
        lblVentasSemanaDetalle?.text = salesThisWeek.isEmpty ? "Sin ventas esta semana" : "\(salesThisWeek.count) venta(s) en la semana"

        lblCobradoHoy?.text = paidCuotasToday.isEmpty ? "--" : formatCurrency(totalCobradoHoy)
        lblCobradoHoyDetalle?.text = paidCuotasToday.isEmpty ? "Sin cobros hoy" : "\(paidCuotasToday.count) cuota(s) pagadas"

        lblPendientes?.text = pendingCuotas.isEmpty ? "--" : "\(pendingCuotas.count)"
        lblPendientesDetalle?.text = pendingCuotas.isEmpty ? "Sin cuotas pendientes" : "\(formatCurrency(totalPendiente)) por cobrar"

        lblStockBajo?.text = lowStockItems.isEmpty ? "--" : "\(lowStockItems.count)"
        lblStockBajoDetalle?.text = lowStockItems.isEmpty ? "Sin alertas de stock" : lowStockItems[0].shortDescription
        lblAlertaStockTitulo?.text = lowStockItems.isEmpty ? "Stock estable" : "\(lowStockItems.count) producto(s) bajo mínimo"
        lblAlertaStockDetalle?.text = lowStockItems.isEmpty ? "Sin productos por debajo del minimo" : lowStockItems.prefix(2).map { $0.shortDescription }.joined(separator: " · ")

        stockAlerts = Array(lowStockItems.prefix(8))
        tblCajero?.reloadData()
        emptyStateView?.isHidden = !stockAlerts.isEmpty
    }

    private func buildLowStockItems() -> [StockAlertItem] {
        if !stocks.isEmpty {
            return stocks.compactMap { stock in
                let minimum = stock.stockMinimo > 0 ? stock.stockMinimo : (stock.producto?.stockMinimo ?? 0)
                guard minimum > 0, stock.stockActual < minimum else { return nil }
                return StockAlertItem(
                    productName: stock.producto?.nombre ?? "Producto",
                    warehouseName: stock.almacen?.nombre ?? "Almacén",
                    current: stock.stockActual,
                    minimum: minimum,
                    unit: stock.unidadMedida ?? stock.producto?.unidadMedida ?? "L"
                )
            }
        }

        return productos.compactMap { producto in
            guard producto.activo, producto.stockMinimo > 0, producto.stockLitros < producto.stockMinimo else { return nil }
            return StockAlertItem(
                productName: producto.nombre ?? "Producto",
                warehouseName: "Red",
                current: producto.stockLitros,
                minimum: producto.stockMinimo,
                unit: producto.unidadMedida ?? "L"
            )
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "S/ 0.00"
    }

    private func relativeDescription(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "hoy"
        }
        if calendar.isDateInYesterday(date) {
            return "ayer"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: date)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stockAlerts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "celdaCajero")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "celdaCajero")
        let alert = stockAlerts[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = alert.productName
        content.secondaryText = "\(formatQuantity(alert.current, unit: alert.unit)) · \(alert.warehouseName)"
        content.textProperties.font = .systemFont(ofSize: 15, weight: .semibold)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content

        let amountLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 72, height: 24))
        amountLabel.textAlignment = .right
        amountLabel.font = .systemFont(ofSize: 12, weight: .bold)
        amountLabel.textColor = UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
        amountLabel.text = "Bajo"

        cell.accessoryView = amountLabel
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .white
        cell.contentView.layer.cornerRadius = 16
        cell.contentView.layer.shadowColor = UIColor.black.cgColor
        cell.contentView.layer.shadowOpacity = 0.06
        cell.contentView.layer.shadowRadius = 8
        cell.contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cell.contentView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        cell.selectionStyle = .none
        return cell
    }

    private func formatQuantity(_ value: Double, unit: String) -> String {
        "\(Int(value.rounded()).formatted()) \(unit)"
    }

    @IBAction private func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}

private struct StockAlertItem {
    let productName: String
    let warehouseName: String
    let current: Double
    let minimum: Double
    let unit: String

    var shortDescription: String {
        "\(productName): \(Int(current.rounded()).formatted()) \(unit)"
    }
}
