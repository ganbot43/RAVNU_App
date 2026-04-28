import Foundation

final class AppSession {
    static let shared = AppSession()

    private enum Keys {
        static let usuario = "usuarioLogueado"
        static let rol = "rolLogueado"
        static let userId = "userDocumentId"
        static let authUid = "authUid"
        static let email = "userEmail"
        static let adminAPIAuthToken = "adminAPIAuthToken"
        static let remoteEnabled = "remoteDataEnabled"
        static let lastSync = "remoteLastSyncDate"
        static let remoteWorkerCount = "remoteWorkerCount"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var usuarioLogueado: String? {
        get { defaults.string(forKey: Keys.usuario) }
        set { defaults.set(newValue, forKey: Keys.usuario) }
    }

    var rolLogueado: String? {
        get { defaults.string(forKey: Keys.rol) }
        set { defaults.set(newValue, forKey: Keys.rol) }
    }

    var userDocumentId: String? {
        get { defaults.string(forKey: Keys.userId) }
        set { defaults.set(newValue, forKey: Keys.userId) }
    }

    var authUid: String? {
        get { defaults.string(forKey: Keys.authUid) }
        set { defaults.set(newValue, forKey: Keys.authUid) }
    }

    var userEmail: String? {
        get { defaults.string(forKey: Keys.email) }
        set { defaults.set(newValue, forKey: Keys.email) }
    }

    var adminAPIAuthToken: String? {
        get { defaults.string(forKey: Keys.adminAPIAuthToken) }
        set { defaults.set(newValue, forKey: Keys.adminAPIAuthToken) }
    }

    var remoteDataEnabled: Bool {
        get { defaults.object(forKey: Keys.remoteEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.remoteEnabled) }
    }

    var lastRemoteSyncAt: Date? {
        get { defaults.object(forKey: Keys.lastSync) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSync) }
    }

    var remoteWorkerCount: Int {
        get { defaults.integer(forKey: Keys.remoteWorkerCount) }
        set { defaults.set(newValue, forKey: Keys.remoteWorkerCount) }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.usuario)
        defaults.removeObject(forKey: Keys.rol)
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.authUid)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.adminAPIAuthToken)
    }
}
