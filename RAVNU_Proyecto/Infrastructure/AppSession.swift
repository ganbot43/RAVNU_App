import Foundation

final class AppSession {
    static let shared = AppSession()

    private enum Keys {
        static let usuario = "usuarioLogueado"
        static let rol = "rolLogueado"
        static let remoteEnabled = "remoteDataEnabled"
        static let lastSync = "remoteLastSyncDate"
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

    var remoteDataEnabled: Bool {
        get { defaults.object(forKey: Keys.remoteEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.remoteEnabled) }
    }

    var lastRemoteSyncAt: Date? {
        get { defaults.object(forKey: Keys.lastSync) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSync) }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.usuario)
        defaults.removeObject(forKey: Keys.rol)
    }
}
