import UIKit
import CoreData

class VentasViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var scrollViewResumen: UIScrollView!
    @IBOutlet weak var tblListaVentas: UITableView!
    @IBOutlet weak var btnResumen: UIButton!
    @IBOutlet weak var btnListaVentas: UIButton!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet private weak var lblIngresosTotal: UILabel?
    @IBOutlet private weak var lblEfectivoTotal: UILabel?
    @IBOutlet private weak var lblCreditoTotal: UILabel?
    @IBOutlet private weak var lblVentaRecienteCliente1: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto1: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle1: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto1: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo1: UILabel?
    @IBOutlet private weak var ventaRecienteCard1: UIView?
    @IBOutlet private weak var lblVentaRecienteCliente2: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto2: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle2: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto2: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo2: UILabel?
    @IBOutlet private weak var ventaRecienteCard2: UIView?
    @IBOutlet private weak var lblVentaRecienteCliente3: UILabel?
    @IBOutlet private weak var lblVentaRecienteProducto3: UILabel?
    @IBOutlet private weak var lblVentaRecienteDetalle3: UILabel?
    @IBOutlet private weak var lblVentaRecienteMonto3: UILabel?
    @IBOutlet private weak var lblVentaRecienteMetodo3: UILabel?
    @IBOutlet private weak var ventaRecienteCard3: UIView?

    private let activeColor = UIColor(red: 0.188, green: 0.196, blue: 0.271, alpha: 1)
    private let inactiveColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
    private let ventaCellIdentifier = "ventaCell"
    private var ventas: [VentaEntity] = []
    private var clientes: [ClienteEntity] = []
    private var productos: [ProductoEntity] = []
    private var filteredVentas: [VentaEntity] = []

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tblListaVentas.tableFooterView = UIView()
        tblListaVentas.rowHeight = 72
        tblListaVentas.dataSource = self
        tblListaVentas.delegate = self
        configureSummaryLabels()
        loadCatalogData()
        loadVentas()
        showResumen()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCatalogData()
        loadVentas()
    }

    @IBAction func btnResumenTapped(_ sender: UIButton) {
        showResumen()
    }

    @IBAction func btnListaVentasTapped(_ sender: UIButton) {
        showListaVentas()
    }

    @IBAction func btnNuevaVentaTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "mostrarModalVenta", sender: sender)
    }

    private func showResumen() {
        scrollViewResumen.isHidden = false
        tblListaVentas.isHidden = true
        emptyStateView.isHidden = true
        updateTabStyle(activeButton: btnResumen, inactiveButton: btnListaVentas)
    }

    private func showListaVentas() {
        scrollViewResumen.isHidden = true
        tblListaVentas.isHidden = false
        emptyStateView.isHidden = !filteredVentas.isEmpty
        updateTabStyle(activeButton: btnListaVentas, inactiveButton: btnResumen)
    }

    private func updateTabStyle(activeButton: UIButton, inactiveButton: UIButton) {
        if var activeConfig = activeButton.configuration {
            activeConfig.baseForegroundColor = activeColor
            activeConfig.background.backgroundColor = .white
            activeButton.configuration = activeConfig
        }
        if var inactiveConfig = inactiveButton.configuration {
            inactiveConfig.baseForegroundColor = inactiveColor
            inactiveConfig.background.backgroundColor = .clear
            inactiveButton.configuration = inactiveConfig
        }
    }

    private func loadCatalogData() {
        do {
            let clienteRequest = ClienteEntity.fetchRequest()
            clienteRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            clientes = try context.fetch(clienteRequest)

            let productoRequest = ProductoEntity.fetchRequest()
            productoRequest.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            productos = try context.fetch(productoRequest)
        } catch {
            showErrorAlert(message: "No se pudieron cargar clientes y productos.")
        }
    }

    private func loadVentas() {
        do {
            let request = VentaEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "fechaVenta", ascending: false)]
            ventas = try context.fetch(request)
            filteredVentas = ventas
            updateResumenMetrics()
            tblListaVentas.reloadData()
            if !tblListaVentas.isHidden {
                emptyStateView.isHidden = !filteredVentas.isEmpty
            }
        } catch {
            showErrorAlert(message: "No se pudieron cargar las ventas.")
        }
    }

    private func configureSummaryLabels() {
        let summaryLabels = [
            lblIngresosTotal, lblEfectivoTotal, lblCreditoTotal,
            lblVentaRecienteCliente1, lblVentaRecienteProducto1, lblVentaRecienteDetalle1, lblVentaRecienteMonto1, lblVentaRecienteMetodo1,
            lblVentaRecienteCliente2, lblVentaRecienteProducto2, lblVentaRecienteDetalle2, lblVentaRecienteMonto2, lblVentaRecienteMetodo2,
            lblVentaRecienteCliente3, lblVentaRecienteProducto3, lblVentaRecienteDetalle3, lblVentaRecienteMonto3, lblVentaRecienteMetodo3
        ]

        summaryLabels.forEach { label in
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.72
        }
    }

    private func updateResumenMetrics() {
        let ingresos = ventas.reduce(0.0) { $0 + $1.total }
        let efectivo = ventas
            .filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.efectivo.rawValue }
            .reduce(0.0) { $0 + $1.total }
        let credito = ventas
            .filter { ($0.metodoPago ?? "").lowercased() == MetodoPagoVenta.credito.rawValue }
            .reduce(0.0) { $0 + $1.total }

        lblIngresosTotal?.text = formatCurrency(ingresos)
        lblEfectivoTotal?.text = formatCurrency(efectivo)
        lblCreditoTotal?.text = formatCurrency(credito)

        let recentRows = [
            (ventaRecienteCard1, lblVentaRecienteCliente1, lblVentaRecienteProducto1, lblVentaRecienteDetalle1, lblVentaRecienteMonto1, lblVentaRecienteMetodo1),
            (ventaRecienteCard2, lblVentaRecienteCliente2, lblVentaRecienteProducto2, lblVentaRecienteDetalle2, lblVentaRecienteMonto2, lblVentaRecienteMetodo2),
            (ventaRecienteCard3, lblVentaRecienteCliente3, lblVentaRecienteProducto3, lblVentaRecienteDetalle3, lblVentaRecienteMonto3, lblVentaRecienteMetodo3)
        ]

        for (index, row) in recentRows.enumerated() {
            if ventas.indices.contains(index) {
                row.0?.isHidden = false
                configureRecentSale(row: row, venta: ventas[index])
            } else {
                row.0?.isHidden = true
            }
        }
    }

    private func configureRecentSale(
        row: (card: UIView?, cliente: UILabel?, producto: UILabel?, detalle: UILabel?, monto: UILabel?, metodo: UILabel?),
        venta: VentaEntity
    ) {
        let metodo = (venta.metodoPago ?? "-").capitalized
        row.cliente?.text = venta.cliente?.nombre ?? "Cliente sin nombre"
        row.producto?.text = venta.producto?.nombre ?? "Producto sin nombre"
        row.detalle?.text = "\(formatLiters(venta.cantidadLitros)) · \(formatDate(venta.fechaVenta))"
        row.monto?.text = formatCurrency(venta.total)
        row.metodo?.text = metodo
    }

    private func formatCurrency(_ amount: Double) -> String {
        String(format: "S/ %.2f", amount)
    }

    private func formatLiters(_ amount: Double) -> String {
        String(format: "%.2f L", amount)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredVentas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ventaCellIdentifier) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: ventaCellIdentifier)
        let venta = filteredVentas[indexPath.row]
        let cliente = venta.cliente?.nombre ?? "Cliente sin nombre"
        let producto = venta.producto?.nombre ?? "Producto sin nombre"
        let metodoPago = venta.metodoPago ?? "-"
        let total = String(format: "S/ %.2f", venta.total)
        let litros = String(format: "%.2fL", venta.cantidadLitros)

        cell.textLabel?.text = "\(cliente) • \(producto)"
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cell.detailTextLabel?.text = "\(litros) • \(metodoPago.capitalized) • \(total)"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.backgroundColor = .white
        cell.layer.cornerRadius = 14
        cell.clipsToBounds = true
        cell.selectionStyle = .none
        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "mostrarModalVenta",
              let destination = segue.destination as? ModalVentaViewController else {
            return
        }

        destination.clientesDisponibles = clientes
        destination.productosDisponibles = productos
        destination.delegate = self
    }
}

extension VentasViewController: ModalVentaViewControllerDelegate {
    func modalVentaViewControllerDidSaveVenta(_ controller: ModalVentaViewController) {
        loadCatalogData()
        loadVentas()
        showListaVentas()
    }
}
