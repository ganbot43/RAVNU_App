import Foundation
import UIKit

final class AppRuntime {
    static let shared = AppRuntime()

    let session = AppSession.shared
    let firebase = FirebaseBootstrap.shared
    let syncCoordinator = RemoteSyncCoordinator.shared

    private init() {}

    func configure() {
        firebase.configureIfAvailable()
        syncCoordinator.configure(firebase: firebase)
        NotificationCenter.default.post(name: .backendModeDidChange, object: backendMode)
    }

    var backendMode: BackendMode {
        if syncCoordinator.isRemoteReady {
            return .firebaseRemote
        }
        if firebase.isAvailable {
            return .firebasePendingConfiguration
        }
        return .localFallback
    }
}

enum BackendMode: String {
    case localFallback
    case firebasePendingConfiguration
    case firebaseRemote
}

extension Notification.Name {
    static let remoteSyncStateDidChange = Notification.Name("remoteSyncStateDidChange")
    static let backendModeDidChange = Notification.Name("backendModeDidChange")
}
