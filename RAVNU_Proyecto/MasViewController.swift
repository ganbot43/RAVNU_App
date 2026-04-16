import CoreData
import UIKit

class MasViewController: UIViewController {

    @IBOutlet weak var lblNombre: UILabel!
    @IBOutlet weak var lblRol: UILabel!
    @IBOutlet weak var lblIniciales: UILabel!
    @IBOutlet weak var lblCobrosTotal: UILabel!
    @IBOutlet weak var lblVencidos: UILabel!
    @IBOutlet weak var lblPendientes: UILabel!

    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarDatosUsuario()
        cargarDatosCuotas()
    }

    // MARK: - Datos

    private func cargarDatosUsuario() {
        let nombre = UserDefaults.standard.string(forKey: "usuarioLogueado") ?? "Usuario"
        let rol = UserDefaults.standard.string(forKey: "rolLogueado") ?? ""

        lblNombre.text = nombre

        let iniciales = nombre.components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
        lblIniciales.text = iniciales.isEmpty ? "U" : iniciales

        switch rol {
        case "Admin": lblRol.text = "Administrador"
        case "Cajero": lblRol.text = "Cajero"
        case "Super": lblRol.text = "Supervisor"
        case "Almacen": lblRol.text = "Almacenero"
        default: lblRol.text = rol
        }
    }

    private func cargarDatosCuotas() {
        let request: NSFetchRequest<CuotaEntity> = CuotaEntity.fetchRequest()
        do {
            let cuotas = try context.fetch(request)
            let noPagadas = cuotas.filter { !$0.pagada }
            let total = noPagadas.reduce(0.0) { $0 + $1.monto }
            lblCobrosTotal.text = "S/\(Int(total))"

            let hoy = Date()
            let vencidas = noPagadas.filter {
                guard let fecha = $0.fechaVencimiento else { return false }
                return fecha < hoy
            }
            let pendientes = noPagadas.filter {
                guard let fecha = $0.fechaVencimiento else { return true }
                return fecha >= hoy
            }
            let totalVencidas = vencidas.reduce(0.0) { $0 + $1.monto }

            lblVencidos.text = "\(vencidas.count) vencidos · S/\(Int(totalVencidas))"
            lblPendientes.text = "\(pendientes.count) pendientes"
        } catch {
            lblCobrosTotal.text = "S/0"
            lblVencidos.text = "0 vencidos"
            lblPendientes.text = "0 pendientes"
        }
    }

    // MARK: - Acciones

    @IBAction func btnCerrarSesion(_ sender: UIButton) {
        UserDefaults.standard.removeObject(forKey: "usuarioLogueado")
        UserDefaults.standard.removeObject(forKey: "rolLogueado")
        cerrarSesionUniversal()
    }

    @IBAction func btnIrCuotas(_ sender: UIButton) {
        performSegue(withIdentifier: "verCuotas", sender: nil)
    }
}
