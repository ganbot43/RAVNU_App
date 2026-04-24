import UIKit

final class RoleTabBarController: UITabBarController {

    private var allRoleTabs: [UIViewController] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        allRoleTabs = viewControllers ?? []
        configureTabsForCurrentRole()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureTabsForCurrentRole()
    }

    private func configureTabsForCurrentRole() {
        if allRoleTabs.isEmpty {
            allRoleTabs = viewControllers ?? []
        }

        let allowedTabs = allowedTabTitles(for: RoleAccessControl.currentRole)
        let filteredTabs = allRoleTabs.filter { controller in
            guard let title = controller.tabBarItem.title else { return false }
            return allowedTabs.contains(title)
        }

        let currentTitles = viewControllers?.map { $0.tabBarItem.title }
        let filteredTitles = filteredTabs.map { $0.tabBarItem.title }
        if currentTitles != filteredTitles {
            setViewControllers(filteredTabs, animated: false)
        }
    }

    private func allowedTabTitles(for role: AppRole) -> Set<String> {
        switch role {
        case .admin:
            return ["Inicio", "Ventas", "Clientes", "Almacén", "Más"]
        case .supervisor:
            return ["Inicio", "Ventas", "Clientes", "Almacén", "Más"]
        case .cajero:
            return ["Inicio", "Ventas", "Clientes", "Más"]
        case .almacen:
            return ["Inicio", "Almacén", "Más"]
        default:
            return ["Inicio", "Más"]
        }
    }
}
