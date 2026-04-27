import UIKit
import CoreData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

fileprivate struct RegistroCliente {
    let id: UUID
    let name: String
    let docType: String
    let docNumber: String
    let phone: String
    let address: String
    let debt: Double
    let limit: Double
    let isActive: Bool

    var status: String {
        if !isActive {
            return "blocked"
        }
        guard limit > 0 else {
            return "active"
        }
        if debt >= limit {
            return "overdue"
        }
        if debt / limit >= 0.3 {
            return "atrisk"
        }
        return "active"
    }

    var statusText: String {
        switch status {
        case "active": return "Activo"
        case "atrisk": return "En riesgo"
        case "overdue": return "Vencido"
        case "blocked": return "Bloqueado"
        default: return "Activo"
        }
    }

    var shortName: String {
        if name.count <= 18 {
            return name
        }
        let pieces = name.split(separator: " ")
        return pieces.prefix(2).joined(separator: " ")
    }
}

fileprivate struct ResumenAnalitico {
    struct StatusMetric {
        let title: String
        let count: Int
        let ratio: CGFloat
        let color: UIColor
    }

    struct DebtorMetric {
        let name: String
        let amount: Double
        let ratio: CGFloat
    }

    struct CreditMetric {
        let name: String
        let amountText: String
        let percentageText: String
        let ratio: CGFloat
        let color: UIColor
    }

    let summaryText: String
    let totalClients: String
    let activeClients: String
    let totalDebt: String
    let overdueDebt: String
    let usedCredit: String
    let statusMetrics: [StatusMetric]
    let debtorMetrics: [DebtorMetric]
    let creditMetrics: [CreditMetric]
}

protocol ModalClienteViewControllerDelegate: AnyObject {
    func modalClienteViewControllerDidSave(_ controller: ModalClienteViewController)
}

final class ClientesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

    @IBOutlet private weak var btnAnalitica: UIButton?
    @IBOutlet private weak var btnClientes: UIButton?
    @IBOutlet private weak var searchBar: UISearchBar?
    @IBOutlet private weak var btnTodos: UIButton?
    @IBOutlet private weak var btnActivos: UIButton?
    @IBOutlet private weak var btnVencidos: UIButton?
    @IBOutlet private weak var btnBloqueados: UIButton?
    @IBOutlet private weak var tblClientes: UITableView?
    @IBOutlet private weak var analyticsScrollView: UIScrollView?
    @IBOutlet private weak var emptyStateView: UIView?
    @IBOutlet private weak var lblResumenClientes: UILabel?
    @IBOutlet private weak var lblTotalClientes: UILabel?
    @IBOutlet private weak var lblActivos: UILabel?
    @IBOutlet private weak var lblRiesgo: UILabel?
    @IBOutlet private weak var lblBloqueados: UILabel?

    private enum PestanaInterna {
        case analytics
        case clients
    }

    private enum ClienteFilter: String, CaseIterable {
        case todos = "Todos"
        case activos = "Activos"
        case vencidos = "Vencidos"
        case bloqueados = "Bloqueados"
    }

    private let clienteCellIdentifier = "clienteCell"
    private let searchController = UISearchController(searchResultsController: nil)
    private let segmentedControl = UISegmentedControl(items: ["Analítica", "Clientes"])
    private let rootContainer = UIView()
    private let analyticsScrollViewV2 = UIScrollView()
    private let analyticsContentView = UIView()
    private let clientsContainer = UIView()
    private let filterScrollView = UIScrollView()
    private let filterStackView = UIStackView()
    private let tableHeaderLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let analyticsStackView = UIStackView()

    private let kpiGridStack = UIStackView()
    private let distributionCard = UIView()
    private let distributionChartView = DonutChartView()
    private let distributionLegendStack = UIStackView()
    private let debtorsCard = UIView()
    private let debtorsStack = UIStackView()
    private let creditCard = UIView()
    private let creditStack = UIStackView()

    private var filterButtons: [ClienteFilter: FilterPillButton] = [:]
    private var clientes: [ClienteEntity] = []
    private var filteredClientes: [ClienteEntity] = []
    private var filtroActivo: ClienteFilter = .todos
    private var pestanaActiva: PestanaInterna = .analytics
    private var textoBusquedaActual = ""
    private var navSubtitleLabel: UILabel?
    private var navSubtitleTrailingConstraint: NSLayoutConstraint?
    private var rootTopConstraint: NSLayoutConstraint?
    private var resumenAnalitico = ResumenAnalitico(
        summaryText: "0 registrados · 0 vencidos",
        totalClients: "0",
        activeClients: "0",
        totalDebt: "S/0",
        overdueDebt: "S/0",
        usedCredit: "0%",
        statusMetrics: [],
        debtorMetrics: [],
        creditMetrics: []
    )

    #if canImport(FirebaseFirestore)
    private let firestore = Firestore.firestore()
    #endif

    private let contexto = AppCoreData.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarBarraNavegacion()
        ocultarVistaLegacyStoryboard()
        construirLayoutHibrido()
        configurarAccesoPorRol()
        configurarBuscador()
        configurarTabla()
        cargarClientes()
        actualizarVisibilidadPestanas(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateRootTopInset()
        layoutNavigationSubtitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarClientes()
    }

    private func configurarBarraNavegacion() {
        title = "Clientes"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appBackground
        appearance.largeTitleTextAttributes = [
            .font: UIFont.sfRounded(size: 34, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        appearance.titleTextAttributes = [
            .font: UIFont.sfRounded(size: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "＋ Agregar"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = .appBlue
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .sfRounded(size: 14, weight: .semibold)
            return outgoing
        }
        button.configuration = configuration
        button.addTarget(self, action: #selector(btnAgregarClienteTapped(_:)), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    private func ocultarVistaLegacyStoryboard() {
        [
            btnAnalitica,
            btnClientes,
            searchBar,
            btnTodos,
            btnActivos,
            btnVencidos,
            btnBloqueados,
            tblClientes,
            analyticsScrollView,
            emptyStateView,
            lblResumenClientes,
            lblTotalClientes,
            lblActivos,
            lblRiesgo,
            lblBloqueados
        ].forEach { view in
            view?.isHidden = true
        }
        view.backgroundColor = .appBackground
    }

    private func construirLayoutHibrido() {
        rootContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootContainer)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = .appBlue
        segmentedControl.backgroundColor = .secondarySystemBackground
        segmentedControl.setTitleTextAttributes([
            .font: UIFont.sfRounded(size: 14, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .font: UIFont.sfRounded(size: 14, weight: .semibold),
            .foregroundColor: UIColor.white
        ], for: .selected)
        segmentedControl.addTarget(self, action: #selector(internalTabChanged(_:)), for: .valueChanged)
        rootContainer.addSubview(segmentedControl)

        analyticsScrollViewV2.translatesAutoresizingMaskIntoConstraints = false
        analyticsScrollViewV2.showsVerticalScrollIndicator = false
        analyticsScrollViewV2.alwaysBounceVertical = true
        analyticsScrollViewV2.backgroundColor = .clear
        rootContainer.addSubview(analyticsScrollViewV2)

        analyticsContentView.translatesAutoresizingMaskIntoConstraints = false
        analyticsScrollViewV2.addSubview(analyticsContentView)

        analyticsStackView.translatesAutoresizingMaskIntoConstraints = false
        analyticsStackView.axis = .vertical
        analyticsStackView.spacing = 18
        analyticsContentView.addSubview(analyticsStackView)

        configurarSeccionAnalitica()

        clientsContainer.translatesAutoresizingMaskIntoConstraints = false
        clientsContainer.backgroundColor = .clear
        rootContainer.addSubview(clientsContainer)
        configurarSeccionClientes()

        let topConstraint = rootContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 54)
        rootTopConstraint = topConstraint

        NSLayoutConstraint.activate([
            topConstraint,
            rootContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            segmentedControl.topAnchor.constraint(equalTo: rootContainer.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: rootContainer.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: rootContainer.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),

            analyticsScrollViewV2.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            analyticsScrollViewV2.leadingAnchor.constraint(equalTo: rootContainer.leadingAnchor),
            analyticsScrollViewV2.trailingAnchor.constraint(equalTo: rootContainer.trailingAnchor),
            analyticsScrollViewV2.bottomAnchor.constraint(equalTo: rootContainer.bottomAnchor),

            analyticsContentView.topAnchor.constraint(equalTo: analyticsScrollViewV2.contentLayoutGuide.topAnchor),
            analyticsContentView.leadingAnchor.constraint(equalTo: analyticsScrollViewV2.contentLayoutGuide.leadingAnchor),
            analyticsContentView.trailingAnchor.constraint(equalTo: analyticsScrollViewV2.contentLayoutGuide.trailingAnchor),
            analyticsContentView.bottomAnchor.constraint(equalTo: analyticsScrollViewV2.contentLayoutGuide.bottomAnchor),
            analyticsContentView.widthAnchor.constraint(equalTo: analyticsScrollViewV2.frameLayoutGuide.widthAnchor),

            analyticsStackView.topAnchor.constraint(equalTo: analyticsContentView.topAnchor, constant: 16),
            analyticsStackView.leadingAnchor.constraint(equalTo: analyticsContentView.leadingAnchor, constant: 16),
            analyticsStackView.trailingAnchor.constraint(equalTo: analyticsContentView.trailingAnchor, constant: -16),
            analyticsStackView.bottomAnchor.constraint(equalTo: analyticsContentView.bottomAnchor, constant: -100),

            clientsContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            clientsContainer.leadingAnchor.constraint(equalTo: rootContainer.leadingAnchor),
            clientsContainer.trailingAnchor.constraint(equalTo: rootContainer.trailingAnchor),
            clientsContainer.bottomAnchor.constraint(equalTo: rootContainer.bottomAnchor)
        ])
    }

    private func configurarSeccionAnalitica() {
        let kpiTitleStack = UIStackView()
        kpiTitleStack.axis = .vertical
        kpiTitleStack.spacing = 2

        let analyticsSummaryLabel = UILabel()
        analyticsSummaryLabel.font = .sfRounded(size: 12, weight: .regular)
        analyticsSummaryLabel.textColor = .secondaryLabel
        analyticsSummaryLabel.numberOfLines = 0
        analyticsSummaryLabel.tag = 9001

        kpiTitleStack.addArrangedSubview(analyticsSummaryLabel)
        analyticsStackView.addArrangedSubview(kpiTitleStack)

        kpiGridStack.axis = .vertical
        kpiGridStack.spacing = 10
        analyticsStackView.addArrangedSubview(kpiGridStack)

        let firstRow = UIStackView()
        firstRow.axis = .horizontal
        firstRow.distribution = .fillEqually
        firstRow.spacing = 10

        let secondRow = UIStackView()
        secondRow.axis = .horizontal
        secondRow.distribution = .fillEqually
        secondRow.spacing = 10

        kpiGridStack.addArrangedSubview(firstRow)
        kpiGridStack.addArrangedSubview(secondRow)

        firstRow.addArrangedSubview(makeKPICard(tag: 100, title: "CLIENTES", symbol: "person.2.fill"))
        firstRow.addArrangedSubview(makeKPICard(tag: 101, title: "DEUDA TOTAL", symbol: "dollarsign.circle.fill"))
        secondRow.addArrangedSubview(makeKPICard(tag: 102, title: "DEUDA VENCIDA", symbol: "exclamationmark.circle.fill"))
        secondRow.addArrangedSubview(makeKPICard(tag: 103, title: "CRÉDITO USADO", symbol: "chart.line.uptrend.xyaxis"))

        distributionCard.translatesAutoresizingMaskIntoConstraints = false
        distributionCard.backgroundColor = .white
        distributionCard.layer.cornerRadius = 16
        distributionCard.applyCardShadow()

        let distributionTitle = sectionTitleLabel("Distribución por Estado")
        distributionCard.addSubview(distributionTitle)

        distributionChartView.translatesAutoresizingMaskIntoConstraints = false
        distributionCard.addSubview(distributionChartView)

        distributionLegendStack.translatesAutoresizingMaskIntoConstraints = false
        distributionLegendStack.axis = .vertical
        distributionLegendStack.spacing = 10
        distributionCard.addSubview(distributionLegendStack)

        analyticsStackView.addArrangedSubview(distributionCard)
        NSLayoutConstraint.activate([
            distributionCard.heightAnchor.constraint(equalToConstant: 190),
            distributionTitle.topAnchor.constraint(equalTo: distributionCard.topAnchor, constant: 16),
            distributionTitle.leadingAnchor.constraint(equalTo: distributionCard.leadingAnchor, constant: 16),
            distributionTitle.trailingAnchor.constraint(equalTo: distributionCard.trailingAnchor, constant: -16),

            distributionChartView.leadingAnchor.constraint(equalTo: distributionCard.leadingAnchor, constant: 16),
            distributionChartView.topAnchor.constraint(equalTo: distributionTitle.bottomAnchor, constant: 14),
            distributionChartView.widthAnchor.constraint(equalToConstant: 120),
            distributionChartView.heightAnchor.constraint(equalToConstant: 120),

            distributionLegendStack.leadingAnchor.constraint(equalTo: distributionChartView.trailingAnchor, constant: 16),
            distributionLegendStack.trailingAnchor.constraint(equalTo: distributionCard.trailingAnchor, constant: -16),
            distributionLegendStack.centerYAnchor.constraint(equalTo: distributionChartView.centerYAnchor)
        ])

        debtorsCard.translatesAutoresizingMaskIntoConstraints = false
        debtorsCard.backgroundColor = .white
        debtorsCard.layer.cornerRadius = 16
        debtorsCard.applyCardShadow()

        let debtorsTitle = sectionTitleLabel("Mayores Deudores")
        debtorsCard.addSubview(debtorsTitle)

        debtorsStack.translatesAutoresizingMaskIntoConstraints = false
        debtorsStack.axis = .vertical
        debtorsStack.spacing = 12
        debtorsCard.addSubview(debtorsStack)

        analyticsStackView.addArrangedSubview(debtorsCard)
        NSLayoutConstraint.activate([
            debtorsTitle.topAnchor.constraint(equalTo: debtorsCard.topAnchor, constant: 16),
            debtorsTitle.leadingAnchor.constraint(equalTo: debtorsCard.leadingAnchor, constant: 16),
            debtorsTitle.trailingAnchor.constraint(equalTo: debtorsCard.trailingAnchor, constant: -16),

            debtorsStack.topAnchor.constraint(equalTo: debtorsTitle.bottomAnchor, constant: 14),
            debtorsStack.leadingAnchor.constraint(equalTo: debtorsCard.leadingAnchor, constant: 16),
            debtorsStack.trailingAnchor.constraint(equalTo: debtorsCard.trailingAnchor, constant: -16),
            debtorsStack.bottomAnchor.constraint(equalTo: debtorsCard.bottomAnchor, constant: -16)
        ])

        creditCard.translatesAutoresizingMaskIntoConstraints = false
        creditCard.backgroundColor = .white
        creditCard.layer.cornerRadius = 16
        creditCard.applyCardShadow()

        let creditTitle = sectionTitleLabel("Utilización de Crédito")
        creditCard.addSubview(creditTitle)

        creditStack.translatesAutoresizingMaskIntoConstraints = false
        creditStack.axis = .vertical
        creditStack.spacing = 14
        creditCard.addSubview(creditStack)

        analyticsStackView.addArrangedSubview(creditCard)
        NSLayoutConstraint.activate([
            creditTitle.topAnchor.constraint(equalTo: creditCard.topAnchor, constant: 16),
            creditTitle.leadingAnchor.constraint(equalTo: creditCard.leadingAnchor, constant: 16),
            creditTitle.trailingAnchor.constraint(equalTo: creditCard.trailingAnchor, constant: -16),

            creditStack.topAnchor.constraint(equalTo: creditTitle.bottomAnchor, constant: 14),
            creditStack.leadingAnchor.constraint(equalTo: creditCard.leadingAnchor, constant: 16),
            creditStack.trailingAnchor.constraint(equalTo: creditCard.trailingAnchor, constant: -16),
            creditStack.bottomAnchor.constraint(equalTo: creditCard.bottomAnchor, constant: -16)
        ])
    }

    private func configurarSeccionClientes() {
        filterScrollView.translatesAutoresizingMaskIntoConstraints = false
        filterScrollView.showsHorizontalScrollIndicator = false
        clientsContainer.addSubview(filterScrollView)

        filterStackView.translatesAutoresizingMaskIntoConstraints = false
        filterStackView.axis = .horizontal
        filterStackView.spacing = 8
        filterScrollView.addSubview(filterStackView)

        tableHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        tableHeaderLabel.font = .sfRounded(size: 12, weight: .regular)
        tableHeaderLabel.textColor = .secondaryLabel
        tableHeaderLabel.text = "0 CLIENTES"
        clientsContainer.addSubview(tableHeaderLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        clientsContainer.addSubview(tableView)

        for filter in ClienteFilter.allCases {
            let button = FilterPillButton(title: filter.rawValue)
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            filterButtons[filter] = button
            filterStackView.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            filterScrollView.topAnchor.constraint(equalTo: clientsContainer.topAnchor, constant: 4),
            filterScrollView.leadingAnchor.constraint(equalTo: clientsContainer.leadingAnchor),
            filterScrollView.trailingAnchor.constraint(equalTo: clientsContainer.trailingAnchor),
            filterScrollView.heightAnchor.constraint(equalToConstant: 44),

            filterStackView.leadingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            filterStackView.trailingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            filterStackView.topAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.topAnchor),
            filterStackView.bottomAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.bottomAnchor),
            filterStackView.heightAnchor.constraint(equalTo: filterScrollView.frameLayoutGuide.heightAnchor),

            tableHeaderLabel.topAnchor.constraint(equalTo: filterScrollView.bottomAnchor, constant: 6),
            tableHeaderLabel.leadingAnchor.constraint(equalTo: clientsContainer.leadingAnchor, constant: 16),
            tableHeaderLabel.trailingAnchor.constraint(equalTo: clientsContainer.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: tableHeaderLabel.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: clientsContainer.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: clientsContainer.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: clientsContainer.bottomAnchor)
        ])
    }

    private func configurarAccesoPorRol() {
        navigationItem.rightBarButtonItem?.customView?.isHidden = RoleAccessControl.canCreateCustomers == false
    }

    private func configurarBuscador() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Buscar clientes..."
        searchController.searchBar.searchBarStyle = .minimal
        definesPresentationContext = true
    }

    private func configurarTabla() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 126
        tableView.separatorStyle = .none
        tableView.backgroundColor = .appBackground
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        tableView.register(ClientCell.self, forCellReuseIdentifier: clienteCellIdentifier)
    }

    private func cargarClientes() {
        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled {
            cargarClientesDesdeFirestore()
            return
        }
        #endif

        cargarClientesDesdeCacheLocal()
    }

    private func cargarClientesDesdeCacheLocal() {
        do {
            let request = ClienteEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
            clientes = try contexto.fetch(request)
            aplicarFiltros()
            actualizarAnalitica()
        } catch {
            mostrarAlerta(title: "Error", message: "No se pudieron cargar los clientes.")
        }
    }

    #if canImport(FirebaseFirestore)
    private func cargarClientesDesdeFirestore() {
        firestore.collection("customers")
            .order(by: "nombre")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.cargarClientesDesdeCacheLocal()
                    self.mostrarAlerta(title: "Clientes", message: "No se pudo cargar desde Firebase. Se mostrará el caché local.\n\(error.localizedDescription)")
                    return
                }

                do {
                    try self.sincronizarClientesFirestoreEnLocal(snapshot?.documents ?? [])
                    self.cargarClientesDesdeCacheLocal()
                } catch {
                    self.cargarClientesDesdeCacheLocal()
                    self.mostrarAlerta(title: "Clientes", message: "No se pudo actualizar el caché local de clientes.")
                }
            }
    }

    /// Mantiene Core Data alineado con la colección remota de clientes.
    private func sincronizarClientesFirestoreEnLocal(_ documents: [QueryDocumentSnapshot]) throws {
        let remoteIDs = Set(documents.map { stableUUID(from: $0.documentID) })

        for document in documents {
            let data = document.data()
            let cliente = try buscarOCrearCliente(documentId: document.documentID)
            cliente.id = UUID(uuidString: stringValue(data, keys: ["id", "uuid", "coreDataId"]) ?? "") ?? stableUUID(from: document.documentID)
            cliente.nombre = stringValue(data, keys: ["nombre", "name", "fullName"])
            cliente.documento = stringValue(data, keys: ["documento", "documentNumber"])
            cliente.telefono = stringValue(data, keys: ["telefono", "phone"])
            cliente.direccion = stringValue(data, keys: ["direccion", "address"])
            cliente.limiteCredito = doubleValue(data, keys: ["limiteCredito", "creditLimit"])
            cliente.creditoUsado = doubleValue(data, keys: ["creditoUsado", "creditUsed"])
            cliente.activo = boolValue(data, keys: ["activo", "active"], default: true)
        }

        let localRequest: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        let localClientes = try contexto.fetch(localRequest)
        for localCliente in localClientes where shouldDeleteLocalCliente(localCliente, keeping: remoteIDs) {
            contexto.delete(localCliente)
        }

        if contexto.hasChanges {
            try contexto.save()
        }
    }

    private func shouldDeleteLocalCliente(_ cliente: ClienteEntity, keeping remoteIDs: Set<UUID>) -> Bool {
        guard let localID = cliente.id else {
            return true
        }
        return remoteIDs.contains(localID) == false
    }

    private func buscarOCrearCliente(documentId: String) throws -> ClienteEntity {
        let request: NSFetchRequest<ClienteEntity> = ClienteEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", stableUUID(from: documentId) as CVarArg)

        if let existing = try contexto.fetch(request).first {
            return existing
        }

        let cliente = ClienteEntity(context: contexto)
        cliente.id = stableUUID(from: documentId)
        return cliente
    }

    private func stringValue(_ data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return value
            }
        }
        return nil
    }

    private func doubleValue(_ data: [String: Any], keys: [String]) -> Double {
        for key in keys {
            if let value = data[key] as? Double { return value }
            if let value = data[key] as? Int { return Double(value) }
            if let value = data[key] as? Int64 { return Double(value) }
            if let value = data[key] as? NSNumber { return value.doubleValue }
            if let value = data[key] as? String, let parsed = Double(value.replacingOccurrences(of: ",", with: ".")) {
                return parsed
            }
        }
        return 0
    }

    private func boolValue(_ data: [String: Any], keys: [String], default defaultValue: Bool) -> Bool {
        for key in keys {
            if let value = data[key] as? Bool { return value }
            if let value = data[key] as? NSNumber { return value.boolValue }
            if let value = data[key] as? String {
                switch value.lowercased() {
                case "true", "1", "si", "sí":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            }
        }
        return defaultValue
    }

    private func stableUUID(from identifier: String) -> UUID {
        if let uuid = UUID(uuidString: identifier) {
            return uuid
        }

        var hasher = Hasher()
        hasher.combine(identifier)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        let upper = String(format: "%08X", UInt32((hash >> 32) & 0xffffffff))
        let lower = String(format: "%08X", UInt32(hash & 0xffffffff))
        let composed = "\(upper)-0000-4000-8000-\(lower)\(lower.prefix(4))"
        return UUID(uuidString: composed) ?? UUID()
    }
    #endif

    private func aplicarFiltros() {
        filteredClientes = clientes.filter { cliente in
            matchesFilter(cliente) && matchesSearch(cliente)
        }
        tableHeaderLabel.text = "\(filteredClientes.count) CLIENTES"
        tableView.reloadData()
        actualizarAnalitica()
        updateFilterButtons()
        updateNavSubtitle()
    }

    private func matchesFilter(_ cliente: ClienteEntity) -> Bool {
        switch filtroActivo {
        case .todos:
            return true
        case .activos:
            return status(for: cliente) == "active"
        case .vencidos:
            return status(for: cliente) == "overdue"
        case .bloqueados:
            return status(for: cliente) == "blocked"
        }
    }

    private func matchesSearch(_ cliente: ClienteEntity) -> Bool {
        guard !textoBusquedaActual.isEmpty else { return true }
        let query = textoBusquedaActual.lowercased()
        return (cliente.nombre ?? "").lowercased().contains(query)
            || sanitizedDocument(from: cliente.documento ?? "").lowercased().contains(query)
            || (cliente.telefono ?? "").lowercased().contains(query)
    }

    private func actualizarAnalitica() {
        let records = clientes.map(crearRegistro(from:))
        let totalDebt = records.reduce(0) { $0 + $1.debt }
        let overdueRecords = records.filter { $0.status == "overdue" }
        let overdueDebt = overdueRecords.reduce(0) { $0 + $1.debt }
        let activeCount = records.filter { $0.status == "active" }.count

        let utilizationValues = records
            .filter { $0.limit > 0 }
            .map { ($0.debt / $0.limit) * 100 }
        let utilizationAverage = utilizationValues.isEmpty ? 0 : utilizationValues.reduce(0, +) / Double(utilizationValues.count)

        let activeStatusCount = records.filter { $0.status == "active" }.count
        let overdueStatusCount = records.filter { $0.status == "overdue" }.count
        let atRiskStatusCount = records.filter { $0.status == "atrisk" }.count
        let blockedStatusCount = records.filter { $0.status == "blocked" }.count

        let total = max(records.count, 1)
        let topDebtors = records
            .filter { $0.debt > 0 }
            .sorted { $0.debt > $1.debt }
            .prefix(4)
            .map { record in
                ResumenAnalitico.DebtorMetric(
                    name: record.shortName,
                    amount: record.debt,
                    ratio: CGFloat(record.debt / max(maximoMayoresDeudores(records), 1))
                )
            }

        let creditMetrics = records
            .filter { $0.limit > 0 }
            .map { record -> ResumenAnalitico.CreditMetric in
                let ratio = min(max(record.debt / record.limit, 0), 1)
                let color: UIColor
                switch ratio {
                case 0.8...:
                    color = .appRed
                case 0.5...:
                    color = .appOrange
                default:
                    color = .appGreen
                }
                return ResumenAnalitico.CreditMetric(
                    name: record.name,
                    amountText: "S/\(Int(record.debt)) / S/\(Int(record.limit))",
                    percentageText: "\(Int(ratio * 100))%",
                    ratio: CGFloat(ratio),
                    color: color
                )
            }

        resumenAnalitico = ResumenAnalitico(
            summaryText: "\(records.count) registrados · \(overdueStatusCount) vencidos",
            totalClients: "\(records.count)",
            activeClients: "\(activeCount)",
            totalDebt: "S/\(Int(totalDebt))",
            overdueDebt: "S/\(Int(overdueDebt))",
            usedCredit: "\(Int(utilizationAverage.rounded()))%",
            statusMetrics: [
                .init(title: "Activo", count: activeStatusCount, ratio: CGFloat(Double(activeStatusCount) / Double(total)), color: .appGreen),
                .init(title: "Vencido", count: overdueStatusCount, ratio: CGFloat(Double(overdueStatusCount) / Double(total)), color: .appRed),
                .init(title: "En riesgo", count: atRiskStatusCount, ratio: CGFloat(Double(atRiskStatusCount) / Double(total)), color: .appOrange),
                .init(title: "Bloqueado", count: blockedStatusCount, ratio: CGFloat(Double(blockedStatusCount) / Double(total)), color: UIColor(hex: "#9CA3AF"))
            ],
            debtorMetrics: Array(topDebtors),
            creditMetrics: creditMetrics
        )

        updateAnalyticsViews()
    }

    private func updateAnalyticsViews() {
        (analyticsStackView.viewWithTag(9001) as? UILabel)?.text = resumenAnalitico.summaryText

        updateKPICard(tag: 100, value: resumenAnalitico.totalClients, subtitle: "\(resumenAnalitico.statusMetrics.first?.count ?? 0) activos", color: .appBlue)
        updateKPICard(tag: 101, value: resumenAnalitico.totalDebt, subtitle: "\(resumenAnalitico.statusMetrics[1].count) vencidos", color: .appRed)
        updateKPICard(tag: 102, value: resumenAnalitico.overdueDebt, subtitle: "pendiente de cobro", color: .appOrange)
        updateKPICard(tag: 103, value: resumenAnalitico.usedCredit, subtitle: "utilización prom.", color: UIColor(hex: "#8B5CF6"))

        distributionChartView.update(metrics: resumenAnalitico.statusMetrics)
        rebuildDistributionLegend()
        rebuildDebtorsChart()
        rebuildCreditRows()
    }

    private func updateKPICard(tag: Int, value: String, subtitle: String, color: UIColor) {
        guard let card = kpiGridStack.viewWithTag(tag) else { return }
        (card.viewWithTag(1) as? UILabel)?.text = value
        (card.viewWithTag(1) as? UILabel)?.textColor = color
        (card.viewWithTag(2) as? UILabel)?.text = subtitle
        (card.viewWithTag(3) as? UIImageView)?.tintColor = color
        card.viewWithTag(4)?.backgroundColor = color.withAlphaComponent(0.12)
    }

    private func rebuildDistributionLegend() {
        distributionLegendStack.arrangedSubviews.forEach { row in
            distributionLegendStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        for metric in resumenAnalitico.statusMetrics {
            distributionLegendStack.addArrangedSubview(StatusLegendRow(metric: metric))
        }
    }

    private func rebuildDebtorsChart() {
        debtorsStack.arrangedSubviews.forEach { row in
            debtorsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        if resumenAnalitico.debtorMetrics.isEmpty {
            debtorsStack.addArrangedSubview(emptyAnalyticsLabel("Sin deudores registrados"))
            return
        }

        resumenAnalitico.debtorMetrics.forEach { debtor in
            debtorsStack.addArrangedSubview(DebtorBarRow(metric: debtor))
        }
    }

    private func rebuildCreditRows() {
        creditStack.arrangedSubviews.forEach { row in
            creditStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        if resumenAnalitico.creditMetrics.isEmpty {
            creditStack.addArrangedSubview(emptyAnalyticsLabel("Sin líneas de crédito registradas"))
            return
        }

        resumenAnalitico.creditMetrics.forEach { metric in
            creditStack.addArrangedSubview(CreditUsageRow(metric: metric))
        }
    }

    private func updateFilterButtons() {
        for (filter, button) in filterButtons {
            button.setSelected(filter == filtroActivo)
        }
    }

    private func actualizarVisibilidadPestanas(animated: Bool) {
        let updates = {
            self.analyticsScrollViewV2.alpha = self.pestanaActiva == .analytics ? 1 : 0
            self.clientsContainer.alpha = self.pestanaActiva == .clients ? 1 : 0
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: updates)
        } else {
            updates()
        }

        analyticsScrollViewV2.isHidden = pestanaActiva != .analytics
        clientsContainer.isHidden = pestanaActiva != .clients
        navigationItem.searchController = pestanaActiva == .clients ? searchController : nil
    }

    private func updateNavSubtitle() {
        navSubtitleLabel?.text = "\(clientes.count) registrados · \(clientes.filter { status(for: $0) == "overdue" }.count) vencidos"
        layoutNavigationSubtitle()
    }

    private func layoutNavigationSubtitle() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        if navSubtitleLabel == nil {
            let label = UILabel()
            label.font = .sfRounded(size: 12, weight: .regular)
            label.textColor = .secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            navigationBar.addSubview(label)
            navSubtitleLabel = label
            let trailingConstraint = label.trailingAnchor.constraint(lessThanOrEqualTo: navigationBar.trailingAnchor, constant: -130)
            navSubtitleTrailingConstraint = trailingConstraint
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 18),
                trailingConstraint,
                label.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -14)
            ])
        }
        navSubtitleLabel?.text = "\(clientes.count) registrados · \(clientes.filter { status(for: $0) == "overdue" }.count) vencidos"
    }

    private func updateRootTopInset() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let bottomGap = navigationBar.bounds.height > 60 ? 38.0 : 8.0
        let subtitleHeight = navSubtitleLabel?.intrinsicContentSize.height ?? 14
        let inset = max(52.0, subtitleHeight + bottomGap)
        rootTopConstraint?.constant = inset
    }

    private func crearRegistro(from cliente: ClienteEntity) -> RegistroCliente {
        let rawDocument = sanitizedDocument(from: cliente.documento ?? "")
        let components = rawDocument.components(separatedBy: " ")
        let docType = components.first ?? "DNI"
        let docNumber = components.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return RegistroCliente(
            id: cliente.id ?? UUID(),
            name: cliente.nombre ?? "Cliente sin nombre",
            docType: docType,
            docNumber: docNumber.isEmpty ? rawDocument : docNumber,
            phone: cliente.telefono ?? "Sin teléfono",
            address: cliente.direccion ?? "Sin dirección",
            debt: cliente.creditoUsado,
            limit: cliente.limiteCredito,
            isActive: cliente.activo
        )
    }

    private func sanitizedDocument(from value: String) -> String {
        value.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func status(for cliente: ClienteEntity) -> String {
        crearRegistro(from: cliente).status
    }

    private func sectionTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .sfRounded(size: 15, weight: .bold)
        label.textColor = .label
        label.text = text
        return label
    }

    private func emptyAnalyticsLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .sfRounded(size: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = text
        return label
    }

    private func makeKPICard(tag: Int, title: String, symbol: String) -> UIView {
        let card = UIView()
        card.tag = tag
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.applyCardShadow()

        let iconBackground = UIView()
        iconBackground.tag = 4
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.layer.cornerRadius = 10
        card.addSubview(iconBackground)

        let iconView = UIImageView(image: UIImage(systemName: symbol))
        iconView.tag = 3
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .sfRounded(size: 10, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title
        card.addSubview(titleLabel)

        let valueLabel = UILabel()
        valueLabel.tag = 1
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .sfRounded(size: 30, weight: .black)
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        valueLabel.setContentHuggingPriority(.required, for: .vertical)
        card.addSubview(valueLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.tag = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .sfRounded(size: 10, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        card.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 90),

            iconBackground.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconBackground.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconBackground.widthAnchor.constraint(equalToConstant: 28),
            iconBackground.heightAnchor.constraint(equalToConstant: 28),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            valueLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 10),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12)
        ])

        return card
    }

    private func maximoMayoresDeudores(_ records: [RegistroCliente]) -> Double {
        records.filter { $0.debt > 0 }.map(\.debt).max() ?? 1
    }

    private func formatCurrency(_ amount: Double) -> String {
        "S/\(Int(amount.rounded()))"
    }

    private func mostrarAlerta(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        let toast = UIView()
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.backgroundColor = .appGreen
        toast.layer.cornerRadius = 12
        toast.alpha = 0

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .white

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .sfRounded(size: 14, weight: .semibold)
        label.textColor = .white
        label.text = message

        toast.addSubview(icon)
        toast.addSubview(label)
        view.addSubview(toast)

        let bottomConstraint = toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 70)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toast.heightAnchor.constraint(equalToConstant: 50),
            bottomConstraint,

            icon.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: toast.centerYAnchor)
        ])

        view.layoutIfNeeded()
        bottomConstraint.constant = -12
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
            self.view.layoutIfNeeded()
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                bottomConstraint.constant = 70
                UIView.animate(withDuration: 0.25, animations: {
                    toast.alpha = 0
                    self.view.layoutIfNeeded()
                }) { _ in
                    toast.removeFromSuperview()
                }
            }
        }
    }

    @objc private func internalTabChanged(_ sender: UISegmentedControl) {
        pestanaActiva = sender.selectedSegmentIndex == 0 ? .analytics : .clients
        actualizarVisibilidadPestanas(animated: true)
    }

    @objc private func filterTapped(_ sender: FilterPillButton) {
        guard let filter = ClienteFilter(rawValue: sender.currentTitle ?? "") else { return }
        filtroActivo = filter
        aplicarFiltros()
    }

    @IBAction private func btnAnaliticaTapped(_ sender: UIButton) {
        segmentedControl.selectedSegmentIndex = 0
        internalTabChanged(segmentedControl)
    }

    @IBAction private func btnClientesTapped(_ sender: UIButton) {
        segmentedControl.selectedSegmentIndex = 1
        internalTabChanged(segmentedControl)
    }

    @IBAction private func btnAgregarClienteTapped(_ sender: Any) {
        guard RoleAccessControl.canCreateCustomers else {
            presentPermissionDeniedAlert(message: RoleAccessControl.denialMessage(for: .manageCustomers))
            return
        }
        performSegue(withIdentifier: "mostrarModalCliente", sender: sender)
    }

    @IBAction private func btnTodosTapped(_ sender: UIButton) {
        filtroActivo = .todos
        aplicarFiltros()
    }

    @IBAction private func btnActivosTapped(_ sender: UIButton) {
        filtroActivo = .activos
        aplicarFiltros()
    }

    @IBAction private func btnVencidosTapped(_ sender: UIButton) {
        filtroActivo = .vencidos
        aplicarFiltros()
    }

    @IBAction private func btnBloqueadosTapped(_ sender: UIButton) {
        filtroActivo = .bloqueados
        aplicarFiltros()
    }

    func updateSearchResults(for searchController: UISearchController) {
        textoBusquedaActual = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        aplicarFiltros()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredClientes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: clienteCellIdentifier, for: indexPath) as! ClientCell
        let record = crearRegistro(from: filteredClientes[indexPath.row])
        cell.configure(with: record)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "mostrarModalCliente",
              let destination = segue.destination as? ModalClienteViewController else {
            return
        }
        destination.delegate = self
    }
}

extension ClientesViewController: ModalClienteViewControllerDelegate {
    func modalClienteViewControllerDidSave(_ controller: ModalClienteViewController) {
        cargarClientes()
        pestanaActiva = .clients
        segmentedControl.selectedSegmentIndex = 1
        actualizarVisibilidadPestanas(animated: false)
        showToast("Cliente guardado correctamente")
    }
}

private final class ClientCell: UITableViewCell {
    private let cardView = UIView()
    private let colorBar = UIView()
    private let nameLabel = UILabel()
    private let docLabel = UILabel()
    private let phoneLabel = UILabel()
    private let statusBadge = StatusBadgeView()
    private let debtLabel = UILabel()
    private let progressContainer = UIView()
    private let progressFill = UIView()
    private let progressLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var progressWidthConstraint: NSLayoutConstraint?
    private var progressRatio: CGFloat = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        progressWidthConstraint?.constant = max((progressContainer.bounds.width) * progressRatio, 0)
    }

    private func setupViews() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 16
        cardView.applyCardShadow()
        contentView.addSubview(cardView)

        colorBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(colorBar)

        let topRow = UIStackView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8
        cardView.addSubview(topRow)

        let nameStack = UIStackView()
        nameStack.axis = .vertical
        nameStack.spacing = 6
        topRow.addArrangedSubview(nameStack)

        nameLabel.font = .sfRounded(size: 15, weight: .bold)
        nameLabel.textColor = .label
        nameStack.addArrangedSubview(nameLabel)

        docLabel.font = .sfRounded(size: 12, weight: .regular)
        docLabel.textColor = .secondaryLabel
        nameStack.addArrangedSubview(docLabel)

        topRow.addArrangedSubview(UIView())
        topRow.addArrangedSubview(statusBadge)

        let infoRow = UIStackView()
        infoRow.translatesAutoresizingMaskIntoConstraints = false
        infoRow.axis = .horizontal
        infoRow.alignment = .top
        infoRow.spacing = 12
        cardView.addSubview(infoRow)

        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 8
        infoRow.addArrangedSubview(leftStack)

        phoneLabel.font = .sfRounded(size: 12, weight: .regular)
        phoneLabel.textColor = .secondaryLabel
        leftStack.addArrangedSubview(phoneLabel)

        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.backgroundColor = UIColor(hex: "#F3F4F6")
        progressContainer.layer.cornerRadius = 2.5
        leftStack.addArrangedSubview(progressContainer)
        progressContainer.heightAnchor.constraint(equalToConstant: 5).isActive = true

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.layer.cornerRadius = 2.5
        progressContainer.addSubview(progressFill)
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
        NSLayoutConstraint.activate([
            progressFill.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor)
        ])

        progressLabel.font = .sfRounded(size: 10, weight: .regular)
        progressLabel.textColor = .secondaryLabel
        leftStack.addArrangedSubview(progressLabel)

        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 8
        infoRow.addArrangedSubview(rightStack)

        debtLabel.font = .sfRounded(size: 16, weight: .bold)
        rightStack.addArrangedSubview(debtLabel)

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        rightStack.addArrangedSubview(chevron)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            colorBar.topAnchor.constraint(equalTo: cardView.topAnchor),
            colorBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            colorBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            colorBar.heightAnchor.constraint(equalToConstant: 3),

            topRow.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            topRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            topRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),

            infoRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            infoRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            infoRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            infoRow.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with client: RegistroCliente) {
        nameLabel.text = client.name
        docLabel.text = "\(client.docType) \(client.docNumber)"
        phoneLabel.text = "☎︎  \(client.phone)"
        statusBadge.update(text: client.statusText, status: client.status)

        let debtText = "S/\(Int(client.debt.rounded()))"
        debtLabel.text = debtText
        debtLabel.textColor = client.debt > 0 ? .appRed : .appGreen

        let ratio = client.limit > 0 ? min(max(client.debt / client.limit, 0), 1) : 0
        progressRatio = CGFloat(ratio)
        progressContainer.isHidden = client.debt == 0 || client.limit == 0
        progressLabel.isHidden = client.debt == 0 || client.limit == 0
        progressLabel.text = "\(Int(ratio * 100))% del límite S/\(Int(client.limit))"

        switch client.status {
        case "overdue":
            colorBar.backgroundColor = .appRed
            progressFill.backgroundColor = .appRed
        case "atrisk":
            colorBar.backgroundColor = .appOrange
            progressFill.backgroundColor = .appOrange
        case "blocked":
            colorBar.backgroundColor = UIColor(hex: "#9CA3AF")
            progressFill.backgroundColor = UIColor(hex: "#9CA3AF")
        default:
            colorBar.backgroundColor = .appGreen
            progressFill.backgroundColor = .appBlue
        }

        setNeedsLayout()
    }
}

private final class FilterPillButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .sfRounded(size: 14, weight: .medium)
            return outgoing
        }
        self.configuration = configuration
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        backgroundColor = .secondarySystemBackground
        configurationUpdateHandler = { button in
            button.configuration?.baseForegroundColor = .secondaryLabel
        }
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 32).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ isSelected: Bool) {
        if isSelected {
            backgroundColor = .appBlue
            configuration?.baseForegroundColor = .white
            layer.borderColor = UIColor.clear.cgColor
            layer.shadowColor = UIColor.appBlue.cgColor
            layer.shadowOpacity = 0.2
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
        } else {
            backgroundColor = .secondarySystemBackground
            configuration?.baseForegroundColor = .secondaryLabel
            layer.borderColor = UIColor.separator.cgColor
            layer.shadowOpacity = 0
        }
    }
}

private final class DonutChartView: UIView {
    private var metrics: [ResumenAnalitico.StatusMetric] = []
    private let lineWidth: CGFloat = 20

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    func update(metrics: [ResumenAnalitico.StatusMetric]) {
        self.metrics = metrics
        layer.sublayers?.removeAll(where: { $0.name == "segment" || $0.name == "centerLabel" })
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.removeAll(where: { $0.name == "segment" || $0.name == "centerLabel" })

        guard !metrics.isEmpty else { return }
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth
        var startAngle = -CGFloat.pi / 2
        let gap: CGFloat = 0.05

        for metric in metrics where metric.count > 0 {
            let span = max(CGFloat.pi * 2 * metric.ratio - gap, 0)
            let endAngle = startAngle + span
            let path = UIBezierPath(
                arcCenter: centerPoint,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )

            let shape = CAShapeLayer()
            shape.name = "segment"
            shape.path = path.cgPath
            shape.strokeColor = metric.color.cgColor
            shape.fillColor = UIColor.clear.cgColor
            shape.lineWidth = lineWidth
            shape.lineCap = .round
            shape.strokeEnd = 1
            layer.addSublayer(shape)

            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 0.8
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shape.add(animation, forKey: "strokeEnd")

            startAngle = endAngle + gap
        }

        let textLayer = CATextLayer()
        textLayer.name = "centerLabel"
        textLayer.contentsScale = window?.screen.scale ?? traitCollection.displayScale
        textLayer.alignmentMode = .center
        textLayer.string = NSAttributedString(
            string: "\(metrics.reduce(0) { $0 + $1.count })\nclientes",
            attributes: [
                .font: UIFont.sfRounded(size: 13, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        )
        textLayer.frame = CGRect(x: 0, y: bounds.midY - 18, width: bounds.width, height: 36)
        layer.addSublayer(textLayer)
    }
}

private final class StatusLegendRow: UIView {
    init(metric: ResumenAnalitico.StatusMetric) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = metric.color
        dot.layer.cornerRadius = 4

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .sfRounded(size: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = metric.title

        let countLabel = UILabel()
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .sfRounded(size: 12, weight: .bold)
        countLabel.textColor = .label
        countLabel.text = "\(metric.count)"

        let progressTrack = UIView()
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = UIColor(hex: "#F3F4F6")
        progressTrack.layer.cornerRadius = 2

        let progressFill = UIView()
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = metric.color
        progressFill.layer.cornerRadius = 2
        progressTrack.addSubview(progressFill)

        addSubview(dot)
        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(progressTrack)

        let fillWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: max(metric.ratio, 0.02))
        fillWidth.isActive = true

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor),

            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor),

            progressTrack.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 8),
            progressTrack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 4),
            progressTrack.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class DebtorBarRow: UIView {
    private let fillView = UIView()
    private var fillConstraint: NSLayoutConstraint?

    init(metric: ResumenAnalitico.DebtorMetric) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .sfRounded(size: 11, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.text = metric.name

        let amountLabel = UILabel()
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = .sfRounded(size: 11, weight: .bold)
        amountLabel.textColor = .appRed
        amountLabel.textAlignment = .right
        amountLabel.text = "S/\(Int(metric.amount))"

        let barTrack = UIView()
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.backgroundColor = UIColor(hex: "#FEE2E2")
        barTrack.layer.cornerRadius = 4

        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.backgroundColor = .appRed
        fillView.layer.cornerRadius = 4
        barTrack.addSubview(fillView)

        addSubview(nameLabel)
        addSubview(barTrack)
        addSubview(amountLabel)

        fillConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillConstraint?.isActive = true

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 88),

            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            amountLabel.widthAnchor.constraint(equalToConstant: 56),

            barTrack.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            barTrack.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -8),
            barTrack.centerYAnchor.constraint(equalTo: centerYAnchor),
            barTrack.heightAnchor.constraint(equalToConstant: 8),

            fillView.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: barTrack.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            heightAnchor.constraint(equalToConstant: 28)
        ])

        layoutIfNeeded()
        fillConstraint?.constant = max(barTrack.bounds.width * metric.ratio, 6)
        UIView.animate(withDuration: 0.6) {
            self.layoutIfNeeded()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class CreditUsageRow: UIView {
    private let fillView = UIView()
    private var fillConstraint: NSLayoutConstraint?

    init(metric: ResumenAnalitico.CreditMetric) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.spacing = 8
        addSubview(topRow)

        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 2

        let nameLabel = UILabel()
        nameLabel.font = .sfRounded(size: 11, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.text = metric.name

        let amountLabel = UILabel()
        amountLabel.font = .sfRounded(size: 10, weight: .regular)
        amountLabel.textColor = .tertiaryLabel
        amountLabel.text = metric.amountText

        leftStack.addArrangedSubview(nameLabel)
        leftStack.addArrangedSubview(amountLabel)
        topRow.addArrangedSubview(leftStack)
        topRow.addArrangedSubview(UIView())

        let percentageLabel = UILabel()
        percentageLabel.font = .sfRounded(size: 10, weight: .bold)
        percentageLabel.textColor = metric.color
        percentageLabel.text = metric.percentageText
        topRow.addArrangedSubview(percentageLabel)

        let track = UIView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor(hex: "#F3F4F6")
        track.layer.cornerRadius = 3
        addSubview(track)

        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.backgroundColor = metric.color
        fillView.layer.cornerRadius = 3
        track.addSubview(fillView)

        fillConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillConstraint?.isActive = true

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: topAnchor),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: trailingAnchor),

            track.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: 6),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),

            fillView.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: track.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: track.bottomAnchor)
        ])

        layoutIfNeeded()
        fillConstraint?.constant = max(track.bounds.width * metric.ratio, metric.ratio == 0 ? 0 : 8)
        UIView.animate(withDuration: 0.5) {
            self.layoutIfNeeded()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class StatusBadgeView: UIView {
    private let label = UILabel()

    init(status: String = "active") {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.font = .sfRounded(size: 11, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
        update(status: status)
    }

    func update(text: String? = nil, status: String) {
        switch status {
        case "active":
            backgroundColor = .appGreen
            label.text = text ?? "Activo"
        case "atrisk":
            backgroundColor = .appOrange
            label.text = text ?? "En riesgo"
        case "overdue":
            backgroundColor = .appRed
            label.text = text ?? "Vencido"
        case "blocked":
            backgroundColor = UIColor(hex: "#9CA3AF")
            label.text = text ?? "Bloqueado"
        default:
            backgroundColor = .appGreen
            label.text = text ?? "Activo"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIColor {
    static let appBlue = UIColor(hex: "#3B82F6")
    static let appGreen = UIColor(hex: "#22C55E")
    static let appRed = UIColor(hex: "#EF4444")
    static let appOrange = UIColor(hex: "#F59E0B")
    static let appBackground = UIColor(hex: "#F4F6FA")
    static let appCard = UIColor.white

    convenience init(hex: String) {
        let hexValue = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&int)
        self.init(
            red: CGFloat((int & 0xFF0000) >> 16) / 255,
            green: CGFloat((int & 0x00FF00) >> 8) / 255,
            blue: CGFloat(int & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

private extension UIFont {
    static func sfRounded(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

private extension UIView {
    func applyCardShadow(
        color: UIColor = .black,
        opacity: Float = 0.06,
        offset: CGSize = CGSize(width: 0, height: 2),
        radius: CGFloat = 8
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
}
