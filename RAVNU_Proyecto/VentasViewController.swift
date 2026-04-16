import UIKit
import CoreData

class VentasViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var scrollViewResumen: UIScrollView!
    @IBOutlet weak var tblListaVentas: UITableView!
    @IBOutlet weak var btnResumen: UIButton!
    @IBOutlet weak var btnListaVentas: UIButton!
    @IBOutlet weak var emptyStateView: UIView!

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
            tblListaVentas.reloadData()
            if !tblListaVentas.isHidden {
                emptyStateView.isHidden = !filteredVentas.isEmpty
            }
        } catch {
            showErrorAlert(message: "No se pudieron cargar las ventas.")
        }
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
