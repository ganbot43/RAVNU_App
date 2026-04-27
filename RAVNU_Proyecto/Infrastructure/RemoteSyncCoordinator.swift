import Foundation

final class RemoteSyncCoordinator {

    // Instancia única de la clase
    static let shared = RemoteSyncCoordinator()

    // Estados posibles de la sincronización
    enum SyncState: String {
        case idle               // Sin actividad
        case waitingForFirebase // Firebase no está listo aún
        case ready              // Listo para sincronizar
        case syncing            // Sincronizando (uso futuro)
        case failed             // Error
    }

    private(set) var firebase: FirebaseBootstrap?   // Configuración de Firebase
    private(set) var state: SyncState = .idle        // Estado actual
    private(set) var lastErrorMessage: String?       // Último error registrado

    private init() {}

    // Configura Firebase y actualiza el estado inicial
    func configure(firebase: FirebaseBootstrap) {
        self.firebase = firebase
        state = firebase.isConfigured ? .ready : .waitingForFirebase
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
    }

    // Retorna true si Firebase está listo y el usuario tiene sincronización activada
    var isRemoteReady: Bool {
        guard let firebase else { return false }
        return AppSession.shared.remoteDataEnabled && firebase.isConfigured
    }

    // Intenta iniciar la sincronización validando las condiciones necesarias
    func startInitialSyncIfPossible() {

        // Firebase debe estar configurado
        guard let firebase else {
            state = .failed
            lastErrorMessage = "FirebaseBootstrap no fue configurado."
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        // El usuario debe tener la sincronización remota activada
        guard AppSession.shared.remoteDataEnabled else {
            state = .idle
            lastErrorMessage = nil
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        // Firebase debe estar inicializado correctamente
        guard firebase.isConfigured else {
            state = .waitingForFirebase
            lastErrorMessage = firebase.configurationMessage
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        // Todo listo: actualizamos estado y registramos la fecha de sincronización
        state = .ready
        lastErrorMessage = nil
        AppSession.shared.lastRemoteSyncAt = Date()
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)

        // TODO: Descargar datos de Firestore y actualizar el caché local
    }
}
