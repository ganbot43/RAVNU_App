import UIKit

class AdministradorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}
