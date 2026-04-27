import CoreData
import UIKit
import SwiftUI

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

    private let contexto = AppCoreData.viewContext
    private let formateadorMoneda: NumberFormatter = {
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
    private var alertasStock: [AlertaStock] = []
    private var hostingController: UIHostingController<CajeroDashboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarTabla()
        configurarEstadoInicial()
        configurarDashboardSwiftUI()
        cargarDatosDashboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarDatosDashboard()
    }

    private func configurarTabla() {
        tblCajero?.dataSource = self
        tblCajero?.delegate = self
        tblCajero?.rowHeight = 78
        tblCajero?.tableFooterView = UIView()
        tblCajero?.separatorStyle = .none
        tblCajero?.backgroundColor = .clear
        tblCajero?.showsVerticalScrollIndicator = false
    }

    private func configurarEstadoInicial() {
        lblNombreBienvenido?.text = "Hola, \(nombreBienvenido ?? "usuario")"
        reiniciarEtiquetas()
    }

    private func configurarDashboardSwiftUI() {
        ocultarVistaLegacy()
        let host = UIHostingController(rootView: CajeroDashboardView(datos: crearDatosDashboard()))
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
            lblNombreBienvenido,
            lblSaldoActual,
            lblResumenSecundario,
            lblVentasHoy,
            lblVentasHoyDetalle,
            lblCobradoHoy,
            lblCobradoHoyDetalle,
            lblPendientes,
            lblPendientesDetalle,
            lblStockBajo,
            lblStockBajoDetalle,
            lblVentasSemana,
            lblVentasSemanaDetalle,
            lblAlertaStockTitulo,
            lblAlertaStockDetalle,
            emptyStateView,
            tblCajero
        ].forEach {
            $0?.isHidden = true
        }
    }

    private func reiniciarEtiquetas() {
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
        lblAlertaStockDetalle?.text = "Sin productos por debajo del mínimo"
        alertasStock = []
        tblCajero?.reloadData()
        emptyStateView?.isHidden = false
        actualizarDashboardSwiftUI()
    }

    private func cargarDatosDashboard() {
        do {
            ventas = try obtenerVentas()
            cuotas = try obtenerCuotas()
            productos = try obtenerProductos()
            stocks = try obtenerStocks()
            actualizarDashboard()
        } catch {
            reiniciarEtiquetas()
        }
    }

    private func obtenerVentas() throws -> [VentaEntity] {
        let request: NSFetchRequest<VentaEntity> = VentaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVenta", ascending: false)]
        return try contexto.fetch(request)
    }

    private func obtenerCuotas() throws -> [CuotaEntity] {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]
        return try contexto.fetch(request)
    }

    private func obtenerProductos() throws -> [ProductoEntity] {
        let request: NSFetchRequest<ProductoEntity> = ProductoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "stockLitros", ascending: true)]
        return try contexto.fetch(request)
    }

    private func obtenerStocks() throws -> [StockAlmacenEntity] {
        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "stockActual", ascending: true),
            NSSortDescriptor(key: "producto.nombre", ascending: true)
        ]
        return try contexto.fetch(request)
    }

    private func actualizarDashboard() {
        let ventasHoy = ventas.filter { venta in
            guard let fecha = venta.fechaVenta else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let ventasSemana = ventasUltimosSieteDias()
        let cuotasPagadasHoy = cuotas.filter { cuota in
            guard cuota.pagada, let fecha = cuota.fechaPago else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let cuotasPendientes = cuotas.filter { !$0.pagada }
        let stocksBajos = construirAlertasStock()

        let totalVentas = ventas.reduce(0) { $0 + $1.total }
        let totalVentasHoy = ventasHoy.reduce(0) { $0 + $1.total }
        let totalVentasSemana = ventasSemana.reduce(0) { $0 + $1.total }
        let totalCobradoHoy = cuotasPagadasHoy.reduce(0) { $0 + $1.monto }
        let totalPendiente = cuotasPendientes.reduce(0) { $0 + $1.monto }

        lblSaldoActual?.text = ventas.isEmpty && cuotasPagadasHoy.isEmpty ? "S/ --" : formatearMoneda(totalVentas + totalCobradoHoy)
        if ventas.isEmpty && cuotasPagadasHoy.isEmpty {
            lblResumenSecundario?.text = "Sin ventas ni cobros registrados"
        } else {
            lblResumenSecundario?.text = "\(ventas.count) ventas registradas · \(cuotasPagadasHoy.count) cobros hoy"
        }

        lblVentasHoy?.text = ventasHoy.isEmpty ? "--" : formatearMoneda(totalVentasHoy)
        lblVentasHoyDetalle?.text = ventasHoy.isEmpty ? "Sin ventas hoy" : "\(ventasHoy.count) venta(s) hoy"
        lblVentasSemana?.text = ventasSemana.isEmpty ? "S/ --" : formatearMoneda(totalVentasSemana)
        lblVentasSemanaDetalle?.text = ventasSemana.isEmpty ? "Sin ventas esta semana" : "\(ventasSemana.count) venta(s) en la semana"

        lblCobradoHoy?.text = cuotasPagadasHoy.isEmpty ? "--" : formatearMoneda(totalCobradoHoy)
        lblCobradoHoyDetalle?.text = cuotasPagadasHoy.isEmpty ? "Sin cobros hoy" : "\(cuotasPagadasHoy.count) cuota(s) pagadas"

        lblPendientes?.text = cuotasPendientes.isEmpty ? "--" : "\(cuotasPendientes.count)"
        lblPendientesDetalle?.text = cuotasPendientes.isEmpty ? "Sin cuotas pendientes" : "\(formatearMoneda(totalPendiente)) por cobrar"

        lblStockBajo?.text = stocksBajos.isEmpty ? "--" : "\(stocksBajos.count)"
        lblStockBajoDetalle?.text = stocksBajos.isEmpty ? "Sin alertas de stock" : stocksBajos[0].descripcionCorta
        lblAlertaStockTitulo?.text = stocksBajos.isEmpty ? "Stock estable" : "\(stocksBajos.count) producto(s) bajo mínimo"
        lblAlertaStockDetalle?.text = stocksBajos.isEmpty ? "Sin productos por debajo del mínimo" : stocksBajos.prefix(2).map { $0.descripcionCorta }.joined(separator: " · ")

        alertasStock = Array(stocksBajos.prefix(8))
        tblCajero?.reloadData()
        emptyStateView?.isHidden = !alertasStock.isEmpty
        actualizarDashboardSwiftUI()
    }

    private func actualizarDashboardSwiftUI() {
        hostingController?.rootView = CajeroDashboardView(datos: crearDatosDashboard())
    }

    private func crearDatosDashboard() -> DatosDashboardCajero {
        let ventasHoy = ventas.filter { venta in
            guard let fecha = venta.fechaVenta else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let cuotasPagadasHoy = cuotas.filter { cuota in
            guard cuota.pagada, let fecha = cuota.fechaPago else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let cuotasPendientes = cuotas.filter { !$0.pagada }
        let ventasSemanales = crearVentasSemanales()
        let stocksBajos = construirAlertasStock()
        let mayorDeudor = obtenerMayorDeudor()

        let metricas = [
            DatosDashboardCajero.Metrica(
                titulo: "Vendido Hoy",
                valor: ventasHoy.isEmpty ? "S/0" : formatearMoneda(ventasHoy.reduce(0) { $0 + $1.total }),
                icono: "arrow.up.right",
                color: Color(.sRGB, red: 59 / 255, green: 130 / 255, blue: 246 / 255, opacity: 1)
            ),
            DatosDashboardCajero.Metrica(
                titulo: "Cobrado Hoy",
                valor: cuotasPagadasHoy.isEmpty ? "S/0" : formatearMoneda(cuotasPagadasHoy.reduce(0) { $0 + $1.monto }),
                icono: "checkmark.circle.fill",
                color: Color(.sRGB, red: 34 / 255, green: 197 / 255, blue: 94 / 255, opacity: 1)
            ),
            DatosDashboardCajero.Metrica(
                titulo: "Por Cobrar",
                valor: cuotasPendientes.isEmpty ? "S/0" : formatearMoneda(cuotasPendientes.reduce(0) { $0 + $1.monto }),
                icono: "clock.fill",
                color: Color(.sRGB, red: 239 / 255, green: 68 / 255, blue: 68 / 255, opacity: 1)
            )
        ]

        let tituloStockBajo = stocksBajos.first?.nombreProducto ?? "Sin alertas"
        let detalleStockBajo = stocksBajos.first.map { "\($0.actualRedondeado) \($0.unidad) restantes" } ?? "Inventario estable"

        return DatosDashboardCajero(
            cantidadNotificaciones: min(max(cuotasPendientes.count, 0), 9),
            metricas: metricas,
            ventasSemanales: ventasSemanales,
            tituloStockBajo: tituloStockBajo,
            detalleStockBajo: detalleStockBajo,
            badgeStockBajo: stocksBajos.isEmpty ? "OK" : "Stock Bajo",
            nombreDeudor: mayorDeudor.nombre,
            deudaDeudor: formatearMoneda(mayorDeudor.monto),
            estadoDeudor: mayorDeudor.monto > 0 ? "Vencido" : "Sin deuda"
        )
    }

    private func crearVentasSemanales() -> [DatosDashboardCajero.VentaSemanal] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "EEE"

        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
        let grouped = Dictionary(grouping: ventas) { venta in
            calendar.startOfDay(for: venta.fechaVenta ?? today)
        }
        let totals = days.map { day -> (label: String, amount: Double) in
            let amount = (grouped[day] ?? []).reduce(0.0) { $0 + $1.total }
            let abbreviation = formatter.string(from: day)
            let label = abbreviation.prefix(1).uppercased() + abbreviation.dropFirst().prefix(2)
            return (String(label), amount)
        }
        let maxAmount = totals.map(\.amount).max() ?? 0

        return totals.map { item in
            DatosDashboardCajero.VentaSemanal(
                dia: item.label,
                monto: item.amount,
                destacado: item.amount == maxAmount && maxAmount > 0
            )
        }
    }

    private func ventasUltimosSieteDias() -> [VentaEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        return ventas.filter { venta in
            guard let fecha = venta.fechaVenta else { return false }
            let day = calendar.startOfDay(for: fecha)
            return day >= startDate && day <= today
        }
    }

    private func obtenerMayorDeudor() -> (nombre: String, monto: Double) {
        let grouped = Dictionary(grouping: cuotas.filter { !$0.pagada }) { cuota in
            cuota.venta?.cliente?.nombre ?? "Sin cliente"
        }
        let sorted = grouped
            .map { (nombre: $0.key, monto: $0.value.reduce(0.0) { $0 + $1.monto }) }
            .sorted { $0.monto > $1.monto }
        return sorted.first ?? ("Sin deuda registrada", 0)
    }

    /// Usa stock por almacén si existe; si no, cae al stock agregado del producto.
    private func construirAlertasStock() -> [AlertaStock] {
        if !stocks.isEmpty {
            let stocksConsolidados = consolidarStocksPorAlmacenYProducto(stocks)
            let agrupadosPorProducto = Dictionary(grouping: stocksConsolidados) { stock in
                identidadProducto(stock.producto)
            }

            return agrupadosPorProducto.values.compactMap { stocksProducto in
                guard let principal = stocksProducto.max(by: { $0.stockActual < $1.stockActual }) else { return nil }
                let totalActual = stocksProducto.reduce(0.0) { $0 + max($1.stockActual, 0) }
                let minimum = principal.producto?.stockMinimo ?? stocksProducto.map(\.stockMinimo).max() ?? 0
                guard minimum > 0, totalActual < minimum else { return nil }

                let nombreAlmacen: String
                if stocksProducto.count > 1 {
                    nombreAlmacen = "Red"
                } else {
                    nombreAlmacen = principal.almacen?.nombre ?? "Almacén"
                }

                return AlertaStock(
                    nombreProducto: principal.producto?.nombre ?? "Producto",
                    nombreAlmacen: nombreAlmacen,
                    actual: totalActual,
                    minimo: minimum,
                    unidad: principal.unidadMedida ?? principal.producto?.unidadMedida ?? "L"
                )
            }
            .sorted { $0.actual < $1.actual }
        }

        return productos.compactMap { producto in
            guard producto.activo, producto.stockMinimo > 0, producto.stockLitros < producto.stockMinimo else { return nil }
            return AlertaStock(
                nombreProducto: producto.nombre ?? "Producto",
                nombreAlmacen: "Red",
                actual: producto.stockLitros,
                minimo: producto.stockMinimo,
                unidad: producto.unidadMedida ?? "L"
            )
        }
    }

    private func consolidarStocksPorAlmacenYProducto(_ lista: [StockAlmacenEntity]) -> [StockAlmacenEntity] {
        lista.reduce(into: [String: StockAlmacenEntity]()) { acumulado, stock in
            let clave = "\(identidadProducto(stock.producto))::\(identidadAlmacen(stock.almacen))"
            if let existente = acumulado[clave] {
                acumulado[clave] = stock.stockActual >= existente.stockActual ? stock : existente
            } else {
                acumulado[clave] = stock
            }
        }
        .values
        .map { $0 }
    }

    private func identidadProducto(_ producto: ProductoEntity?) -> String {
        guard let producto else { return "producto:nil" }
        if let id = producto.id?.uuidString, id.isEmpty == false {
            return "producto:\(id)"
        }
        if let nombre = producto.nombre?.trimmingCharacters(in: .whitespacesAndNewlines), nombre.isEmpty == false {
            return "producto:nombre:\(nombre.lowercased())"
        }
        return "producto:obj:\(producto.objectID.uriRepresentation().absoluteString)"
    }

    private func identidadAlmacen(_ almacen: AlmacenEntity?) -> String {
        guard let almacen else { return "almacen:nil" }
        if let id = almacen.id?.uuidString, id.isEmpty == false {
            return "almacen:\(id)"
        }
        if let nombre = almacen.nombre?.trimmingCharacters(in: .whitespacesAndNewlines), nombre.isEmpty == false {
            return "almacen:nombre:\(nombre.lowercased())"
        }
        return "almacen:obj:\(almacen.objectID.uriRepresentation().absoluteString)"
    }

    private func formatearMoneda(_ value: Double) -> String {
        formateadorMoneda.string(from: NSNumber(value: value)) ?? "S/ 0.00"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        alertasStock.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "celdaCajero")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "celdaCajero")
        let alerta = alertasStock[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = alerta.nombreProducto
        content.secondaryText = "\(formatearCantidad(alerta.actual, unidad: alerta.unidad)) · \(alerta.nombreAlmacen)"
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

    private func formatearCantidad(_ value: Double, unidad: String) -> String {
        "\(Int(value.rounded()).formatted()) \(unidad)"
    }

    @IBAction private func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}

private struct AlertaStock {
    let nombreProducto: String
    let nombreAlmacen: String
    let actual: Double
    let minimo: Double
    let unidad: String

    var descripcionCorta: String {
        "\(nombreProducto): \(Int(actual.rounded()).formatted()) \(unidad)"
    }

    var actualRedondeado: Int {
        Int(actual.rounded())
    }
}
