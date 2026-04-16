import UIKit
import CoreData

protocol ModalClienteViewControllerDelegate: AnyObject {
    func modalClienteViewControllerDidSave(_ controller: ModalClienteViewController)
}

final class ClientesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet private weak var btnAnalitica: UIButton!
    @IBOutlet private weak var btnClientes: UIButton!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var btnTodos: UIButton!
    @IBOutlet private weak var btnActivos: UIButton!
    @IBOutlet private weak var btnVencidos: UIButton!
    @IBOutlet private weak var btnBloqueados: UIButton!
    @IBOutlet private weak var tblClientes: UITableView!
    @IBOutlet private weak var analyticsScrollView: UIScrollView!
    @IBOutlet private weak var emptyStateView: UIView!
    @IBOutlet private weak var lblResumenClientes: UILabel!
    @IBOutlet private weak var lblTotalClientes: UILabel!
    @IBOutlet private weak var lblActivos: UILabel!
    @IBOutlet private weak var lblRiesgo: UILabel!
    @IBOutlet private weak var lblBloqueados: UILabel!

    private let activeColor = UIColor(red: 0.188, green: 0.196, blue: 0.271, alpha: 1)
    private let inactiveColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
    private let selectedFilterColor = UIColor(red: 0.286, green: 0.475, blue: 0.976, alpha: 1)
    private let clienteCellIdentifier = "clienteCell"

    private var clientes: [ClienteEntity] = []
    private var filteredClientes: [ClienteEntity] = []
    private var currentFilter: ClienteFilter = .todos
    private var currentSearchText = ""

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

    private enum ClienteFilter {
        case todos
        case activos
        case vencidos
        case bloqueados
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tblClientes.dataSource = self
        tblClientes.delegate = self
        tblClientes.rowHeight = 104
        tblClientes.tableFooterView = UIView()
        searchBar.delegate = self
        configureSearchBar()
        loadClientes()
        showClientes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadClientes()
    }

    private func configureSearchBar() {
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Buscar clientes..."
    }

    private func loadClientes() {
        do {
            let request = ClienteEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            clientes = try context.fetch(request)
            applyFilters()
            updateAnalytics()
        } catch {
            showAlert(title: "Error", message: "No se pudieron cargar los clientes.")
        }
    }

    private func applyFilters() {
        filteredClientes = clientes.filter { cliente in
            matchesFilter(cliente) && matchesSearch(cliente)
        }
        tblClientes.reloadData()
        emptyStateView.isHidden = !filteredClientes.isEmpty || tblClientes.isHidden
        lblResumenClientes.text = "\(clientes.count) registrados · \(clientes.filter(isClienteVencido).count) vencidos"
    }

    private func matchesFilter(_ cliente: ClienteEntity) -> Bool {
        switch currentFilter {
        case .todos:
            return true
        case .activos:
            return isClienteActivo(cliente)
        case .vencidos:
            return isClienteVencido(cliente)
        case .bloqueados:
            return !cliente.activo
        }
    }

    private func matchesSearch(_ cliente: ClienteEntity) -> Bool {
        guard !currentSearchText.isEmpty else { return true }
        let query = currentSearchText.lowercased()
        return (cliente.nombre ?? "").lowercased().contains(query)
            || (cliente.documento ?? "").lowercased().contains(query)
            || (cliente.telefono ?? "").lowercased().contains(query)
    }

    private func updateAnalytics() {
        lblTotalClientes.text = "\(clientes.count)"
        lblActivos.text = "\(clientes.filter(isClienteActivo).count)"
        lblRiesgo.text = "\(clientes.filter(isClienteEnRiesgo).count)"
        lblBloqueados.text = "\(clientes.filter { !$0.activo }.count)"
    }

    private func isClienteActivo(_ cliente: ClienteEntity) -> Bool {
        cliente.activo && !isClienteVencido(cliente)
    }

    private func isClienteEnRiesgo(_ cliente: ClienteEntity) -> Bool {
        guard cliente.limiteCredito > 0 else { return false }
        let ratio = cliente.creditoUsado / cliente.limiteCredito
        return ratio >= 0.3 && ratio < 1.0 && cliente.activo
    }

    private func isClienteVencido(_ cliente: ClienteEntity) -> Bool {
        guard cliente.limiteCredito > 0 else { return false }
        return cliente.creditoUsado >= cliente.limiteCredito
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

    private func updateFilterButtons() {
        styleFilterButton(btnTodos, selected: currentFilter == .todos)
        styleFilterButton(btnActivos, selected: currentFilter == .activos)
        styleFilterButton(btnVencidos, selected: currentFilter == .vencidos)
        styleFilterButton(btnBloqueados, selected: currentFilter == .bloqueados)
    }

    private func styleFilterButton(_ button: UIButton, selected: Bool) {
        if var config = button.configuration {
            config.baseForegroundColor = selected ? .white : inactiveColor
            config.background.backgroundColor = selected ? selectedFilterColor : .white
            button.configuration = config
        }
    }

    private func showClientes() {
        analyticsScrollView.isHidden = true
        tblClientes.isHidden = false
        emptyStateView.isHidden = !filteredClientes.isEmpty
        updateTabStyle(activeButton: btnClientes, inactiveButton: btnAnalitica)
        updateFilterButtons()
    }

    private func showAnalitica() {
        analyticsScrollView.isHidden = false
        tblClientes.isHidden = true
        emptyStateView.isHidden = true
        updateTabStyle(activeButton: btnAnalitica, inactiveButton: btnClientes)
    }

    private func statusInfo(for cliente: ClienteEntity) -> (title: String, color: UIColor, amount: String, progress: String) {
        if !cliente.activo {
            return ("Bloqueado", UIColor(red: 0.53, green: 0.53, blue: 0.57, alpha: 1),
                    String(format: "S/%.0f", cliente.creditoUsado),
                    "Cuenta inactiva")
        }
        if isClienteVencido(cliente) {
            return ("Vencido", UIColor(red: 0.89, green: 0.24, blue: 0.24, alpha: 1),
                    String(format: "S/%.0f", cliente.creditoUsado),
                    String(format: "%.0f%% del límite S/%.0f", porcentajeCredito(cliente), cliente.limiteCredito))
        }
        if isClienteEnRiesgo(cliente) {
            return ("En Riesgo", UIColor(red: 0.95, green: 0.67, blue: 0.04, alpha: 1),
                    String(format: "S/%.0f", cliente.creditoUsado),
                    String(format: "%.0f%% del límite S/%.0f", porcentajeCredito(cliente), cliente.limiteCredito))
        }
        return ("Activo", UIColor(red: 0.25, green: 0.80, blue: 0.42, alpha: 1),
                String(format: "S/%.0f", cliente.creditoUsado),
                cliente.limiteCredito > 0
                    ? String(format: "%.0f%% del límite S/%.0f", porcentajeCredito(cliente), cliente.limiteCredito)
                    : "Sin línea de crédito")
    }

    private func porcentajeCredito(_ cliente: ClienteEntity) -> Double {
        guard cliente.limiteCredito > 0 else { return 0 }
        return min((cliente.creditoUsado / cliente.limiteCredito) * 100, 100)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func btnAnaliticaTapped(_ sender: UIButton) {
        showAnalitica()
    }

    @IBAction private func btnClientesTapped(_ sender: UIButton) {
        showClientes()
    }

    @IBAction private func btnAgregarClienteTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "mostrarModalCliente", sender: sender)
    }

    @IBAction private func btnTodosTapped(_ sender: UIButton) {
        currentFilter = .todos
        applyFilters()
        updateFilterButtons()
    }

    @IBAction private func btnActivosTapped(_ sender: UIButton) {
        currentFilter = .activos
        applyFilters()
        updateFilterButtons()
    }

    @IBAction private func btnVencidosTapped(_ sender: UIButton) {
        currentFilter = .vencidos
        applyFilters()
        updateFilterButtons()
    }

    @IBAction private func btnBloqueadosTapped(_ sender: UIButton) {
        currentFilter = .bloqueados
        applyFilters()
        updateFilterButtons()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredClientes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: clienteCellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: clienteCellIdentifier)
        let cliente = filteredClientes[indexPath.row]
        let info = statusInfo(for: cliente)

        var content = cell.defaultContentConfiguration()
        content.text = cliente.nombre ?? "Cliente sin nombre"
        content.secondaryText = "\(cliente.documento ?? "Sin documento")\n\(cliente.telefono ?? "Sin teléfono")\n\(info.progress)"
        content.secondaryTextProperties.numberOfLines = 3
        content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content

        let badge = UILabel(frame: CGRect(x: 0, y: 0, width: 92, height: 54))
        badge.numberOfLines = 2
        badge.textAlignment = .right
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = info.color
        badge.text = "\(info.title)\n\(info.amount)"
        cell.accessoryView = badge
        cell.selectionStyle = .none
        cell.backgroundColor = .white
        cell.layer.cornerRadius = 18
        cell.clipsToBounds = true
        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "mostrarModalCliente",
              let destination = segue.destination as? ModalClienteViewController else {
            return
        }
        destination.delegate = self
    }
}

extension ClientesViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilters()
    }
}

extension ClientesViewController: ModalClienteViewControllerDelegate {
    func modalClienteViewControllerDidSave(_ controller: ModalClienteViewController) {
        loadClientes()
        showClientes()
    }
}
