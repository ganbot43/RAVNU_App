import UIKit
import CoreData

class LoginViewController: UIViewController {

    @IBOutlet weak var txtUsuario: UITextField!
    
    @IBOutlet weak var txtContraseña: UITextField!
    
    @IBOutlet weak var btnSelectorRol: UIButton!
    
    var rolSeleccionado: String = ""
    private lazy var contexto: NSManagedObjectContext? = {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        seedUsuariosInicialesSiEsNecesario()
        
        let roles = [
            UIAction(title: "Administrador", handler: { _ in
                self.rolSeleccionado = "Admin"
                self.btnSelectorRol.setTitle("Administrador", for: .normal)
            }),
            UIAction(title: "Cajero", handler: { _ in
                self.rolSeleccionado = "Cajero"
                self.btnSelectorRol.setTitle("Cajero", for: .normal)
            }),
            UIAction(title: "Supervisor", handler: { _ in
                self.rolSeleccionado = "Super"
                self.btnSelectorRol.setTitle("Supervisor", for: .normal)
            }),
            UIAction(title: "Almacenero", handler: { _ in
                self.rolSeleccionado = "Almacen"
                self.btnSelectorRol.setTitle("Almacenero", for: .normal)
            })
        ]
        
        btnSelectorRol.menu = UIMenu(title: "Seleccione su cargo", children: roles)
        btnSelectorRol.showsMenuAsPrimaryAction = true
        btnSelectorRol.changesSelectionAsPrimaryAction = true
        
    }
    
    @IBAction func btnIngresar(_ sender: UIButton) {
        guard let usuario = txtUsuario.text, !usuario.isEmpty,
              let password = txtContraseña.text, !password.isEmpty else {
            mostrarAlerta(mensaje: "Completa usuario y contraseña.")
            return
        }
        
        guard !rolSeleccionado.isEmpty else {
            mostrarAlerta(mensaje: "Selecciona un rol antes de ingresar.")
            return
        }
        
        guard let login = buscarLogin(usuario: usuario, contrasena: password, rol: rolSeleccionado) else {
            mostrarAlerta(mensaje: "Credenciales incorrectas para el rol seleccionado.")
            return
        }
        
        let datos = "\(login.usuario ?? usuario) - \(login.rol ?? rolSeleccionado)"

        UserDefaults.standard.set(login.usuario ?? usuario, forKey: "usuarioLogueado")
        UserDefaults.standard.set(login.rol ?? rolSeleccionado, forKey: "rolLogueado")

        switch rolSeleccionado {
        case "Admin", "Cajero", "Super", "Almacen":
            performSegue(withIdentifier: "verCajero", sender: datos)
        default:
            mostrarAlerta(mensaje: "Rol no valido.")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        configurarBienvenida(en: segue.destination, nombre: sender as? String)
    }

    private func configurarBienvenida(en destination: UIViewController, nombre: String?) {
        if let bienvenida = destination as? AdministradorViewController {
            bienvenida.nombreBienvenido = nombre
        } else if let bienvenida = destination as? CajeroViewController {
            bienvenida.nombreBienvenido = nombre
        } else if let bienvenida = destination as? SupervisorViewController {
            bienvenida.nombreBienvenido = nombre
        } else if let bienvenida = destination as? AlmaceneroViewController {
            bienvenida.nombreBienvenido = nombre
        } else if let tabBarController = destination as? UITabBarController {
            tabBarController.viewControllers?.forEach { configurarBienvenida(en: $0, nombre: nombre) }
        } else if let navigationController = destination as? UINavigationController,
                  let topViewController = navigationController.topViewController {
            configurarBienvenida(en: topViewController, nombre: nombre)
        }
    }
    
    private func buscarLogin(usuario: String, contrasena: String, rol: String) -> LoginEntity? {
        guard let contexto else { return nil }
        
        let request: NSFetchRequest<LoginEntity> = LoginEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "usuario ==[c] %@ AND contrasena == %@ AND rol == %@",
            usuario,
            contrasena,
            rol
        )
        
        do {
            return try contexto.fetch(request).first
        } catch {
            print("Error consultando Core Data: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func seedUsuariosInicialesSiEsNecesario() {
        guard let contexto else { return }
        
        let request: NSFetchRequest<LoginEntity> = LoginEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let existeData = try contexto.count(for: request) > 0
            guard !existeData else { return }
            
            let usuariosIniciales = [
                ("Ruth", "1234", "Admin"),
                ("Ruth", "1234", "Cajero"),
                ("Ruth", "1234", "Super"),
                ("Ruth", "1234", "Almacen")
            ]
            
            for usuario in usuariosIniciales {
                let nuevoLogin = LoginEntity(context: contexto)
                nuevoLogin.id = UUID()
                nuevoLogin.usuario = usuario.0
                nuevoLogin.contrasena = usuario.1
                nuevoLogin.rol = usuario.2
            }
            
            try contexto.save()
        } catch {
            print("Error guardando usuarios iniciales: \(error.localizedDescription)")
        }
    }
    
    private func mostrarAlerta(mensaje: String) {
        let alerta = UIAlertController(title: "Login", message: mensaje, preferredStyle: .alert)
        alerta.addAction(UIAlertAction(title: "OK", style: .default))
        present(alerta, animated: true)
    }
}

extension UIViewController {
    func cerrarSesionUniversal() {
        print("Cerrando sesión de Ruth...")
        self.dismiss(animated: true, completion: nil)
    }
}
