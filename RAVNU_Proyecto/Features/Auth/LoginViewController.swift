import UIKit
import CoreData
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class LoginViewController: UIViewController {

    @IBOutlet weak var txtUsuario: UITextField!
    
    @IBOutlet weak var txtContraseña: UITextField!

    private weak var btnSelectorRol: UIButton?
    
    
    var rolSeleccionado: String = ""
    private lazy var contexto: NSManagedObjectContext = AppCoreData.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureLoginMode()
    }

    private var isRemoteLoginEnabled: Bool {
        FirebaseBootstrap.shared.isConfigured
    }

    private func configureLoginMode() {
        txtUsuario.placeholder = isRemoteLoginEnabled ? "Correo electrónico" : "Usuario"
        txtContraseña.isSecureTextEntry = true

        if isRemoteLoginEnabled {
            btnSelectorRol?.isHidden = true
            btnSelectorRol?.isEnabled = false
        } else {
            seedUsuariosInicialesSiEsNecesario()
            configureLocalRoleSelector()
        }
    }

    private func configureLocalRoleSelector() {
        let roles = [
            UIAction(title: "Administrador", handler: { _ in
                self.rolSeleccionado = "Admin"
                self.btnSelectorRol?.setTitle("Administrador", for: .normal)
            }),
            UIAction(title: "Cajero", handler: { _ in
                self.rolSeleccionado = "Cajero"
                self.btnSelectorRol?.setTitle("Cajero", for: .normal)
            }),
            UIAction(title: "Supervisor", handler: { _ in
                self.rolSeleccionado = "Super"
                self.btnSelectorRol?.setTitle("Supervisor", for: .normal)
            }),
            UIAction(title: "Almacenero", handler: { _ in
                self.rolSeleccionado = "Almacen"
                self.btnSelectorRol?.setTitle("Almacenero", for: .normal)
            })
        ]

        btnSelectorRol?.menu = UIMenu(title: "Seleccione su cargo", children: roles)
        btnSelectorRol?.showsMenuAsPrimaryAction = true
        btnSelectorRol?.changesSelectionAsPrimaryAction = true
    }
    
    @IBAction func btnIngresar(_ sender: UIButton) {
        let usuario = (txtUsuario.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = (txtContraseña.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !usuario.isEmpty, !password.isEmpty else {
            mostrarAlerta(mensaje: "Completa usuario y contraseña.")
            return
        }

        if isRemoteLoginEnabled {
            guard isValidEmail(usuario) else {
                mostrarAlerta(mensaje: "Ingresa un correo válido para iniciar sesión con Firebase.")
                return
            }
            loginWithFirebase(email: usuario, password: password)
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

        AppSession.shared.usuarioLogueado = login.usuario ?? usuario
        AppSession.shared.rolLogueado = login.rol ?? rolSeleccionado

        switch rolSeleccionado {
        case "Admin", "Cajero", "Super", "Almacen":
            performSegue(withIdentifier: "verCajero", sender: datos)
        default:
            mostrarAlerta(mensaje: "Rol no valido.")
        }
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func loginWithFirebase(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.mostrarAlerta(mensaje: self.firebaseLoginMessage(for: error))
                return
            }

            guard let user = result?.user else {
                self.mostrarAlerta(mensaje: "No se pudo obtener el usuario autenticado.")
                return
            }

            self.fetchRemoteProfile(for: user)
        }
    }

    private func fetchRemoteProfile(for authUser: User) {
        let usersCollection = Firestore.firestore().collection("users")

        usersCollection
            .whereField("authUid", isEqualTo: authUser.uid)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.mostrarAlerta(mensaje: "No se pudo consultar el perfil remoto: \(error.localizedDescription)")
                    return
                }

                if let document = snapshot?.documents.first {
                    self.completeRemoteLogin(with: document)
                    return
                }

                guard let email = authUser.email else {
                    self.mostrarAlerta(mensaje: "No se encontró el correo del usuario autenticado.")
                    return
                }

                usersCollection
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments { [weak self] emailSnapshot, emailError in
                        guard let self else { return }

                        if let emailError {
                            self.mostrarAlerta(mensaje: "No se pudo obtener el rol del usuario: \(emailError.localizedDescription)")
                            return
                        }

                        guard let emailDocument = emailSnapshot?.documents.first else {
                            self.mostrarAlerta(mensaje: "No existe un perfil de usuario en Firestore para este acceso.")
                            return
                        }

                        emailDocument.reference.setData(["authUid": authUser.uid], merge: true)
                        self.completeRemoteLogin(with: emailDocument)
                    }
            }
    }

    private func completeRemoteLogin(with document: QueryDocumentSnapshot) {
        let data = document.data()
        let rawRole = (data["roleId"] as? String) ?? (data["role"] as? String) ?? ""
        let role = normalizedRole(from: rawRole)
        let isActive = data["active"] as? Bool ?? true

        guard isActive else {
            mostrarAlerta(mensaje: "Tu usuario está inactivo. Contacta al administrador.")
            return
        }

        guard !role.isEmpty else {
            mostrarAlerta(mensaje: "El usuario no tiene un rol válido configurado en Firestore.")
            return
        }

        let displayName =
            (data["username"] as? String) ??
            (data["fullName"] as? String) ??
            (data["email"] as? String) ??
            (txtUsuario.text ?? "Usuario")

        let datos = "\(displayName) - \(role)"
        AppSession.shared.usuarioLogueado = displayName
        AppSession.shared.rolLogueado = role
        performSegue(withIdentifier: "verCajero", sender: datos)
    }
    #else
    private func loginWithFirebase(email: String, password: String) {
        mostrarAlerta(mensaje: "Firebase Auth y Firestore aún no están integrados en el target.")
    }
    #endif
    
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

    private func isValidEmail(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    #if canImport(FirebaseAuth)
    private func firebaseLoginMessage(for error: Error) -> String {
        guard let authError = error as NSError?,
              let code = AuthErrorCode(rawValue: authError.code) else {
            return "No se pudo iniciar sesión: \(error.localizedDescription)"
        }

        switch code {
        case .invalidEmail:
            return "El correo no tiene un formato válido."
        case .userNotFound:
            return "No existe un usuario con ese correo en Firebase Authentication."
        case .wrongPassword, .invalidCredential:
            return "La contraseña o las credenciales no son válidas."
        case .userDisabled:
            return "Este usuario está deshabilitado en Firebase Authentication."
        case .networkError:
            return "No se pudo conectar con Firebase. Revisa tu conexión."
        default:
            return "No se pudo iniciar sesión: \(error.localizedDescription)"
        }
    }
    #endif

    private func normalizedRole(from rawValue: String) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin", "administrador":
            return "Admin"
        case "cajero":
            return "Cajero"
        case "super", "supervisor":
            return "Super"
        case "almacen", "almacenero":
            return "Almacen"
        default:
            return rawValue
        }
    }
}

extension UIViewController {
    func cerrarSesionUniversal() {
        print("Cerrando sesión de Ruth...")
        self.dismiss(animated: true, completion: nil)
    }
}
