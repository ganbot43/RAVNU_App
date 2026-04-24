import CoreData
import SwiftUI
import UIKit

final class MasViewController: UIViewController {

    @IBOutlet private weak var lblNombre: UILabel?
    @IBOutlet private weak var lblRol: UILabel?
    @IBOutlet private weak var lblIniciales: UILabel?
    @IBOutlet private weak var lblCobrosTotal: UILabel?
    @IBOutlet private weak var lblVencidos: UILabel?
    @IBOutlet private weak var lblPendientes: UILabel?
    @IBOutlet private weak var lblDetalleTesoreria: UILabel?
    @IBOutlet private weak var lblDetalleCobros: UILabel?
    @IBOutlet private weak var stackModulosAdmin: UIStackView?
    @IBOutlet private weak var stackModulosAdminRow: UIStackView?
    @IBOutlet private weak var cardTesoreria: UIView?
    @IBOutlet private weak var cardCompras: UIView?
    @IBOutlet private weak var cardRRHH: UIView?
    @IBOutlet private weak var cardCobros: UIView?

    private let context = AppCoreData.viewContext
    private var hostingController: UIHostingController<MoreDashboardView>?

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
        configureLegacyUI()
        configureCardTaps()
        configureHybridView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshHybridView()
    }

    private func configureLegacyUI() {
        [
            lblNombre,
            lblRol,
            lblIniciales,
            lblCobrosTotal,
            lblVencidos,
            lblPendientes,
            lblDetalleTesoreria,
            lblDetalleCobros,
            stackModulosAdmin,
            stackModulosAdminRow,
            cardTesoreria,
            cardCompras,
            cardRRHH,
            cardCobros
        ].forEach { $0?.isHidden = true }
    }

    private func configureHybridView() {
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

    private func refreshHybridView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> MoreDashboardView {
        MoreDashboardView(
            data: makeDashboardData(),
            onOpenTreasury: { [weak self] in self?.tesoreriaCardTapped() },
            onOpenCollections: { [weak self] in self?.cobrosCardTapped() },
            onOpenPurchases: { [weak self] in self?.comprasCardTapped() },
            onOpenHumanResources: { [weak self] in self?.rrhhCardTapped() },
            onLogout: { [weak self] in self?.performLogout() }
        )
    }

    private func makeDashboardData() -> MoreDashboardViewData {
        let nombre = AppSession.shared.usuarioLogueado ?? "Usuario"
        let rol = AppSession.shared.rolLogueado ?? ""

        let ventas = fetchEntities(VentaEntity.fetchRequest())
        let cuotas = fetchEntities(CuotaEntity.fetchRequest())
        let ordenes = fetchEntities(OrdenCompraEntity.fetchRequest())
        let proveedores = fetchEntities(ProveedorEntity.fetchRequest())
        let usuarios = fetchEntities(LoginEntity.fetchRequest())

        let cuotasNoPagadas = cuotas.filter { !$0.pagada }
        let hoy = Calendar.current.startOfDay(for: Date())
        let vencidas = cuotasNoPagadas.filter {
            guard let fecha = $0.fechaVencimiento else { return false }
            return Calendar.current.startOfDay(for: fecha) < hoy
        }
        let pendientes = cuotasNoPagadas.filter {
            guard let fecha = $0.fechaVencimiento else { return true }
            return Calendar.current.startOfDay(for: fecha) >= hoy
        }

        let ingresosVentas = ventas.reduce(0.0) { $0 + $1.total }
        let ingresosCuotas = cuotas.filter { $0.pagada }.reduce(0.0) { $0 + $1.monto }
        let ingresosTotales = ingresosVentas + ingresosCuotas
        let gastosTotales = ordenes.reduce(0.0) { $0 + $1.total }
        let saldo = ingresosTotales - gastosTotales

        let ordenesPendientes = ordenes.filter {
            let status = ($0.estado ?? "").lowercased()
            return status.contains("pend") || status.contains("registr") || status.contains("aproba") || status.contains("pagad")
        }

        let visibleModules = MoreDashboardViewData.VisibleModules(
            tesoreria: RoleAccessControl.canViewTreasury,
            cobros: RoleAccessControl.canManageCollections,
            compras: RoleAccessControl.canManagePurchases,
            rrhh: RoleAccessControl.isAdmin
        )

        let teamMembers = usuarios.prefix(4).map { login in
            MoreDashboardViewData.TeamMember(
                initials: iniciales(from: login.usuario ?? "Usuario"),
                colorHex: colorHexForRole(login.rol ?? "")
            )
        }

        return MoreDashboardViewData(
            title: "Más",
            subtitle: "Módulos de gestión",
            userName: nombre,
            userRole: tituloRol(from: rol),
            userSubtitle: "Estación Central Lima",
            userInitials: iniciales(from: nombre),
            treasuryAmount: formatCurrency(saldo),
            treasuryDelta: gastosTotales > 0 ? "↘ \(formatCurrency(gastosTotales)) vs mes anterior" : "Sin egresos registrados",
            treasuryIncome: "Ingresos \(formatCurrency(ingresosTotales))",
            treasuryExpense: "Gastos \(formatCurrency(gastosTotales))",
            collectionsAmount: formatCurrency(cuotasNoPagadas.reduce(0.0) { $0 + $1.monto }),
            collectionsOverdue: vencidas.isEmpty ? "Sin vencidos" : "\(vencidas.count) vencidos · \(formatCurrency(vencidas.reduce(0.0) { $0 + $1.monto }))",
            collectionsPending: pendientes.isEmpty ? "Sin pendientes" : "\(pendientes.count) pendientes",
            purchasesAmount: formatCurrency(ordenes.reduce(0.0) { $0 + $1.total }),
            purchasesPending: ordenesPendientes.isEmpty ? "Sin pendientes" : "\(ordenesPendientes.count) pendiente\(ordenesPendientes.count == 1 ? "" : "s")",
            purchasesSuppliers: proveedores.isEmpty ? "Sin proveedores" : "\(proveedores.count) proveedores",
            teamTitle: "RRHH · PERSONAL",
            teamSubtitle: "Resumen del equipo",
            teamCount: "\(usuarios.count) Trabajadores",
            teamStatus: usuarios.isEmpty ? "Sin usuarios cargados" : "Todos activos hoy",
            teamMembers: teamMembers,
            sparklineValues: [0.72, 0.75, 0.73, 0.71, 0.78, 0.81, 0.80, 0.77],
            visibleModules: visibleModules
        )
    }

    private func fetchEntities<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        (try? context.fetch(request)) ?? []
    }

    private func iniciales(from nombre: String) -> String {
        let value = nombre
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
        return value.isEmpty ? "U" : value
    }

    private func tituloRol(from rol: String) -> String {
        switch rol {
        case "Admin":
            return "Administrador"
        case "Cajero":
            return "Cajero"
        case "Super":
            return "Supervisor"
        case "Almacen":
            return "Almacenero"
        default:
            return rol
        }
    }

    private func colorHexForRole(_ role: String) -> String {
        switch role {
        case "Admin":
            return "4F7CF7"
        case "Super":
            return "F6B73C"
        case "Almacen":
            return "8B5CF6"
        case "Cajero":
            return "22C55E"
        default:
            return "94A3B8"
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/ 0"
    }

    @IBAction private func btnCerrarSesion(_ sender: UIButton) {
        performLogout()
    }

    private func performLogout() {
        AppSession.shared.clear()
        cerrarSesionUniversal()
    }

    private func configureCardTaps() {
        let cobrosTap = UITapGestureRecognizer(target: self, action: #selector(cobrosCardTapped))
        cardCobros?.addGestureRecognizer(cobrosTap)
        cardCobros?.isUserInteractionEnabled = true

        let tesoreriaTap = UITapGestureRecognizer(target: self, action: #selector(tesoreriaCardTapped))
        cardTesoreria?.addGestureRecognizer(tesoreriaTap)
        cardTesoreria?.isUserInteractionEnabled = true

        let comprasTap = UITapGestureRecognizer(target: self, action: #selector(comprasCardTapped))
        cardCompras?.addGestureRecognizer(comprasTap)
        cardCompras?.isUserInteractionEnabled = true

        let rrhhTap = UITapGestureRecognizer(target: self, action: #selector(rrhhCardTapped))
        cardRRHH?.addGestureRecognizer(rrhhTap)
        cardRRHH?.isUserInteractionEnabled = true
    }

    @objc private func cobrosCardTapped() {
        performSegue(withIdentifier: "mostrarPantallaCuotas", sender: nil)
    }

    @objc private func tesoreriaCardTapped() {
        performSegue(withIdentifier: "mostrarPantallaTesoreria", sender: nil)
    }

    @objc private func comprasCardTapped() {
        performSegue(withIdentifier: "mostrarPantallaCompras", sender: nil)
    }

    @objc private func rrhhCardTapped() {
        performSegue(withIdentifier: "mostrarPantallaRRHH", sender: nil)
    }
}
