import UIKit

class SupervisorViewController: UIViewController {

    @IBOutlet weak var lblNombreBienvenido: UILabel!
    var nombreBienvenido: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lblNombreBienvenido.text = "Bienvenido \(nombreBienvenido ?? "")!"
    }

    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}


