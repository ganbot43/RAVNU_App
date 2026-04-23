import Foundation

final class RemoteSyncCoordinator {
    static let shared = RemoteSyncCoordinator()

    enum SyncState: String {
        case idle
        case waitingForFirebase
        case ready
        case syncing
        case failed
    }

    private(set) var firebase: FirebaseBootstrap?
    private(set) var state: SyncState = .idle
    private(set) var lastErrorMessage: String?

    private init() {}

    func configure(firebase: FirebaseBootstrap) {
        self.firebase = firebase
        state = firebase.isConfigured ? .ready : .waitingForFirebase
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
    }

    var isRemoteReady: Bool {
        guard let firebase else { return false }
        return AppSession.shared.remoteDataEnabled && firebase.isConfigured
    }

    func startInitialSyncIfPossible() {
        guard let firebase else {
            state = .failed
            lastErrorMessage = "FirebaseBootstrap no fue configurado."
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        guard AppSession.shared.remoteDataEnabled else {
            state = .idle
            lastErrorMessage = nil
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        guard firebase.isConfigured else {
            state = .waitingForFirebase
            lastErrorMessage = firebase.configurationMessage
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        state = .ready
        lastErrorMessage = nil
        AppSession.shared.lastRemoteSyncAt = Date()
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
        // Punto de entrada futuro para descargar Firestore y actualizar el cache local.
    }
}
