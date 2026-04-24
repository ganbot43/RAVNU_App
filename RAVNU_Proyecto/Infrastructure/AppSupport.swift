import CoreData
import UIKit

enum AppCoreData {
    private static let fallbackContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RAVNU_Proyecto")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("No se pudo crear el contenedor Core Data de respaldo: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    static var persistentContainer: NSPersistentContainer {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            assertionFailure("AppDelegate no disponible. Se usará un contenedor en memoria.")
            return fallbackContainer
        }
        return appDelegate.persistentContainer
    }

    static var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    static func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }

    static func saveIfNeeded(_ context: NSManagedObjectContext = viewContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

extension UIViewController {
    func presentPermissionDeniedAlert(message: String) {
        let alert = UIAlertController(
            title: "Acceso restringido",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
