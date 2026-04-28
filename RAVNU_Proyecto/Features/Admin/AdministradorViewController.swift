import UIKit
import SwiftUI

class AdministradorViewController: UIViewController {

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
            subtitle: "Tienes acceso completo a ventas, clientes, almacén, compras, tesorería y RRHH.",
            badgeText: "Administrador",
            accentColor: Color(.systemBlue),
            onLogout: { [weak self] in
                self?.cerrarSesionUniversal()
            }
        )
    }
}
