import CoreData
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

    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
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
        configureRoleAccess()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureRoleAccess()
        cargarDatosUsuario()
        cargarDatosCuotas()
    }

    private func configureRoleAccess() {
        let rol = UserDefaults.standard.string(forKey: "rolLogueado") ?? ""

        let canSeeTesoreria = rol == "Admin" || rol == "Super"
        let canSeeCobros = rol == "Admin" || rol == "Super" || rol == "Cajero"
        let canSeeCompras = rol == "Admin" || rol == "Almacen"
        let canSeeRRHH = rol == "Admin"

        cardTesoreria?.isHidden = !canSeeTesoreria
        cardCobros?.isHidden = !canSeeCobros
        cardCompras?.isHidden = !canSeeCompras
        cardRRHH?.isHidden = !canSeeRRHH
        stackModulosAdminRow?.isHidden = !canSeeCompras && !canSeeRRHH
        stackModulosAdmin?.isHidden = !canSeeTesoreria && !canSeeCompras && !canSeeRRHH
    }

    private func configureTextBehavior() {
        [lblNombre, lblRol, lblCobrosTotal, lblVencidos, lblPendientes, lblDetalleTesoreria, lblDetalleCobros].forEach { label in
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.78
        }

        lblNombre?.numberOfLines = 1
        lblVencidos?.numberOfLines = 2
        lblPendientes?.numberOfLines = 2
        lblDetalleTesoreria?.numberOfLines = 2
        lblDetalleCobros?.numberOfLines = 2

        [cardTesoreria, cardCobros, cardCompras, cardRRHH].forEach { card in
            card?.layer.shadowColor = UIColor.black.cgColor
            card?.layer.shadowOpacity = 0.06
            card?.layer.shadowRadius = 8
            card?.layer.shadowOffset = CGSize(width: 0, height: 3)
        }
    }

    private func cargarDatosUsuario() {
        let nombre = UserDefaults.standard.string(forKey: "usuarioLogueado") ?? "Usuario"
        let rol = UserDefaults.standard.string(forKey: "rolLogueado") ?? ""

        lblNombre?.text = nombre
        lblIniciales?.text = iniciales(from: nombre)
        lblRol?.text = tituloRol(from: rol)
    }

    private func cargarDatosCuotas() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()

        do {
            let cuotas = try context.fetch(request)
            let noPagadas = cuotas.filter { !$0.pagada }
            let hoy = Calendar.current.startOfDay(for: Date())

            let vencidas = noPagadas.filter {
                guard let fecha = $0.fechaVencimiento else { return false }
                return Calendar.current.startOfDay(for: fecha) < hoy
            }

            let pendientes = noPagadas.filter {
                guard let fecha = $0.fechaVencimiento else { return true }
                return Calendar.current.startOfDay(for: fecha) >= hoy
            }

            let total = noPagadas.reduce(0.0) { $0 + $1.monto }
            let totalVencidas = vencidas.reduce(0.0) { $0 + $1.monto }

            lblCobrosTotal?.text = noPagadas.isEmpty ? "S/ --" : formatCurrency(total)
            lblVencidos?.text = vencidas.isEmpty ? "Sin vencidos" : "\(vencidas.count) vencido(s) · \(formatCurrency(totalVencidas))"
            lblPendientes?.text = pendientes.isEmpty ? "Sin pendientes" : "\(pendientes.count) pendiente(s) por cobrar"
            lblDetalleTesoreria?.text = noPagadas.isEmpty
                ? "Todavia no hay ventas al credito registradas."
                : "Clientes con deuda activa por ventas al credito."
            lblDetalleCobros?.text = noPagadas.isEmpty
                ? "Cuando registres cuotas apareceran aqui."
                : "Revisa y cobra cuotas desde este modulo."
        } catch {
            lblCobrosTotal?.text = "S/ --"
            lblVencidos?.text = "Sin vencidos"
            lblPendientes?.text = "Sin pendientes"
            lblDetalleTesoreria?.text = "No se pudo cargar la deuda de clientes."
            lblDetalleCobros?.text = "Intenta nuevamente."
        }
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

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "S/ 0"
    }

    @IBAction private func btnCerrarSesion(_ sender: UIButton) {
        UserDefaults.standard.removeObject(forKey: "usuarioLogueado")
        UserDefaults.standard.removeObject(forKey: "rolLogueado")
        cerrarSesionUniversal()
    }

    @IBAction private func btnIrCuotas(_ sender: UIButton) {
        performSegue(withIdentifier: "mostrarPantallaCuotas", sender: nil)
    }
}
