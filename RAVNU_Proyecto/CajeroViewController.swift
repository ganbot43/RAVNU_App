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
    private var movimientos: [DashboardMovement] = []

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
        tblCajero?.rowHeight = 72
        tblCajero?.tableFooterView = UIView()
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
        movimientos = []
        tblCajero?.reloadData()
        emptyStateView?.isHidden = false
    }

    private func loadDashboardData() {
        do {
            ventas = try fetchVentas()
            cuotas = try fetchCuotas()
            productos = try fetchProductos()
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
        let lowStockProducts = productos.filter { $0.activo && $0.stockLitros <= 500 }

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

        lblStockBajo?.text = lowStockProducts.isEmpty ? "--" : "\(lowStockProducts.count)"
        lblStockBajoDetalle?.text = lowStockProducts.isEmpty ? "Sin alertas de stock" : firstLowStockDescription(from: lowStockProducts)
        lblAlertaStockTitulo?.text = lowStockProducts.isEmpty ? "Stock estable" : "\(lowStockProducts.count) alerta(s) de stock bajo"
        lblAlertaStockDetalle?.text = lowStockProducts.isEmpty ? "Sin productos por debajo del minimo" : stockAlertDescription(from: lowStockProducts)

        movimientos = buildMovements(ventas: ventas, cuotas: cuotas).prefix(8).map { $0 }
        tblCajero?.reloadData()
        emptyStateView?.isHidden = !movimientos.isEmpty
    }

    private func buildMovements(ventas: [VentaEntity], cuotas: [CuotaEntity]) -> [DashboardMovement] {
        let salesMovements = ventas.compactMap { venta -> DashboardMovement? in
            guard let fecha = venta.fechaVenta else { return nil }
            let cliente = venta.cliente?.nombre ?? "Cliente"
            let producto = venta.producto?.nombre ?? "Producto"
            let detalle = "\(producto) • \(relativeDescription(for: fecha))"
            return DashboardMovement(
                title: "Venta a \(cliente)",
                subtitle: detalle,
                amount: formatCurrency(venta.total),
                date: fecha,
                accentColor: UIColor(red: 0.192, green: 0.431, blue: 0.984, alpha: 1)
            )
        }

        let cuotaMovements = cuotas.compactMap { cuota -> DashboardMovement? in
            let fecha = cuota.fechaPago ?? cuota.fechaVencimiento
            guard let resolvedDate = fecha else { return nil }
            let cliente = cuota.venta?.cliente?.nombre ?? "Cliente"
            let estado = cuota.pagada ? "Cuota pagada" : "Cuota pendiente"
            let detalle = "Cuota \(cuota.numero) • \(relativeDescription(for: resolvedDate))"
            return DashboardMovement(
                title: "\(estado) de \(cliente)",
                subtitle: detalle,
                amount: formatCurrency(cuota.monto),
                date: resolvedDate,
                accentColor: cuota.pagada
                    ? UIColor(red: 0.149, green: 0.651, blue: 0.392, alpha: 1)
                    : UIColor(red: 0.925, green: 0.506, blue: 0.086, alpha: 1)
            )
        }

        return (salesMovements + cuotaMovements).sorted { $0.date > $1.date }
    }

    private func firstLowStockDescription(from productos: [ProductoEntity]) -> String {
        guard let producto = productos.first else {
            return "Sin alertas de stock"
        }
        let stock = Int(producto.stockLitros.rounded())
        return "\(producto.nombre ?? "Producto") con \(stock)L"
    }

    private func stockAlertDescription(from productos: [ProductoEntity]) -> String {
        productos
            .prefix(3)
            .map { producto in
                let nombre = producto.nombre ?? "Producto"
                let stock = Int(producto.stockLitros.rounded())
                return "\(nombre): \(stock)L"
            }
            .joined(separator: " · ")
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
        movimientos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "celdaCajero")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "celdaCajero")
        let movimiento = movimientos[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = movimiento.title
        content.secondaryText = movimiento.subtitle
        content.textProperties.font = .systemFont(ofSize: 15, weight: .semibold)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content

        let amountLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 96, height: 24))
        amountLabel.textAlignment = .right
        amountLabel.font = .systemFont(ofSize: 14, weight: .bold)
        amountLabel.textColor = movimiento.accentColor
        amountLabel.text = movimiento.amount

        cell.accessoryView = amountLabel
        cell.backgroundColor = .white
        cell.layer.cornerRadius = 16
        cell.clipsToBounds = true
        cell.selectionStyle = .none
        return cell
    }

    @IBAction private func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}

private struct DashboardMovement {
    let title: String
    let subtitle: String
    let amount: String
    let date: Date
    let accentColor: UIColor
}
