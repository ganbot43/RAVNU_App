//
//  AppDelegate.swift
//  RAVNU_Proyecto
//
//  Created by XCODE on 8/04/26.
//

import UIKit
import CoreData
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppRuntime.shared.configure()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "RAVNU_Proyecto")
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

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
        // Entrada futura para descargar Firestore y actualizar el cache local.
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
