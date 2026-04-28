import CoreData
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

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

    #if canImport(SwiftUI)
    @discardableResult
    func embedHostedView<Content: View>(
        _ rootView: Content,
        in containerView: UIView? = nil,
        backgroundColor: UIColor = .clear
    ) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: rootView)
        let targetView = containerView ?? view
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = backgroundColor
        targetView?.addSubview(host.view)
        if let targetView {
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: targetView.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
            ])
        }
        host.didMove(toParent: self)
        return host
    }
    #endif
}

#if canImport(SwiftUI)
struct RoleWelcomeView: View {
    let title: String
    let subtitle: String
    let badgeText: String
    let accentColor: Color
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 16) {
                    Text(badgeText.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accentColor)

                    Text(title)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Color(.label))

                    Text(subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Arquitectura híbrida activa")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(.label))

                    Text("La navegación principal sigue en Storyboard con UINavigationController y UITabBarController. El contenido visual de cada módulo debe migrarse a SwiftUI embebido.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

                Button(action: onLogout) {
                    Text("Cerrar sesión")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}
#endif
