import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class FirebaseBootstrap {
    static let shared = FirebaseBootstrap()

    private(set) var isConfigured = false
    private(set) var isAvailable = false
    private(set) var configurationMessage = "Firebase SDK no integrado en el proyecto."

    private init() {}

    func configureIfAvailable() {
        #if canImport(FirebaseCore)
        isAvailable = true
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = FirebaseApp.app() != nil
        configurationMessage = isConfigured
            ? "Firebase configurado correctamente."
            : "Firebase SDK presente, pero la app aun no pudo configurarse."
        #else
        isAvailable = false
        isConfigured = false
        configurationMessage = "Agrega FirebaseCore y GoogleService-Info.plist para activar modo remoto."
        #endif
    }
}
