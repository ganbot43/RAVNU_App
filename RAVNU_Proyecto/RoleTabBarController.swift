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

        let role = UserDefaults.standard.string(forKey: "rolLogueado") ?? "Cajero"
        let allowedTabs = allowedTabTitles(for: role)
        let filteredTabs = allRoleTabs.filter { controller in
            guard let title = controller.tabBarItem.title else { return false }
            return allowedTabs.contains(title)
        }

        if viewControllers?.map(\.tabBarItem.title) != filteredTabs.map(\.tabBarItem.title) {
            setViewControllers(filteredTabs, animated: false)
        }
    }

    private func allowedTabTitles(for role: String) -> Set<String> {
        switch role {
        case "Admin":
            return ["Inicio", "Ventas", "Clientes", "Almacén", "Más"]
        case "Super":
            return ["Inicio", "Ventas", "Clientes", "Almacén", "Más"]
        case "Cajero":
            return ["Inicio", "Ventas", "Clientes", "Más"]
        case "Almacen":
            return ["Inicio", "Almacén", "Más"]
        default:
            return ["Inicio", "Más"]
        }
    }
}
