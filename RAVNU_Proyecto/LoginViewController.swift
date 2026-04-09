//
import UIKit

class LoginViewController: UIViewController{
    
    
    
    @IBOutlet weak var txtUsuario: UITextField!
    
    
    @IBOutlet weak var txtContraseña: UITextField!
    
    @IBOutlet weak var btnSelectorRol: UIButton!
    
    var rolSeleccionado: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let roles = [
            UIAction(title: "Administrador", handler: { _ in self.rolSeleccionado = "Admin" }),
            UIAction(title: "Cajero", handler: { _ in self.rolSeleccionado = "Cajero" }),
            UIAction(title: "Supervisor", handler: { _ in self.rolSeleccionado = "Super" }),
            UIAction(title: "Almacenero", handler: { _ in self.rolSeleccionado = "Almacen" })
        ]
        
        btnSelectorRol.menu = UIMenu(title: "Seleccione su cargo", children: roles)
        btnSelectorRol.showsMenuAsPrimaryAction = true
        btnSelectorRol.changesSelectionAsPrimaryAction = true
        
    }
    
    
    @IBAction func btnIngresar(_ sender: UIButton) {
        
        // Validamos que el usuario haya escrito algo
        guard let usuario = txtUsuario.text, !usuario.isEmpty,
              let password = txtContraseña.text, !password.isEmpty else {
            print("Faltan datos")
            return
        }
        
        if usuario == "Ruth" && password == "1234" {
            
            switch rolSeleccionado {
            case "Admin":
                self.performSegue(withIdentifier: "verAdmin", sender: nil)
                
            case "Cajero":
                self.performSegue(withIdentifier: "verCajero", sender: nil)
                
            case "Super":
                self.performSegue(withIdentifier: "verSuper", sender: nil)
                
            case "Almacen":
                self.performSegue(withIdentifier: "verAlmacen", sender: nil)
                
            default:
                print("Selecciona un rol primero")
            }
            
        } else {
            print("Credenciales incorrectas")
        }
    }
    
}
extension UIViewController {
    func cerrarSesionUniversal() {
        print("Cerrando sesión de Ruth...")
        self.dismiss(animated: true, completion: nil)
    }
}
