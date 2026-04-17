import CoreData
import UIKit

final class CuotasViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var analyticsScrollView: UIScrollView?
    @IBOutlet private weak var tblCuotas: UITableView?
    @IBOutlet private weak var btnAnalitica: UIButton?
    @IBOutlet private weak var btnCuotas: UIButton?
    @IBOutlet private weak var btnTodos: UIButton?
    @IBOutlet private weak var btnPendiente: UIButton?
    @IBOutlet private weak var btnVencido: UIButton?
    @IBOutlet private weak var btnPagado: UIButton?
    @IBOutlet private weak var lblVencidoTotal: UILabel?
    @IBOutlet private weak var lblVencidoDetalle: UILabel?
    @IBOutlet private weak var lblPendienteTotal: UILabel?
    @IBOutlet private weak var lblPendienteDetalle: UILabel?
    @IBOutlet private weak var lblHoyTotal: UILabel?
    @IBOutlet private weak var lblHoyDetalle: UILabel?
    @IBOutlet private weak var lblProgreso: UILabel?
    @IBOutlet private weak var lblClientesDeuda: UILabel?
    @IBOutlet private weak var emptyStateView: UIView?

    private enum FiltroCuota {
        case todos
        case pendiente
        case vencido
        case pagado
    }

    private let cellIdentifier = "cuotaCell"
    private let activeColor = UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
    private let inactiveColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)
    private var cuotas: [CuotaEntity] = []
    private var filteredCuotas: [CuotaEntity] = []
    private var filtroActual: FiltroCuota = .todos

    private var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer.viewContext
    }

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
        configureTextBehavior()
        configureTableView()
        loadCuotas()
        updateFilterButtons()
        showAnalitica()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCuotas()
    }

    private func configureTableView() {
        tblCuotas?.register(CuotaTableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tblCuotas?.dataSource = self
        tblCuotas?.delegate = self
        tblCuotas?.rowHeight = 150
        tblCuotas?.estimatedRowHeight = 150
        tblCuotas?.tableFooterView = UIView()
        tblCuotas?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tblCuotas?.showsVerticalScrollIndicator = false
    }

    private func configureTextBehavior() {
        [
            lblVencidoTotal,
            lblVencidoDetalle,
            lblPendienteTotal,
            lblPendienteDetalle,
            lblHoyTotal,
            lblHoyDetalle,
            lblProgreso,
            lblClientesDeuda
        ].forEach { label in
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.72
        }

        lblClientesDeuda?.numberOfLines = 2
        [btnTodos, btnPendiente, btnVencido, btnPagado].forEach { button in
            button?.titleLabel?.adjustsFontSizeToFitWidth = true
            button?.titleLabel?.minimumScaleFactor = 0.72
        }
    }

    private func loadCuotas() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "fechaVencimiento", ascending: true)]

        do {
            cuotas = try context.fetch(request)
            applyFilter()
            updateAnalytics()
        } catch {
            cuotas = []
            filteredCuotas = []
            tblCuotas?.reloadData()
            emptyStateView?.isHidden = false
        }
    }

    private func updateAnalytics() {
        let today = Calendar.current.startOfDay(for: Date())
        let pendientes = cuotas.filter { !$0.pagada }
        let vencidas = pendientes.filter {
            guard let fecha = $0.fechaVencimiento else { return false }
            return Calendar.current.startOfDay(for: fecha) < today
        }
        let hoy = pendientes.filter {
            guard let fecha = $0.fechaVencimiento else { return false }
            return Calendar.current.isDateInToday(fecha)
        }
        let pagadas = cuotas.filter { $0.pagada }

        let totalPendiente = pendientes.reduce(0.0) { $0 + $1.monto }
        let totalVencido = vencidas.reduce(0.0) { $0 + $1.monto }
        let totalHoy = hoy.reduce(0.0) { $0 + $1.monto }
        let porcentaje = cuotas.isEmpty ? 0 : Int((Double(pagadas.count) / Double(cuotas.count) * 100).rounded())
        let clientesConDeuda = Set(pendientes.compactMap { $0.venta?.cliente?.nombre }).count

        lblVencidoTotal?.text = vencidas.isEmpty ? "S/0" : formatCurrency(totalVencido)
        lblVencidoDetalle?.text = vencidas.isEmpty ? "0 cuotas" : "\(vencidas.count) cuota(s)"
        lblPendienteTotal?.text = pendientes.isEmpty ? "S/0" : formatCurrency(totalPendiente)
        lblPendienteDetalle?.text = pendientes.isEmpty ? "0 cuotas" : "\(pendientes.count) cuota(s)"
        lblHoyTotal?.text = hoy.isEmpty ? "S/0" : formatCurrency(totalHoy)
        lblHoyDetalle?.text = hoy.isEmpty ? "Sin cobros" : "\(hoy.count) hoy"
        lblProgreso?.text = "\(porcentaje)% cobrado"
        lblClientesDeuda?.text = clientesConDeuda == 0 ? "Sin clientes con deuda activa" : "\(clientesConDeuda) cliente(s) con deuda activa"
    }

    private func applyFilter() {
        let today = Calendar.current.startOfDay(for: Date())
        switch filtroActual {
        case .todos:
            filteredCuotas = cuotas
        case .pendiente:
            filteredCuotas = cuotas.filter { !$0.pagada }
        case .vencido:
            filteredCuotas = cuotas.filter { cuota in
                guard !cuota.pagada, let fecha = cuota.fechaVencimiento else { return false }
                return Calendar.current.startOfDay(for: fecha) < today
            }
        case .pagado:
            filteredCuotas = cuotas.filter { $0.pagada }
        }
        tblCuotas?.reloadData()
        emptyStateView?.isHidden = !filteredCuotas.isEmpty
    }

    private func showAnalitica() {
        analyticsScrollView?.isHidden = false
        tblCuotas?.isHidden = true
        emptyStateView?.isHidden = true
        updateTabStyle(activeButton: btnAnalitica, inactiveButton: btnCuotas)
    }

    private func showCuotas() {
        analyticsScrollView?.isHidden = true
        tblCuotas?.isHidden = false
        emptyStateView?.isHidden = !filteredCuotas.isEmpty
        updateTabStyle(activeButton: btnCuotas, inactiveButton: btnAnalitica)
    }

    private func updateTabStyle(activeButton: UIButton?, inactiveButton: UIButton?) {
        if var activeConfig = activeButton?.configuration {
            activeConfig.baseForegroundColor = UIColor(red: 0.188, green: 0.196, blue: 0.271, alpha: 1)
            activeConfig.background.backgroundColor = .white
            activeButton?.configuration = activeConfig
        }
        if var inactiveConfig = inactiveButton?.configuration {
            inactiveConfig.baseForegroundColor = inactiveColor
            inactiveConfig.background.backgroundColor = .clear
            inactiveButton?.configuration = inactiveConfig
        }
    }

    private func updateFilterButtons() {
        let buttons: [(UIButton?, FiltroCuota)] = [
            (btnTodos, .todos),
            (btnPendiente, .pendiente),
            (btnVencido, .vencido),
            (btnPagado, .pagado)
        ]
        buttons.forEach { button, filter in
            guard var config = button?.configuration else { return }
            let isActive = filter == filtroActual
            config.baseForegroundColor = isActive ? .white : inactiveColor
            config.baseBackgroundColor = isActive ? activeColor : .white
            button?.configuration = config
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/0"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Sin fecha" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }

    private func isVencida(_ cuota: CuotaEntity) -> Bool {
        guard !cuota.pagada, let fecha = cuota.fechaVencimiento else { return false }
        return Calendar.current.startOfDay(for: fecha) < Calendar.current.startOfDay(for: Date())
    }

    @IBAction private func btnVolverTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction private func btnAnaliticaTapped(_ sender: UIButton) {
        showAnalitica()
    }

    @IBAction private func btnCuotasTapped(_ sender: UIButton) {
        showCuotas()
    }

    @IBAction private func btnTodosTapped(_ sender: UIButton) {
        filtroActual = .todos
        updateFilterButtons()
        applyFilter()
    }

    @IBAction private func btnPendienteTapped(_ sender: UIButton) {
        filtroActual = .pendiente
        updateFilterButtons()
        applyFilter()
    }

    @IBAction private func btnVencidoTapped(_ sender: UIButton) {
        filtroActual = .vencido
        updateFilterButtons()
        applyFilter()
    }

    @IBAction private func btnPagadoTapped(_ sender: UIButton) {
        filtroActual = .pagado
        updateFilterButtons()
        applyFilter()
    }

    @IBAction private func btnPagarTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "mostrarModalCuota", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let modalCuota = segue.destination as? ModalCuotaViewController {
            modalCuota.delegate = self
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredCuotas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let cuota = filteredCuotas[indexPath.row]
        let cliente = cuota.venta?.cliente?.nombre ?? "Cliente"
        let numero = cuota.numero
        let totalCuotas = max(cuota.venta?.cuotas?.count ?? Int(numero), Int(numero))
        let estado: CuotaTableViewCell.Status = cuota.pagada ? .pagado : (isVencida(cuota) ? .vencido : .pendiente)

        if let cuotaCell = cell as? CuotaTableViewCell {
            cuotaCell.configure(
                cliente: cliente,
                cuota: "Cuota \(numero) de \(totalCuotas)",
                monto: formatCurrency(cuota.monto),
                vencimiento: "Vence \(formatDate(cuota.fechaVencimiento))",
                progress: totalCuotas == 0 ? 0 : CGFloat(numero) / CGFloat(totalCuotas),
                status: estado
            )
        }
        return cell
    }
}

extension CuotasViewController: ModalCuotaViewControllerDelegate {

    func modalCuotaViewControllerDidSavePago(_ controller: ModalCuotaViewController) {
        loadCuotas()
        showCuotas()
    }
}

private final class CuotaTableViewCell: UITableViewCell {

    enum Status {
        case pendiente
        case vencido
        case pagado

        var title: String {
            switch self {
            case .pendiente:
                return "Pendiente"
            case .vencido:
                return "Vencido"
            case .pagado:
                return "Pagado"
            }
        }

        var color: UIColor {
            switch self {
            case .pendiente:
                return UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
            case .vencido:
                return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
            case .pagado:
                return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
            }
        }
    }

    private let cardView = UIView()
    private let clienteLabel = UILabel()
    private let cuotaLabel = UILabel()
    private let montoLabel = UILabel()
    private let estadoLabel = UILabel()
    private let vencimientoLabel = UILabel()
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
        cardView.layer.shadowOpacity = 0.07
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.addSubview(cardView)

        [clienteLabel, cuotaLabel, montoLabel, estadoLabel, vencimientoLabel, progressBackground, progressBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        clienteLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        clienteLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        clienteLabel.numberOfLines = 1
        clienteLabel.adjustsFontSizeToFitWidth = true
        clienteLabel.minimumScaleFactor = 0.82

        cuotaLabel.font = .systemFont(ofSize: 13, weight: .regular)
        cuotaLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)

        montoLabel.font = .systemFont(ofSize: 22, weight: .bold)
        montoLabel.textColor = UIColor(red: 0.074, green: 0.086, blue: 0.157, alpha: 1)
        montoLabel.textAlignment = .right
        montoLabel.adjustsFontSizeToFitWidth = true
        montoLabel.minimumScaleFactor = 0.75

        estadoLabel.font = .systemFont(ofSize: 12, weight: .bold)
        estadoLabel.textAlignment = .center
        estadoLabel.textColor = .white
        estadoLabel.layer.cornerRadius = 10
        estadoLabel.clipsToBounds = true

        vencimientoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        vencimientoLabel.textColor = UIColor(red: 0.596, green: 0.608, blue: 0.675, alpha: 1)

        progressBackground.backgroundColor = UIColor(red: 0.935, green: 0.941, blue: 0.961, alpha: 1)
        progressBackground.layer.cornerRadius = 3
        progressBackground.clipsToBounds = true
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true

        [clienteLabel, cuotaLabel, montoLabel, estadoLabel, vencimientoLabel, progressBackground].forEach {
            cardView.addSubview($0)
        }
        progressBackground.addSubview(progressBar)

        progressWidthConstraint = progressBar.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: 0)
        progressWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            clienteLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            clienteLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            clienteLabel.trailingAnchor.constraint(lessThanOrEqualTo: estadoLabel.leadingAnchor, constant: -12),

            estadoLabel.centerYAnchor.constraint(equalTo: clienteLabel.centerYAnchor),
            estadoLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            estadoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            estadoLabel.heightAnchor.constraint(equalToConstant: 22),

            cuotaLabel.topAnchor.constraint(equalTo: clienteLabel.bottomAnchor, constant: 4),
            cuotaLabel.leadingAnchor.constraint(equalTo: clienteLabel.leadingAnchor),
            cuotaLabel.trailingAnchor.constraint(lessThanOrEqualTo: montoLabel.leadingAnchor, constant: -12),

            montoLabel.topAnchor.constraint(equalTo: estadoLabel.bottomAnchor, constant: 10),
            montoLabel.trailingAnchor.constraint(equalTo: estadoLabel.trailingAnchor),
            montoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 116),

            progressBackground.topAnchor.constraint(equalTo: cuotaLabel.bottomAnchor, constant: 26),
            progressBackground.leadingAnchor.constraint(equalTo: clienteLabel.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: montoLabel.leadingAnchor, constant: -16),
            progressBackground.heightAnchor.constraint(equalToConstant: 6),

            progressBar.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),

            vencimientoLabel.topAnchor.constraint(equalTo: progressBackground.bottomAnchor, constant: 12),
            vencimientoLabel.leadingAnchor.constraint(equalTo: clienteLabel.leadingAnchor),
            vencimientoLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18)
        ])
    }

    func configure(cliente: String, cuota: String, monto: String, vencimiento: String, progress: CGFloat, status: Status) {
        clienteLabel.text = cliente
        cuotaLabel.text = cuota
        montoLabel.text = monto
        vencimientoLabel.text = vencimiento
        estadoLabel.text = status.title
        estadoLabel.backgroundColor = status.color
        progressBar.backgroundColor = status.color

        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressBar.widthAnchor.constraint(
            equalTo: progressBackground.widthAnchor,
            multiplier: min(max(progress, 0.08), 1)
        )
        progressWidthConstraint?.isActive = true
    }
}
