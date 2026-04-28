import UIKit
import SwiftUI

class SupervisorViewController: UIViewController {

    var nombreBienvenido: String?
    private var hostingController: UIHostingController<RoleWelcomeView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        hostingController = embedHostedView(crearVistaRaiz())
    }

    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }

    private func crearVistaRaiz() -> RoleWelcomeView {
        RoleWelcomeView(
            title: "Bienvenido \(nombreBienvenido ?? "")",
            subtitle: "Puedes operar ventas, clientes, cobros, almacén y supervisión financiera según la matriz de permisos activa.",
            badgeText: "Supervisor",
            accentColor: Color(.systemPurple),
            onLogout: { [weak self] in
                self?.cerrarSesionUniversal()
            }
        )
    }
}
