import UIKit
import CoreData
import SwiftUI
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class LoginViewController: UIViewController {

    @IBOutlet weak var txtUsuario: UITextField!
    @IBOutlet weak var txtContraseña: UITextField!

    private var hostingController: UIHostingController<LoginHybridView>?
    private let estadoFormulario = EstadoFormularioLogin()
    private lazy var contexto: NSManagedObjectContext = AppCoreData.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        configurarModoLogin()
        configurarVistaHibrida()
    }

    private var usaFirebase: Bool {
        FirebaseBootstrap.shared.isConfigured
    }

    private func configurarModoLogin() {
        txtUsuario.placeholder = "Correo electrónico"
        txtContraseña.isSecureTextEntry = true
    }

    private func configurarVistaHibrida() {
        txtUsuario.isHidden = true
        txtContraseña.isHidden = true
        view.subviews
            .filter { $0 is UIButton && $0 !== txtUsuario && $0 !== txtContraseña }
            .forEach { $0.isHidden = true }

        let host = UIHostingController(rootView: crearVistaLogin())
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

    private func actualizarVistaHibrida() {
        hostingController?.rootView = crearVistaLogin()
    }

    private func crearVistaLogin() -> LoginHybridView {
        LoginHybridView(
            estado: estadoFormulario,
            usaFirebase: usaFirebase,
            onLogin: { [weak self] in
                self?.iniciarSesion(
                    usuario: self?.estadoFormulario.usuario ?? "",
                    contraseña: self?.estadoFormulario.contraseña ?? "",
                    rol: self?.estadoFormulario.rolSeleccionado ?? ""
                )
            }
        )
    }

    @IBAction func btnIngresar(_ sender: UIButton) {
        let usuario = (txtUsuario.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let contraseña = (txtContraseña.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        iniciarSesion(usuario: usuario, contraseña: contraseña, rol: estadoFormulario.rolSeleccionado)
    }

    private func iniciarSesion(usuario: String, contraseña: String, rol: String) {
        guard !usuario.isEmpty, !contraseña.isEmpty else {
            mostrarAlerta(mensaje: "Completa usuario y contraseña.")
            return
        }

        guard usaFirebase else {
            mostrarAlerta(mensaje: "Firebase no está configurado. Verifica la integración y vuelve a intentar.")
            return
        }

        guard esCorreoValido(usuario) else {
            mostrarAlerta(mensaje: "Ingresa un correo válido para iniciar sesión con Firebase.")
            return
        }

        iniciarSesionConFirebase(correo: usuario, contraseña: contraseña)
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func iniciarSesionConFirebase(correo: String, contraseña: String) {
        Auth.auth().signIn(withEmail: correo, password: contraseña) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.mostrarAlerta(mensaje: self.mensajeErrorFirebase(error))
                return
            }

            guard let user = result?.user else {
                self.mostrarAlerta(mensaje: "No se pudo obtener el usuario autenticado.")
                return
            }

            self.obtenerPerfilRemoto(usuarioAuth: user)
        }
    }

    private func obtenerPerfilRemoto(usuarioAuth: User) {
        let firestore = Firestore.firestore()
        let lookupRef = firestore.collection("users_lookup").document(usuarioAuth.uid)

        lookupRef.getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.mostrarAlerta(mensaje: "No se pudo consultar el acceso del usuario: \(error.localizedDescription)")
                return
            }

            guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                self.mostrarAlerta(mensaje: "No existe el acceso del usuario en users_lookup. Solicita que un administrador regularice tu cuenta.")
                return
            }

            let estaActivo = data["active"] as? Bool ?? true
            guard estaActivo else {
                self.mostrarAlerta(mensaje: "Tu usuario está inactivo. Contacta al administrador.")
                return
            }

            guard let userId = data["userId"] as? String, userId.isEmpty == false else {
                self.mostrarAlerta(mensaje: "El acceso del usuario no tiene un perfil asociado.")
                return
            }

            firestore.collection("users").document(userId).getDocument { [weak self] userSnapshot, userError in
                guard let self else { return }

                if let userError {
                    self.mostrarAlerta(mensaje: "No se pudo obtener el perfil del usuario: \(userError.localizedDescription)")
                    return
                }

                guard let userSnapshot, userSnapshot.exists else {
                    self.mostrarAlerta(mensaje: "No existe el perfil del usuario asociado al acceso.")
                    return
                }

                self.completarLoginRemoto(documento: userSnapshot)
            }
        }
    }

    private func completarLoginRemoto(documento: DocumentSnapshot) {
        guard let data = documento.data() else {
            mostrarAlerta(mensaje: "No se pudo leer el perfil remoto del usuario.")
            return
        }
        let rolCrudo = (data["roleId"] as? String) ?? (data["role"] as? String) ?? ""
        let rol = normalizarRol(rolCrudo)
        let estaActivo = data["active"] as? Bool ?? true

        guard estaActivo else {
            mostrarAlerta(mensaje: "Tu usuario está inactivo. Contacta al administrador.")
            return
        }

        guard !rol.isEmpty else {
            mostrarAlerta(mensaje: "El usuario no tiene un rol válido configurado en Firestore.")
            return
        }

        let nombreMostrado =
            (data["username"] as? String) ??
            (data["fullName"] as? String) ??
            (data["email"] as? String) ??
            (estadoFormulario.usuario.isEmpty ? "Usuario" : estadoFormulario.usuario)

        let datos = "\(nombreMostrado) - \(rol)"
        AppSession.shared.usuarioLogueado = nombreMostrado
        AppSession.shared.rolLogueado = rol
        performSegue(withIdentifier: "verCajero", sender: datos)
    }
    #else
    private func iniciarSesionConFirebase(correo: String, contraseña: String) {
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

    private func mostrarAlerta(mensaje: String) {
        let alerta = UIAlertController(title: "Login", message: mensaje, preferredStyle: .alert)
        alerta.addAction(UIAlertAction(title: "OK", style: .default))
        present(alerta, animated: true)
    }

    private func esCorreoValido(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    #if canImport(FirebaseAuth)
    private func mensajeErrorFirebase(_ error: Error) -> String {
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

    private func normalizarRol(_ valorCrudo: String) -> String {
        switch valorCrudo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin", "administrador":
            return "Admin"
        case "cajero":
            return "Cajero"
        case "super", "supervisor":
            return "Super"
        case "almacen", "almacenero":
            return "Almacen"
        default:
            return valorCrudo
        }
    }
}

final class EstadoFormularioLogin: ObservableObject {
    @Published var usuario: String = ""
    @Published var contraseña: String = ""
    @Published var rolSeleccionado: String = "Admin"
}

extension UIViewController {
    func cerrarSesionUniversal() {
        self.dismiss(animated: true, completion: nil)
    }
}
